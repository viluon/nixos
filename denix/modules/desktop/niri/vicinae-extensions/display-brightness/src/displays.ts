import { execFile } from "node:child_process";
import { promisify } from "node:util";

const run = promisify(execFile);

export type Display = {
  id: string;
  name: string;
  description: string;
  isInternal: boolean;
  percent: number;
  setPercent: (percent: number) => Promise<void>;
};

async function output(command: string, args: string[]): Promise<string> {
  const { stdout } = await run(command, args);
  return stdout;
}

async function backlights(): Promise<Display[]> {
  const listing = await output("brightnessctl", [
    "--list",
    "--machine-readable",
    "--class=backlight",
  ]);

  return listing
    .split("\n")
    .filter((line) => line.length > 0)
    .map((line) => {
      const [device, , , percent] = line.split(",");
      return {
        id: `backlight:${device}`,
        name: "Built-in display",
        description: device,
        isInternal: true,
        percent: Number.parseInt(percent, 10),
        setPercent: async (target) => {
          await run("brightnessctl", [
            "--quiet",
            `--device=${device}`,
            "set",
            `${target}%`,
          ]);
        },
      };
    });
}

type DdcMonitor = {
  bus: string;
  connector: string;
  model: string;
};

function parseDdcDetect(detection: string): DdcMonitor[] {
  return detection
    .split(/\n(?=\S)/)
    .filter((block) => block.startsWith("Display "))
    .map((block) => {
      const field = (label: string) =>
        block.match(new RegExp(`${label}:\\s*(.*)`))?.[1]?.trim() ?? "";
      return {
        bus: field("I2C bus").replace("/dev/i2c-", ""),
        connector: field("DRM connector").replace(/^card\d+-/, ""),
        model: field("Monitor").split(":")[1] || "External display",
      };
    });
}

async function ddcBrightness(
  bus: string,
): Promise<{ current: number; max: number }> {
  const [, , , current, max] = (
    await output("ddcutil", ["--bus", bus, "getvcp", "10", "--brief"])
  )
    .trim()
    .split(/\s+/);
  return {
    current: Number.parseInt(current, 10),
    max: Number.parseInt(max, 10),
  };
}

async function ddcDisplay(monitor: DdcMonitor): Promise<Display> {
  const { current, max } = await ddcBrightness(monitor.bus);
  return {
    id: `ddc:${monitor.bus}`,
    name: monitor.model,
    description: monitor.connector,
    isInternal: false,
    percent: Math.round((current / max) * 100),
    setPercent: async (target) => {
      await run("ddcutil", [
        "--bus",
        monitor.bus,
        "--noverify",
        "setvcp",
        "10",
        `${Math.round((target / 100) * max)}`,
      ]);
    },
  };
}

async function ddcDisplays(): Promise<Display[]> {
  const monitors = parseDdcDetect(
    await output("ddcutil", ["detect", "--brief"]),
  );
  return Promise.all(monitors.map(ddcDisplay));
}

export async function detectDisplays(): Promise<Display[]> {
  return (await Promise.all([backlights(), ddcDisplays()])).flat();
}
