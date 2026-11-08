import { createServerClient } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";

// Pages under /admin that work without a session.
const PUBLIC_ADMIN = ["/admin/login", "/admin/accept", "/admin/forgot"];

/** Refreshes the Supabase session cookie on every admin request and sends signed-out visitors to the login page.
    This is only the first gate: the admin layout re-checks staff role and 2-step login, and RLS checks every query. */
// Pages for students and parents: they live only on the public website (D-125).
const PUBLIC_PAGES = ["/guardian", "/delete-account", "/pay", "/privacy", "/terms", "/refunds", "/site", "/store-kit"];
const isPublicPage = (p: string) => PUBLIC_PAGES.some((x) => p === x || p.startsWith(`${x}/`));

export async function proxy(request: NextRequest) {
  const host = request.headers.get("host") ?? "";
  const p = request.nextUrl.pathname;
  // cbt.solutiontee.com is the public website (D-114): its home page is /site; the admin lives on admin.solutiontee.com.
  if (host.startsWith("cbt.")) {
    if (p === "/") return NextResponse.rewrite(new URL("/site", request.url));
    if (p.startsWith("/admin") || p === "/download/aab") return NextResponse.redirect(new URL(p + request.nextUrl.search, "https://admin.solutiontee.com"));
    if (p === "/download") return NextResponse.redirect(new URL("/#download", request.url));
    return NextResponse.next();
  }
  // admin.solutiontee.com is only for staff (D-125): student and parent pages move to cbt.solutiontee.com (old links keep working).
  if (host.startsWith("admin.")) {
    if (isPublicPage(p)) return NextResponse.redirect(new URL(p + request.nextUrl.search, "https://cbt.solutiontee.com"), 308);
    if (p === "/") return NextResponse.redirect(new URL("/admin", request.url));
  }
  if (!p.startsWith("/admin")) return NextResponse.next();
  let response = NextResponse.next({ request });
  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY!,
    {
      cookies: {
        getAll: () => request.cookies.getAll(),
        setAll: (list) => {
          list.forEach(({ name, value }) => request.cookies.set(name, value));
          response = NextResponse.next({ request });
          list.forEach(({ name, value, options }) => response.cookies.set(name, value, options));
        },
      },
    },
  );

  // getClaims() verifies the JWT; do not trust getSession() on the server.
  const { data } = await supabase.auth.getClaims();
  const signedIn = Boolean(data?.claims?.sub);
  const path = request.nextUrl.pathname;

  if (!signedIn && !PUBLIC_ADMIN.some((p) => path.startsWith(p))) {
    const url = request.nextUrl.clone();
    url.pathname = "/admin/login";
    url.search = path === "/admin" ? "" : `?next=${encodeURIComponent(path)}`;
    return NextResponse.redirect(url);
  }

  response.headers.set("X-Frame-Options", "DENY");
  response.headers.set("Referrer-Policy", "strict-origin-when-cross-origin");
  response.headers.set("X-Content-Type-Options", "nosniff");
  return response;
}

export const config = {
  matcher: ["/", "/admin/:path*", "/download", "/download/aab", "/guardian/:path*", "/delete-account", "/pay", "/pay/:path*", "/privacy", "/terms",
    "/refunds", "/site", "/store-kit/:path*"],
};
