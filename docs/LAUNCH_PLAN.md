# Hearth — Soft launch & 6‑month audience plan

_Last updated: 2026‑10‑20. Starts November 2026._

**Approach:** build in public. Get Hearth known **now**, collect pre‑registrations through our own waitlist, shape the app together with the community, and only spend money on the Play Store once real people have signed up.

| Decision | Choice |
|---|---|
| First audience | Adults (18+) who love stories, fiction and roleplay |
| First market | Indonesia, then SEA (Philippines, Malaysia, Singapore) |
| Budget | Under $100/month (model + infrastructure + marketing) |
| Money | Free at first; test a "Hearth+" subscription in month 5 |
| Play Store | Console account opened **only after ≥10 waitlist registrations** |

---

## 1. Why this can work (research summary)

- **The market is big but crowded.** About 337 AI companion apps earn revenue. Character.AI has about 20M monthly users (down from about 28M in mid‑2024). Others include Replika, Chai, Talkie, PolyBuzz and Janitor AI.
- **People are looking for alternatives.** The most common complaints about Character.AI are its **filters**, **memory loss / out‑of‑character replies**, and **paywalls**. Hearth's Relationship Journal ("Why did that change?") and literary Story mode answer the memory and consistency complaint directly. That is the pitch.
- **Hearth fits an open middle ground.** Character.AI is family‑safe; NSFW‑first apps are explicit. Adult storytellers who want *good writing* sit between them. Hearth is 18+, tasteful and editorial.
- **How small apps got their first users:**
  - OpenCharacter reached about 10k users by joining Reddit threads where people asked for Character.AI alternatives, plus a few paid TikTok creators.
  - Seewa grew from zero using a list of 40+ subreddits and Discord servers.
  - Discord is where AI communities gather.
  - The main channels are **Reddit + Discord + short video**, timed to moments when a big platform changes something.
- **Play Store gates for a new personal account.** A closed test with **≥12 testers opted in for 14 continuous days** is required before production *and* before pre‑registration. If testers drop below 12, the 14 days start again. Apps with AI chat must have **in‑app reporting of AI replies**. Thin "one box in, one box out" apps are being rejected; Hearth's journal, universes and Story mode are a clear point of difference.
- **Indonesia:**
  - Apps must register as a **PSE with Komdigi** (unregistered apps can be blocked).
  - **PP Tunas** (PP 17/2025, rules in Permen 9/2026) covers AI products children can reach. It requires a risk self‑assessment and age checks. Being **18+ only with an age gate** keeps us on the safe side.
  - The **PDP law** (personal data) is in force.
- **United States (later):** California **SB 243** (in force since Jan 2026) and **SB 1119** (from Jan 2027) add duties for companion chatbots: AI disclosure, a crisis protocol, age assurance and break reminders. About a dozen other states have similar laws. **No US marketing before month 6**, and only after a compliance check.
- **Costs:**
  - Ollama Cloud Pro is about $20/month; usage limits reset every 5 hours and every week (check ollama.com/pricing).
  - Supabase free tier for the beta, Pro $25/month at public launch.
  - Play Console $25 once.
  - The total fits under $100/month.

---

## 2. The plan at a glance

```
Nov 2026          Dec              Jan 2027          Feb             Mar             Apr
│ M1 BE SEEN       │ M2 FOUNDERS    │ M3 LAUNCH ID    │ M4 SHARE       │ M5 HEARTH+     │ M6 EXPAND
│ landing page     │ Play account*  │ Play production │ share a        │ subscription   │ PH/MY/SG
│ waitlist         │ closed test    │ Indonesia only  │ character      │ test           │ decide next
│ web preview      │ (14 days)      │ reviews, ASO    │ invite codes   │                │
│ Discord, TikTok  │ Play pre‑reg   │                 │ creators       │                │
│ launch blockers  │                │                 │                │                │
* opened as soon as the waitlist reaches 10 registrations
```

Dates move with the **triggers** (section 3), not the calendar. If a trigger comes early, move forward. If it's late, keep building the community; don't spend.

---

## 3. Triggers (spend money only when these are hit)

| Trigger | Condition | What it unlocks |
|---|---|---|
| **T1 — Demand** | ≥10 waitlist registrations | Open a personal Play Console account ($25) |
| **T2 — Founders** | ≥15–20 people opted in as *Founding Storytellers* **and** launch blockers done | Start the 14‑day closed test (needs 12 active; the margin covers drop‑outs) |
| **T3 — Ready** | Closed test passed, crash‑free, report rate <1% | Apply for production; open **Play pre‑registration**; email the waitlist the store link |
| **T4 — Public** | ≥300 waitlist + pre‑registrations, D7 ≥15% among founders | Public launch in Indonesia; switch Supabase to Pro |
| **T5 — Pay** | D30 ≥7%, ≥500 monthly users | Test Hearth+ |
| **T6 — Expand** | Paying users cover infrastructure | New countries; consider iOS |

---

## 4. Month by month

### Month 1 (Nov) — Be seen: waitlist, preview, community
**Build (code):**
1. **Landing page** in English and Bahasa Indonesia, Midnight Editorial style, on free GitHub Pages:
   - The pitch: *"Stories that remember you."* / *"Cerita yang mengingatmu."*
   - 3 screenshots or clips: Story mode, the Journal "Why?", a character page.
   - Waitlist form: email, "What stories do you love?", 18+ checkbox, and a "Make me a Founding Storyteller" opt‑in.
   - A counter: "x of 20 founding spots taken".
   - Links to Discord and the privacy page.
   - Saved to a Supabase `waitlist` table (anyone can insert, nobody can read).
2. **"Try the preview" web build.** The app already runs on the web with sample data, at no model cost. Show a banner: "Preview: replies are samples. Join the waitlist →".
3. **Launch blockers**, needed before the closed test:
   - release signing;
   - 18+ confirmation at sign‑up;
   - password reset;
   - **delete account** (in the app + a web page);
   - **report this reply**;
   - privacy policy and terms (they include "Characters are AI, not people" and crisis contacts; Indonesia: 119 ext. 8);
   - a daily limit on suggested replies plus a global cost switch;
   - crash reporting;
   - basic analytics (Supabase `events` table);
   - Bahasa Indonesia UI.

**Community:**
- Create a **Discord** with these channels: `#announcements`, `#story-nights`, `#ideas` (forum, feature voting), `#feedback`, `#show-your-characters`, `#bahasa-indonesia`.
- Create **TikTok + Instagram + Threads** accounts with the same handle (e.g. `@hearth.stories`).
- First posts: the idea, why you're building it, a 15‑second Story‑mode clip, and "Help me name the next feature".
- Join communities as a **member first** (no link drops): Indonesian Wattpad/fiction groups, r/CharacterAI‑alternative threads, roleplay Discords, writing Facebook groups.

**Target by end of month:** ≥100 waitlist sign‑ups, ≥10 (T1), ≥50 Discord members.

### Month 2 (Dec) — Founding Storytellers & closed test
- **T1 → Play Console setup**, in this order:
  1. account and ID verification (a few days, up to about 2 weeks);
  2. create the app (`app.hearth.hearth`);
  3. store listing;
  4. Data safety form;
  5. content rating questionnaire;
  6. target audience **18+**;
  7. AI‑generated content declaration;
  8. privacy policy URL;
  9. account deletion URL;
  10. closed testing track;
  11. a **Google Group** for testers (one email list = all testers).
- **Register as a PSE with Komdigi** and file the PP Tunas self‑assessment ("18+ only, age gate, no child accounts").
- **T2 → start the 14 days.** Invite founders from the waitlist (message in section 7).
- Twice a week, remind founders to open the app. Don't let the count drop below 12.
- Each founder gets:
  - a "Founding Storyteller" badge;
  - a private Discord role;
  - free Hearth+ for 3 months at launch;
  - their name in the credits.
- **Co‑design:**
  - a weekly poll in `#ideas`;
  - 5 short interviews (20 min);
  - a public roadmap page updated every Friday.
- Fix the top 5 issues; check the UX_REVIEW journeys on real 360dp phones.
- **T3 →** apply for production, open **Play pre‑registration**, email the waitlist: "Pre‑register on Google Play and get your founder reward."
- **Content bank** for launch: 10 house characters with Indonesian/SEA settings, 30 short clips.

**Target:** ≥20 founders active through 14 days, ≥300 waitlist + pre‑registrations.

### Month 3 (Jan 2027) — Public launch in Indonesia
- Production release, **Indonesia only** (Malaysia optional).
- Switch Supabase to Pro. Keep daily free replies generous but capped.
- Launch week:
  - a Discord story night;
  - a "Launch day" TikTok;
  - helpful, openly‑disclosed posts in the Reddit/Facebook threads you've been part of.
- **Store listing tests** (Play experiments are free): test the icon, the first screenshot and the short description.
- Reply to **every** Play review within 48 hours.

**Target:** 500 installs, D1 ≥30%, D7 ≥12%, model cost <$0.03 per daily user.

### Month 4 (Feb) — Make Hearth spread
- Ship **Share a character**: a public link and a "Featured" shelf, reviewed before going public.
- Ship **invite codes**: both people get bonus free replies.
- Monthly **story challenge** ("Write a character set in Jakarta 2099"); winners are featured in the app.
- 5–10 **micro‑creators** (booktok, writing, roleplay accounts), paid in free Hearth+ rather than cash.

**Target:** 2,000 installs; 15% of new users come from a shared link or invite.

### Month 5 (Mar) — Hearth+ test
- Play Billing subscription, about **Rp 39–49k/month**, with regional pricing.
- Benefits: more daily replies, the Atlas model, longer memory, early features.
- The free tier stays good. Show the offer to half of new users first, and compare their retention.
- Founders get their promised free months.

**Target:** 2–4% of monthly users pay; revenue ≥ model cost.

### Month 6 (Apr) — Expand & decide
- Open the Philippines, Malaysia and Singapore (English is ready).
- If retention holds, start an iOS TestFlight.
- US only after an SB 243 / SB 1119 check (crisis protocol, break reminders, age assurance).
- Write a one‑page **decision memo**: scale, change audience, or change channels.

**Target:** 5,000 installs, 800 weekly active users, infrastructure paid for by subscribers.

---

## 5. Weekly rhythm (from week 1, solo‑friendly, about 5 hours a week)

| Day | Do |
|---|---|
| Mon | Build update: one short clip (TikTok/Reels/Threads) + changelog in `#announcements` |
| Wed | A poll or "pick the next feature" in `#ideas`; answer every comment |
| Fri | **Story night** in Discord with a house character; update the public roadmap |
| Daily, 15 min | Reply in communities you joined; review reports/feedback; check the waitlist count |
| Monthly | 5 interviews → summary → roadmap |

**Content ideas that show what's special:**
- "She remembered what I said 40 messages ago" (Journal clip).
- "Tap *Why?* to see why trust grew."
- Chat ↔ Story mode switch.
- A character made in 60 seconds.
- An Indonesian folklore universe.
- Behind‑the‑scenes: "building an AI story app alone".

---

## 6. Metrics we track

Collected in the Supabase `events` table and read with SQL views every Monday:

| Metric | Goal |
|---|---|
| Waitlist sign‑ups / week, landing page conversion | ≥25% of visitors |
| Founders active in the closed test | ≥12 every day (aim 15+) |
| D1 / D7 / D30 retention | 30% / 12–15% / 7% |
| Messages per session (median) | ≥15 |
| % who open Story mode / the Journal | ≥30% / ≥20% |
| Reported replies | <1% of replies |
| Model cost per daily active user | <$0.03 |
| Share/invite share of new installs (M4+) | ≥15% |

---

## 7. Ready‑to‑use copy

**Waitlist headline**
- EN: *Stories that remember you.* Roleplay with characters who keep track of what you've lived through together. 18+.
- ID: *Cerita yang mengingatmu.* Roleplay dengan karakter yang ingat setiap momen bersamamu. Khusus 18+.

**Founding Storyteller invite (email / DM)**
- EN: "Hi! You joined the Hearth waitlist — thank you. I'm opening 20 Founding Storyteller spots to test the Android app for 2 weeks before anyone else. You'll get a founder badge, 3 months of Hearth+ free, and a real say in what I build next. All you need is an Android phone and a Google account. Want in? Reply yes."
- ID: "Hai! Terima kasih sudah daftar di waitlist Hearth. Aku membuka 20 slot *Founding Storyteller* untuk mencoba aplikasi Android selama 2 minggu sebelum orang lain. Kamu dapat badge founder, Hearth+ gratis 3 bulan, dan ikut menentukan fitur berikutnya. Cukup HP Android dan akun Google. Mau ikut? Balas 'ya'."

**Community post (when someone asks for a Character.AI alternative)**
"Disclosure: I'm building one, so take this with salt. Hearth is an 18+ story‑first app where characters keep a journal of your relationship, so they don't forget. It's in early access; the waitlist + preview are here: <link>. Happy to hear what you miss most in other apps."

---

## 8. Budget (monthly)

| Item | M1 | M2 | M3–M6 |
|---|---|---|---|
| Ollama Cloud | $0 (preview uses sample replies) | $20 (Pro) | $20 (Max $100 only if revenue covers it) |
| Supabase | $0 (free) | $0 | $25 (Pro) |
| Play Console | — | $25 once | — |
| Domain (optional) | ~$1 | ~$1 | ~$1 |
| Marketing | $0 | $0 | $0–40 (creator gifts are free Hearth+) |
| **Total** | **~$1** | **~$46** | **~$46–86** |

**Cost safety:**
- daily free‑reply caps;
- a limit on suggested replies;
- a one‑switch global "busy" mode on a model.

If limits are hit, lower free replies before adding spend.

---

## 9. Rules we keep

- **18+ only**, with an age gate. Never market to minors. No romance/NSFW marketing.
- Characters are clearly AI. A crisis‑help notice is in the app and the terms.
- Review `reports` every day; the backend still owns all relationship values.
- Don't share APK files publicly (only ≤10 trusted people, before the Play Store).
- Be openly the developer in every community post.

## 10. Risks

| Risk | What we do |
|---|---|
| Closed test drops below 12 | Recruit 15–20; reminders twice a week; Discord story nights give a reason to open the app |
| Play rejects the app (AI policy) | Report button, test account with full AI access for reviewers, clear 18+ rating, distinct features |
| Komdigi blocking | Register as a PSE before the public launch |
| Model costs spike | Caps + global switch; Pro plan limits |
| Founder burnout (solo) | Fixed 5 hours/week community rhythm; batch content on one day |
| Character.AI copies features | Our edge is the community + editorial quality, not one feature |

---

## Sources

- Market: [roborhythms — AI companion market 2026](https://www.roborhythms.com/ai-companion-app-market-2026/), [companionrater — statistics](https://companionrater.com/blog/ai-companion-statistics-2026), [fast.io — roleplay apps](https://fast.io/resources/best-ai-roleplay-apps-2026/), [unstar.app — apps ranked](https://unstar.app/blog/character-ai-replika-chai-talkie-janitor-ai-companion-apps-ranked-2026), [roborhythms — alternatives that remember](https://www.roborhythms.com/character-ai-alternatives-remember-chats/)
- Growth: [Bureau of Investigative Journalism — small AI companion developers](https://www.thebureauinvestigates.com/stories/2026-06-07/incentivising-intimacy-the-ai-developers-cashing-in-on-romantic-chatbots), [Signum — Discord and AI](https://signumgc.substack.com/p/discord-the-superapp-for-ai)
- Google Play: [closed testing requirement](https://extendsclass.com/blog/google-plays-closed-testing-requirement-what-developers-need-to-know-in-2026), [12‑tester rule](https://www.choicely.com/blog/google-play-12-tester-rule), [AI content policy (TechCrunch)](https://techcrunch.com/2024/06/06/google-play-cracks-down-on-ai-apps-after-circulation-of-apps-for-making-deepfake-nudes), [Android Developers Blog 2026](https://android-developers.googleblog.com/2026/08/ensuring-safety-genai-preventing-non-consensual-intimate-content.html)
- Law: [FPF — SB 243](https://fpf.org/blog/understanding-the-new-wave-of-chatbot-legislation-california-sb-243-and-beyond/), [ZwillGen — SB 1119](https://www.zwillgen.com/artificial-intelligence/adams-law-california-raises-the-bar-for-child-chatbot-protections/), [Orrick — 2026 state chatbot laws](https://www.orrick.com/en/Insights/2026/04/2026-State-Chatbot-Laws-Key-Provisions-and-Regulatory-Trends), [ANTARA — PP Tunas](https://en.antaranews.com/news/410118/indonesia-issues-child-data-protection-rules-pp-tunas-for-platforms), [PS Engage — PP Tunas](https://ps-engage.com/pp-tunas-indonesias-new-digital-regulation-to-protect-children-online/), [PSE registration guide](https://balizero.com/business/pse-registration-indonesia), [Indonesia PDP status](https://adaptistconsulting.com/reports/indonesias-pdp-law-is-fully-enforceable-without-regulator/)
- Costs: [Ollama Cloud](https://registry.ollama.ai/cloud), [awesome‑ollama‑models (plans)](https://github.com/RedBeret/awesome-ollama-models)

Figures come from third‑party reports and can change. Check Google Play Console help, ollama.com/pricing and Komdigi before acting on them.
