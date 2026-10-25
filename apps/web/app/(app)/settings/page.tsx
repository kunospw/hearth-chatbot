"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import Link from "next/link";
import { useSession } from "@/components/providers/session";
import { type ThemeChoice, useTheme } from "@/components/providers/theme";
import { Button } from "@/components/ui/button";
import { Overline } from "@/components/ui/overline";
import { signOut } from "@/lib/auth/auth";
import { getProfile, setAdultContent } from "@/lib/repositories/profile";
import { getClientBackend } from "@/lib/supabase/client";

const THEMES: { value: ThemeChoice; label: string }[] = [
  { value: "dark", label: "Dark" },
  { value: "true-black", label: "True black" },
  { value: "light", label: "Light" },
  { value: "system", label: "System" },
];

export default function SettingsPage() {
  const { choice, setChoice } = useTheme();
  const { session, configured } = useSession();
  const useReal = configured && !!session;
  const qc = useQueryClient();

  const { data: profile } = useQuery({
    queryKey: ["profile"],
    queryFn: () => getProfile(getClientBackend()),
    enabled: useReal,
  });
  const mature = useMutation({
    mutationFn: (on: boolean) => setAdultContent(getClientBackend(), on),
    onSuccess: () => void qc.invalidateQueries({ queryKey: ["profile"] }),
  });

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
        <Overline>Roleplay</Overline>
        {useReal ? (
          <label className="flex items-center justify-between gap-3">
            <span className="t-body">
              Mature content
              <span className="block t-caption text-subtle">
                Allows adult themes. Characters are always adults.
              </span>
            </span>
            <input
              type="checkbox"
              checked={profile?.adultContent ?? false}
              onChange={(e) => mature.mutate(e.target.checked)}
              className="h-5 w-5 accent-[var(--primary)]"
            />
          </label>
        ) : (
          <p className="t-body text-muted">Sign in to change mature-content settings.</p>
        )}
        <Link href="/settings/ai" className="text-ink t-body">
          AI settings →
        </Link>
      </section>

      <section className="flex flex-col gap-3">
        <Overline>Account</Overline>
        {useReal ? (
          <>
            <p className="t-body text-muted">{session?.user.email}</p>
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
