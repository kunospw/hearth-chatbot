# Hearth — UI specification (Midnight Editorial)

## 1. Colour tokens
| Token | Hex | Use |
|---|---|---|
| bg | #131214 | App ground |
| surface | #1C1A1D | Cards, fields, sheets |
| surfaceRaised | #262327 | Chips, pills, pressed states |
| outline | #3A3539 | Borders |
| text | #EEE7E1 | Body text (15.6:1 contrast on bg) |
| textMuted | #B3AAA3 | Secondary text (8.4:1) |
| textSubtle | #9C948D | Labels, captions (6.3:1) |
| primary | #9A3349 | **Fills only**: primary buttons, active toggles |
| primaryPressed | #7E2739 | Pressed state of primary |
| primaryInk | #E9A0AE | Links, focus rings, highlights |
| primarySoft | #3B1F27 | User message bubble, active nav pill |
| pin | #F2CF9A | Pinned items |
| danger | #EF8A78 (text) / #8E2B22 (fill) | Destructive actions |
| ok | #8DBF95 | Available, success |
| scrim | #080708 at 66% | Behind sheets |

Text on primary is #FFF6F3. Each character has its own tile and ink pair (for example #2F4A4F / #BFD9D6), with the ink at ≥4.5:1 on its tile. The app accent never sits behind a portrait.
The "True black" theme swaps bg to #000000 and surface to #121112.

## 2. Typography
Newsreader is the story and display serif; Figtree is the UI font.
| Role | Size / line height | Notes |
|---|---|---|
| display | 30 / 1.15, Newsreader 500 | Screen titles |
| title | 19 / 1.25, Newsreader 500 | Chat titles, card titles |
| story | 19 / 1.72, Newsreader 400 | User-adjustable 15–26 |
| chat | 16 / 1.62, Figtree | User-adjustable 14–22 |
| label | 16, weight 600 | Buttons |
| body | 15 / 1.5 | |
| overline | 13, weight 600, +6% letter spacing, uppercase | Section labels |
| caption | 13 / 1.45 | |

Line spacing settings: chat 1.50 / 1.62 / 1.80 and story 1.58 / 1.72 / 1.90 (Compact / Comfortable / Roomy).
In roleplay text, *actions* render italic in textMuted, "dialogue" renders brightest (#F6EFE9), and narration renders in #D9D1CA.

## 3. Spacing, radius, depth, motion
- Spacing on a 4dp base: 4, 8, 12, 16, **20 (screen gutter)**, 24, 32. Use 16dp gutters inside chat at 360dp wide.
- Radius: field 12, button 14, card 18, sheet 26 (top corners), avatars 9–16 or fully round.
- Depth is tonal (bg → surface → surfaceRaised). Shadows appear only on floating things: toasts and the "new reply" pill.
- Motion: 150ms for presses and toggles, 250ms emphasized-decelerate for sheets and pushes. Respect "Remove animations"; when it's on, show replies whole instead of streaming them.

## 4. Navigation
- Bottom NavigationBar with three labelled tabs: **Characters, Chats, Library** (Library holds Universes, Memories and Personas).
- Settings is reached from the profile button on the Characters header.
- Pushed full screen with no bottom bar: Character details, Editor (as a fullscreen dialog), Chat/Story, Universe detail, Memories, Relationship journal, Settings, AI settings.
- Chat ↔ Story is a state toggle on the same route, never a new route.
- Android back pops one level. On a tab root it goes to Characters, then exits.
- "Save & start chat" replaces the editor in the back stack, so Back from the new chat goes home.

Routes (go_router):
```
/characters               /characters/:id          /characters/new | /characters/:id/edit
/characters/:id/relationship?entry=…
/chats                    /chat/:conversationId
/library?tab=universes|memories|personas
/universes/:id            /universes/:id/memories
/settings                 /settings/ai
```

## 5. Screens
- **Character Library (home):** greeting; search; *Continue chatting* (conversations: one large card plus two rows; one tap resumes); *Your recent characters* (round avatars that open the profile); a 2-column character grid (3 columns at ≥600dp) with a "Create a character" card; drafts.
- **Details:** portrait hero; name; short description; tags; universe link; Relationship journal entry point; introduction clamped to 3 lines with "Read more"; "More about X" disclosure. Bottom bar: *Edit* (secondary) and *Start new chat* (primary), plus a "Resume …" link if a chat exists.
- **Editor:** picture (optional) plus a fallback colour; Name (the only required field); Short description; Personality; Greeting (a default is generated if left blank). "More details" stays collapsed by default and holds backstory, speaking style, example dialogue, always/never rules, relationships, opening scenario and universe. A sticky "Save & start chat" sits at the bottom, and "Save draft" in the header. Leaving with changes opens a sheet: Save draft / Keep editing / Discard.
- **Chat:** header with Back, avatar and name (opens the profile), a *Story* pill and ⋯. The ⋯ options sheet holds: Relationship journal, Switch mode, Text size & reading, Memories in this world, Change AI model, Rename, Start a new chat, Delete chat. The composer is 1–5 lines; Send swaps to Stop while a reply is generating.
- **Story:** minimal header (Back, "Name · Story ▾" options, Aa, Chat pill); scene title; prose paragraphs; user turns shown as small "YOU" italic blocks; the composer reads "What happens next? (optional)", and sending it empty means **Continue**.
- **Chats:** search; Pinned and Recent sections; each row is one tap target with a separate ⋯ button (Pin, Rename, Delete with confirmation).
- **Library:** segmented tabs. *Universes* shows cards with era, description, character faces and counts, plus a "separate timeline" explainer. *Memories* has a universe filter, a "How memories work" card, Add memory, and four groups: Important Memories, Story Facts, Character Relationships, World Details. Each memory has an inline pin and opens an edit sheet. *Personas* is a radio list.
- **Universe detail:** hero, description, separate-timeline note, characters, Memories & lore link, Edit.
- **AI settings:** model radio cards, each with a status line (Available · "2 of 30 free replies left today" / "Daily limit reached · resets 07:00" / "Busy right now"); response length; writing style; creativity with a hint. "Advanced" is collapsed and holds temperature, max tokens, context depth, repetition penalty and reset.
- **Settings:** account; theme (Dark / True black / System); chat text size; default mode; AI settings link; privacy toggles; export; sign out.
- **Relationship journal:** see RELATIONSHIP_ENGINE.md.

## 6. Components
| Widget | Props / states |
|---|---|
| CharacterAvatar | image?, tile, ink, initial, size, shape. Paints tile + initial first, fades the image in over 150ms, and on error keeps the initial. |
| CharacterCard | portrait, name, short (2 lines), first tag; one InkWell; min height 210 |
| ContinueCard / ChatTile | avatar, title, character · time, preview, optional ⋯ (48dp) |
| RichRoleplayText | parses `*actions*` and `"dialogue"` into TextSpans; tolerant of half-streamed markup |
| AiMessage / UserBubble | thinking, streaming (caret), done, stopped, editing; alts[] + altIndex |
| MessageActions | "‹ 2 of 3 ›", Rewrite, Copy, Edit: labelled, 44dp tall. Always shown on the latest AI reply; older messages open them from ⋯. |
| Composer | multiline, Send ↔ Stop, story variant with Continue, SafeArea bottom |
| InlineNotice | error/limit card in the list with a primary and a secondary action |
| ModelPicker | radio list with availability and the reason when disabled |
| ReadingSheet | size A−/A+, line spacing, live preview, story-only narration and pacing |
| JumpToLatestPill | shown while new content arrives below the viewport |
| HomeSkeleton / FirstRun / OfflineState | home's non-content states |
| DiscardSheet, ConfirmDeleteSheet, Toast (+Undo) | |
| Segmented, FilterChip, Switch row, Radio row | selected = light pill (#EEE7E1, dark text) or soft-burgundy chip |

## 7. State matrix
| Screen | Empty | Loading | Error | Success |
|---|---|---|---|---|
| Home | "Your first story starts here" + Meet the sample characters / Create my own | Skeletons | "Can't reach Hearth right now" + Try again | Search count; no match offers Create "query" |
| Chat/Story | Greeting is already present | "X is writing…" → streaming with Stop | Inline card: limit / busy / offline; message kept; Switch model / Try again | Copied, Updated, Stopped (partial text kept) |
| Chats | "No chats yet" + Browse characters | Skeleton rows | Offline banner | Pinned / Renamed / Delete confirmed |
| Memories | "Nothing here yet" per group | Skeleton | Save disabled while empty | Saved / Pinned / Deleted + Undo |
| AI settings | — | Status shimmer | Per-model reason + reset time | "Switched to X" and the waiting reply resumes |

## 8. Interaction rules
- **Resume:** reopens at the newest message, in the mode that chat was last in (stored per conversation).
- **Chat ↔ Story keeps your place:** before switching, record the first visible message id and the 0–1 fraction scrolled into it. After the new layout, scroll to the same spot. If you were at the bottom, stay at the bottom.
- **Streaming:** follow new text only when within 72dp of the bottom; otherwise show the pill. Throttle rebuilds to about 60ms.
- **Keyboard:**
  - Use `resizeToAvoidBottomInset: true` with a reversed `ListView.builder`.
  - When the composer gets focus, wait about 300ms, then jump to the latest message only if you're already near it.
  - Android Enter inserts a newline; Ctrl+Enter sends on hardware keyboards.
- **Safe areas:** edge-to-edge with transparent bars. The composer, nav and sheets sit inside `SafeArea(bottom)`.
- **Destructive actions:** whole chats get a confirmation with the safe option first. Small deletes get Undo.
- **Rewrite:** adds an alt and streams into it; the next user message branches from the visible alt.

## 9. Responsive and accessibility
- Compact (<600dp) is as designed. Medium (600–839) uses NavigationRail and a 3-column grid. Expanded (≥840) gives Chats a list-detail layout and caps text at 640dp wide.
- Support text scale up to 200%; never use fixed heights on text containers.
- Icon buttons get tooltips and semantic labels; toggles use Switch semantics; chips expose their selected state.
- Announce a reply once, when it finishes (SemanticsService.announce), not chunk by chunk.

## 10. Dart token sketch
```dart
abstract final class Space { static const xs=4.0, sm=8.0, md=12.0, lg=16.0, gutter=20.0, xl=24.0, xxl=32.0; }
abstract final class Radii { static const field=12.0, button=14.0, card=18.0, sheet=26.0; }
abstract final class Hit { static const primary=48.0, inline=44.0; }
abstract final class Reading {
  static const chatSize=(min:14, def:16, max:22), storySize=(min:15, def:19, max:26);
  static const storyMaxWidth=640.0;
}
```
