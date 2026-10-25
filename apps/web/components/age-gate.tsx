"use client";

import { useEffect, useState } from "react";
import { Button } from "@/components/ui/button";

// A hard 18+ wall before the app. Required to operate an adult product; this is
// a content gate, not legal age verification (a verification vendor is a
// pre-launch step for regulated regions).

const KEY = "hearth-age-ok";

export function AgeGate({ children }: { children: React.ReactNode }) {
  const [ok, setOk] = useState<boolean | null>(null);

  useEffect(() => {
    try {
      setOk(localStorage.getItem(KEY) === "1");
    } catch {
      setOk(false);
    }
  }, []);

  if (ok === null) return null; // avoid a flash before we know
  if (ok) return <>{children}</>;

  return (
    <div className="min-h-dvh flex items-center justify-center p-gutter">
      <div className="w-full max-w-sm flex flex-col gap-5 text-center">
        <div>
          <div className="t-overline">Hearth</div>
          <h1 className="t-display mt-1">Adults only</h1>
        </div>
        <p className="t-body text-muted">
          Hearth contains mature, fictional roleplay. By entering you confirm you
          are 18 or older and that mature content is lawful where you are.
        </p>
        <div className="flex flex-col gap-3">
          <Button
            onClick={() => {
              try {
                localStorage.setItem(KEY, "1");
              } catch {
                /* ignore */
              }
              setOk(true);
            }}
          >
            I am 18 or older — enter
          </Button>
          <Button
            variant="ghost"
            onClick={() => {
              window.location.href = "https://www.google.com";
            }}
          >
            Leave
          </Button>
        </div>
      </div>
    </div>
  );
}
