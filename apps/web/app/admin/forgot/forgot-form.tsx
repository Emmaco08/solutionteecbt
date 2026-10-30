"use client";
import { useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { SpinnerGap } from "@phosphor-icons/react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { createClient } from "@/lib/supabase/client";

/**
 * Admin password reset, the same way the app does it (docs/AUTH_EMAIL.md):
 * 1. POST /api/auth/forgot-password emails a one-time code (rate-limited; same answer for unknown emails).
 * 2. verifyOtp(recovery) signs in at level 1, updateUser sets the new password.
 * 3. The admin still has to pass the authenticator step on /admin/mfa before anything opens.
 */
export function ForgotForm() {
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [step, setStep] = useState<"email" | "code">("email");
  const [codeLength, setCodeLength] = useState(8);
  const [info, setInfo] = useState("");
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);

  async function sendCode(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setBusy(true);
    setError("");
    try {
      const r = await fetch("/api/auth/forgot-password", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ email }) });
      const j = await r.json();
      if (!r.ok) throw new Error(j.error ?? "Could not send the code. Try again.");
      if (j.codeLength) setCodeLength(j.codeLength);
      setInfo(j.message);
      setStep("code");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Could not send the code. Try again.");
    } finally {
      setBusy(false);
    }
  }

  async function reset(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const f = new FormData(e.currentTarget);
    const token = String(f.get("code")).replace(/\s/g, "");
    const password = String(f.get("password"));
    if (password !== String(f.get("confirm"))) return setError("The two passwords are not the same.");
    if (password.length < 10 || !/[a-z]/i.test(password) || !/\d/.test(password)) return setError("Use at least 10 characters with letters and numbers.");
    setBusy(true);
    setError("");
    const supabase = createClient();
    const { error: otpError } = await supabase.auth.verifyOtp({ email, token, type: "recovery" });
    if (otpError) {
      setBusy(false);
      return setError(/expired|invalid/i.test(otpError.message) ? "That code is wrong or has expired. Ask for a new one." : otpError.message);
    }
    const { data, error: upError } = await supabase.auth.updateUser({ password });
    if (upError) {
      setBusy(false);
      return setError(/same|different/i.test(upError.message) ? "Choose a password you have not used before." : upError.message);
    }
    const token2 = (await supabase.auth.getSession()).data.session?.access_token;
    if (token2 && data.user) {
      fetch("/api/auth/notify", { method: "POST", headers: { "content-type": "application/json", authorization: `Bearer ${token2}` }, body: JSON.stringify({ event: "password_changed" }) }).catch(() => {});
    }
    router.replace("/admin/mfa");
    router.refresh();
  }

  if (step === "email") {
    return (
      <form onSubmit={sendCode} className="space-y-5" noValidate>
        <div className="space-y-2">
          <Label htmlFor="email">Admin email</Label>
          <Input id="email" type="email" autoComplete="username" required className="h-12" value={email} onChange={(e) => setEmail(e.target.value.trim())} />
        </div>
        {error ? <p role="alert" className="text-sm font-bold text-error">{error}</p> : null}
        <Button type="submit" disabled={busy || !email} className="h-12 w-full text-[15px]">
          {busy ? <SpinnerGap className="animate-spin" size={18} /> : null} Send me a code
        </Button>
        <p className="text-center text-sm"><Link href="/admin/login" className="font-bold text-link">Back to log in</Link></p>
      </form>
    );
  }

  return (
    <form onSubmit={reset} className="space-y-5" noValidate>
      <p className="rounded-xl bg-info-soft px-4 py-3 text-sm text-on-info-soft">{info} Check your spam folder too.</p>
      <div className="space-y-2">
        <Label htmlFor="code">{codeLength}-digit code</Label>
        <Input id="code" name="code" inputMode="numeric" autoComplete="one-time-code" maxLength={codeLength} required className="h-12 tracking-[.3em]" />
      </div>
      <div className="space-y-2">
        <Label htmlFor="password">New password</Label>
        <Input id="password" name="password" type="password" autoComplete="new-password" required minLength={10} className="h-12" />
        <p className="text-xs text-muted-foreground">At least 10 characters with letters and numbers. Save it in a password manager.</p>
      </div>
      <div className="space-y-2">
        <Label htmlFor="confirm">New password again</Label>
        <Input id="confirm" name="confirm" type="password" autoComplete="new-password" required className="h-12" />
      </div>
      {error ? <p role="alert" className="text-sm font-bold text-error">{error}</p> : null}
      <Button type="submit" disabled={busy} className="h-12 w-full text-[15px]">
        {busy ? <SpinnerGap className="animate-spin" size={18} /> : null} Set new password
      </Button>
      <p className="text-center text-sm">
        <button type="button" className="font-bold text-link" onClick={() => { setStep("email"); setError(""); }}>Send a new code</button>
      </p>
    </form>
  );
}
