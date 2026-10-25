"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { Button } from "@/components/ui/button";
import { Overline } from "@/components/ui/overline";
import { updatePassword } from "@/lib/auth/auth";
import { getBrowserClient } from "@/lib/supabase/client";
import { hasSupabaseEnv } from "@/lib/supabase/env";

const inputCls =
  "rounded-field border border-outline bg-surface px-3 min-h-12 text-[15px] text-text placeholder:text-subtle outline-none focus:border-ink";

export default function ResetPasswordPage() {
  const router = useRouter();
  const [ready, setReady] = useState<boolean | null>(null); // recovery session present?
  const [password, setPassword] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [done, setDone] = useState(false);

  // The reset link lands here with a recovery token. Establish the session
  // (handles both the PKCE `?code=` flow and the implicit hash flow), then
  // show the new-password form.
  useEffect(() => {
    if (!hasSupabaseEnv) {
      setReady(false);
      return;
    }
    const sb = getBrowserClient();
    let active = true;

    (async () => {
      try {
        const code = new URLSearchParams(window.location.search).get("code");
        if (code) await sb.auth.exchangeCodeForSession(code);
      } catch {
        /* implicit flow or already exchanged */
      }
      const { data } = await sb.auth.getUser();
      if (active) setReady(!!data.user);
    })();

    const { data: sub } = sb.auth.onAuthStateChange((_event, session) => {
      if (active && session) setReady(true);
    });
    return () => {
      active = false;
      sub.subscription.unsubscribe();
    };
  }, []);

  async function submit() {
    setBusy(true);
    setError(null);
    try {
      await updatePassword(password);
      setDone(true);
      setTimeout(() => router.push("/characters"), 1200);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Couldn’t update the password.");
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="min-h-dvh flex items-center justify-center p-gutter bg-bg">
      <div className="w-full max-w-sm flex flex-col gap-6">
        <header className="flex flex-col gap-1 text-center">
          <Overline>Hearth</Overline>
          <h1 className="t-display">Set a new password</h1>
        </header>

        {ready === null ? (
          <p className="t-body text-muted text-center">Checking your link…</p>
        ) : done ? (
          <p className="t-body text-muted text-center">Password updated — signing you in…</p>
        ) : ready ? (
          <form
            className="flex flex-col gap-3"
            onSubmit={(e) => {
              e.preventDefault();
              void submit();
            }}
          >
            <input
              type="password"
              required
              minLength={6}
              autoComplete="new-password"
              placeholder="New password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className={inputCls}
            />
            {error ? <p className="t-caption text-danger">{error}</p> : null}
            <Button type="submit" disabled={busy || password.length < 6}>
              {busy ? "Updating…" : "Update password"}
            </Button>
          </form>
        ) : (
          <div className="flex flex-col gap-4 text-center">
            <p className="t-body text-muted">
              This reset link is invalid or has expired. Request a new one, and open it in the
              same browser.
            </p>
            <Link href="/sign-in" className="text-ink underline">
              Back to sign in
            </Link>
          </div>
        )}
      </div>
    </div>
  );
}
