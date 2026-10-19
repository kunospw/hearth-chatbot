# UX review: journeys to keep passing

| Journey | Path | Taps |
|---|---|---|
| A · Start chatting | Character card → Start new chat | 2 |
| B · Resume | Continue story card on home | 1 |
| C · Create → chat | New character → name → Save & start chat | 2 (+ typing) |
| D · Chat → Story | Story pill (keeps the reading position) | 1 |
| E · Edit a memory | Chat ⋯ → Memories in this world → tap memory → Save | 4 |
| F · Model after a rate limit | Inline error → Switch model → pick (auto-resends) | 2 |
| G · Why a relationship changed | "Trust grew a little · Why?" → journal entry expanded | 1 |

**Acceptance checks on a 360dp Android device**
- **Layout:** no horizontal scroll; inline targets ≥44dp, primary targets ≥48dp; the composer stays visible with the keyboard open.
- **Scrolling:** streaming never moves the view while you're reading back. Switching modes lands on the same message.
- **Data safety:** deleting a chat asks first, deleting a memory offers Undo, and leaving the editor with changes asks before discarding.
- **Fallbacks and copy:** a failed portrait shows the initial, and technical words appear only in AI settings → Advanced.

**Open questions for user testing:**
- Is "Universe" clear without the word "lorebook"?
- Is "Rewrite" the right label?
- Should the active persona show in the chat header?
- At what reply length should Story mode become the default?
