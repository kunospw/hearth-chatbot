import type { CSSProperties } from "react";
import { parseRoleplay } from "@/lib/roleplay/parse";

// Renders roleplay prose: *actions* italic/muted, "dialogue" brightest,
// narration in between. Tolerant of half-streamed markup. SPEC §2.
export function RichRoleplayText({
  text,
  className = "",
  style,
}: {
  text: string;
  className?: string;
  style?: CSSProperties;
}) {
  const paragraphs = parseRoleplay(text);
  return (
    <div className={className} style={style}>
      {paragraphs.map((segs, i) => (
        <p key={i} className="m-0 mb-3 last:mb-0">
          {segs.map((s, j) => {
            if (s.kind === "action") {
              return (
                <em key={j} className="italic" style={{ color: "var(--text-muted)" }}>
                  {s.text}
                </em>
              );
            }
            const color = s.kind === "dialogue" ? "var(--dialogue)" : "var(--narration)";
            return (
              <span key={j} style={{ color }}>
                {s.text}
              </span>
            );
          })}
        </p>
      ))}
    </div>
  );
}
