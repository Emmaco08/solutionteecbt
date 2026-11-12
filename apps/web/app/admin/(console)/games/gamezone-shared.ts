// Shared by the server page and the client panels (D-157). A plain module: no "use client".

export const GZ_GAMES = [
  { id: "duel", name: "JAMB Duel", seconds: 15, rounds: 10 },
  { id: "rush", name: "Speed Rush", seconds: 120, rounds: null },
  { id: "survival", name: "Knowledge Survival", seconds: 12, rounds: 20 },
  { id: "blitz", name: "Maths Blitz", seconds: 60, rounds: null },
  { id: "words", name: "Word War", seconds: 10, rounds: 10 },
  { id: "memory", name: "Memory Flash", seconds: 180, rounds: null },
  { id: "relay", name: "Team Relay", seconds: 15, rounds: 12 },
] as const;
