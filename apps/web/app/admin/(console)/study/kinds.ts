export const KINDS = ["video_solution", "lesson", "note", "novel", "doc"] as const;
export type StudyKind = (typeof KINDS)[number];
export type StudyState = { error?: string };

// Labels for the five kinds of study content (shared by the list and the form).
export const KIND_INFO = {
  video_solution: { label: "Video solutions", one: "video solution", hint: "A teacher explains one past question. Link it to the question so it shows under the solution." },
  lesson: { label: "Video lessons", one: "video lesson", hint: "A full lesson on one topic." },
  note: { label: "Notes", one: "note", hint: "Short topic notes. Use $...$ for maths, # for headings, - for lists and **bold**." },
  novel: { label: "Literature novels", one: "novel", hint: "Summary, chapters, themes and characters of a set novel." },
  doc: { label: "Documents", one: "document", hint: "A PDF such as the JAMB syllabus or the brochure." },
} as const;
