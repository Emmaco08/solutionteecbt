"use client";
import Link from "next/link";
import { motion, useReducedMotion } from "motion/react";
import { useEffect, useState } from "react";
import { CheckCircle, Clock, SpinnerGap, WarningCircle } from "@phosphor-icons/react";
import { payStatus, type PayStatus } from "./status";

/** Checks the payment every 4 s for up to 3 minutes (the Paystack webhook usually arrives within seconds). */
export function PayResult({ reference, initial }: { reference: string; initial: PayStatus }) {
  const [s, setS] = useState(initial);
  const [tries, setTries] = useState(0);
  const still = useReducedMotion();
  useEffect(() => {
    if (s.status !== "pending" && s.status !== "abandoned") return;
    if (tries > 45) return;
    const t = setTimeout(async () => { setS(await payStatus(reference)); setTries((n) => n + 1); }, 4000);
    return () => clearTimeout(t);
  }, [s, tries, reference]);

  const until = s.until ? new Date(s.until).toLocaleDateString("en-NG", { day: "numeric", month: "long", year: "numeric" }) : null;
  if (s.status === "success") {
    return (
      <div className="text-center">
        <motion.span initial={still ? false : { scale: 0.4, opacity: 0 }} animate={{ scale: 1, opacity: 1 }} transition={{ type: "spring", stiffness: 260, damping: 16 }}
          className="mx-auto grid size-20 place-items-center rounded-full bg-[#E8F7EE] text-[#16A34A]"><CheckCircle size={48} weight="fill" /></motion.span>
        <h1 className="mt-5 text-2xl font-bold">Premium is on! 🎉</h1>
        <p className="mt-2 text-[15px] text-muted-foreground">{s.plan ? `${s.plan} plan` : "Your plan"}{until ? `, until ${until}` : ""}. Open the SolutionTee app: Premium is already there (log in with the same email).</p>
        <Link href="/" className="mt-6 inline-flex h-12 items-center justify-center rounded-2xl bg-[#0B1F44] px-6 font-bold text-white dark:bg-white dark:text-[#0B1F44]">Back to the website</Link>
      </div>
    );
  }
  if (s.status === "failed") {
    return (
      <div className="text-center">
        <span className="mx-auto grid size-20 place-items-center rounded-full bg-error-soft text-on-error-soft"><WarningCircle size={44} weight="fill" /></span>
        <h1 className="mt-5 text-2xl font-bold">The payment did not go through</h1>
        <p className="mt-2 text-[15px] text-muted-foreground">No money was taken for Premium. You can try again with another way to pay.</p>
        <Link href="/pay" className="mt-6 inline-flex h-12 items-center justify-center rounded-2xl bg-[#F2B233] px-6 font-bold text-[#0B1F44]">Try again</Link>
      </div>
    );
  }
  if (s.status === "needs_review" || s.status === "refunded") {
    return (
      <div className="text-center">
        <span className="mx-auto grid size-20 place-items-center rounded-full bg-warning-soft text-on-warning-soft"><Clock size={44} weight="fill" /></span>
        <h1 className="mt-5 text-2xl font-bold">{s.status === "refunded" ? "This payment was refunded" : "We are checking this payment"}</h1>
        <p className="mt-2 text-[15px] text-muted-foreground">{s.status === "refunded" ? "The money went back to you." : "Our team will look at it and email you. You do not need to pay again."} Questions? Write to support@mail.solutiontee.com.</p>
      </div>
    );
  }
  return (
    <div className="text-center">
      <span className="mx-auto grid size-20 place-items-center rounded-full bg-info-soft text-on-info-soft"><SpinnerGap size={40} className="animate-spin" /></span>
      <h1 className="mt-5 text-2xl font-bold">Confirming your payment…</h1>
      <p className="mt-2 text-[15px] text-muted-foreground">{s.status === "unknown" ? "We could not find this payment yet." : "This usually takes a few seconds."} Paid by bank transfer? It can take a few minutes. You do not need to pay again.</p>
      {tries > 45 ? <p className="mt-4 text-sm">Still waiting. Open the app later: Premium turns on by itself when the payment arrives.</p> : null}
    </div>
  );
}
