# Game Zone v2 (update 3 of 3, D-157)

Owner's brief: every game playable **against the AI and against real students, with automatic matchmaking**; JAMB
subjects limited to the student's own combination; speed and memory games (JAMB Duel, Speed Rush, Knowledge Survival,
Maths Blitz, Word War, Memory Flash, team relay); the best UI and animation.

## Games
| Game | Players | How it plays | Questions |
|---|---|---|---|
| **JAMB Duel** | 1v1 live | Same question for both at the same moment (server clock), 15 s each, faster right answer scores more; live opponent bar | Past questions from the student's combination (free years only for free students) |
| **Speed Rush** | 2–6 live | A race track: each right answer moves your car; a wrong answer stalls it for 2 s; first to 10 right wins | Same pool, short questions only |
| **Knowledge Survival** | up to 20 live | 3 hearts; a wrong or late answer costs a heart; questions get harder each round; last one standing wins | Same pool, harder as rounds go on |
| **Maths Blitz** | 1v1 live or solo | 60 seconds of mental maths (+ − × ÷, fractions, percentages, powers), made on the server; combo multiplier | Generated (no bank needed) |
| **Word War** | 1v1 live | Synonyms, antonyms and "which is spelt right", 10 rounds | A word list (admin-editable; starter list of common JAMB Use of English words) |
| **Memory Flash** | solo or 1v1 | See 6 cards (formula, symbol, element, date) for 6 s, then match them from memory; levels grow | A card list per subject (admin-editable; starter set for Physics, Chemistry, Maths, Biology) |
| **Team Relay** | 2 teams of 3 live | Players take turns; each right answer passes the baton; the team that finishes 15 first wins | Same pool |

## Ways to play (every game)
- **Quick Match** — tap and the server finds an opponent of a similar level in one of your subjects (widening the search
  every few seconds). Nobody in 15 s → **SolutionTee Bot** joins (clearly labelled), so a game always starts.
- **Practice vs AI** — three levels (Easy, Medium, Hard); the bot's speed and accuracy follow the level.
- **Play a friend** — a 6-letter code or a share link; also from a Community profile ("Challenge to a duel").
- **Ranked** — a rating per game (starts at 1000, Elo), weekly Game Zone leaderboard, rank badges (Bronze → Diamond).

## Rules on the server (fair play)
- One Postgres "match" with a start time; every question has its own start time; answers are scored with the server's
  clock (no client timers trusted); the right option is never sent before the round ends.
- Live updates through private Realtime topics (`gm:<match>` for players, `gz:<user>` for "match found"), with polling
  as a backup (same as the tutor chat).
- XP: play, win, streak of wins; no reward for guessing (score needs > 40% right); daily cap and anti-farming (same
  opponent at most 3 rated games a day).
- Subjects: only the student's JAMB combination (and Use of English); WAEC/NECO students pick from their exam subjects.
- Premium questions stay locked: free students only get free-year questions in games.

## Art direction (owner: "real games with real graphics")
- A real mobile-game look, drawn as our own vector art (sharp on every phone, small download, fully ours):
  cartoon student characters (skin tones, hair styles, school uniform colours; idle, focus, cheer, hit and win poses),
  a stadium arena at night with spotlights, chunky 3D buttons, a race track with cars, floating islands over rising
  lava, a card table, a neon arcade and a castle, a victory screen with a treasure chest, stars and rank shields.
- Game font for headings (Lilita One, free Google font, bundled) with the app font for small text.
- In the app: characters and scenes animate (Rive or Flutter painters), with sounds (off by default) and haptics.

## App
- **Game Zone hub**: a hero card for Quick Match, a grid of 7 game cards (animated illustration, players online now),
  ranked level and rating, "Your week" stats, recent matches, daily challenge.
- **Matchmaking screen**: radar sweep, your avatar, opponent avatars flying in, subject chip, cancel; "Bot is joining"
  after 15 s.
- **Live game screens**: big timer ring, opponent strip, answer buttons with instant colour, combo flames, score pop,
  race track (Speed Rush), hearts (Survival), card flip (Memory Flash), relay baton (Team Relay).
- **Results**: winner animation (confetti, trophy), XP and rating change, accuracy and speed per question, rematch,
  share.
- Respect reduce motion, light/dark, 60 fps on a 3 GB phone (no blur over lists), sounds off by default.

## Website / admin
- Admin → Games: switch each game on/off, questions per game, seconds, XP, bot levels, word list and memory cards
  editors, live matches now, players online, reports of abuse.

## Owner decisions (answered 12 Nov 2026)
1. **Team Relay** needs 6 students online at once; until we have many players, fill missing seats with bots? **Yes.**
2. **Word War and Memory Flash content**: I will make a starter word list (about 150 JAMB words) and starter memory cards
   (about 120). Should SolutionTee review them before they go live? **Yes: seeded switched off, approve in Admin → Games.**
3. **Ranked prizes**: **XP only**, and every XP amount is set by admin (per game too).

## Test plan
- Matchmaking: two test accounts find each other in seconds; a third gets a bot after 15 s.
- Timing: answers after a round's end score 0 even if the phone's clock is wrong; the answer key is not in any response
  before the round ends.
- Survival with 20 players (bots) ends with one winner; hearts and rounds are right.
- RLS: a student cannot read another match's answers or the question key.
- Widget tests: hub, matchmaking states, duel round, results; reduce motion.
