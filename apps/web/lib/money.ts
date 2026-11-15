/** Kobo → "₦1,500" (shared by server pages and client components). */
export const naira = (k: number) => `₦${Math.round(k / 100).toLocaleString("en-NG")}`;
