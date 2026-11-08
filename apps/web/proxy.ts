import { createServerClient } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";

// Pages under /admin that work without a session.
const PUBLIC_ADMIN = ["/admin/login", "/admin/accept", "/admin/forgot"];

/** Refreshes the Supabase session cookie on every admin request and sends signed-out visitors to the login page.
    This is only the first gate: the admin layout re-checks staff role and 2-step login, and RLS checks every query. */
export async function proxy(request: NextRequest) {
  // cbt.solutiontee.com is the public website (D-114): its home page is /site; the admin lives on admin.solutiontee.com.
  if ((request.headers.get("host") ?? "").startsWith("cbt.")) {
    const p = request.nextUrl.pathname;
    if (p === "/") return NextResponse.rewrite(new URL("/site", request.url));
    if (p.startsWith("/admin")) return NextResponse.redirect(new URL(p, "https://admin.solutiontee.com"));
    return NextResponse.next();
  }
  if (!request.nextUrl.pathname.startsWith("/admin")) return NextResponse.next();
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
  matcher: ["/", "/admin/:path*"],
};
