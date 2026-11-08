"use client";
import { animate, motion, useInView, useReducedMotion } from "motion/react";
import { useEffect, useRef, useState } from "react";

const ease = [0.22, 1, 0.36, 1] as const;

/** Fades and slides in when it scrolls into view (once). Still when the visitor asked for less motion. */
export function Reveal({ children, delay = 0, y = 24, className }: { children: React.ReactNode; delay?: number; y?: number; className?: string }) {
  const still = useReducedMotion();
  return (
    <motion.div
      className={className}
      initial={still ? false : { opacity: 0, y }}
      whileInView={{ opacity: 1, y: 0 }}
      viewport={{ once: true, margin: "-60px" }}
      transition={{ duration: 0.6, delay, ease }}
    >
      {children}
    </motion.div>
  );
}

/** A number that counts up when it comes into view. */
export function CountUp({ to, suffix = "", className }: { to: number; suffix?: string; className?: string }) {
  const ref = useRef<HTMLSpanElement>(null);
  const seen = useInView(ref, { once: true, margin: "-40px" });
  const still = useReducedMotion();
  const [v, setV] = useState(still ? to : 0);
  useEffect(() => {
    if (!seen || still) return;
    const c = animate(0, to, { duration: 1.6, ease, onUpdate: (n) => setV(Math.round(n)) });
    return () => c.stop();
  }, [seen, still, to]);
  return <span ref={ref} className={className}>{v.toLocaleString("en-NG")}{suffix}</span>;
}

export { ease };
