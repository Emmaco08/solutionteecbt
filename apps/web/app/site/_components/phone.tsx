"use client";
import { motion, useMotionValue, useReducedMotion, useSpring, useTransform } from "motion/react";
import { useRef, useSyncExternalStore } from "react";

/** The app is designed at 390 × 844 (prototype and Flutter). Screens are drawn at that size and scaled into the phone. */
export const SCREEN_W = 390;
export const SCREEN_H = 844;

/**
 * A realistic phone: titanium-style frame with side buttons, black bezel, camera island, glass reflection that moves
 * with the tilt, and a soft floor shadow. Tilts in 3D towards a mouse and floats gently with a CSS loop (still with
 * reduce motion). No blur filters: they are slow to draw on phones (D-131).
 */
export function Phone3D({ children, width = 300, tilt = true, float = true, rotate = 0, className }: {
  children: React.ReactNode; width?: number; tilt?: boolean; float?: boolean; rotate?: number; className?: string;
}) {
  const still = useReducedMotion();
  const ref = useRef<HTMLDivElement>(null);
  const mx = useMotionValue(0), my = useMotionValue(0);
  const rx = useSpring(useTransform(my, [-0.5, 0.5], [10, -10]), { stiffness: 120, damping: 16 });
  const ry = useSpring(useTransform(mx, [-0.5, 0.5], [-14, 14]), { stiffness: 120, damping: 16 });
  const glare = useTransform(ry, [-14, 14], ["-30%", "30%"]);
  const pad = Math.round(width * 0.034);
  const inner = width - pad * 2;
  const scale = inner / SCREEN_W;
  const innerH = Math.round(SCREEN_H * scale);
  const radius = Math.round(width * 0.155);

  return (
    <div className={`${className ?? ""} ${float && !still ? "st-float" : ""}`} style={{ perspective: 1600 }}>
      <motion.div
        ref={ref}
        onPointerMove={(e) => {
          // Mouse only: on phones a finger moving over the phone while scrolling must not start the tilt (D-131).
          if (!tilt || still || !ref.current || e.pointerType !== "mouse") return;
          const r = ref.current.getBoundingClientRect();
          mx.set((e.clientX - r.left) / r.width - 0.5);
          my.set((e.clientY - r.top) / r.height - 0.5);
        }}
        onPointerLeave={() => { mx.set(0); my.set(0); }}
        style={{ rotateX: still ? 0 : rx, rotateY: still ? rotate : ry, rotateZ: 0, transformStyle: "preserve-3d", width }}
        className="relative mx-auto"
      >
        {/* Frame */}
        <div
          className="relative"
          style={{
            padding: pad, borderRadius: radius,
            background: "linear-gradient(145deg,#5b6678 0%,#1b2333 22%,#0b111d 50%,#2a3446 78%,#6b7689 100%)",
            boxShadow: "0 0 0 1px rgba(255,255,255,.08) inset, 0 2px 1px rgba(255,255,255,.25) inset, 0 50px 90px -30px rgba(3,10,25,.75), 0 30px 50px -40px rgba(37,99,179,.6)",
          }}
        >
          {/* Side buttons */}
          <span className="absolute rounded-l-sm bg-[#2a3446]" style={{ left: -3, top: "18%", width: 4, height: width * 0.09 }} />
          <span className="absolute rounded-l-sm bg-[#2a3446]" style={{ left: -3, top: "30%", width: 4, height: width * 0.15 }} />
          <span className="absolute rounded-r-sm bg-[#2a3446]" style={{ right: -3, top: "24%", width: 4, height: width * 0.22 }} />
          {/* Screen */}
          <div className="relative overflow-hidden bg-black" style={{ height: innerH, borderRadius: radius - pad }}>
            <div className="absolute left-0 top-0 origin-top-left" style={{ width: SCREEN_W, height: SCREEN_H, transform: `scale(${scale})` }}>
              {children}
            </div>
            {/* Camera island */}
            <div className="absolute left-1/2 -translate-x-1/2 rounded-full bg-black" style={{ top: Math.round(10 * scale * 1.2), width: inner * 0.32, height: Math.max(18, 30 * scale) }}>
              <span className="absolute right-[14%] top-1/2 size-[30%] max-h-[10px] max-w-[10px] -translate-y-1/2 rounded-full bg-[#1a2333] ring-1 ring-[#2e3a52]" />
            </div>
            {/* Glass reflection */}
            <motion.div className="pointer-events-none absolute -inset-y-4 -left-1/2 w-[200%]" style={{ x: glare, background: "linear-gradient(115deg,transparent 30%,rgba(255,255,255,.14) 42%,transparent 55%)" }} />
          </div>
        </div>
        {/* Floor shadow */}
        <div className="pointer-events-none absolute left-1/2 -translate-x-1/2" style={{ bottom: -36, width: width * 0.9, height: 48, transform: "translateZ(-80px)", background: "radial-gradient(closest-side, rgba(0,0,0,.35), transparent)" }} />
      </motion.div>
    </div>
  );
}

/** The visitor's window size, live (server: a common laptop). */
export function useScreen(): { w: number; h: number } {
  const v = useSyncExternalStore(
    (cb) => { window.addEventListener("resize", cb); return () => window.removeEventListener("resize", cb); },
    () => `${window.innerWidth}x${window.innerHeight}`,
    () => "1440x900",
  );
  const [w, h] = v.split("x").map(Number);
  return { w, h };
}

/** A phone is about 2.23 times as tall as it is wide (frame included). */
export const PHONE_RATIO = 2.23;

/**
 * Phone width that fits the visitor's screen (owner, 16 Nov 2026: mockups too big on some laptops): no taller than the
 * window minus [reserve] (menu and padding), no wider than [vw] of it, between [min] and [max].
 */
export function fitPhone(s: { w: number; h: number }, o: { max: number; min?: number; reserve?: number; vw?: number }) {
  const byH = (s.h - (o.reserve ?? 0)) / PHONE_RATIO;
  const byW = s.w * (o.vw ?? 1);
  return Math.round(Math.max(o.min ?? 200, Math.min(o.max, byH, byW)));
}
