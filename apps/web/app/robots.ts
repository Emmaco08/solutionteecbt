import type { MetadataRoute } from "next";

/** Search engines may read the public website; the admin, API, downloads and one-time pages are off limits (D-125).
 *  admin.solutiontee.com also sends "X-Robots-Tag: noindex" on every page. */
export default function robots(): MetadataRoute.Robots {
  return {
    rules: [{ userAgent: "*", allow: ["/", "/privacy", "/terms", "/refunds"], disallow: ["/admin", "/api", "/download", "/guardian", "/pay", "/delete-account", "/store-kit"] }],
  };
}
