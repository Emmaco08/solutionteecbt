"use client";
import { useState, useTransition } from "react";
import { stopChildAccount } from "./actions";

export function StopButton({ token, name }: { token: string; name: string }) {
  const [pending, start] = useTransition();
  const [sure, setSure] = useState(false);
  const [done, setDone] = useState<{ ok: boolean; message: string } | null>(null);
  if (done) return <p className={`mt-6 rounded-xl px-3 py-3 text-sm ${done.ok ? "bg-success-soft text-on-success-soft" : "bg-error-soft text-on-error-soft"}`}>{done.message}</p>;
  return (
    <div className="mt-6 grid gap-3">
      <label className="flex items-start gap-3 rounded-xl border p-3 text-left text-sm">
        <input type="checkbox" className="mt-0.5 size-5" checked={sure} onChange={(e) => setSure(e.target.checked)} />
        <span>I am {name}&apos;s parent or guardian and I want to turn off this account.</span>
      </label>
      <button
        type="button"
        disabled={!sure || pending}
        onClick={() => start(async () => setDone(await stopChildAccount(token)))}
        className="h-12 rounded-xl bg-[#B42318] px-5 font-bold text-white disabled:opacity-50"
      >
        {pending ? "Turning off…" : "Turn off the account"}
      </button>
    </div>
  );
}
