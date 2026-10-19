# Hearth marketing kit (working name: "Hearth")

Regenerate all images with `python marketing/build.py` (needs Chrome). Edit slide text in `build.py`, colours/fonts in `templates/brand.css`.

## Brand sheet
- **Direction:** Midnight Editorial. Quiet, literary, warm. Never loud, never "AI hype".
- **Colours:** background `#131214`, surface `#1C1A1D`, text `#EEE7E1`, muted `#B3AAA3`, burgundy `#9A3349` (fills only), rose ink `#E9A0AE` (accent words, links), soft burgundy `#3B1F27`.
- **Fonts:** Newsreader (headlines, story text; italic for the accent word), Figtree (labels, UI). Both are in `assets/fonts` (OFL).
- **Logo:** the flame, `assets/brand/hearth_mark.svg`. Keep clear space of half its height; never recolour.
- **Voice:** second person, short sentences, writer-to-writer. "Your world", "when you ask", "you choose what stays". Say *AI helps*, never *AI writes for you*.

## Pitch and bios
- **One line:** A calm place to write, plan and shape your stories, with AI that helps only when you ask.
- **Instagram bio:** Hearth: write. organise. world-build. / AI help only when you ask. / Early access opening soon / link below
- **TikTok bio:** building a calm writing app for storytellers. AI optional. join the waitlist
- **Alt bio:** A writing home for worldbuilders. Early access in small groups.
- **Handles to check** (availability unverified): `hearthwrites`, `hearth.app`, `usehearth`, `hearthstories`, `writeathearth`. Search the name for trademark clashes before committing.

## Hashtags (rotate 5 to 8 per post)
Writing: #writingcommunity #amwriting #writersofinstagram #authorsofinstagram #creativewriting #storytelling
Worldbuilding: #worldbuilding #fantasywriting #characterdesign #writingtools
TikTok: #writertok #booktok #authortok #writingtips #worldbuildingtok

## Safe-to-post checklist
- No explicit or suggestive content in any public post. Mature features are described only as "age-gated, 18+, off by default".
- No screenshots of real user chats or data. Use made-up sample text.
- Say "early access / in development"; promise nothing you have not built.
- Mention AI plainly. Do not hide it, do not oversell it.
- Link in bio carries `?src=ig` or `?src=tiktok`; stories and posts get their own `?src=`.

## 4-week calendar (1 to 3 posts a week is enough)
| Week | Post | Format |
|---|---|---|
| 1 | The concept: "Write the story only you can" | 5-slide carousel (`out/carousel_*.png`) |
| 1 | Meet Hearth (flame reveal, the one-line pitch) | 10 s motion video |
| 2 | A chapter being written with AI nudge, you decide what stays | Screen recording + captions |
| 2 | Poll: what is hardest, plot, characters or worldbuilding? | Story poll |
| 3 | World page: characters, places and lore linked to chapters | Carousel or short video |
| 3 | Building in public: what I changed this week and why | Image + caption |
| 4 | Behind the scenes: how the calm design was made | Short video |
| 4 | Waitlist count + ask which feature you want first | Image + question |

## Caption templates
- **Concept:** "I'm building a quiet place for long stories. Chapters, notes, your world in one spot, and AI help only when you ask. Early access is opening in small groups, link in bio. What is the one thing your writing app is missing?"
- **Building in public:** "This week: [one change]. Why: [one reason a writer asked]. Next: [one thing]. Tell me if I'm wrong."
- **Poll follow-up:** "You voted [X]. So the first thing I'm building is [Y]."

## Reply templates
- *"Is it free?"* The early version will have a free tier; details soon. Join the waitlist to hear first.
- *"Does AI write the story?"* No. You write. AI offers suggestions when you ask and you decide what stays.
- *"Is it NSFW?"* Mature writing support will be 18+, age-verified in the app and off by default. Nothing explicit is ever shown publicly.
- *"When can I try it?"* Small invite groups rolling out in waves. The waitlist is first in line.

## Ready now (in `out/`)
`profile.png` (1080 square flame for the avatar), `carousel_1..5.png` (1080×1350 concept carousel).
Next up: highlight covers, a 9:16 flame-reveal intro video (needs ffmpeg), and real app clips.

## Videos (ffmpeg installed)
- `out/intro_flame.mp4`: 7 s, 1080×1920, 30 fps flame reveal, wordmark, typewriter tagline, "Early access · link in bio". Made by `node render_video.js templates/intro.html 7 out/intro_flame.mp4 30` (frame-accurate: `templates/intro.html` exposes `window.setT(seconds)`; copy it to make new clips).
- Add trending audio inside TikTok/Instagram when you upload.

## Using After Effects
- Import `assets/brand/hearth_mark.svg` (File > Import, then Layer > Create Shapes from Vector Layer) so the flame is editable. Colours: burgundy `#9A3349`, rose `#E9A0AE`, background `#131214`.
- Fonts: install `assets/fonts/Newsreader.ttf` and `Figtree.ttf` (variable fonts; pick weights from the font menu).
- Comp 1080×1920, 30 fps. Keep text out of the top and bottom ~250 px (platform UI).
- You can drop `out/intro_flame.mp4` or the carousel PNGs in as footage and add your own audio-synced cuts on top.
