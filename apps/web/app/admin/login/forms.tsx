"use client";
import { useActionState, useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { Eye, EyeSlash, SpinnerGap } from "@phosphor-icons/react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { createClient } from "@/lib/supabase/client";
import { createFirstAdmin, type SetupState } from "./actions";

const friendly = (msg: string) =>
  /invalid login/i.test(msg) ? "Email or password is not correct."
  : /rate|too many/i.test(msg) ? "Too many tries. Wait a minute and try again."
  : /not confirmed/i.test(msg) ? "Confirm your email first, then log in."
  : msg;

function PasswordInput(props: React.ComponentProps<typeof Input>) {
  const [show, setShow] = useState(false);
  return (
    <div className="relative">
      <Input {...props} type={show ? "text" : "password"} className="h-12 pr-12" />
      <button type="button" onClick={() => setShow((s) => !s)} aria-label={show ? "Hide password" : "Show password"}
        className="absolute inset-y-0 right-0 grid w-12 place-items-center text-muted-foreground hover:text-foreground">
        {show ? <EyeSlash size={20} /> : <Eye size={20} />}
      </button>
    </div>
  );
}

export function LoginForm({ notice, next }: { notice?: string; next: string }) {
  const router = useRouter();
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);

  async function onSubmit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setBusy(true);
    setError("");
    const f = new FormData(e.currentTarget);
    const { error } = await createClient().auth.signInWithPassword({
      email: String(f.get("email")).trim(), password: String(f.get("password")),
    });
    if (error) { setError(friendly(error.message)); setBusy(false); return; }
    router.replace(`/admin/mfa?next=${encodeURIComponent(next)}`);
    router.refresh();
  }

  return (
    <form onSubmit={onSubmit} className="space-y-5" noValidate>
      {notice ? <p className="rounded-xl bg-warning-soft px-4 py-3 text-sm text-on-warning-soft">{notice}</p> : null}
      <div className="space-y-2">
        <Label htmlFor="email">Email</Label>
        <Input id="email" name="email" type="email" autoComplete="username" required className="h-12" />
      </div>
      <div className="space-y-2">
        <Label htmlFor="password">Password</Label>
        <PasswordInput id="password" name="password" autoComplete="current-password" required />
      </div>
      {error ? <p role="alert" className="text-sm font-bold text-error">{error}</p> : null}
      <Button type="submit" disabled={busy} className="h-12 w-full text-[15px]">
        {busy ? <SpinnerGap className="animate-spin" size={18} /> : null} Log in
      </Button>
      <p className="text-center text-xs text-muted-foreground">Forgot your password? Ask a super admin to send a reset link.</p>
    </form>
  );
}

export function SetupForm() {
  const router = useRouter();
  const [state, action, pending] = useActionState<SetupState, FormData>(createFirstAdmin, {});
  const [creds, setCreds] = useState<{ email: string; password: string } | null>(null);

  useEffect(() => {
    if (!state.ok || !creds) return;
    createClient().auth.signInWithPassword(creds).then(({ error }) => {
      if (!error) { router.replace("/admin/mfa"); router.refresh(); }
    });
  }, [state.ok, creds, router]);

  return (
    <form
      action={(f) => { setCreds({ email: String(f.get("email")).trim().toLowerCase(), password: String(f.get("password")) }); action(f); }}
      className="space-y-5"
    >
      <div className="space-y-2">
        <Label htmlFor="name">Full name</Label>
        <Input id="name" name="name" autoComplete="name" required className="h-12" />
      </div>
      <div className="space-y-2">
        <Label htmlFor="email">Email</Label>
        <Input id="email" name="email" type="email" autoComplete="username" required className="h-12" />
      </div>
      <div className="space-y-2">
        <Label htmlFor="password">Password</Label>
        <PasswordInput id="password" name="password" autoComplete="new-password" required minLength={10} />
        <p className="text-xs text-muted-foreground">At least 10 characters with letters and numbers. Save it in a password manager.</p>
      </div>
      {state.error ? <p role="alert" className="text-sm font-bold text-error">{state.error}</p> : null}
      <Button type="submit" disabled={pending || state.ok} className="h-12 w-full text-[15px]">
        {pending || state.ok ? <SpinnerGap className="animate-spin" size={18} /> : null} Create super admin
      </Button>
    </form>
  );
}
