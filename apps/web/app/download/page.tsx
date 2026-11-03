import { Suspense } from "react";
import type { Metadata } from "next";
import { connection } from "next/server";
import { hasR2 } from "@/lib/env";
import { readJson } from "@/lib/r2";
import type { ApkInfo } from "./apk/route";

export const metadata: Metadata = {
  title: "Download the Android app",
  description: "SolutionTee CBT for Android (test version).",
  robots: { index: false, follow: false },
};

export default function Page() {
  return (
    <main className="grid min-h-dvh place-items-center bg-[var(--c-bg)] px-4 py-10">
      <Suspense fallback={<div className="h-96 w-full max-w-md animate-pulse rounded-3xl bg-card" />}>
        <Download />
      </Suspense>
    </main>
  );
}

async function Download() {
  await connection();
  const info = hasR2() ? await readJson<ApkInfo>("apk/latest.json").catch(() => null) : null;
  const mb = info ? (info.size / 1024 / 1024).toFixed(1) : "";
  const date = info ? new Date(info.built_at).toLocaleString("en-NG", { day: "numeric", month: "short", year: "numeric", hour: "numeric", minute: "2-digit", timeZone: "Africa/Lagos" }) : "";
  return (
    <section className="w-full max-w-md rounded-3xl border bg-card p-6 shadow-sm">
      {/* Real brand mark from /brand (never redrawn) */}
      <img src="/brand/favicon.svg" alt="" className="mb-4 size-16 rounded-2xl" />
      <h1 className="text-2xl font-bold">SolutionTee CBT</h1>
      <p className="mt-1 text-sm text-muted-foreground">Learn. Think. Solve.</p>
      <p className="mt-4 rounded-xl bg-warning-soft px-3 py-2 text-sm text-on-warning-soft">
        <b>Test version for Android.</b> For the team and invited testers only. Please do not share this link.
      </p>
      {info ? (
        <>
          <a href="/download/apk" className="mt-5 flex h-12 w-full items-center justify-center rounded-xl bg-primary text-[15px] font-bold text-primary-foreground hover:opacity-90">
            Download the app ({mb} MB)
          </a>
          <p className="mt-2 text-center text-xs text-muted-foreground">Version {info.version} · {date}</p>
        </>
      ) : (
        <p className="mt-5 text-sm">The app file is being prepared. Check back soon.</p>
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
