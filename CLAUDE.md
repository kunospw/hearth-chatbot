# Hearth — AI roleplay app (Flutter)

Hearth is a mobile-first, dark-first AI character roleplay app.
Core loop: **open the app → choose a character → start roleplaying.**
Everything else supports that loop.

## Stack
- Flutter (Android first) with Material 3, go_router and google_fonts (bundle the fonts as assets).
- Supabase for auth, Postgres, realtime and edge functions.
- Ollama Cloud for model inference, called **only** from Supabase edge functions, never from the device.

## Source of truth
Read these before writing UI or backend code:
- `docs/SPEC.md`: tokens, typography, spacing, components, navigation, screens, states and interaction rules.
- `docs/RELATIONSHIP_ENGINE.md`: the relationship journal, deterministic engine, database schema and prompt contract.
- `docs/UX_REVIEW.md`: tap-count targets and known risks.
- `prototype/Main.dc.html`: the working interactive prototype (HTML plus JS logic). It is a **reference for behaviour and copy, not code to port**. The JS inside shows the exact reply streaming, scroll anchoring, stage maths and anti-farming rules.
- `assets/`: sample character portraits (SVG).

## Non-negotiable design rules
- The visual direction is **Midnight Editorial**: charcoal surfaces, burgundy `#9A3349` used **only as a fill**, rose ink `#E9A0AE` for links and focus, Newsreader for story and display text, Figtree for UI. Do not restyle.
- Read every colour, size and radius from the theme extensions in SPEC.md. Never hard-code hex values in widgets.
- Touch targets: 48dp for primary actions, at least 44dp for inline actions.
- No technical words (tokens, context, temperature) outside AI Settings → Advanced.
- AI replies are full-width prose, not bubbles. Only the user's messages are bubbles.
- Never auto-scroll while the user is reading earlier messages. Show a "New reply below" pill instead.
- Relationship values are owned by the backend. The model may only *propose* an event; the server validates it and persists it.

## Suggested build order
1. Theme: `HearthColors`, `Space`, `Radii`, `Reading`, `Hit` and the text theme.
2. Shared widgets: CharacterAvatar (image with initial fallback), CharacterCard, ChatTile, RichRoleplayText, Composer, InlineNotice, sheets.
3. Screens with mock repositories: Character Library → Details → Chat/Story → Editor → Chats → Library/Universe/Memory → Journal → Settings.
4. Supabase schema and RLS, then edge functions: `chat_turn` (engine pre-step → prompt build → stream reply → validate proposal) and `apply_correction`.
5. Wire the real data in, then check the journeys in UX_REVIEW.md on a 360dp-wide device.

---

# Living documentation (updated at the end of every phase)

## Status
- **Phase 1 – Foundation: done** (plus motion and logo polish after first test). Theme, router shell, mock repositories, tests, debug APK.
- **Phase 2 – Shared widgets: done.** See "Shared widgets" below. Characters and Chats tabs now use them; the full screens are phase 3.
- **Phase 3 – Core loop: done.** Character Library, Details, Chat, Story, fake streaming, rewrite/alts, edit/copy, model-limit and offline flows, reading sheet.
- **Phase 4 – Creation and management: done** (plus Light mode). Editor, drafts, Chats list (+ wide list-detail), Library (Universes/Memories/Personas), Universe detail, Memories, AI settings, App settings.
- **Phase 5 – Relationship Journal on mock data: done.** Pure-Dart engine, journal screen + sheets, in-chat notes, Story ornament, manual-pacing approvals. The mock backend runs the engine on the device; Phase 6 swaps in the server.
- **Phase 6 – Backend: built and tested locally, not yet deployed** (needs your Supabase project and Ollama key; steps in `supabase/README.md`). Without `--dart-define SUPABASE_URL/SUPABASE_ANON_KEY` the app still runs on sample data.

## Commands
```
flutter pub get
flutter analyze                 # must be clean
flutter test                    # must be green
flutter run                     # device or emulator
flutter build apk --debug       # -> build/app/outputs/flutter-apk/app-debug.apk (sideload to a phone)
flutter build apk --release     # smaller file; hides the debug-only /dev route
```

## Machine setup notes (Windows)
- JDK 17 is a portable Temurin at `C:\Users\dyahr\.jdks\temurin-17\jdk-17.0.20.1+1`, set with `flutter config --jdk-dir`. The `JAVA_HOME` env var points at a folder that no longer exists, so ignore it.
- Android SDK is at `D:\Android`. The pub cache is on `D:\pub-cache` while the project is on `C:`, so `android/gradle.properties` sets `kotlin.incremental=false` (Kotlin incremental caches fail across drive roots). Do not remove it.
- If the Android SDK reports an unaccepted licence, run `flutter doctor --android-licenses` yourself.

## Architecture
- **Feature-first** under `lib/`: `core/{theme,router,widgets,util}`, `features/<feature>/{data,domain,presentation}`, `data/mock/` for seed data transcribed from the prototype.
- **Riverpod** (`flutter_riverpod` 2.x, no codegen). Each repository is an abstract `interface class` with a `Mock…` implementation beside it and a provider that picks the implementation. Phase 6 swaps in Supabase implementations by changing those providers only.
- **go_router**: `StatefulShellRoute.indexedStack` for Characters / Chats / Library (`lib/core/router/app_router.dart`). Every detail route uses `parentNavigatorKey: rootNavigatorKey` so it covers the bottom bar. Open details with `context.push` (not `go`) so Back returns to the tab. `/characters/new` is declared before `/characters/:id`. `AppShell` shows a `NavigationBar` under 600dp and a `NavigationRail` from 600dp; Back on Chats/Library goes to Characters first, then exits.
- **Theme** (`lib/core/theme/`): `HearthColors` and `HearthText` are real `ThemeExtension`s (read with `context.hc` / `context.ht`). `Space`, `Radii`, `Hit`, `Reading`, `Motion`, `Breakpoints` are const classes in `tokens.dart`. `HearthTheme.build(choice)` maps them onto Material 3. Text buttons use `primaryInk`; only filled buttons, switches and the nav pill use burgundy fills.
- **Fonts**: Newsreader and Figtree are bundled as variable TTFs in `assets/fonts` (OFL licences alongside) and declared in `pubspec.yaml`. Styles set both `fontWeight` and a `wght` `FontVariation`. `google_fonts` is deliberately **not** used (nothing is fetched at runtime).
- **Mock data**: `lib/data/mock/mock_data.dart` holds the prototype copy verbatim (characters, canned replies, universes, memories, personas, models, swatches, seed conversations). Relationship seeds are in `mock_relationships.dart`.
- **Brand**: the Hearth flame (burgundy fill + rose-ink ember). `HearthLogo` (`core/widgets/hearth_logo.dart`) paints it from theme colours; `assets/brand/hearth_mark.svg` is the source, `icon.png` / `icon_fg.png` are rendered from it (Chrome headless, 1024px) and `dart run flutter_launcher_icons` writes the Android adaptive icons (bg `#131214`).
- **Motion** (`core/widgets/motion_widgets.dart`, `splash_gate.dart`, `tap_card.dart`): pushes use `FadeForwardsPageTransitionsBuilder`; tabs ease in via `FadeBranches` (only the selected tab is on stage, the others are `Offstage` with tickers off; every child is wrapped identically so state is never lost; never fade an outgoing tab under `TickerMode`, it freezes half-faded on top); lists use `EntranceFade(index)` (480ms soft ease-out, 70ms stagger capped at 6 steps; `Motion.tab/enter/soft` are the gentle-motion tokens); tappable cards use `PressScale`; a 1.2s `SplashGate` plays on cold start. Durations/curves come from `Motion` in `tokens.dart`. **Every motion helper must check `reduceMotion(context)`** (SPEC §3). New list/card widgets in later phases should use `TapCard`/`EntranceFade`/`PressScale` rather than ad-hoc animation.
- **Dev screen**: `/dev` ("Design reference": type scale, colours, theme toggle) exists only when `kDebugMode`. It is not in the spec; remove it before release.

## Shared widgets (Phase 2) — reuse these, don't rebuild
All in `lib/core/widgets/` unless noted. Read colours/sizes from `context.hc`, `context.ht`, `Space/Radii/Hit/Sizes/Motion`.
- `CharacterAvatar` (`.of(Character)`): tile + initial first, image fades in 150ms, initial stays on error. SVG asset or network URL. Pass `size: double.infinity` + `initialSize` to fill a tight parent (e.g. `AspectRatio`).
- `RichRoleplayText(text, style:, streaming:)` over `core/util/roleplay_parser.dart` (`parseRoleplay`, `stripRoleplay`). Tolerant of half-streamed markup; an action inside dialogue returns to dialogue afterwards (the prototype dropped back to narration; deliberate improvement).
- `Composer`: Send ↔ Stop, 1–5 lines, Enter = newline, Ctrl/Cmd+Enter sends. Story variant: empty send = Continue (`onSend('')`).
- `InlineNotice`, `MessageActions` ("‹ 2 of 3 ›" only when >1 alt), `JumpToLatestPill`, `ChatTile`, `ContinueCard`, `TapCard` (entrance + press + ripple).
- Sheets (`sheets.dart`): `showHearthSheet`, `showOptionsSheet`, `showDiscardSheet` (dismiss = keep editing), `showConfirmDeleteSheet` (safe option first). `toast.dart`: `showToast(context, text, onUndo:)`.
- `controls.dart`: `HearthSegmented`, `HearthChip`, `SwitchRow`, `RadioRow`. `states.dart`: `Skeleton*`, `HomeSkeleton`, `SkeletonRows`, `EmptyState`, `FirstRunState`, `OfflineState`, `OfflineBanner`.
- `features/characters/presentation/widgets/`: `CharacterCard`, `CreateCharacterCard`, `CharacterGrid` (rows sized with `IntrinsicHeight`, 2 cols / 3 from 600dp). **Never put a `LayoutBuilder` inside a card used by the grid**: `IntrinsicHeight` can't measure it.
- `AiMessage` / `UserBubble` / thinking indicator are built with the chat screen in Phase 3.
- Debug-only `/dev/gallery` shows every widget in each state with a 200% text switch (open it from the palette icon → "Widget gallery").

## Phase 4 — how it works
- **Light mode**: `HearthColors.light` (warm paper, same burgundy fills). New tokens: `onInverse` (content on a `text`-filled pill: selected segment, toasts, new-reply pill; renamed from `onLight`), `inverseAccent` (Undo on that pill), `onScrim`, `ember` (logo centre), `brightness`. `HearthTheme.forColors(colors)`; `HearthThemeChoice` = Dark / True black / Light / System. `app.dart` gives MaterialApp a light `theme` and a `darkTheme` (True black only if chosen); System follows the phone between Light and Dark; status/nav-bar icons follow the theme. `test/contrast_test.dart` checks WCAG contrast for all three palettes (≥7:1 body text, ≥4.5:1 muted/links/danger/ok/accents, ≥3:1 pin and ember). **When adding a colour, add it to all three palettes and the contrast test.**
- **Section labels**: use `Overline('Text')` (`core/widgets/overline.dart`): uppercase per SPEC §2; screen readers hear the original text. Don't write `Text(..., style: t.overline)`.
- **Toasts vs bottom bars**: wrap any bar pinned to the bottom (chat composer, editor Save bar) in `ToastInset` so toasts float above it. Pass `aboveBottomBar: false` for a toast shown as the screen closes. The editor and chat clear stale toasts when opened.
- **Characters**: `charactersProvider` is now an `AsyncNotifier` (`save(character)`); `characterProvider(id)` derives from it. `CharacterForm` (editor model) + `CharacterDraft`; `DraftsNotifier` (in memory). Editor = `character_editor_screen.dart` (PopScope + discard sheet; Save & start chat uses `pushReplacement`; pictures via `image_picker`, overridable with `pickPictureProvider`; picture bytes live in memory). The editor's Backstory field is the character's introduction (`Character.intro`); there is no separate backstory field.
- **Library**: `UniversesNotifier`, `MemoriesNotifier` (pin in place, `remove` returns a `RemovedMemory` for Undo), `PersonasNotifier`, `selectedPersonaIdProvider`. Views: `universes_view`, `memories_view` (also used by `/universes/:id/memories`), `personas_view`, sheets in `library_sheets.dart`.
- **Chats**: `chats_tab.dart`; from 840dp the list sits beside the open chat (`ChatScreen(embedded: true)`).
- **Settings**: `AppPrefs` (default mode, privacy toggles), `AiPrefs` (length/style/creativity + Advanced; the technical words appear only under Advanced). Selecting a model in AI settings resumes a reply waiting in an open chat. "Hide message previews" and "Blur in app switcher" are stored but have no effect yet (no notifications / platform flag until later).
- **Home**: the top bar is only the logo and "Hearth"; the greeting is its own heading under it.

## Core loop (Phase 3) — how it works
- **State**: `ConversationsNotifier` (`features/chat/data/conversation_repository.dart`) holds all conversations (async, newest first) and edits them with `change(id, fn)`, `setMode`, `rename`, `togglePin`, `delete`, `startNew(character)`. `conversationProvider(id)` is one conversation. Repositories are in-memory mocks; `MockScenario` (normal / empty / offline) and mock latency come from `data/mock/mock_scenario.dart` and are switchable in the debug design reference.
- **`ChatController`** (`chat_controller.dart`, `chatControllerProvider(conversationId)`): `send`, `continueStory`, `rewrite`, `retry`, `stop`, `setAlt`, `edit`. Holds only transient state (`GenStatus` idle/thinking/streaming, `activeId`, `stoppedIds`, `error`). It marks generation as started *before* the placeholder message is added. Text is written to the conversation through a 60ms `Throttler`. Stop keeps partial text + "…"; stopping before any text removes the placeholder and refunds the free reply. Errors: `ModelUnavailableError` (limit/busy) and `OfflineChatError`; the user's message is always kept.
- **Replies**: `ReplyStreamingService` (interface) → `FakeReplyStreamingService` emits *cumulative* text word-group by word-group (`reply_streaming_service.dart`). Phase 6 swaps in the server implementation. `animate:false` (user turned animations off) emits the whole reply once.
- **Models**: `model_usage.dart` — `selectedModelIdProvider` (persisted), `modelUsageProvider` (free replies left: Ember 2, Lumen 41, Atlas busy; resets 07:00), `modelStatusProvider(id)`. The picker is `features/settings/presentation/model_picker.dart`.
- **Reading prefs**: `reading_prefs.dart` (persisted): chat size 14–22, story size 15–26, one shared line-spacing index (Compact/Comfortable/Roomy), story Narration and Pacing. Sheet: `reading_sheet.dart`.
- **Chat screen** (`chat_screen.dart`): one route `/chat/:id`; mode (`Conversation.mode`) is per-conversation and persisted. Chat = reversed `ListView`; Story = normal list capped at 640dp. Both use `MessageList` (`message_list.dart`).
- **Reading position** (`MessageList` + `ScrollAnchor`): before switching modes, `captureAnchor()` records the first visible message id and the 0–1 fraction scrolled into it (or "bottom"); the new list restores it iteratively (jump to an estimate by average height, let the target build, then correct exactly) and stays invisible until restored. Follow rule: only within 72dp of the bottom.
- **No drift while reading back**: when a reply is written while the reader is scrolled away (>72dp), the chat view *freezes* the message being written as they last saw it and shows the "New reply below" pill; it reveals everything when they return near the bottom or tap the pill. Freezing starts from a listener on the controller state (so the very first rebuild doesn't change the layout). In Story, growth below doesn't move content above, so only the pill is needed.
- **Home** (`characters_tab.dart`): greeting, search (name/description/tags, match count, "Create “q”"), Continue chatting (1 large card + 2 rows), recent characters, grid, and the skeleton / first-run / offline states. Drafts arrive in Phase 4.
- **Details** (`character_details_screen.dart`): hero, tags, universe link, journal entry, intro clamped to 3 lines, "More about X", bottom bar (Edit / Start new chat / Resume link).
- `JumpToLatestPill` is removed from the tree when hidden (so it isn't announced).

## Phase 5 — how it works
- **Engine** (`features/relationship/domain/`, pure Dart, no Flutter imports): `relationship_models.dart` (Values, Fact, RelationshipEvent, Suggestion, LedgerEntry, Relationship, RelationshipNote), `event_catalogue.dart` (the 14 event kinds + `classifyUserText`), `relationship_bands.dart` (words, behaviour lines, `promptBlock`, stage maths, presets), `relationship_engine.dart` (`RelationshipEngine`). Tests: `test/relationship_engine_test.dart` (93 tests, one per spec rule).
- **Pipeline** per user message: classify → trivial filter → evidence (last 6 messages) → cooldown (6; appreciation 10) → diminishing returns ×1/(1+0.5n) over 30 turns → scene budget (8 pts / 10 turns) → daily cap ±12 → romance gate → locked-fact check → pacing multiplier **last**, rounded to 0.5 (Manual pacing turns it into a suggestion) → idempotence by (messageId, kind). Cooldowns/budgets are derived from a ledger, so Undo frees them. The log is append-only: Undo adds a reversing event and strikes the original. Corrections become the new baseline.
- **Backend seam**: `RelationshipBackend` (interface) → `MockRelationshipBackend` (runs the engine). `RelationshipsNotifier` (`relationshipsProvider`) caches per `rel-<character>-<persona>`; `relationshipProvider(characterId)` is the AsyncValue for screens. The UI has **no way to set a number** except `correct()`. Phase 6: implement the interface against `chat_turn` / `apply_correction` and change `relationshipBackendProvider`.
- **Chat integration** (`chat_controller.dart`): `send()` asks the backend about your message and stores a `RelationshipNote` on it; `_generate` builds `promptBlock` + `replyTier` for the request; after the reply the fake model *proposes* one event (`relationshipProposal`) and the backend validates it. A rewrite or alt switch takes back what the old version did (and counts it again if you come back); editing your message re-evaluates it; deleting a chat keeps its events marked "from a deleted chat".
- **UI** (`features/relationship/presentation/`): `relationship_journal_screen.dart` (non-lazy scroll so `?entry=` can `ensureVisible` an entry), `relationship_sheets.dart` (Adjust / Edit stages / Add fact + `meterColor`), `relationship_note_widgets.dart` (`RelationshipNoteLine` for Chat, `RelationshipOrnament` for Story). Notes are words only, ≥44dp, and vanish when Settings → "During roleplay" is Hidden (`appPrefsProvider.relationshipNotes`, edited in the journal).
- Meter colours are theme tokens (`meterTrust/Affection/Attraction/Tension`), contrast-tested in both modes.

- **App text size** (Settings → Appearance; `AppPrefs.uiScale`, 0.9/1/1.15/1.3): `app.dart` multiplies the phone's text scale by it for the whole app. "Chat text size" is separate and only changes message text.
- **Pinned Back**: detail screens with a hero (character details, universe) put Back (and Edit) in a `Stack` overlay above the scrolling list, not inside the hero.

## Decisions on spec ambiguities (Phase 5)
1. The prompt-block sample in RELATIONSHIP_ENGINE.md differs from the prototype (e.g. "tension 14 (mild)"). I follow the prototype's bands and words (14 → "at ease"), and drop the prototype's `character:` line.
2. Prototype hysteresis could override the romance gate; I **re-cap after hysteresis**, so a closed gate always wins.
3. Prototype applied pacing by delta sign; I apply it by *gain vs setback*. Tension going up is a setback.
4. The prototype was regex-only; I follow the spec pipeline above (evidence, 20-turn hash window, daily cap, idempotence).
5. Insults map to `conflict` (tension +4) rather than losing trust/affection.
6. The Morrow seed values changed to 30/25/0/2 so stage 1 matches the stage maths.
7. Tests for chats use Jun (`c2`): Vesper's seed has a promise at turn 14, so another promise is in cooldown.

## Phase 6 — how it works
- **Where things are**: `supabase/migrations` (schema + RLS + functions), `supabase/functions/{chat_turn,apply_correction,_shared}` (TypeScript, runs on Deno and Node), `supabase/tests`, `supabase/README.md` (deploy steps). Flutter: `lib/core/backend/` (`BackendApi` interface, `SupabaseBackendApi`, mappers, config), `lib/features/auth/`, and `Supabase*Repository` / `Server*` classes beside the mocks.
- **Mode switch**: `backendApiProvider` is null (sample data, no sign-in; what all older tests use) unless `main` overrides it, which it does when `SUPABASE_URL` and `SUPABASE_ANON_KEY` are passed with `--dart-define`. Every repository provider picks Mock or Supabase from it. `AuthGate` (in `app.dart`) shows the sign-in screen until signed in.
- **Ownership rules**: the app reads/edits only its own rows (RLS `user_id = auth.uid()`). `relationships*` tables have no write policy; only `commit_relationship()` (service role, called by the edge functions) changes them. `models.ollama_model` is not readable by the app. Model proposals are stored server-side (`relationship_proposals`), so a switched-back reply version is recounted without trusting the app.
- **Engine**: the Dart engine is the reference; `functions/_shared/engine/` is a port. `tests/golden/scenarios.json` runs through both (`test/engine_golden_test.dart`, `tests/engine_golden.test.ts`) and through the real SQL (`tests/db_roundtrip.test.ts`). Ledger is derived from events + pending suggestions (not stored).
- **Chat flow with a server**: controller flushes your saved messages (`ConversationRepository.flush`) → `chat_turn` (ids + AI preferences only) → SSE `start` (note for your message, relationship, free replies left) / `delta` / `done` (note for the reply) / `error`. `ReplyStreamingService.handlesRelationship` tells the controller to skip its own relationship calls. Errors map to cards: `ModelUnavailableError`, `ReplyFailedError`, `OfflineChatError`.
- **Lessons**: (1) with `StreamController(onCancel: …)` never return the upstream cancel future when listeners use `cancelOnError`: the error is only delivered after it completes. (2) Use controllers, not `async*`, for streams that must cancel at once (Stop while the model is still thinking). (3) `flutter test` fake async: listeners fed from a real-async source need `runAsync`.
- **Mature content** (Settings, off by default) is `profiles.adult_content`; it changes one paragraph of the server prompt. The "everyone is an adult / nothing sexual involving minors" rule is always in the prompt.

- **Archive / delete / old chats**: `Character.archived`, `Conversation.archived` (migration `…0600_archive.sql`). Shared ⋯ menus: `chats/presentation/chat_actions.dart` (`showChatOptions`: pin, rename, archive, delete) and `characters/presentation/character_actions.dart` (`showCharacterOptions`: open, edit, archive, delete with chat count). Archived items leave Home and the Chats list ("Chats | Archived" chips; "Archived (n)" section on Home). A character page lists all its chats; the chat ⋯ has "All chats with X". Deleting a character deletes its chats first (works in sample and server mode).
- **Refresh**: `core/widgets/refresh.dart` (`refreshAll`, `PullToRefresh`, `RefreshButton`, `LoadingBar`, `RefreshOnResume`); opening a chat reloads it (`ConversationsNotifier.reload`) so another device's messages appear.

- **Persona switcher + reply ideas** (`chat_tools_row.dart`, a fixed 48dp row above the composer; it keeps its height while a reply is written so nothing shifts): "As X" (shown with >1 persona) opens "Play this chat as"; the choice is stored on `Conversation.personaId` (`conversations.persona_id`, migration `…0800`) and also becomes the selected persona (the journal follows it). "Suggest replies" calls `suggest_replies` (edge function, `_shared/suggest.ts`; uses the selected model without spending a free reply) via `SuggestionService` (`Mock…` / `Server…`); `SuggestionsController` keeps the ideas only for the last message they were written for. Picking one fills the message box; nothing is sent. Tests: `test/persona_suggestions_test.dart`, `supabase/functions/_shared/suggest.test.ts`.

## Decisions on spec ambiguities (Phase 6)
1. Daily free replies reset at 00:00 UTC (server), not 07:00 local.
2. Dismissing a Manual-pacing suggestion frees its cooldown and budget (like Undo); changed in both engines.
3. Curly apostrophes (’) count the same as ' in the classifier (phone keyboards).
4. `apply_correction` carries every journal action (not only corrections); `relationship_snapshot()` / `ensure_relationship()` are read through the database, not an edge function.
5. Character drafts stay on the device; messages load in full at start.
6. The seeded `models.ollama_model` values are placeholders: confirm them against `https://ollama.com/api/tags`.

## Testing notes
- `flutter test` runs ~550 tests (plus `cd supabase && npm test`, and `bash supabase/tests/run.sh` with Docker) (theme, data, navigation, motion, parser, shared widgets, chat controller, reply service, scroll anchor, home/details, chat screen, utils). Widget tests use a 360×800 view and 200% text scale for overflow checks. `test/support/harness.dart` (`pumpHearth`) boots the whole app on mocks with fast timings.
- In lazily built lists, `find` only sees widgets inside the viewport; use `ensureVisible` (after `scrollUntilVisible`) before tapping, and scope scrolling to the screen's own `Scrollable` (`find.byType(Scrollable).first` can be a tab underneath).
- `pumpAndSettle` is fine while a reply streams (it ends when the reply does), but use a `pumpUntil` loop to observe frames in between.
- Don't leave `flutter run` / a web server running while running `flutter test` (build-dir locks cause hangs).
- A failing layout exception in a widget test can make `pumpAndSettle` hang; run a single file with `--timeout 60s` to find it.

## Decisions on spec ambiguities (Phase 4)
1. **Light mode** is new (not in the spec); it keeps Midnight Editorial's structure. The segmented "selected" pill is dark-on-light in Light mode.
2. **Pin in place** (spec) beats the prototype, which re-sorted pinned memories to the top.
3. **Account card** shows the active persona and "Your stories are saved on this device"; **Export** and **Sign out** are present but say they arrive with the online account (Phase 6 adds auth).
4. **Characters, drafts, memories, universes and personas are held in memory** in the mock phase, so they reset when the app restarts (settings, theme, model, persona and reading prefs persist).
5. **Empty inline edit**: Save is disabled (no toast), as with memories.
6. **Create a universe** is included (the prototype has it) with a name and description; its era reads "Your own world".
7. **Editor "Save draft"** is disabled until something is typed; an edit of an existing character saves as a draft of that edit.

## Decisions on spec ambiguities (Phase 3)
1. **Copy** puts plain text on the clipboard (markup removed), as the prototype does.
2. **Older messages** get a ⋯ (Copy / Edit); the user's own messages get one too. Long-press does the same. Rewrite is only offered on the latest AI reply. Older alts can't be browsed (only the latest reply has "‹ 2 of 3 ›").
3. **Stopping** appends "…" to the partial text (prototype behaviour) and shows "Stopped" under it.
4. **Relationship notes** in chat/story are shown from Phase 5 (Subtle / Hidden).
5. **Home order** follows SPEC §5: greeting, search, Continue chatting, recent characters, grid. On a 360×800 phone the recent-characters row sits below the fold.
6. **Drafts** on the home screen wait for the editor (Phase 4).
7. **Offline** only affects list screens (via the mock scenario) and replies (one-shot "Fail the next reply" in the design reference), so an already-open chat keeps working.
8. **Story scene title** is the conversation title; the line above it is the universe name or "Standalone story" (prototype copy).
9. **Large text**: at ≥130% text scale the chat/story headers collapse the Story/Chat pill and the avatar to icon buttons so nothing overflows.
10. **Deleting a chat** pops the screen first, then deletes, so "not found" never flashes.
11. **Narration / Pacing** are stored but have no effect until the real model is wired (Phase 6).
12. **Model usage** is held in memory and resets when the app restarts; the real daily reset is server-side.

## Decisions on spec ambiguities (Phase 2)
1. **Selected chip** uses `primarySoft` fill + `primaryInk` text and border; unselected is `surfaceRaised`. Visual chip is compact, tap target 44dp.
2. **Toast** is a Material `SnackBar` styled as the light pill (so it sits above the nav bar automatically); Undo text uses `primaryPressed` (nearest token to the prototype's #7A2236).
3. **Confirm-delete sheet** shows "keep" as a filled primary button first and "delete" as a `dangerFill` button second.
4. **Offline/first-run/skeleton states** were added beyond the Phase 2 list because Phase 3's home needs them.
5. Reduced-motion: skeleton, caret, entrance, splash, pill and fades all check `reduceMotion(context)`.

## Decisions on spec ambiguities (Phase 1)
1. **Theme "System"** resolves to Dark, because the spec defines no light palette.
2. **`supabase_flutter` is not in `pubspec.yaml` yet.** It is added in Phase 6 to avoid shipping an unused dependency.
3. **Jun and Iselde have no portrait.** The prototype's `/_blob/…` images are not in the repo; only `vesper.svg` and `morrow.svg` exist. They fall back to tile + initial.
4. **Chat timestamps** are `DateTime`s formatted by `timeLabel()` ("2m ago", "Yesterday", "Wed", "Oct 2") instead of the prototype's fixed strings. Seed conversation c3 is 3 days old.
5. **Model names** (Ember, Lumen, Atlas Pro) are UI labels; the mapping to real Ollama models is a Phase 6 decision.

## UX_REVIEW journeys
Journey G (why did that change?) is now **1 tap**: "Trust grew a little · Why?" under the message opens the journal with that entry expanded (`test/relationship_ui_test.dart`). Journeys A–F are as reported in Phases 3–4.
