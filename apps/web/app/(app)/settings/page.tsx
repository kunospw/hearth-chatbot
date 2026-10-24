"use client";

import { useSession } from "@/components/providers/session";
import { type ThemeChoice, useTheme } from "@/components/providers/theme";
import { Button } from "@/components/ui/button";
import { Overline } from "@/components/ui/overline";
import { signOut } from "@/lib/auth/auth";

const THEMES: { value: ThemeChoice; label: string }[] = [
  { value: "dark", label: "Dark" },
  { value: "true-black", label: "True black" },
  { value: "light", label: "Light" },
  { value: "system", label: "System" },
];

export default function SettingsPage() {
  const { choice, setChoice } = useTheme();
  const { session, configured } = useSession();

  return (
    <div className="flex flex-col gap-8">
      <header className="flex flex-col gap-1">
        <Overline>Settings</Overline>
        <h1 className="t-display">Settings</h1>
      </header>

      <section className="flex flex-col gap-3">
        <Overline>Appearance</Overline>
        <div className="flex flex-wrap gap-2">
          {THEMES.map((t) => (
            <button
              key={t.value}
              type="button"
              onClick={() => setChoice(t.value)}
              className={`rounded-button px-4 min-h-11 text-[15px] font-medium border transition-colors ${
                choice === t.value
                  ? "bg-soft text-ink border-ink"
                  : "bg-surface text-muted border-outline hover:text-text"
              }`}
            >
              {t.label}
            </button>
          ))}
        </div>
      </section>

      <section className="flex flex-col gap-3">
        <Overline>Account</Overline>
        {configured && session ? (
          <>
            <p className="t-body text-muted">{session.user.email}</p>
            <Button variant="ghost" className="self-start" onClick={() => signOut()}>
              Sign out
            </Button>
          </>
        ) : (
          <p className="t-body text-muted">
            {configured
              ? "You’re signed out."
              : "Running in preview mode. Connect Supabase to enable accounts."}
          </p>
        )}
      </section>
    </div>
  );
}
