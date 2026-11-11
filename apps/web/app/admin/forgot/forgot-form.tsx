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
 * 2. verifyOtp(recovery) signs in at level 1.
 * 3. With 2-step login on, Supabase only changes the password at level 2, so the authenticator code is asked
 *    first (challengeAndVerify), then updateUser sets the new password and the admin goes straight in.
 */
export function ForgotForm() {
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [step, setStep] = useState<"email" | "code" | "mfa">("email");
  const [codeLength, setCodeLength] = useState(8);
  const [info, setInfo] = useState("");
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);
  const [password, setPassword] = useState("");
  const [factorId, setFactorId] = useState("");
  const [totp, setTotp] = useState("");

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

  /** Saves the new password (the session is at the level Supabase needs) and opens the admin. */
  async function finish(pw: string) {
    const supabase = createClient();
    const { data, error: upError } = await supabase.auth.updateUser({ password: pw });
    if (upError) {
      setBusy(false);
      return setError(/same|different/i.test(upError.message) ? "Choose a password you have not used before."
        : /aal2/i.test(upError.message) ? "Enter the code from your authenticator app first." : upError.message);
    }
    const token2 = (await supabase.auth.getSession()).data.session?.access_token;
    if (token2 && data.user) {
      fetch("/api/auth/notify", { method: "POST", headers: { "content-type": "application/json", authorization: `Bearer ${token2}` }, body: JSON.stringify({ event: "password_changed" }) }).catch(() => {});
    }
    router.replace("/admin");
    router.refresh();
  }

  async function reset(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const f = new FormData(e.currentTarget);
    const token = String(f.get("code")).replace(/\s/g, "");
    const pw = String(f.get("password"));
    if (pw !== String(f.get("confirm"))) return setError("The two passwords are not the same.");
    if (pw.length < 10 || !/[a-z]/i.test(pw) || !/\d/.test(pw)) return setError("Use at least 10 characters with letters and numbers.");
    setBusy(true);
    setError("");
    const supabase = createClient();
    // A code already used in this browser (for example a try before this fix) has signed it in: keep that sign-in.
    const current = (await supabase.auth.getUser()).data.user;
    if (!current || current.email?.toLowerCase() !== email.toLowerCase()) {
      const { error: otpError } = await supabase.auth.verifyOtp({ email, token, type: "recovery" });
      if (otpError) {
        setBusy(false);
        return setError(/expired|invalid/i.test(otpError.message) ? "That code is wrong or has expired. Ask for a new one." : otpError.message);
      }
    }
    const { data: aal } = await supabase.auth.mfa.getAuthenticatorAssuranceLevel();
    if (aal?.nextLevel === "aal2" && aal.currentLevel !== "aal2") {
      const { data: factors } = await supabase.auth.mfa.listFactors();
      const verified = factors?.totp.find((x) => x.status === "verified");
      if (verified) {
        setPassword(pw);
        setFactorId(verified.id);
        setStep("mfa");
        setBusy(false);
        return;
      }
    }
    await finish(pw);
  }

  async function confirmMfa(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setBusy(true);
    setError("");
    const { error: mfaError } = await createClient().auth.mfa.challengeAndVerify({ factorId, code: totp.trim() });
    if (mfaError) {
      setBusy(false);
      setTotp("");
      return setError(/invalid|expired/i.test(mfaError.message) ? "That code is not right. Check the time on your phone and try the newest code." : mfaError.message);
    }
    await finish(password);
  }

  if (step === "mfa") {
    return (
      <form onSubmit={confirmMfa} className="space-y-5" noValidate>
        <p className="rounded-xl bg-info-soft px-4 py-3 text-sm text-on-info-soft">Email code accepted. Now open your authenticator app and enter the 6-digit code for SolutionTee admin to save the new password.</p>
        <div className="space-y-2">
          <Label htmlFor="totp">Authenticator code</Label>
          <Input id="totp" inputMode="numeric" autoComplete="one-time-code" maxLength={6} required autoFocus className="h-12 tracking-[.3em]"
            value={totp} onChange={(e) => setTotp(e.target.value.replace(/\D/g, ""))} />
        </div>
        {error ? <p role="alert" className="text-sm font-bold text-error">{error}</p> : null}
        <Button type="submit" disabled={busy || totp.length !== 6} className="h-12 w-full text-[15px]">
          {busy ? <SpinnerGap className="animate-spin" size={18} /> : null} Confirm and save password
        </Button>
      </form>
    );
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
