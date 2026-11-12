import type { NextConfig } from "next";

// Security headers for the public website and the payment pages (D-115). The admin has its own in proxy.ts.
const supabase = process.env.NEXT_PUBLIC_SUPABASE_URL ?? "https://mxeemubacnmcmmmzteax.supabase.co";
const csp = [
  "default-src 'self'",
  "script-src 'self' 'unsafe-inline'", // Next.js bootstraps with inline scripts; no third-party scripts at all
  "style-src 'self' 'unsafe-inline'",
  "img-src 'self' data: blob:",
  "font-src 'self'",
  `connect-src 'self' ${supabase} ${supabase.replace("https://", "wss://")}`,
  "frame-ancestors 'none'",
  "base-uri 'self'",
  "form-action 'self'",
  "object-src 'none'",
  "upgrade-insecure-requests",
].join("; ");
const secure = [
  { key: "Content-Security-Policy", value: csp },
  { key: "X-Frame-Options", value: "DENY" },
  { key: "X-Content-Type-Options", value: "nosniff" },
  { key: "Strict-Transport-Security", value: "max-age=63072000; includeSubDomains" },
  { key: "Cross-Origin-Opener-Policy", value: "same-origin" },
  { key: "Permissions-Policy", value: "camera=(), microphone=(), geolocation=(), interest-cohort=()" },
];
// Payment pages: never cached, never send the address (with its one-time code) to another site.
const payOnly = [...secure, { key: "Referrer-Policy", value: "no-referrer" }, { key: "Cache-Control", value: "no-store, max-age=0" }];

// Admin pages: strict but without a CSP (the editors load R2 images and math fonts); signed-in only (proxy + layout).
const adminOnly = [
  { key: "X-Frame-Options", value: "DENY" },
  { key: "X-Content-Type-Options", value: "nosniff" },
  { key: "Strict-Transport-Security", value: "max-age=63072000; includeSubDomains" },
  { key: "Referrer-Policy", value: "same-origin" },
  { key: "Cross-Origin-Opener-Policy", value: "same-origin" },
  // The tutor desk and admin chats record voice notes (D-153): the microphone is allowed for this site only.
  { key: "Permissions-Policy", value: "camera=(), microphone=(self), geolocation=(), interest-cohort=()" },
  { key: "Cache-Control", value: "private, no-store, max-age=0" },
  { key: "X-Robots-Tag", value: "noindex, nofollow, noarchive" },
];

const nextConfig: NextConfig = {
  async headers() {
    return [
      { source: "/", headers: [...secure, { key: "Referrer-Policy", value: "strict-origin-when-cross-origin" }] },
      { source: "/site", headers: [...secure, { key: "Referrer-Policy", value: "strict-origin-when-cross-origin" }] },
      { source: "/pay", headers: payOnly },
      { source: "/pay/:path*", headers: payOnly },
      { source: "/guardian/:path*", headers: payOnly },
      { source: "/delete-account", headers: payOnly },
      { source: "/privacy", headers: secure },
      { source: "/terms", headers: secure },
      { source: "/refunds", headers: secure },
      { source: "/api/web/:path*", headers: [{ key: "Cache-Control", value: "no-store" }, { key: "X-Content-Type-Options", value: "nosniff" }] },
      // The admin site (D-125): never in search engines, never in a frame, never cached, no referrer to other sites.
      { source: "/:path*", has: [{ type: "host", value: "admin.solutiontee.com" }], headers: [{ key: "X-Robots-Tag", value: "noindex, nofollow, noarchive" }] },
      { source: "/admin/:path*", headers: adminOnly },
      { source: "/admin", headers: adminOnly },
      { source: "/download", headers: adminOnly },
    ];
  },
  // Workspace package written in TypeScript (CSV validator, DB types).
  transpilePackages: ["@solutiontee/shared"],
  poweredByHeader: false,
  // CSV imports send up to 5,000 rows in one atomic server action.
  experimental: { serverActions: { bodySizeLimit: "10mb" } },
  cacheComponents: true,
  partialPrefetching: true,
  turbopack: {
    rules: {
      "*.css": {
        loaders: ["@tailwindcss/turbopack"],
        as: "*.css",
      },
    },
  },
};

export default nextConfig;
