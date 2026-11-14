// Shared by the server page and the client panels (D-157). A plain module: no "use client".

export const GZ_GAMES = [
  { id: "duel", name: "JAMB Duel", seconds: 15, rounds: 10 },
  { id: "reading", name: "Comprehension Clash", seconds: 75, rounds: 5 },
  { id: "rush", name: "Speed Rush", seconds: 120, rounds: null },
  { id: "survival", name: "Knowledge Survival", seconds: 12, rounds: 20 },
  { id: "blitz", name: "Maths Blitz", seconds: 60, rounds: null },
  { id: "words", name: "Word War", seconds: 10, rounds: 10 },
  { id: "memory", name: "Memory Flash", seconds: 180, rounds: null },
  { id: "relay", name: "Team Relay", seconds: 15, rounds: 12 },
] as const;

export type GzGameId = (typeof GZ_GAMES)[number]["id"];

/** What each game is, what content suits it and where that content comes from (Admin → Games tabs, owner 13 Nov 2026). */
export const GZ_GUIDE: Record<GzGameId, { how: string[]; best: string[]; content: "questions" | "passages" | "words" | "cards" | "auto" }> = {
  duel: {
    how: [
      "Two students (or a student and the SolutionTee Bot) get the same question at the same moment.",
      "Each question has a timer (15 seconds by default). A right answer scores 100 points plus up to 50 for speed.",
      "10 questions; the higher score wins. Ranked games move the student's rating.",
    ],
    best: [
      "Short, clear multiple-choice questions a student can read in 5 seconds.",
      "One right answer and 3 believable wrong ones. No 'all of the above'.",
      "Avoid long calculations and questions that need a picture.",
    ],
    content: "questions",
  },
  reading: {
    how: [
      "Both players get the same passage. It appears on screen quickly, a part at a time, for a reading time set by its length (words per minute below).",
      "When the time ends the passage disappears and the questions come one after another (5 by default, 75 seconds in all).",
      "Most right answers wins; on a tie, whoever finished first wins. Finishing early adds 2 points a second.",
    ],
    best: [
      "Passages of 150 to 350 words: stories, reports, opinions, like JAMB Use of English.",
      "Mix the question types: main idea, the writer's purpose or tone, a word or phrase in context, a deduction (what we can infer), and one detail.",
      "Questions must be answerable from memory after one fast read: avoid 'In line 12…' and long quotes.",
    ],
    content: "passages",
  },
  rush: {
    how: [
      "2 to 6 players race cars. Every right answer moves your car forward; first to 10 right answers wins.",
      "Each player answers at their own speed. A wrong answer spins the car out for 2 seconds.",
    ],
    best: ["Quick recall questions that take 3 to 8 seconds: definitions, facts, simple calculations.", "Short options (one or two words or a number) work best."],
    content: "questions",
  },
  survival: {
    how: ["Up to 20 players get the same question at the same time. Everyone starts with 3 hearts.", "A wrong or late answer costs a heart. The last player standing wins."],
    best: ["Questions that get harder: the game puts hard ones first, so mark difficulty in the CSV.", "Clear, fair questions with one undoubted answer (losing a heart to a doubtful question feels unfair)."],
    content: "questions",
  },
  blitz: {
    how: ["60 seconds of quick mental maths. Right answers in a row build a combo (up to 5×)."],
    best: ["No upload needed: the server makes fresh sums for every game (percentages, fractions, squares, simple equations)."],
    content: "auto",
  },
  words: {
    how: ["10 rounds of Use of English vocabulary: same meaning (synonym), opposite (antonym) or the right spelling.", "Same word for both players at the same time; the faster right answer scores more."],
    best: ["JAMB-level words students meet in comprehension and lexis questions.", "Wrong answers that look tempting (similar meaning or a common misspelling)."],
    content: "words",
  },
  memory: {
    how: ["Cards are shown face up, then turned over. Players match pairs (term ↔ meaning) from memory. 3 levels, more pairs each level."],
    best: ["Very short pairs (30 letters or fewer a side): symbol ↔ element, word ↔ meaning, formula ↔ name, date ↔ event.", "Cards are chosen from the student's subject when there are enough, else from any subject."],
    content: "cards",
  },
  relay: {
    how: ["Two teams of 3 (bots fill empty seats). Same question for everyone; every right answer adds to your team's score.", "A team answering right in a row builds a bonus."],
    best: ["Medium questions anyone in the team can attempt: a mix of easy and medium difficulty keeps it fun."],
    content: "questions",
  },
};
