"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { Button } from "@/components/ui/button";
import { Overline } from "@/components/ui/overline";
import { requestPasswordReset, signIn, signUp } from "@/lib/auth/auth";
import { hasSupabaseEnv } from "@/lib/supabase/env";

type Mode = "in" | "reset";

const inputCls =
  "rounded-field border border-outline bg-surface px-3 min-h-12 text-[15px] text-text placeholder:text-subtle outline-none focus:border-ink";

export default function SignInPage() {
  const router = useRouter();
  const [mode, setMode] = useState<Mode>("in");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [sent, setSent] = useState(false);

  async function auth(kind: "in" | "up") {
    setBusy(true);
    setError(null);
    try {
      if (kind === "in") await signIn(email, password);
      else await signUp(email, password);
      router.push("/characters");
    } catch (e) {
      setError(e instanceof Error ? e.message : "Something went wrong.");
    } finally {
      setBusy(false);
    }
  }

  async function sendReset() {
    setBusy(true);
    setError(null);
    try {
      // Land back on whichever origin we're on (localhost or staging).
      await requestPasswordReset(email, `${window.location.origin}/auth/reset`);
      setSent(true);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Couldn’t send the email.");
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="min-h-dvh flex items-center justify-center p-gutter bg-bg">
      <div className="w-full max-w-sm flex flex-col gap-6">
        <header className="flex flex-col gap-1 text-center">
          <Overline>Hearth</Overline>
          <h1 className="t-display">{mode === "reset" ? "Reset password" : "Welcome back"}</h1>
        </header>

        {!hasSupabaseEnv ? (
          <p className="t-body text-muted text-center">
            Supabase isn’t configured yet, so sign-in is disabled. You can still{" "}
            <Link href="/characters" className="underline text-ink">
              explore the preview
            </Link>
            .
          </p>
        ) : mode === "reset" ? (
          sent ? (
            <div className="flex flex-col gap-4 text-center">
              <p className="t-body text-muted">
                If an account exists for <span className="text-text">{email}</span>, a reset
                link is on its way. Open it in this browser to set a new password.
              </p>
              <Button variant="text" onClick={() => setMode("in")}>
                Back to sign in
              </Button>
            </div>
          ) : (
            <form
              className="flex flex-col gap-3"
              onSubmit={(e) => {
                e.preventDefault();
                void sendReset();
              }}
            >
              <input
                type="email"
                required
                autoComplete="email"
                placeholder="Email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                className={inputCls}
              />
              {error ? <p className="t-caption text-danger">{error}</p> : null}
              <Button type="submit" disabled={busy}>
                {busy ? "Sending…" : "Send reset link"}
              </Button>
              <Button type="button" variant="text" disabled={busy} onClick={() => setMode("in")}>
                Back to sign in
              </Button>
            </form>
          )
        ) : (
          <form
            className="flex flex-col gap-3"
            onSubmit={(e) => {
              e.preventDefault();
              void auth("in");
            }}
          >
            <input
              type="email"
              required
              autoComplete="email"
              placeholder="Email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              className={inputCls}
            />
            <input
              type="password"
              required
              autoComplete="current-password"
              placeholder="Password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className={inputCls}
            />
            {error ? <p className="t-caption text-danger">{error}</p> : null}
            <Button type="submit" disabled={busy}>
              {busy ? "Signing in…" : "Sign in"}
            </Button>
            <div className="flex items-center justify-between">
              <button
                type="button"
                className="t-caption text-ink"
                onClick={() => {
                  setError(null);
                  setMode("reset");
                }}
              >
                Forgot password?
              </button>
              <button
                type="button"
                className="t-caption text-ink"
                disabled={busy}
                onClick={() => void auth("up")}
              >
                Create an account
              </button>
            </div>
          </form>
        )}
      </div>
    </div>
  );
}
