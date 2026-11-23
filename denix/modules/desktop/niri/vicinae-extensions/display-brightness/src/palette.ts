import { readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

export type Palette = {
  accent: string;
  frame: string;
  track: string;
};

export function loadPalette(): Palette {
  const base16: Record<string, string> = JSON.parse(
    readFileSync(join(homedir(), ".config/stylix/palette.json"), "utf8"),
  );
  return {
    accent: `#${base16.base0A}`,
    frame: `#${base16.base05}`,
    track: `#${base16.base02}`,
  };
}
