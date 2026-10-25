export function PreviewNotice({ kind }: { kind: string }) {
  return (
    <p className="t-body text-muted">
      Sign in to create and manage {kind}. Preview mode has no saved data.
    </p>
  );
}
