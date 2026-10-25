import type { PostgrestError, SupabaseClient } from "@supabase/supabase-js";
import { BackendError, OfflineError, isAbortError, isNetworkError } from "./errors";
import { parseSse, type SseEvent } from "./sse";

// The few things the app asks of the server, as plain TypeScript. Repositories
// use this instead of the Supabase client directly, so the Supabase details
// stay in one place. Mirrors lib/core/backend/{backend_api,supabase_api}.dart.

export interface SelectOptions {
  columns?: string;
  eq?: Record<string, string | number | boolean>;
  orderBy?: string;
  ascending?: boolean;
  limit?: number;
}

type Row = Record<string, unknown>;

export class BackendApi {
  constructor(
    private readonly sb: SupabaseClient,
    private readonly url: string,
    private readonly anonKey: string,
  ) {}

  /** The signed-in user id from the local session, or null when signed out. */
  async currentUserId(): Promise<string | null> {
    const { data } = await this.sb.auth.getSession();
    return data.session?.user.id ?? null;
  }

  private fail(e: unknown): never {
    if (e instanceof BackendError || e instanceof OfflineError) throw e;
    if (isAbortError(e)) throw e; // let the caller see the abort
    if (isNetworkError(e)) throw new OfflineError();
    const pg = e as Partial<PostgrestError>;
    if (pg && typeof pg.message === "string" && "code" in (e as object)) {
      throw new BackendError(
        Number.parseInt(pg.code ?? "", 10) || 400,
        pg.code ?? "db_error",
        pg.message,
      );
    }
    throw e;
  }

  private postgrest(error: PostgrestError | null): void {
    if (!error) return;
    throw new BackendError(
      Number.parseInt(error.code ?? "", 10) || 400,
      error.code ?? "db_error",
      error.message,
    );
  }

  async select<T = Row>(table: string, opts: SelectOptions = {}): Promise<T[]> {
    try {
      // The builder's type changes across .eq -> .order -> .limit, so keep it
      // loose here (the client itself is untyped, like the Flutter app).
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      let q: any = this.sb.from(table).select(opts.columns ?? "*");
      for (const [k, v] of Object.entries(opts.eq ?? {})) q = q.eq(k, v);
      if (opts.orderBy) q = q.order(opts.orderBy, { ascending: opts.ascending ?? true });
      if (opts.limit != null) q = q.limit(opts.limit);
      const { data, error } = (await q) as {
        data: Row[] | null;
        error: PostgrestError | null;
      };
      this.postgrest(error);
      return (data ?? []) as unknown as T[];
    } catch (e) {
      this.fail(e);
    }
  }

  async upsert(table: string, rows: Row | Row[], onConflict?: string): Promise<void> {
    try {
      const { error } = await this.sb
        .from(table)
        .upsert(rows, onConflict ? { onConflict } : undefined);
      this.postgrest(error);
    } catch (e) {
      this.fail(e);
    }
  }

  async update(
    table: string,
    values: Row,
    eq: Record<string, string | number | boolean>,
  ): Promise<void> {
    try {
      let q = this.sb.from(table).update(values);
      for (const [k, v] of Object.entries(eq)) q = q.eq(k, v);
      const { error } = await q;
      this.postgrest(error);
    } catch (e) {
      this.fail(e);
    }
  }

  async delete(
    table: string,
    eq: Record<string, string | number | boolean>,
  ): Promise<void> {
    try {
      let q = this.sb.from(table).delete();
      for (const [k, v] of Object.entries(eq)) q = q.eq(k, v);
      const { error } = await q;
      this.postgrest(error);
    } catch (e) {
      this.fail(e);
    }
  }

  /** A database function (relationship_snapshot, ensure_relationship…). */
  async rpc(fn: string, params: Record<string, unknown> = {}): Promise<unknown> {
    try {
      const { data, error } = await this.sb.rpc(fn, params);
      this.postgrest(error as PostgrestError | null);
      return data;
    } catch (e) {
      this.fail(e);
    }
  }

  /** An edge function that answers with one JSON object. */
  async invoke(fn: string, body: Record<string, unknown>): Promise<Row> {
    try {
      const { data, error } = await this.sb.functions.invoke(fn, { body });
      if (error) {
        const ctx = (error as { context?: { status?: number } }).context;
        throw new BackendError(ctx?.status ?? 500, "server_error", error.message);
      }
      return (data && typeof data === "object" ? data : {}) as Row;
    } catch (e) {
      this.fail(e);
    }
  }

  private async freshToken(): Promise<string | null> {
    const { data } = await this.sb.auth.getSession();
    const session = data.session;
    if (!session) return null;
    if (session.expires_at && session.expires_at * 1000 - Date.now() < 60_000) {
      const refreshed = await this.sb.auth.refreshSession();
      return refreshed.data.session?.access_token ?? session.access_token;
    }
    return session.access_token;
  }

  /**
   * An edge function that answers with server-sent events. Pass an
   * AbortController signal and call controller.abort() to stop — the server
   * sees the connection close and stops the model, even mid-thinking.
   */
  async *stream(
    fn: string,
    body: Record<string, unknown>,
    signal?: AbortSignal,
  ): AsyncGenerator<SseEvent> {
    const token = await this.freshToken();
    if (!token) throw new BackendError(401, "unauthorized", "Sign in first.");

    let res: Response;
    try {
      res = await fetch(`${this.url}/functions/v1/${fn}`, {
        method: "POST",
        headers: {
          "content-type": "application/json",
          authorization: `Bearer ${token}`,
          apikey: this.anonKey,
          accept: "text/event-stream",
        },
        body: JSON.stringify(body),
        signal,
      });
    } catch (e) {
      if (isAbortError(e)) throw e;
      throw new OfflineError();
    }

    if (res.status !== 200) {
      let j: Record<string, unknown> = {};
      try {
        const parsed = await res.json();
        if (parsed && typeof parsed === "object") j = parsed as Record<string, unknown>;
      } catch {
        /* non-JSON error body */
      }
      const err = j.error as { code?: string; message?: string } | undefined;
      throw new BackendError(
        res.status,
        err?.code ?? "server_error",
        err?.message ?? "Something went wrong.",
        j,
      );
    }
    if (!res.body) {
      throw new BackendError(res.status, "server_error", "No response body.");
    }
    yield* parseSse(res.body);
  }

  /** Stores a portrait under the user's own folder; returns its public URL. */
  async uploadPortrait(bytes: Blob, contentType = "image/jpeg"): Promise<string> {
    try {
      const uid = await this.currentUserId();
      if (!uid) throw new BackendError(401, "unauthorized", "Sign in first.");
      const ext = contentType.includes("png") ? "png" : "jpg";
      const path = `${uid}/${crypto.randomUUID()}.${ext}`;
      const { error } = await this.sb.storage
        .from("portraits")
        .upload(path, bytes, { contentType });
      if (error) throw new BackendError(400, "upload_failed", error.message);
      return this.sb.storage.from("portraits").getPublicUrl(path).data.publicUrl;
    } catch (e) {
      this.fail(e);
    }
  }
}
