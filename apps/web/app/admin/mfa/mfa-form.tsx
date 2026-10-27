"use client";
import { useEffect, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { SpinnerGap, Copy, ShieldCheck } from "@phosphor-icons/react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { createClient } from "@/lib/supabase/client";

type Mode =
  | { kind: "loading" }
  | { kind: "enroll"; factorId: string; qr: string; secret: string }
  | { kind: "verify"; factorId: string }
  | { kind: "error"; message: string };

export function MfaForm({ next }: { next: string }) {
  const router = useRouter();
  const [mode, setMode] = useState<Mode>({ kind: "loading" });
  const [code, setCode] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const started = useRef(false);

  useEffect(() => {
    if (started.current) return;
    started.current = true;
    (async () => {
      const supabase = createClient();
      const { data, error } = await supabase.auth.mfa.listFactors();
      if (error) return setMode({ kind: "error", message: error.message });
      const verified = data.totp.find((f) => f.status === "verified");
      if (verified) return setMode({ kind: "verify", factorId: verified.id });
      // Clear half-finished setups, then start a fresh one.
      for (const f of data.all.filter((f) => f.status !== "verified")) await supabase.auth.mfa.unenroll({ factorId: f.id });
      const enrolled = await supabase.auth.mfa.enroll({ factorType: "totp", friendlyName: `SolutionTee admin ${new Date().toISOString().slice(0, 10)}` });
      if (enrolled.error) return setMode({ kind: "error", message: enrolled.error.message });
      setMode({ kind: "enroll", factorId: enrolled.data.id, qr: enrolled.data.totp.qr_code, secret: enrolled.data.totp.secret });
    })();
  }, []);

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (mode.kind !== "enroll" && mode.kind !== "verify") return;
    setBusy(true);
    setError("");
    const { error } = await createClient().auth.mfa.challengeAndVerify({ factorId: mode.factorId, code: code.trim() });
    if (error) {
      setError(/invalid|expired/i.test(error.message) ? "That code is not right. Check the time on your phone and try the newest code." : error.message);
      setBusy(false);
      setCode("");
      return;
    }
    router.replace(next);
    router.refresh();
  }

  if (mode.kind === "loading") return <div className="h-48 animate-pulse rounded-2xl bg-muted" aria-busy="true" />;
  if (mode.kind === "error") return <p role="alert" className="rounded-xl bg-error-soft px-4 py-3 text-sm text-on-error-soft">{mode.message}</p>;

  return (
    <form onSubmit={onSubmit} className="space-y-6">
      {mode.kind === "enroll" ? (
        <ol className="space-y-4 text-sm leading-6">
          <li>
            <b>1. Scan this code</b> with your authenticator app.
            <div className="mt-3 grid place-items-center rounded-2xl border bg-white p-4">
              {/* QR comes from Supabase as an SVG data URL */}
              <img src={mode.qr} alt="QR code for your authenticator app" className="size-44" />
            </div>
          </li>
          <li>
            Can&apos;t scan? Enter this key in the app:
            <div className="mt-2 flex items-center gap-2 rounded-xl bg-muted px-3 py-2 font-mono text-xs break-all">
              <span className="grow">{mode.secret}</span>
              <button type="button" aria-label="Copy key" onClick={() => navigator.clipboard.writeText(mode.secret)} className="grid size-9 place-items-center rounded-lg hover:bg-background">
                <Copy size={16} />
              </button>
            </div>
          </li>
          <li><b>2. Type the 6-digit code</b> the app shows.</li>
        </ol>
      ) : (
        <p className="flex items-center gap-2 text-sm text-muted-foreground"><ShieldCheck size={18} weight="fill" className="text-success" /> Open your authenticator app and type the 6-digit code for SolutionTee.</p>
      )}
      <div className="space-y-2">
        <Label htmlFor="code">6-digit code</Label>
        <Input
          id="code" inputMode="numeric" autoComplete="one-time-code" pattern="[0-9]{6}" maxLength={6} autoFocus required
          value={code} onChange={(e) => setCode(e.target.value.replace(/\D/g, "").slice(0, 6))}
          className="h-14 text-center font-mono text-2xl tracking-[0.5em]"
        />
      </div>
      {error ? <p role="alert" className="text-sm font-bold text-error">{error}</p> : null}
      <Button type="submit" disabled={busy || code.length !== 6} className="h-12 w-full text-[15px]">
        {busy ? <SpinnerGap className="animate-spin" size={18} /> : null} {mode.kind === "enroll" ? "Turn on 2-step login" : "Continue"}
      </Button>
    </form>
  );
}
