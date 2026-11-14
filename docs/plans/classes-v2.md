# Online classes v2: programmes, pay once, attend every session (owner, 14 Nov 2026)

**Status:** built 14 Nov 2026 (D-163): server, admin, website and app done; server tested end to end.

## What the owner asked
- The admin creates a class **once** (for example "JAMB Marathon Class"), sets it to Paid with a price, flyer and full
  details. Later the admin only adds **sessions** (start time, end time / length, link) to it; nothing is recreated.
- A student **pays once** for that class and can attend **every** session of it, again and again.
- The app needs a better card and screen: simple, clean UI, good motion, and a countdown to the start and to the end of
  each session.
- cbt.solutiontee.com/classes becomes a **trustworthy shop for paid classes only**: flyer cards; tapping a card opens a
  full detail page (everything the admin set) with a Pay button; payment happens there.

## Words
- **Programme** (`class_programs`): what students buy, e.g. JAMB Marathon Class. It has a title, tagline, flyer, about
  text, what you will learn, teacher (name, bio, photo), exam and subjects, timetable note ("Mon, Wed, Fri · 6–8 pm"),
  start and end dates, access (Free / Premium / Paid), price and an optional old price, an optional seat limit, FAQ,
  status (Draft / Published / Closed) and "show on the website".
- **Session** (`classes`, unchanged table + `program_id`): one live meeting with its time, length and link. Sessions
  without a programme still work as before (old single classes).
- **Enrolment** (`class_enrollments`): a student who paid for (or registered for) a programme.

## Decisions (logged in DECISIONS D-163)
- Access lasts until the programme's end date. If the admin leaves the end date empty, it never ends: every session
  ever added to that programme. The admin decides per programme, so no single rule is forced.
- Buying stays open while the programme is published and not past its end date (late joiners can watch the
  recordings of earlier sessions). Seat limit, if set, counts enrolments.
- Premium does not include paid programmes (the same as paid classes today). Free and Premium programmes are in the
  app only; the website lists **paid** programmes only.
- Payment uses the existing, tested Paystack flow: `content_pay_start` gets a `class_program` kind, the purchase is
  recorded once (`content_purchases`), and a trigger enrols the student. A second payment for the same programme is
  refused ("bought").

## Server
- Tables `class_programs`, `class_enrollments`; `classes.program_id`; RLS: staff edit, students read through RPCs.
- `private.program_allowed`, `class_allowed` includes enrolment, `program_offer`, `content_pay_start` and the
  `content_purchases` trigger, payments/purchases kind checks.
- RPCs: `programs_list()` (app), `program_detail(id)` (app), `public_programs()` and `public_program(slug)` (website,
  no login, no links), `my_class_dashboard()` includes programme sessions, `class_reminders_job` reminds enrolled
  students too, `class_join` says "pay_program" for programme sessions.
- Images: flyers and teacher photos under `public/classes/…` in the private bucket, signed when a published programme
  uses them (app); the website shows them through `/classes/img/[id]/[kind]` (a short signed redirect).

## Admin (Online classes)
- Programmes first: create / edit (all fields, flyer and teacher photo upload), status, enrolments and money taken.
- Under each programme: its sessions with "Add session" (time, length, link, recording, materials stay as today).
- Old single classes are kept, listed below.

## App
- Classes screen: programme cards (flyer, live / next-session countdown, price or "Enrolled"), then upcoming sessions.
- Programme screen: flyer hero, price card, big countdown to the next session (or to the end while live), the session
  timeline, Pay / Join.
- Session screen: countdown to start; while live a countdown to the end with a progress ring and a pulsing Join button.
- Home "next class" card redesigned with a live countdown.

## Website
- /classes: hero, trust strip (Paystack secure payment, real teachers, recordings, support), flyer cards with price,
  timetable note, next session and seats left.
- /classes/[slug]: flyer, title, tagline, sticky price card with Pay, what you will learn, timetable, teacher, FAQ,
  trust notes; sign in with an email code then Paystack; after paying the student lands in My classes.

## Test plan
- SQL: enrol through a fake purchase → `class_allowed` true for every session of the programme; second purchase is
  refused; seats; end date; free/premium programmes; reminders include enrolled students.
- Web: tsc, eslint, build; page renders with and without programmes.
- App: analyze, tests, golden screenshots of the cards and screens.
