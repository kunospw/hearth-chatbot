// Mirrors BackendException / OfflineBackendException in
// lib/core/backend/backend_api.dart.

/** The server said no (or something went wrong there). */
export class BackendError extends Error {
  readonly status: number;
  /** A short machine word: model_limit, model_busy, not_found, unauthorized… */
  readonly code: string;
  /** The whole error answer, which can carry more (the relationship, a note). */
  readonly body: Record<string, unknown>;

  constructor(
    status: number,
    code: string,
    message: string,
    body: Record<string, unknown> = {},
  ) {
    super(message);
    this.name = "BackendError";
    this.status = status;
    this.code = code;
    this.body = body;
  }
}

/** No connection to the server. */
export class OfflineError extends Error {
  constructor() {
    super("No connection to the server.");
    this.name = "OfflineError";
  }
}

/** Was this thrown because the request was intentionally aborted (Stop)? */
export function isAbortError(e: unknown): boolean {
  return (e as { name?: string })?.name === "AbortError";
}

/** Heuristic: did this throw because the network is down? (Not an abort.) */
export function isNetworkError(e: unknown): boolean {
  if (isAbortError(e)) return false; // abort is intentional, not offline
  if (e instanceof TypeError) return true; // fetch() network failure
  const name = (e as { name?: string })?.name ?? "";
  const msg = String((e as Error)?.message ?? "");
  return name === "NetworkError" || /network|failed to fetch/i.test(msg);
}
