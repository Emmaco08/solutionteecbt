/** Shared by the Ads page and its save action (big update 2, ads v2, D-104). */
export type Format = "banner" | "native" | "interstitial" | "rewarded" | "app_open" | "rewarded_interstitial";
export type Rules = {
  banner_screens: string[]; home_cards: number; native_every: number; news_card: boolean;
  inter_every_tests: number; inter_spots: string[]; ai_every: number; interstitial_gap_s: number; interstitial_per_day: number;
  app_open_after_min: number; rint_spots: string[]; rewarded_per_day: number;
  banner_sticky: "off" | "top" | "bottom" | "both"; random_break_pct: number; note_cards_every: number;
};
export type Rewards = {
  ai_prompts: number; note_hours: number; streak_freeze: number;
  year_ads: number; year_minutes: number; xp_ads: number; xp_amount: number; xp_daily_cap: number;
};
export type AdsSettings = {
  level: string; test_mode: boolean;
  formats: Record<Format, boolean>; units: Record<Format, string>;
  rewards: Rewards; custom: Rules;
};

export const BANNER_SCREENS: { id: string; label: string }[] = [
  { id: "home", label: "Home" }, { id: "study", label: "Study" }, { id: "ai", label: "AI tutor" }, { id: "news", label: "News (list and article)" },
  { id: "notes", label: "Lesson notes" }, { id: "pq", label: "Past questions" }, { id: "videos", label: "Videos" }, { id: "novels", label: "Novels" },
  { id: "bookmarks", label: "Bookmarks" }, { id: "leaderboard", label: "Leaderboard" }, { id: "challenges", label: "Challenges list" },
  { id: "results", label: "Test results" }, { id: "review", label: "Answer review" }, { id: "history", label: "Test history" },
  { id: "me", label: "Me" }, { id: "xp", label: "XP wallet" }, { id: "settings", label: "Settings" }, { id: "notifications", label: "Notifications" },
];
export const BREAK_SPOTS: { id: string; label: string }[] = [
  { id: "video_start", label: "Before a video" }, { id: "video_end", label: "After a video" }, { id: "note", label: "After reading a note" },
  { id: "quiz", label: "After an AI quiz" }, { id: "section", label: "Opening a Study section" }, { id: "ai", label: "After AI answers (every N)" },
];
export const EARN_SPOTS: { id: string; label: string }[] = [
  { id: "test", label: "After a test" }, { id: "video_end", label: "After a video" }, { id: "ai", label: "After AI answers" },
  { id: "note", label: "After a note" },
];
