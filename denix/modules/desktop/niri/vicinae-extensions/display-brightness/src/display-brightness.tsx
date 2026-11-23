import {
  Action,
  ActionPanel,
  Grid,
  Icon,
  Toast,
  showToast,
} from "@vicinae/api";
import { useEffect, useRef, useState } from "react";
import { type Display, detectDisplays } from "./displays";
import { loadPalette } from "./palette";
import { brightnessTile } from "./tile";

const step = 5;

function clamp(percent: number): number {
  return Math.min(100, Math.max(0, percent));
}

function parseTypedPercent(searchText: string): number | undefined {
  const match = searchText.trim().match(/^(\d{1,3})%?$/);
  return match ? clamp(Number.parseInt(match[1], 10)) : undefined;
}

function useCoalescingWriter() {
  const wanted = useRef(new Map<string, number>());
  const busy = useRef(new Set<string>());

  return async (display: Display, percent: number) => {
    wanted.current.set(display.id, percent);
    if (busy.current.has(display.id)) {
      return;
    }

    busy.current.add(display.id);
    try {
      let written: number | undefined;
      while (wanted.current.get(display.id) !== written) {
        written = wanted.current.get(display.id)!;
        await display.setPercent(written);
      }
    } catch (error) {
      await showToast({
        style: Toast.Style.Failure,
        title: `Failed to set ${display.name} brightness`,
        message: String(error),
      });
    } finally {
      busy.current.delete(display.id);
    }
  };
}

export default function DisplayBrightness() {
  const [displays, setDisplays] = useState<Display[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [searchText, setSearchText] = useState("");
  const [palette] = useState(loadPalette);
  const write = useCoalescingWriter();

  const refresh = async () => {
    setIsLoading(true);
    setDisplays(await detectDisplays());
    setIsLoading(false);
  };

  useEffect(() => {
    refresh();
  }, []);

  const setPercent = (
    targets: Display[],
    percentFor: (display: Display) => number,
  ) => {
    const updates = new Map(
      targets.map((display) => [display.id, clamp(percentFor(display))]),
    );
    setDisplays((current) =>
      current.map((display) => {
        const percent = updates.get(display.id);
        return percent === undefined ? display : { ...display, percent };
      }),
    );
    for (const display of targets) {
      write(display, updates.get(display.id)!);
    }
  };

  const typedPercent = parseTypedPercent(searchText);

  return (
    <Grid
      columns={Math.max(2, displays.length)}
      aspectRatio="16/9"
      isLoading={isLoading}
      filtering={false}
      searchText={searchText}
      onSearchTextChange={setSearchText}
      searchBarPlaceholder="Type a percentage and press Enter"
    >
      {displays.map((display) => (
        <Grid.Item
          key={display.id}
          id={display.id}
          content={brightnessTile(display.percent, display.isInternal, palette)}
          title={`${display.name} · ${display.percent}%`}
          subtitle={display.description}
          actions={
            <ActionPanel>
              {typedPercent !== undefined && (
                <Action
                  title={`Set to ${typedPercent}%`}
                  icon={Icon.Checkmark}
                  onAction={() => {
                    setPercent([display], () => typedPercent);
                    setSearchText("");
                  }}
                />
              )}
              <Action
                title={`Increase by ${step}%`}
                icon={Icon.Plus}
                shortcut={{ modifiers: ["ctrl"], key: "arrowRight" }}
                onAction={() =>
                  setPercent([display], ({ percent }) => percent + step)
                }
              />
              <Action
                title={`Decrease by ${step}%`}
                icon={Icon.Minus}
                shortcut={{ modifiers: ["ctrl"], key: "arrowLeft" }}
                onAction={() =>
                  setPercent([display], ({ percent }) => percent - step)
                }
              />
              <ActionPanel.Section title="All displays">
                <Action
                  title={`Increase all by ${step}%`}
                  icon={Icon.PlusCircle}
                  shortcut={{ modifiers: ["ctrl", "shift"], key: "arrowRight" }}
                  onAction={() =>
                    setPercent(displays, ({ percent }) => percent + step)
                  }
                />
                <Action
                  title={`Decrease all by ${step}%`}
                  icon={Icon.MinusCircle}
                  shortcut={{ modifiers: ["ctrl", "shift"], key: "arrowLeft" }}
                  onAction={() =>
                    setPercent(displays, ({ percent }) => percent - step)
                  }
                />
                {typedPercent !== undefined && (
                  <Action
                    title={`Set all to ${typedPercent}%`}
                    icon={Icon.CheckCircle}
                    onAction={() => {
                      setPercent(displays, () => typedPercent);
                      setSearchText("");
                    }}
                  />
                )}
              </ActionPanel.Section>
              <Action
                title="Refresh"
                icon={Icon.ArrowClockwise}
                shortcut={{ modifiers: ["ctrl"], key: "r" }}
                onAction={refresh}
              />
            </ActionPanel>
          }
        />
      ))}
    </Grid>
  );
}
