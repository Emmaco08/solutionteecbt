# SolutionTee CBT — Product Spec (docs/SPEC.md)

App name: **SolutionTee CBT** · Tagline: **Learn. Think. Solve.**
Users: Nigerian secondary-school leavers preparing for JAMB UTME, WAEC and NECO. Many are under 18, on low/mid-range Android phones with expensive data.
Admins/teachers: manage all content and settings from a web CMS.

Nothing about content, limits, prices, tabs or exam rules is hardcoded in the app. Everything comes from the backend and is editable in the admin CMS.

---

## 1. First launch: splash, welcome, onboarding

1. **Splash**: animated SolutionTee logo reveal + tagline.
2. **Welcome**: "Welcome to SolutionTee CBT".
3. **Feature slides** (4–5, swipeable, Skip / dots / Next, smooth parallax + Lottie-style illustrations, content editable in CMS):
   - Real CBT experience for JAMB, WAEC & NECO (show the three logos)
   - Past questions, video solutions & lesson notes
   - SolutionTee AI tutor that explains step by step
   - Track your progress and weak topics
   - Join live JAMB classes
4. Last slide → **Create account / Log in**. Onboarding shows only once (stored locally).

## 2. Authentication

- **Email + password sign-up** → 6-digit **OTP** emailed via Brevo (Supabase Auth email OTP with Brevo as custom SMTP) → verify screen with auto-advance OTP boxes, paste support, 60 s resend cooldown, 10 min expiry.
- **Continue with Google** (native Google Sign-In → Supabase).
- Forgot password via OTP. Show/hide password. Clear inline errors.
- **Profile setup** after first sign-in: full name, phone (optional), state, school (optional), target exam(s), JAMB subject combination (English + 3), target score.
- **First-time guided tour**: spotlight coach marks walking through each bottom tab and key buttons (start a test, study, AI, profile, upgrade). Skippable; replayable from Profile → Help.

## 3. Navigation (server-driven tabs)

Bottom navigation built from the `app_tabs` table: `key, title, icon, type, sort_order, enabled, premium_only, config_json, min_app_version`.
Built-in types: `home`, `study`, `test`, `ai_chat`, `profile`.
Generic types so admin can add tabs without an app update: `content_list` (CMS section), `webview` (URL), `link`.
Max 5 tabs in the bar; extra tabs go into a "More" sheet. Last config cached for offline use.

## 4. Home tab

- Greeting + streak counter + daily goal ring.
- **Quick start cards** for JAMB, WAEC, NECO CBT (with logos).
- Continue unfinished test.
- **News & announcements** carousel (CMS).
- Question of the day.
- Upgrade banner for free users (hidden for premium).
- Next live class card (if enrolled).

## 5. Study tab

CMS-managed sections (admin can add, rename, reorder, hide, delete):
- **Past questions (study mode)**: browse by exam → subject → year; answer + explanation shown immediately.
- **Past-question video solutions**.
- **Topic video lessons**: subject → topic (mapped to syllabus topics).
- **Lesson notes**: rich text with LaTeX, images, tables, attached PDFs.
- **Recommended novels** (JAMB literature/English texts): summaries, themes, character analysis, chapter quizzes. Only content we own or are licensed to publish.
- **JAMB brochure**, **JAMB syllabus**, **WAEC syllabus**, **NECO syllabus**: in-app PDF viewer + structured topic list.
- Custom sections added by admin.
Each item: free/premium flag, bookmark, download for offline, progress marker.

## 6. Test tab (CBT simulator)

**Modes**: Full exam simulation · Single-subject practice · Topic drill · Quick test (e.g. 20 questions) · Practice by year.

**Exam rules come from the `exam_configs` table.** Defaults to seed:
- JAMB UTME: 4 subjects, Use of English compulsory; English 60 questions, each other subject 40 questions (180 total); 120 minutes; total scaled to 400.
- WAEC / NECO: objective papers per subject per year; per-subject duration and question count configurable.

**CBT screen** (should feel like the real JAMB CBT, but cleaner):
- Exam logo + candidate name header, countdown timer (warning colors at 10 and 5 min).
- Subject tabs; question palette grid (answered / unanswered / flagged / current).
- Question with rich text, inline and display LaTeX, images, tables.
- **Comprehension passages**: one passage linked to a group of questions, shown in a collapsible/split pane that stays visible while answering that group.
- Options A–E, large tap targets, change answer anytime.
- Previous / Next / Flag; on-screen basic calculator.
- Submit with confirmation summary; auto-submit at time-out; **resume after app is killed or phone restarts**.
- Works fully **offline** with downloaded packs; attempts sync when online.

**Results**: total + per-subject score, JAMB-style score out of 400, accuracy, time per question, weak topics, celebratory animation, share card image.
**Review**: each question with the student's answer, correct answer and explanation; button **"Ask SolutionTee AI to explain"** (uses AI quota).

## 7. Free vs Premium (all enforced server-side)

Defaults (all editable in CMS):
| | Free | Premium |
|---|---|---|
| Exams | JAMB only | JAMB, WAEC, NECO + any added later |
| Years | **2000, 2001, 2002** only | All years |
| AI tutor | **3 prompts per day** | **100 prompts per day** |
| Study content | Items marked free | Everything |
| Offline downloads | Free content only | Everything |

- Locked items show a lock icon; tapping opens a friendly **paywall bottom sheet** listing benefits and plans.
- Daily AI quota resets at midnight Africa/Lagos time. Show "x prompts left today".
- `free_access_rules`, `ai_limits`, `plans` tables drive this. Entitlements live in `entitlements` (user, plan, source, starts_at, expires_at) and are the single source of truth for app + website.

## 8. Payments

**Policy reality (researched Oct 2026):** Google Play's billing-choice / external-payments program launched in the US, UK and EEA on 30 June 2026 and is scheduled to reach the rest of the world (including Nigeria) by **30 Sep 2027**. Until it reaches Nigeria, selling premium access inside an app installed from the Play Store must go through **Google Play Billing** (which shows Google Pay, cards and other Play payment methods at checkout).

Implement a `PaymentProvider` interface with two Flutter build **flavors**:
- **`play` flavor (Play Store)**: Google Play Billing via `in_app_purchase` (Billing Library version required by Play at build time). Server-side verification in an Edge Function using the Google Play Developer API, acknowledge purchases, handle pending purchases and refunds.
- **`direct` flavor (APK downloaded from our website)**: Paystack (card, bank transfer, USSD). Server initializes the transaction → open Paystack checkout in an in-app browser → grant access only after the webhook (signature verified) + verify call.
- Remote flag `paystack_in_play_build` (default **false**) so Paystack can be switched on in the Play build once Google's program covers Nigeria and we enroll.
- Do not show text in the Play build that steers users to pay on the website unless the policy allows it at that time.

**Website**: Paystack for premium activation and JAMB class fees. Paying on the website unlocks the same account in the app.

**Prices set by admin**: Paystack uses the admin price directly. Play Billing prices must also be set in Play Console: the admin plan editor stores the matching Play product ID and shows a reminder to update the price there.

## 9. AI tutor — "SolutionTee AI"

**App UI**: streaming replies, Markdown + LaTeX rendering, subject selector, suggested prompts, "hint mode" toggle (guides without giving the answer straight away), copy, chat history, new chat, quota counter, upgrade prompt when quota ends. "Explain this question" deep-links from test review with the question pre-attached.

**Edge Function `ai-chat`**: verify JWT → atomic quota check/decrement → retrieve context → call NVIDIA (`/v1/chat/completions`, `stream: true`) → stream SSE to the app → save messages.

**Making it "highly trained" for Nigerian students** (we cannot fine-tune on the free API, so use prompt + retrieval):
- **RAG**: chunk and embed syllabus topics, lesson notes and past-question explanations into pgvector using an NVIDIA embedding model from the same API; retrieve top-k by subject/topic for each question.
- **System prompt** (stored in CMS, versioned). It must make the AI:
  - teach like an excellent, patient Nigerian secondary-school teacher aligned to the JAMB/WAEC/NECO syllabuses;
  - explain step by step, show full working for Maths, Physics, Chemistry, Economics calculations, and write all math in LaTeX (`$...$`);
  - use simple English and Nigerian examples (naira, local places, everyday Nigerian life);
  - give exam tips, common traps, shortcuts and mnemonics;
  - check understanding with a short follow-up question;
  - never invent which exam year a question came from; say when it is unsure;
  - stay on education topics; decline harmful or unrelated requests politely;
  - keep answers concise on mobile unless asked to go deeper.
- **Free-tier limits**: NVIDIA's free API is rate-limited (about 40 requests per minute per key, shown in the NVIDIA dashboard). Implement a server-side queue with retry/backoff, a configurable fallback model list, caching of identical "explain question X" answers, and a friendly "AI is busy, try again in a moment" state. Add a pre-launch item in `docs/SETUP.md`: confirm NVIDIA's terms allow production use for our case and plan a paid provider if usage grows.
- Admin can change model id, temperature, max tokens, system prompt, limits.

## 10. Profile / dashboard

Avatar, name, plan + expiry + upgrade/renew, stats (tests taken, average per subject, score trend chart, weak topics, time spent), streak + badges, test history, bookmarks, downloads manager, AI prompts left today, my classes (if enrolled), settings (theme, notifications, reduce motion, data saver), help & replay tour, contact support (WhatsApp + email), Terms, Privacy, **delete account** (required by Google Play), log out.

## 11. Notifications

FCM push: admin announcements, "New questions added" (e.g. "JAMB 2024 Physics is now available"), streak reminders, class reminders. Per-topic opt-out in settings.

## 12. Admin CMS (`/admin` on the web app)

Roles: `super_admin`, `admin`, `editor`, `teacher`. High-end, fast, clean UI with the same brand.

- **Dashboard**: users, new sign-ups, premium users, revenue, tests taken, AI usage, top subjects.
- **Exams**: exam bodies (JAMB/WAEC/NECO + add new like Post-UTME), subjects, years, exam_configs; publish/unpublish a year (students see newly published years immediately).
- **Questions**:
  - Editor with rich text, **live KaTeX preview**, image upload, options A–E, correct answer, explanation, topic, difficulty, year, subject, exam.
  - **Comprehension passages**: create a passage and attach a group of questions to it.
  - **CSV bulk import**: downloadable template; column mapping; validation preview highlighting row errors; per-row LaTeX preview; dry run; commit; import history with undo. CSV columns at minimum: `exam, year, subject, passage_id, question, option_a, option_b, option_c, option_d, option_e, answer, explanation, topic, difficulty, image_url`. UTF-8, quoted fields, LaTeX allowed.
  - CSV export, search/filter, duplicate detection, bulk publish.
- **Study content**: sections, lessons (rich text + LaTeX + images + PDFs), videos (YouTube/Vimeo link or upload to storage), novels, documents (brochure, syllabuses). Free/premium flag, scheduled publishing.
- **App control**: tabs manager (add/remove/rename/reorder/icon/enable), onboarding slides, home banners & news, free access rules, AI limits + system prompt + model, plans & prices, feature flags, minimum app version (force update), maintenance mode.
- **Users**: search, view activity, grant/extend/revoke premium manually, ban.
- **Payments**: Paystack + Play transactions, status, reconciliation, refunds log.
- **Classes & community** (Phase 5): cohorts, teachers, schedules, meeting links, materials, moderation.
- **Legal pages**: edit Terms & Privacy (shown in app + website).
- **Audit log** of all admin actions.

## 13. Legal

Draft **Terms of Service** and **Privacy Policy** for Nigeria, referencing the Nigeria Data Protection Act 2023: data collected, purpose, AI processing by a third-party provider, payment processors (Paystack, Google), refunds, account deletion, minors and parental consent, data retention, contact address. Mark both "DRAFT — review by a lawyer before launch". Also prepare answers for the Play Console Data safety form in `docs/legal/`.

## 14. Website (Phase 5)

Responsive marketing site + student portal in `/apps/web`:
- **Landing**: animated hero with phone mockup of the app, features, exam logos, how it works, pricing, testimonials (placeholders until real), FAQ, download buttons (Play Store + direct APK), news/blog, footer with disclaimer and legal links.
- **JAMB classes**: class info, timetable, teachers, price (from CMS), **register + pay with Paystack**.
- **Student dashboard**: enrolled classes, schedule with **Google Meet (or other) meeting links**, join button active near class time, recordings, materials, assignments, announcements, CBT results synced from the app, premium status, payments history.
- **Community**: class groups/channels, teacher announcements, threaded discussions, Q&A, reactions, report/moderation, realtime updates (Supabase Realtime). Teachers and admins can message students.
- SEO (metadata, sitemap, Open Graph), fast on 3G, Lighthouse ≥ 90.

## 15. Launch videos (Phase 6)

Built with Remotion in `/video`, free tools only:
- App launch video: 30–45 s 16:9 (YouTube/website) + 15–30 s 9:16 (WhatsApp Status, TikTok, Instagram Reels).
- Website / JAMB classes promo: 9:16 + 16:9.
- Use real screen recordings from my phone (`adb shell screenrecord` or scrcpy recording) inside device mockups, brand colors, real logo, tagline end card.
- Free voice-over (open-source TTS such as Piper or Kokoro, or my own recording) and royalty-free music/SFX whose licenses allow commercial use; list every asset + license in `video/CREDITS.md`.
- Render with low concurrency to suit my low-RAM laptop.
