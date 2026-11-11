// What each badge can count (server: private.badge_metrics) and the icons the app knows (D-142).
export const METRICS: Record<string, string> = {
  streak: "Longest streak (days)", tests: "Tests finished", correct: "Correct answers", questions: "Questions answered",
  jamb_best: "Best full JAMB mock score", full_mocks: "Full JAMB mocks finished", perfect: "Perfect tests (10+ questions)",
  score70: "Tests with 70% or more", night: "Tests after 10 pm", early: "Tests from 5 to 8 am", weekend: "Weekend tests",
  speed: "Fast and accurate tests", days: "Days with a test", hours: "Hours in tests", topic_tests: "Topic drills",
  subject_tests: "Single-subject tests", quick_tests: "Quick tests", custom_tests: "Custom exams", lessons: "Lessons finished (any kind)",
  videos: "Videos watched to the end", notes: "Notes read to the end", novels: "Novels finished", ai_chats: "AI tutor chats",
  challenges: "Challenges finished", podium: "Challenge top-3 finishes", referrals: "Friends invited (counted)",
  qotd: "Question of the day right", xp: "XP earned", comments: "News comments", likes: "News likes",
};
export const ICONS = ["fire", "exam", "target", "checkFat", "trophy", "timer", "sealCheck", "chartLineUp", "lightning", "calendarCheck", "clock",
  "moonStars", "sunHorizon", "calendarStar", "listChecks", "bookOpenText", "hourglass", "gearSix", "books", "playCircle", "notePencil",
  "bookOpen", "sparkle", "flagCheckered", "medal", "users", "lightbulb", "coins", "chatCircleText", "heart", "star", "crownSimple", "rocket", "graduationCap"];
export const LEVELS = ["bronze", "silver", "gold", "diamond"] as const;
export type Level = (typeof LEVELS)[number];
