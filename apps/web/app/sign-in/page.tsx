"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { Button } from "@/components/ui/button";
import { Overline } from "@/components/ui/overline";
import { signIn, signUp } from "@/lib/auth/auth";
import { hasSupabaseEnv } from "@/lib/supabase/env";

export default function SignInPage() {
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function submit(mode: "in" | "up") {
    setBusy(true);
    setError(null);
    try {
      if (mode === "in") await signIn(email, password);
      else await signUp(email, password);
      router.push("/characters");
    } catch (e) {
      setError(e instanceof Error ? e.message : "Something went wrong.");
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="min-h-dvh flex items-center justify-center p-gutter bg-bg">
      <div className="w-full max-w-sm flex flex-col gap-6">
        <header className="flex flex-col gap-1 text-center">
          <Overline>Hearth</Overline>
          <h1 className="t-display">Welcome back</h1>
        </header>

        {!hasSupabaseEnv ? (
          <p className="t-body text-muted text-center">
            Supabase isn’t configured yet, so sign-in is disabled. You can still{" "}
            <Link href="/characters" className="underline text-ink">
              explore the preview
            </Link>
            .
          </p>
        ) : (
          <form
            className="flex flex-col gap-3"
            onSubmit={(e) => {
              e.preventDefault();
              void submit("in");
            }}
          >
            <input
              type="email"
              required
              autoComplete="email"
              placeholder="Email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              className="rounded-field border border-outline bg-surface px-3 min-h-12 text-[15px] text-text placeholder:text-subtle outline-none focus:border-ink"
            />
            <input
              type="password"
              required
              autoComplete="current-password"
              placeholder="Password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className="rounded-field border border-outline bg-surface px-3 min-h-12 text-[15px] text-text placeholder:text-subtle outline-none focus:border-ink"
            />
            {error ? <p className="t-caption text-danger">{error}</p> : null}
            <Button type="submit" disabled={busy}>
              {busy ? "Signing in…" : "Sign in"}
            </Button>
            <Button
              type="button"
              variant="text"
              disabled={busy}
              onClick={() => void submit("up")}
            >
              Create an account
            </Button>
          </form>
        )}
      </div>
    </div>
  );
}
