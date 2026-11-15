// Leaderboard reward types and helpers used by the server page and the client forms (not "use client").
export type Place = { xp: number; days: number };
export type LbRewards = { on: boolean; boards: { jamb: boolean; challenges: boolean }; week: Place[]; month: Place[] };
export type Winner = { board: string; period: string; label: string; rank: number; name: string; score: number; xp_given: number; days_given: number };

const fill = (a: Partial<Place>[] | undefined) => Array.from({ length: 10 }, (_, i) => ({ xp: Number(a?.[i]?.xp ?? 0), days: Number(a?.[i]?.days ?? 0) }));
export const normalise = (r: Partial<LbRewards> | undefined): LbRewards => ({
  on: r?.on === true, boards: { jamb: r?.boards?.jamb !== false, challenges: r?.boards?.challenges !== false }, week: fill(r?.week), month: fill(r?.month),
});
