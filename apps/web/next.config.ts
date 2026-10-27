import type { NextConfig } from "next";

const nextConfig: NextConfig = {
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
