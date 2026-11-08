import { Suspense } from "react";
import type { Metadata } from "next";
import { connection } from "next/server";
import { hasR2 } from "@/lib/env";
import { readJson } from "@/lib/r2";
import { apkInfoKey, type ApkInfo } from "./apk/route";
import { requireStaff } from "@/lib/auth";

export const metadata: Metadata = {
  title: "Download the Android app",
  description: "SolutionTee CBT for Android (test version).",
  robots: { index: false, follow: false },
};

export default function Page({ searchParams }: { searchParams: Promise<{ channel?: string }> }) {
  return (
    <main className="grid min-h-dvh place-items-center bg-[var(--c-bg)] px-4 py-10">
      <Suspense fallback={<div className="h-96 w-full max-w-md animate-pulse rounded-3xl bg-card" />}>
        <Download searchParams={searchParams} />
      </Suspense>
    </main>
  );
}

async function Download({ searchParams }: { searchParams: Promise<{ channel?: string }> }) {
  await connection();
  await requireStaff(); // the team's download page: signed-in staff only (D-125). Students use cbt.solutiontee.com.
  const channel = (await searchParams).channel;
  const test = channel === "test", play = channel === "play";
  const info = hasR2() ? await readJson<ApkInfo>(apkInfoKey(test ? "test" : play ? "play" : "main")).catch(() => null) : null;
  const mb = info ? (info.size / 1024 / 1024).toFixed(1) : "";
  const date = info ? new Date(info.built_at).toLocaleString("en-NG", { day: "numeric", month: "short", year: "numeric", hour: "numeric", hour12: true, minute: "2-digit", timeZone: "Africa/Lagos" }) : "";
  return (
    <section className="w-full max-w-md rounded-3xl border bg-card p-6 shadow-sm">
      {/* Real brand mark from /brand (never redrawn) */}
      <img src="/brand/favicon.svg" alt="" className="mb-4 size-16 rounded-2xl" />
      <h1 className="text-2xl font-bold">SolutionTee CBT</h1>
      <p className="mt-1 text-sm text-muted-foreground">Learn. Think. Solve.</p>
      <p className="mt-4 rounded-xl bg-warning-soft px-3 py-2 text-sm text-on-warning-soft">
        {play ? (
          <>
            <b>Google Play version (preview).</b> This is how the app will be on Google Play: no Paystack inside the app, no
            update from this page (Google Play updates it), and Premium is bought with Google Play. Buying only works once
            the app is on a Play Console testing track.
          </>
        ) : test ? (
          <>
            <b>Work-in-progress build{info?.branch ? ` from “${info.branch}”` : ""}.</b> For checking new changes before they go to the team.
          </>
        ) : (
          <>
            <b>Test version for Android.</b> For the team and invited testers only. Please do not share this link.
          </>
        )}
      </p>
      {info ? (
        <>
          <a href={test ? "/download/apk?channel=test" : play ? "/download/apk?channel=play" : "/download/apk"} className="mt-5 flex h-12 w-full items-center justify-center rounded-xl bg-primary text-[15px] font-bold text-primary-foreground hover:opacity-90">
            Download the app ({mb} MB)
          </a>
          <p className="mt-2 text-center text-xs text-muted-foreground">Version {info.version} · {date}</p>
        </>
      ) : (
        <p className="mt-5 text-sm">The app file is being prepared. Check back soon.</p>
      )}
      {!play && !test && (
        <a href="/download?channel=play" className="mt-3 block text-center text-sm font-semibold text-secondary underline-offset-4 hover:underline">
          Try the Google Play version (preview)
        </a>
      )}
      {play && (
        <a href="/download/aab" className="mt-3 flex h-11 w-full items-center justify-center rounded-xl border text-sm font-bold hover:bg-muted">
          Google Play Console file (.aab) for uploading
        </a>
      )}
      {play && (
        <p className="mt-3 rounded-xl bg-info-soft px-3 py-2 text-xs text-on-info-soft">
          It installs over the normal app and keeps your account. To go back, install the normal app from{" "}
          <a href="/download" className="font-semibold underline">this page</a> again.
        </p>
      )}
      <h2 className="mt-6 text-sm font-bold">How to install</h2>
      <ol className="mt-2 list-decimal space-y-1.5 pl-5 text-sm text-muted-foreground">
        <li>Open this page on your Android phone and tap <b>Download the app</b>.</li>
        <li>Open the downloaded file. If Android asks, allow <b>Install unknown apps</b> for your browser.</li>
        <li>Tap <b>Install</b>, then <b>Open</b>, and create your account.</li>
        <li>To update later, download again and install over the old one. Your account stays.</li>
      </ol>
      <p className="mt-6 text-[11px] leading-4 text-muted-foreground">
        SolutionTee CBT is an independent exam-practice platform and is not affiliated with or endorsed by JAMB, WAEC or NECO.
      </p>
    </section>
  );
}
