export default function Home() {
  return (
    <main
      style={{
        minHeight: "100dvh",
        display: "grid",
        placeItems: "center",
        padding: 20,
      }}
    >
      <div style={{ maxWidth: 420, textAlign: "center" }}>
        <h1 style={{ fontSize: 30, margin: 0, color: "var(--text)" }}>Hearth</h1>
        <p style={{ color: "var(--text-muted)", marginTop: 12 }}>
          Web migration scaffold is running. The Midnight Editorial design
          system, auth, and the character/chat screens come next.
        </p>
      </div>
    </main>
  );
}
