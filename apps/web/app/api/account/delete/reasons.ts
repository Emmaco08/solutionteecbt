/** Reasons students can pick before deleting their account (app and website, D-126). */
export const DELETE_REASONS = [
  "I finished my exams",
  "I don't use it any more",
  "Too many ads",
  "Premium is too expensive",
  "The app has problems or is slow",
  "I found another app",
  "I have another account",
  "Privacy worries",
  "Other",
] as const;

export const cleanReason = (r: unknown) => (typeof r === "string" && (DELETE_REASONS as readonly string[]).includes(r) ? r : "Other");
export const cleanNote = (n: unknown) => (typeof n === "string" ? n.replace(/\s+/g, " ").trim().slice(0, 500) : "");
