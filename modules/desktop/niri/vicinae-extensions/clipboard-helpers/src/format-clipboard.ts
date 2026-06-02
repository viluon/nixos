import { Clipboard, Toast, clearSearchBar, showToast } from "@vicinae/api";

type JsonObject = Record<string, unknown>;

type ThrowableStep = {
  className: string | undefined;
  methodName: string | undefined;
  fileName: string | undefined;
  lineNumber: number | undefined;
};

type Throwable = {
  className: string | undefined;
  message: string | undefined;
  stepArray: ThrowableStep[] | undefined;
  cause: Throwable | undefined;
};

type ClipboardLink = {
  markdown: string;
  toastTitle: string;
  toastMessage: string;
};

function isJsonObject(value: unknown): value is JsonObject {
  return Boolean(value) && typeof value === "object" && !Array.isArray(value);
}

function parseHttpsUrl(raw: string): URL | undefined {
  let parsedUrl: URL;
  try {
    parsedUrl = new URL(raw);
  } catch {
    return undefined;
  }

  if (parsedUrl.protocol !== "https:") {
    return undefined;
  }

  return parsedUrl;
}

function getPathSegments(parsedUrl: URL): string[] {
  return parsedUrl.pathname
    .split("/")
    .map((segment) => segment.trim())
    .filter((segment) => segment.length > 0);
}

function parseGithubPullRequestUrl(raw: string): ClipboardLink | undefined {
  const parsedUrl = parseHttpsUrl(raw);
  if (parsedUrl === undefined) {
    return undefined;
  }

  if (!parsedUrl.hostname.toLowerCase().includes("github")) {
    return undefined;
  }

  const segments = getPathSegments(parsedUrl);
  const pullIndex = segments.findIndex((segment) => segment === "pull");

  if (pullIndex < 2 || pullIndex + 1 >= segments.length) {
    return undefined;
  }

  const pullNumber = segments[pullIndex + 1];
  if (!/^\d+$/.test(pullNumber)) {
    return undefined;
  }

  const repository = segments[pullIndex - 1];

  return {
    markdown: `[${repository}#${pullNumber}](${raw})`,
    toastTitle: "Copied markdown pull link",
    toastMessage: `${repository}#${pullNumber}`,
  };
}

function parseYouTrackIssueUrl(raw: string): ClipboardLink | undefined {
  const parsedUrl = parseHttpsUrl(raw);
  if (parsedUrl === undefined) {
    return undefined;
  }

  if (!parsedUrl.hostname.toLowerCase().includes("youtrack")) {
    return undefined;
  }

  const segments = getPathSegments(parsedUrl);
  if (
    segments[0] !== "issue" ||
    (segments.length !== 2 && segments.length !== 3)
  ) {
    return undefined;
  }

  const issueId = segments[1];
  if (!/^[A-Za-z][A-Za-z0-9]*-\d+$/.test(issueId)) {
    return undefined;
  }

  return {
    markdown: `[${issueId}](${raw})`,
    toastTitle: "Copied markdown issue link",
    toastMessage: issueId,
  };
}

function parseClipboardLink(raw: string): ClipboardLink | undefined {
  return parseGithubPullRequestUrl(raw) ?? parseYouTrackIssueUrl(raw);
}

function parseThrowableStep(value: unknown): ThrowableStep | undefined {
  if (!isJsonObject(value)) {
    return undefined;
  }

  const className =
    typeof value.className === "string" ? value.className : undefined;
  const methodName =
    typeof value.methodName === "string" ? value.methodName : undefined;
  const fileName =
    typeof value.fileName === "string" ? value.fileName : undefined;
  const lineNumber =
    typeof value.lineNumber === "number" ? value.lineNumber : undefined;

  if (
    className === undefined &&
    methodName === undefined &&
    fileName === undefined &&
    lineNumber === undefined
  ) {
    return undefined;
  }

  return {
    className,
    methodName,
    fileName,
    lineNumber,
  };
}

function parseThrowable(value: unknown): Throwable | undefined {
  if (!isJsonObject(value)) {
    return undefined;
  }

  const className =
    typeof value.className === "string" ? value.className : undefined;
  const message = typeof value.message === "string" ? value.message : undefined;
  const cause = parseThrowable(value.cause);

  const rawSteps = Array.isArray(value.stepArray) ? value.stepArray : [];
  const stepArray = rawSteps
    .map((rawStep) => parseThrowableStep(rawStep))
    .filter((step): step is ThrowableStep => step !== undefined);

  if (
    className === undefined &&
    message === undefined &&
    stepArray.length === 0 &&
    cause === undefined
  ) {
    return undefined;
  }

  return {
    className,
    message,
    stepArray: stepArray.length > 0 ? stepArray : undefined,
    cause: cause ?? undefined,
  };
}

function findThrowable(value: unknown): Throwable | undefined {
  if (Array.isArray(value)) {
    for (const item of value) {
      const found = findThrowable(item);
      if (found !== undefined) {
        return found;
      }
    }
    return undefined;
  }

  if (!isJsonObject(value)) {
    return undefined;
  }

  if ("throwable" in value) {
    const directThrowable = parseThrowable(value.throwable);
    if (directThrowable !== undefined) {
      return directThrowable;
    }
  }

  const selfThrowable = parseThrowable(value);
  if (
    selfThrowable !== undefined &&
    (selfThrowable.stepArray || selfThrowable.cause)
  ) {
    return selfThrowable;
  }

  for (const nested of Object.values(value)) {
    const found = findThrowable(nested);
    if (found !== undefined) {
      return found;
    }
  }

  return undefined;
}

function formatSourceLocation(
  fileName: string | undefined,
  lineNumber: number | undefined,
): string {
  if (fileName === undefined) {
    return "Unknown Source";
  }

  if (lineNumber === undefined || lineNumber < 0) {
    return fileName;
  }

  return `${fileName}:${lineNumber}`;
}

function formatThrowableStep(step: ThrowableStep): string {
  const className = step.className ?? "UnknownClass";
  const methodName = step.methodName ?? "unknownMethod";
  const location = formatSourceLocation(step.fileName, step.lineNumber);

  return `\tat ${className}.${methodName}(${location})`;
}

function appendThrowableLines(
  outputLines: string[],
  throwable: Throwable,
  asCause: boolean,
): void {
  const className = throwable.className ?? "java.lang.RuntimeException";
  const messageSuffix = throwable.message ? `: ${throwable.message}` : "";
  const header = `${className}${messageSuffix}`;
  outputLines.push(asCause ? `Caused by: ${header}` : header);

  for (const step of throwable.stepArray ?? []) {
    outputLines.push(formatThrowableStep(step));
  }

  if (throwable.cause !== undefined) {
    appendThrowableLines(outputLines, throwable.cause, true);
  }
}

function formatThrowableStackTrace(throwable: Throwable): string {
  const outputLines: string[] = [];
  appendThrowableLines(outputLines, throwable, false);
  return outputLines.join("\n");
}

function parseThrowableStackTrace(raw: string): string | undefined {
  let parsedPayload: unknown;
  try {
    parsedPayload = JSON.parse(raw);
  } catch {
    return undefined;
  }

  const throwable = findThrowable(parsedPayload);
  if (throwable === undefined) {
    return undefined;
  }

  return formatThrowableStackTrace(throwable);
}

export default async function formatClipboard(): Promise<void> {
  await clearSearchBar();

  const clipboardText = await Clipboard.readText();
  const trimmedText = clipboardText?.trim();

  if (!trimmedText) {
    await showToast({
      style: Toast.Style.Failure,
      title: "Clipboard empty",
    });
    return;
  }

  const clipboardLink = parseClipboardLink(trimmedText);
  if (clipboardLink !== undefined) {
    await Clipboard.copy(clipboardLink.markdown);
    await showToast({
      style: Toast.Style.Success,
      title: clipboardLink.toastTitle,
      message: clipboardLink.toastMessage,
    });
    return;
  }

  const stackTrace = parseThrowableStackTrace(trimmedText);
  if (stackTrace !== undefined) {
    await Clipboard.copy(stackTrace);
    await showToast({
      style: Toast.Style.Success,
      title: "Copied Java stack trace",
    });
    return;
  }

  await showToast({
    style: Toast.Style.Failure,
    title: "Clipboard format unsupported",
    message:
      "Need GitHub pull URL, YouTrack issue URL, or JSON payload with throwable",
  });
}
