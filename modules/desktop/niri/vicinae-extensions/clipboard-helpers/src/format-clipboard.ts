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

const issueKeyPattern = /^[A-Za-z][A-Za-z0-9]*-\d+$/;

type LinkParser = (parsedUrl: URL, raw: string) => ClipboardLink | undefined;

function hostIncludes(parsedUrl: URL, keyword: string): boolean {
  return parsedUrl.hostname.toLowerCase().includes(keyword);
}

function makeLink(raw: string, label: string, kind: string): ClipboardLink {
  return {
    markdown: `[${label}](${raw})`,
    toastTitle: `Copied markdown ${kind} link`,
    toastMessage: label,
  };
}

function parseGithubRepoRef(
  parsedUrl: URL,
  raw: string,
): ClipboardLink | undefined {
  if (!hostIncludes(parsedUrl, "github")) {
    return undefined;
  }

  const segments = getPathSegments(parsedUrl);
  const refIndex = segments.findIndex(
    (segment) => segment === "pull" || segment === "issues",
  );

  if (refIndex < 2 || refIndex + 1 >= segments.length) {
    return undefined;
  }

  const number = segments[refIndex + 1];
  if (!/^\d+$/.test(number)) {
    return undefined;
  }

  const repository = segments[refIndex - 1];
  const kind = segments[refIndex] === "pull" ? "pull" : "issue";

  return makeLink(raw, `${repository}#${number}`, kind);
}

function makeIssueTrackerParser(
  hostKeyword: string,
  pathKeyword: string,
): LinkParser {
  return (parsedUrl, raw) => {
    if (!hostIncludes(parsedUrl, hostKeyword)) {
      return undefined;
    }

    const segments = getPathSegments(parsedUrl);
    if (segments[0] !== pathKeyword) {
      return undefined;
    }

    const issueId = segments[1];
    if (issueId === undefined || !issueKeyPattern.test(issueId)) {
      return undefined;
    }

    return makeLink(raw, issueId, "issue");
  };
}

const linkParsers: LinkParser[] = [
  parseGithubRepoRef,
  makeIssueTrackerParser("youtrack", "issue"),
  makeIssueTrackerParser("jira", "browse"),
];

function parseClipboardLink(raw: string): ClipboardLink | undefined {
  const parsedUrl = parseHttpsUrl(raw);
  if (parsedUrl === undefined) {
    return undefined;
  }

  for (const parser of linkParsers) {
    const link = parser(parsedUrl, raw);
    if (link !== undefined) {
      return link;
    }
  }

  return undefined;
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
      "Need GitHub, YouTrack, or Jira URL, or JSON payload with throwable",
  });
}
