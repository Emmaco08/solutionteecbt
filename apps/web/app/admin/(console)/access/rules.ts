// The rule keys the app and the database understand (same as the approved prototype, D-027).
export type RuleValue = number | "all" | boolean | "oldest" | "newest";
export type RuleDef = { key: string; label: string; help: string; kind: "years" | "count" | "bool" | "which"; group: string };

export const RULES: RuleDef[] = [
  { key: "jamb", label: "JAMB years (tests)", help: "How many years of JAMB a student can practise. 0 = locked.", kind: "years", group: "Past questions" },
  { key: "waec", label: "WAEC years (tests)", help: "0 = locked.", kind: "years", group: "Past questions" },
  { key: "neco", label: "NECO years (tests)", help: "0 = locked.", kind: "years", group: "Past questions" },
  { key: "pq", label: "Study mode years", help: "Years open in study mode (answers shown at once).", kind: "years", group: "Past questions" },
  { key: "which", label: "Which years open first", help: "Oldest or newest published years.", kind: "which", group: "Past questions" },
  { key: "videos", label: "Video solutions", help: "", kind: "bool", group: "Study" },
  { key: "lessons", label: "Topic video lessons", help: "", kind: "bool", group: "Study" },
  { key: "notes", label: "Lesson notes", help: "", kind: "bool", group: "Study" },
  { key: "novels", label: "Novels", help: "", kind: "bool", group: "Study" },
  { key: "syllabus", label: "Syllabuses and brochures", help: "How many documents. Use 'all' for every one.", kind: "years", group: "Study" },
  { key: "ai", label: "AI tutor prompts per day", help: "Resets at midnight Lagos time.", kind: "count", group: "More" },
  { key: "offline", label: "Offline downloads", help: "Premium only is recommended (packs are encrypted).", kind: "bool", group: "More" },
  { key: "compete", label: "Challenges & events", help: "", kind: "bool", group: "More" },
];
