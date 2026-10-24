import { AgeGate } from "@/components/age-gate";
import { AppShell } from "@/components/shell/app-shell";

export default function AppLayout({ children }: { children: React.ReactNode }) {
  return (
    <AgeGate>
      <AppShell>{children}</AppShell>
    </AgeGate>
  );
}
