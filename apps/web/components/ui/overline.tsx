// Uppercased section label (CSS text-transform, so screen readers hear the
// original text). Use this instead of styling text directly. SPEC §2.
export function Overline({
  children,
  className = "",
}: {
  children: React.ReactNode;
  className?: string;
}) {
  return <div className={`t-overline ${className}`}>{children}</div>;
}
