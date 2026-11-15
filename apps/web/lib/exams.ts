// Exams that ship with the app: their logos come from /brand/exam-bodies and their code cannot change (D-138).
// Shared by server pages and client forms, so it must not live in a "use client" file (a server page would get a
// client reference instead of the list).
export const BUILT_IN_EXAMS: readonly string[] = ["JAMB", "WAEC", "NECO"];
