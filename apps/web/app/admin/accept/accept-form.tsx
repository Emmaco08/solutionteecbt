"use client";
import { useEffect, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { SpinnerGap } from "@phosphor-icons/react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { createClient } from "@/lib/supabase/client";

export function AcceptForm({ tokenHash, type }: { tokenHash: string; type: "invite" | "recovery" }) {
  const router = useRouter();
  const [state, setState] = useState<"checking" | "ready" | "bad">(tokenHash ? "checking" : "bad");
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);
  const started = useRef(false);

  useEffect(() => {
    if (!tokenHash || started.current) return;
    started.current = true;
    createClient().auth.verifyOtp({ token_hash: tokenHash, type }).then(({ error }) => setState(error ? "bad" : "ready"));
  }, [tokenHash, type]);

  async function onSubmit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const f = new FormData(e.currentTarget);
    const pw = String(f.get("password"));
    if (pw.length < 10 || !/[a-zA-Z]/.test(pw) || !/\d/.test(pw)) return setError("Use at least 10 characters with letters and numbers.");
    if (pw !== String(f.get("confirm"))) return setError("The two passwords are different.");
    setBusy(true);
    const { error } = await createClient().auth.updateUser({ password: pw });
    if (error) { setError(error.message); setBusy(false); return; }
    router.replace("/admin/mfa");
    router.refresh();
  }

  if (state === "checking") return <div className="h-40 animate-pulse rounded-2xl bg-muted" aria-busy="true" />;
  if (state === "bad")
    return <p role="alert" className="rounded-xl bg-error-soft px-4 py-3 text-sm text-on-error-soft">This link has expired or was already used. Ask a super admin to send a new one.</p>;

  return (
    <form onSubmit={onSubmit} className="space-y-5">
      <div className="space-y-2">
        <Label htmlFor="password">New password</Label>
        <Input id="password" name="password" type="password" autoComplete="new-password" required className="h-12" />
      </div>
      <div className="space-y-2">
        <Label htmlFor="confirm">Type it again</Label>
        <Input id="confirm" name="confirm" type="password" autoComplete="new-password" required className="h-12" />
      </div>
      {error ? <p role="alert" className="text-sm font-bold text-error">{error}</p> : null}
      <Button type="submit" disabled={busy} className="h-12 w-full text-[15px]">
        {busy ? <SpinnerGap className="animate-spin" size={18} /> : null} Save and continue
      </Button>
    </form>
  );
}
