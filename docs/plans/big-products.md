# Plan — C. Big new products (owner: "Let move to C … I dont need number 16 for now", 2026-11-11)

Order: 13 Online classes → 17 JAMB classes on the website (builds on 13) → 12 Request a tutor → 14 Games →
15 Community. 16 (student web app) is later. One commit per product, tests and docs with each. **Owner** marks a
decision that is the owner's (prices, content); defaults are logged in DECISIONS.md.

## Shared: payments
Classes and tutor plans use the existing Paystack item flow (`start_item` with kind "item"; `content_pay_start` recognises
the class or tutor-plan id and records kind `class` / `tutor`, so the Paystack function is unchanged) → `finish_payment` →
`content_purchases`) with new kinds `class` and `tutor`, so the price always comes from the server, payments are
verified by the webhook, the status check and the sweep, and every channel (card, transfer, USSD, bank apps) works.

## 13 — Online classes (D-147)
- `classes` (title, about, subject, teacher, start, minutes, Free / Premium / Paid + price, seats, status) and
  `class_links` (join link, recording link: staff only). Students get a link only from `class_join()` /
  `class_recording()`, which check access and time (join opens 15 minutes before the start until the end).
- `class_registrations`: Free = tap Register; Premium = Premium students; Paid = after payment.
- Reminders by a 1-minute job: 2 h, 1 h, 30 min, 10 min, 3 min before, at the start, and 10 minutes in if they
  have not joined; each once per student.
- Admin → Classes: add, edit, cancel, links, students registered and who joined.
- App: Classes screen (Upcoming, Live now, Past with recordings), class page with Register / Pay / Join / Watch,
  Home card for the next class, search.

## 17 — JAMB classes on the website (D-148)
- cbt.solutiontee.com/classes: about, timetable, teachers, price, register and pay (website Paystack flow).
- Student dashboard on the website: schedule, join, recordings, materials (PDFs), assignments (submit, marks).

## 12 — Request a tutor (D-149)
- Request form (subject, level, goals, times), admin replies in an in-app chat and by email, tutor plans bought in
  the app, assigned tutor with WhatsApp / phone links. Admin: requests, tutors, plans, conversations. **Owner:**
  tutor plan prices.

## 14 — Games (D-150)
- Study → Games: Speed Quiz Duel (AI or a friend), Live Exam Arena (20–50 students, same question, live board),
  Beat the AI Tutor; XP rewards with daily caps; questions only from years the student can open.

## 15 — Community (D-151)
- Education-only posts (text, pictures, maths), comments, likes, follows, "For you" feed; every post checked by AI
  before it shows; @solutiontee for an AI answer; report and block; admin moderation.

## Risks
- Class links leaking: links are never in a table students can read and are only given inside the time window.
- Payments: server prices only; a paid class that is cancelled is refunded by the admin (Paystack refund flow).
- Community and tutor chat are user content: AI check, reports, blocks, rate limits, staff moderation.
