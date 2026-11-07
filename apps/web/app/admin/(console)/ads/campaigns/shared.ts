/** Brand campaigns (house ads), big update 2 ads v2 part B3, D-105. */
export type Campaign = {
  id?: string; brand: string; name: string; status: "draft" | "active" | "paused" | "ended";
  starts_on: string | null; ends_on: string | null; placements: string[];
  share_pct: number; cap_per_day: number; weight: number; link: string | null; cta: string;
  banner_key: string | null; card_key: string | null; card_title: string | null; card_body: string | null;
  break_kind: "image" | "video"; break_key: string | null; video_key: string | null; skip_after_s: number;
  live?: boolean; views?: number; clicks?: number; students?: number;
};
export type CampaignReport = {
  campaign: Campaign; students: number;
  rows: { day: string; placement: string; views: number; clicks: number }[];
};
export const PLACEMENTS: { id: string; label: string; needs: string }[] = [
  { id: "banner", label: "Banner", needs: "Banner picture (wide, e.g. 640 × 100)" },
  { id: "card", label: "Card in lists and Home", needs: "Card picture + title" },
  { id: "break", label: "Full-screen break", needs: "Break picture or video" },
  { id: "video_pre", label: "Video lessons: before", needs: "Ad video" },
  { id: "video_mid", label: "Video lessons: middle", needs: "Ad video" },
  { id: "video_post", label: "Video lessons: after", needs: "Ad video" },
];
