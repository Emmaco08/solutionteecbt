"use client";
import { useMemo, useState } from "react";
import { CheckCircle, SpinnerGap, Trash } from "@phosphor-icons/react";
import { createClient } from "@/lib/supabase/client";

/** Email → code → type DELETE → the account is deleted by the same server endpoint the app uses. */
export function DeleteFlow() {
  const sb = useMemo(() => createClient(), []);
  const [step, setStep] = useState<"email" | "code" | "confirm" | "done">("email");
  const [email, setEmail] = useState("");
  const [code, setCode] = useState("");
  const [word, setWord] = useState("");
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const [note, setNote] = useState<string | null>(null);

  async function send(e?: React.FormEvent) {
    e?.preventDefault();
    setBusy(true); setErr(null);
    try {
      const r = await fetch("/api/web/login-code", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ email, purpose: "delete" }) });
      const j = await r.json().catch(() => ({}));
      if (!r.ok) throw new Error(j.error ?? "Something went wrong. Try again.");
      setNote(j.message ?? null); setStep("code");
    } catch (x) { setErr(x instanceof Error ? x.message : "No internet connection."); } finally { setBusy(false); }
  }

  async function verify(e?: React.FormEvent) {
    e?.preventDefault();
    setBusy(true); setErr(null);
    const { error } = await sb.auth.verifyOtp({ email: email.trim().toLowerCase(), token: code.trim(), type: "recovery" });
    setBusy(false);
    if (error) setErr("That code is wrong or has expired. Check it, or ask for a new one.");
    else setStep("confirm");
  }

  async function del(e?: React.FormEvent) {
    e?.preventDefault();
    setBusy(true); setErr(null);
    try {
      const { data } = await sb.auth.getSession();
      const token = data.session?.access_token;
      if (!token) throw new Error("Please start again.");
      const r = await fetch("/api/account/delete", { method: "POST", headers: { "content-type": "application/json", authorization: `Bearer ${token}` }, body: JSON.stringify({ confirm: "DELETE" }) });
      const j = await r.json().catch(() => ({}));
      if (!r.ok) throw new Error(j.error ?? "We could not delete the account. Contact support.");
      await sb.auth.signOut({ scope: "local" });
      setStep("done");
    } catch (x) { setErr(x instanceof Error ? x.message : "No internet connection."); } finally { setBusy(false); }
  }

  const btn = "mt-4 inline-flex h-12 w-full items-center justify-center gap-2 rounded-2xl font-bold disabled:opacity-60";
  return (
    <section className="mt-8 rounded-3xl border bg-card p-6 shadow-sm">
      {step === "done" ? (
        <div className="text-center">
          <CheckCircle size={48} weight="fill" className="mx-auto text-[#16A34A]" />
          <h2 className="mt-3 text-xl font-bold">Your account has been deleted</h2>
          <p className="mt-2 text-sm text-muted-foreground">We are sorry to see you go. You can create a new account at any time.</p>
        </div>
      ) : step === "email" ? (
        <form onSubmit={send}>
          <label htmlFor="del-email" className="text-sm font-bold">Email on your account</label>
          <input id="del-email" type="email" required autoComplete="email" value={email} onChange={(e) => setEmail(e.target.value)} placeholder="tolu@gmail.com"
            className="mt-2 h-12 w-full rounded-2xl border bg-background px-4 outline-none focus:ring-2 focus:ring-ring" />
          {err ? <p className="mt-3 rounded-xl bg-error-soft px-3 py-2 text-sm text-on-error-soft">{err}</p> : null}
          <button type="submit" disabled={busy || !email} className={`${btn} bg-[#0B1F44] text-white dark:bg-white dark:text-[#0B1F44]`}>{busy ? <SpinnerGap size={18} className="animate-spin" /> : null} Send me a code</button>
        </form>
      ) : step === "code" ? (
        <form onSubmit={verify}>
          <p className="text-sm text-muted-foreground">{note ?? `We sent a code to ${email}.`}</p>
          <input autoFocus inputMode="numeric" autoComplete="one-time-code" maxLength={8} value={code} onChange={(e) => setCode(e.target.value.replace(/\D/g, ""))} aria-label="Code"
            placeholder="••••••" className="mt-4 h-14 w-full rounded-2xl border bg-background text-center text-2xl font-bold tracking-[0.4em] outline-none focus:ring-2 focus:ring-ring" />
          {err ? <p className="mt-3 rounded-xl bg-error-soft px-3 py-2 text-sm text-on-error-soft">{err}</p> : null}
          <button type="submit" disabled={busy || code.length < 6} className={`${btn} bg-[#0B1F44] text-white dark:bg-white dark:text-[#0B1F44]`}>{busy ? <SpinnerGap size={18} className="animate-spin" /> : null} Continue</button>
        </form>
      ) : (
        <form onSubmit={del}>
          <p className="text-sm"><b>This cannot be undone.</b> Type <b>DELETE</b> to delete the account for {email}.</p>
          <input value={word} onChange={(e) => setWord(e.target.value)} aria-label="Type DELETE" className="mt-3 h-12 w-full rounded-2xl border bg-background px-4 font-bold uppercase outline-none focus:ring-2 focus:ring-ring" />
          {err ? <p className="mt-3 rounded-xl bg-error-soft px-3 py-2 text-sm text-on-error-soft">{err}</p> : null}
          <button type="submit" disabled={busy || word.trim().toUpperCase() !== "DELETE"} className={`${btn} bg-[#B42318] text-white`}>{busy ? <SpinnerGap size={18} className="animate-spin" /> : <Trash size={18} weight="bold" />} Delete my account</button>
        </form>
      )}
    </section>
  );
}
