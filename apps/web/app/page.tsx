const swatches = [
  ["bg", "--bg"],
  ["surface", "--surface"],
  ["raised", "--surface-raised"],
  ["outline", "--outline"],
  ["primary", "--primary"],
  ["ink", "--ink"],
  ["soft", "--primary-soft"],
  ["pin", "--pin"],
  ["danger", "--danger"],
  ["ok", "--ok"],
] as const;

const meters = [
  ["trust", "--meter-trust"],
  ["affection", "--meter-affection"],
  ["attraction", "--meter-attraction"],
  ["tension", "--meter-tension"],
] as const;

export default function Home() {
  return (
    <main
      style={{
        minHeight: "100dvh",
        maxWidth: 680,
        margin: "0 auto",
        padding: "var(--space-gutter)",
        display: "flex",
        flexDirection: "column",
        gap: "var(--space-xl)",
      }}
    >
      <header style={{ display: "flex", flexDirection: "column", gap: 8 }}>
        <span className="t-overline">Midnight Editorial</span>
        <h1 className="t-display">Hearth</h1>
        <p className="t-body" style={{ color: "var(--text-muted)" }}>
          Design system specimen — type scale, palette, and roleplay styling,
          ported from the Flutter theme.
        </p>
      </header>

      <section style={{ display: "flex", flexDirection: "column", gap: 10 }}>
        <span className="t-overline">Type scale</span>
        <div className="t-display">Display · Newsreader 30</div>
        <div className="t-title">Title · Newsreader 19</div>
        <div className="t-story">
          Story · Newsreader 19. The rain kept its own time against the window.
        </div>
        <div className="t-chat">Chat · Figtree 16 — the everyday reading size.</div>
        <div className="t-label">Label · Figtree 16 semibold</div>
        <div className="t-body">Body · Figtree 15 for supporting copy.</div>
        <div className="t-caption">Caption · Figtree 13 subtle</div>
      </section>

      <section style={{ display: "flex", flexDirection: "column", gap: 10 }}>
        <span className="t-overline">Roleplay styling</span>
        <p
          className="t-story"
          style={{
            padding: "var(--space-lg)",
            background: "var(--surface)",
            borderRadius: "var(--r-card)",
            border: "1px solid var(--outline)",
          }}
        >
          <span style={{ color: "var(--narration)" }}>
            She set the cup down and studied him.{" "}
          </span>
          <em style={{ color: "var(--text-muted)" }}>
            (leans forward, voice low){" "}
          </em>
          <span style={{ color: "var(--dialogue)" }}>
            &ldquo;You came back.&rdquo;
          </span>
        </p>
      </section>

      <section style={{ display: "flex", flexDirection: "column", gap: 10 }}>
        <span className="t-overline">Palette</span>
        <div
          style={{
            display: "grid",
            gridTemplateColumns: "repeat(auto-fill, minmax(90px, 1fr))",
            gap: 10,
          }}
        >
          {swatches.map(([name, v]) => (
            <div key={name} style={{ display: "flex", flexDirection: "column", gap: 4 }}>
              <div
                style={{
                  height: 44,
                  borderRadius: "var(--r-field)",
                  background: `var(${v})`,
                  border: "1px solid var(--outline)",
                }}
              />
              <span className="t-caption">{name}</span>
            </div>
          ))}
        </div>
      </section>

      <section style={{ display: "flex", flexDirection: "column", gap: 10 }}>
        <span className="t-overline">Relationship meters</span>
        {meters.map(([name, v]) => (
          <div key={name} style={{ display: "flex", alignItems: "center", gap: 10 }}>
            <span className="t-caption" style={{ width: 72 }}>
              {name}
            </span>
            <div
              style={{
                flex: 1,
                height: 8,
                borderRadius: 999,
                background: "var(--surface-raised)",
                overflow: "hidden",
              }}
            >
              <div style={{ width: "62%", height: "100%", background: `var(${v})` }} />
            </div>
          </div>
        ))}
      </section>

      <section style={{ display: "flex", gap: 10, flexWrap: "wrap" }}>
        <button
          style={{
            minHeight: "var(--hit-primary)",
            padding: "0 20px",
            borderRadius: "var(--r-button)",
            background: "var(--primary)",
            color: "var(--on-primary)",
            border: "none",
            fontFamily: "var(--font-figtree)",
            fontWeight: 600,
            fontSize: 16,
          }}
        >
          Start roleplaying
        </button>
        <button
          style={{
            minHeight: "var(--hit-primary)",
            padding: "0 20px",
            borderRadius: "var(--r-button)",
            background: "transparent",
            color: "var(--ink)",
            border: "1px solid var(--outline)",
            fontFamily: "var(--font-figtree)",
            fontWeight: 600,
            fontSize: 16,
          }}
        >
          Browse characters
        </button>
      </section>
    </main>
  );
}
