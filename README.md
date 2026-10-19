# Hearth handoff bundle

## Using this with Claude Code
1. Unzip into the root of your Flutter project (or into an empty folder you'll `flutter create` in).
2. Keep `CLAUDE.md` at the project root. Claude Code loads it automatically, and it points to everything else. If you already have a CLAUDE.md, paste this one's contents into yours.
3. Start Claude Code in that folder and try a first prompt like:
   > Read CLAUDE.md and docs/SPEC.md. Set up the Hearth theme (HearthColors, Space, Radii, Reading, Hit, text theme), then build CharacterAvatar and the Character Library screen with mock data matching prototype/Main.dc.html.
4. Build one screen at a time, in the order CLAUDE.md lists. For the backend, point Claude Code at docs/RELATIONSHIP_ENGINE.md.

## What's inside
- `CLAUDE.md`: project brief and the design rules that must not drift.
- `docs/SPEC.md`: tokens, type, spacing, navigation, screens, components, states and interaction rules.
- `docs/RELATIONSHIP_ENGINE.md`: the journal UI, the deterministic engine, SQL schema, prompt block and model contract.
- `docs/UX_REVIEW.md`: journeys, tap counts and acceptance checks.
- `prototype/*.dc.html`: source of the interactive design canvas. These need the canvas runtime to render, so open the live canvas to *see* them. Claude Code can still read them for exact copy, mock data and logic.
- `assets/`: sample portraits (vesper.svg, morrow.svg).
