"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useSession } from "@/components/providers/session";
import {
  ChatIcon,
  LibraryIcon,
  PeopleIcon,
  SettingsIcon,
} from "@/components/ui/icons";

// App shell: header + primary navigation. Bottom bar under 640px, a left rail
// from 640px (SPEC: NavigationBar < medium, NavigationRail from medium).

const NAV = [
  { href: "/characters", label: "Characters", Icon: PeopleIcon },
  { href: "/chats", label: "Chats", Icon: ChatIcon },
  { href: "/library", label: "Library", Icon: LibraryIcon },
] as const;

function isActive(pathname: string, href: string): boolean {
  return pathname === href || pathname.startsWith(`${href}/`);
}

export function AppShell({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const { configured, session, loading } = useSession();
  const previewMode = !configured;

  // Detail / editor routes (/characters/<id>, /characters/new) are full-screen
  // with their own header — no nav chrome (SPEC).
  if (pathname.startsWith("/characters/")) {
    return <div className="min-h-dvh bg-bg">{children}</div>;
  }

  return (
    <div className="min-h-dvh flex flex-col sm:flex-row bg-bg">
      {/* Rail (sm+) */}
      <nav className="hidden sm:flex flex-col items-stretch gap-1 w-56 shrink-0 border-r border-outline p-3">
        <Link href="/characters" className="flex items-center gap-2 px-3 py-3">
          <span className="t-title">Hearth</span>
        </Link>
        <div className="mt-2 flex flex-col gap-1">
          {NAV.map(({ href, label, Icon }) => {
            const active = isActive(pathname, href);
            return (
              <Link
                key={href}
                href={href}
                className={`flex items-center gap-3 rounded-field px-3 min-h-12 text-[15px] font-medium transition-colors ${
                  active ? "bg-soft text-ink" : "text-muted hover:bg-surface"
                }`}
              >
                <Icon size={22} />
                {label}
              </Link>
            );
          })}
        </div>
        <div className="mt-auto">
          <Link
            href="/settings"
            className="flex items-center gap-3 rounded-field px-3 min-h-12 text-[15px] font-medium text-muted hover:bg-surface"
          >
            <SettingsIcon size={22} />
            Settings
          </Link>
        </div>
      </nav>

      <div className="flex-1 flex flex-col min-w-0">
        {/* Header (small screens) */}
        <header className="sm:hidden sticky top-0 z-10 flex items-center justify-between px-gutter h-14 bg-bg/90 backdrop-blur border-b border-outline">
          <Link href="/characters" className="t-title">
            Hearth
          </Link>
          <Link href="/settings" aria-label="Settings" className="text-muted p-2 -mr-2">
            <SettingsIcon size={22} />
          </Link>
        </header>

        {previewMode ? (
          <div className="px-gutter py-2 text-center t-caption bg-soft text-ink">
            Preview — sample data. Connect Supabase to sign in and save your work.
          </div>
        ) : loading ? null : !session ? (
          <div className="px-gutter py-2 text-center t-caption bg-soft text-ink">
            You’re signed out.{" "}
            <Link href="/sign-in" className="underline">
              Sign in
            </Link>{" "}
            to see your characters.
          </div>
        ) : null}

        <main className="flex-1 overflow-y-auto">
          <div className="mx-auto w-full max-w-3xl px-gutter py-5 pb-24 sm:pb-8">
            {children}
          </div>
        </main>

        {/* Bottom nav (small screens) */}
        <nav className="sm:hidden sticky bottom-0 z-10 grid grid-cols-3 border-t border-outline bg-bg/95 backdrop-blur">
          {NAV.map(({ href, label, Icon }) => {
            const active = isActive(pathname, href);
            return (
              <Link
                key={href}
                href={href}
                className={`flex flex-col items-center justify-center gap-1 min-h-14 text-[12px] ${
                  active ? "text-ink" : "text-muted"
                }`}
              >
                <Icon size={22} />
                {label}
              </Link>
            );
          })}
        </nav>
      </div>
    </div>
  );
}
