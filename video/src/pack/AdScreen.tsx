import React from "react";
import { AbsoluteFill, Audio, staticFile as sfile, Img, Sequence, staticFile } from "remotion";
import { Lottie } from "@remotion/lottie";
import { Phone, SCREEN } from "../components";
import loaderDark from "../../public/brand/solutiontee-loader-dark.json";
import { C, EndCard, FONT, Flash, GoldStage, KText, SERIF, Star4, easeInOut, easeOut, lerp, p, rnd, spr, useF, useS } from "./kit";

// Ad C, "Turn screen time into score time" (D-182): 30 s, dark gold cinematic (reference 3), 100 BPM (a beat every
// 0.6 s, a bar every 2.4 s).
export const SCREEN_SECONDS = 30;

const GOLD_TEXT: React.CSSProperties = {
  background: "linear-gradient(180deg,#FFF3CF 0%,#F7C65A 45%,#C7861B 75%,#8A5A0E 100%)",
  WebkitBackgroundClip: "text",
  backgroundClip: "text",
  color: "transparent",
};

/** A huge word in gold, letter by letter out of a blur (behind the phone). */
const GoldWord: React.FC<{ word: string; at: number; y: number; size: number; out: number }> = ({ word, at, y, size, out }) => {
  const t = useS();
  const F = useF();
  if (t < at - 0.05 || t > out + 0.4) return null;
  const o = p(t, out, out + 0.3, easeInOut);
  // fit the width: bold capitals are about 0.7 em wide each
  const s = Math.min(size * F.ks, (F.W - 100) / (word.length * 0.7));
  return (
    <div style={{ position: "absolute", left: 0, width: F.W, top: y, transform: `translateY(-50%) scale(${lerp(1, 1.06, p(t, at, out, (v) => v))})`, textAlign: "center", fontFamily: FONT, fontWeight: 800, fontSize: s, letterSpacing: "-0.05em", lineHeight: 1, opacity: 1 - o, filter: o > 0 ? `blur(${o * 18}px)` : undefined, whiteSpace: "nowrap" }}>
      {word.split("").map((ch, i) => {
        const k = p(t, at + i * 0.045, at + i * 0.045 + 0.5, easeOut);
        return (
          <span key={i} style={{ display: "inline-block", ...GOLD_TEXT, transform: `translateY(${(1 - k) * 0.4}em)`, opacity: k, filter: k < 1 ? `blur(${(1 - k) * 20}px)` : "drop-shadow(0 10px 40px rgba(242,178,51,.35))" }}>{ch}</span>
        );
      })}
    </div>
  );
};

/** Dark glass card (notifications, chips). */
const Glass: React.FC<{ x: number; y: number; w: number; at: number; out?: number; children: React.ReactNode; rot?: number; flip?: number }> = ({ x, y, w, at, out, children, rot = 0, flip }) => {
  const t = useS();
  const k = spr(t, at, { damping: 13, stiffness: 150 });
  const o = out === undefined ? 1 : 1 - p(t, out, out + 0.25);
  if (k <= 0.001 || o <= 0) return null;
  const fl = flip === undefined ? 0 : p(t, flip, flip + 0.35, easeInOut);
  return (
    <div style={{ position: "absolute", left: x, top: y, width: w, transform: `translate(-50%,-50%) scale(${k}) rotate(${rot + Math.sin(t * 1.5 + x) * 1.5}deg) rotateX(${fl * 360}deg)`, opacity: o * Math.min(1, k * 2), perspective: 800 }}>
      <div style={{ borderRadius: 30, padding: "24px 30px", background: "linear-gradient(160deg, rgba(255,255,255,.14), rgba(255,255,255,.05))", border: "1.5px solid rgba(255,255,255,.16)", boxShadow: "0 30px 60px -20px rgba(0,0,0,.8)", fontFamily: FONT, color: "#fff" }}>{children}</div>
    </div>
  );
};

// ------------------------------------------------------------------ 0–2.4 s: Turn screen time into score time

const NOTES: [string, string][] = [
  ["37 unread messages", "Group chat"],
  ["New video for you", "Watch now"],
  ["Someone liked your post", "Just now"],
  ["You have 5 new followers", "2 min ago"],
];
const QUESTIONS: [string, string][] = [
  ["Q12 · Mathematics", "Find the roots of x² − 5x + 6 = 0"],
  ["Q4 · Biology", "The site of aerobic respiration is…"],
  ["Q31 · Use of English", "Choose the word opposite in meaning"],
  ["Q8 · Physics", "A body moving in a circle has…"],
];

const Hook: React.FC = () => {
  const F = useF();
  const t = useS();
  if (t > 2.6) return null;
  const pos = [[-0.18, -0.12, -6], [0.2, 0.02, 5], [-0.14, 0.16, -3], [0.16, 0.3, 4]];
  return (
    <AbsoluteFill style={{ opacity: 1 - p(t, 2.35, 2.55) }}>
      <KText text="Turn / *screen time*" at={0} y={F.cy - 600 * F.ky} size={120} color="#fff" accent="#F7C65A" stagger={0.06} dur={0.32} />
      <KText text="into / *score time.*" at={1.2} y={F.cy + 640 * F.ky} size={130} color="#fff" accent="#F7C65A" stagger={0.07} />
      {NOTES.map(([a, b], i) => {
        const [px, py, r] = pos[i];
        const flipAt = 1.2 + i * 0.12;
        const flipped = t > flipAt + 0.17;
        const [qa, qb] = QUESTIONS[i];
        return (
          <Glass key={i} x={F.cx + px * F.W * 0.85} y={F.cy + py * F.H * 0.9} w={600 * F.ks} at={0.15 + i * 0.15} rot={r} flip={flipAt}>
            <div style={{ display: "flex", alignItems: "center", gap: 20 }}>
              <div style={{ width: 66 * F.ks, height: 66 * F.ks, borderRadius: 20, background: flipped ? "linear-gradient(135deg,#F7C65A,#C7861B)" : "rgba(255,255,255,.18)", display: "grid", placeItems: "center", fontWeight: 800, fontSize: 30 * F.ks, color: flipped ? C.navy : "#fff" }}>{flipped ? "?" : "●"}</div>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontWeight: 800, fontSize: 32 * F.ks, color: flipped ? "#F7C65A" : "#fff", whiteSpace: "nowrap" }}>{flipped ? qa : a}</div>
                <div style={{ fontWeight: 600, fontSize: 27 * F.ks, opacity: 0.75, whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>{flipped ? qb : b}</div>
              </div>
            </div>
          </Glass>
        );
      })}
    </AbsoluteFill>
  );
};

// ------------------------------------------------------------------ 2.4–4.8 s: the logo on gold

const Brand: React.FC = () => {
  const F = useF();
  const t = useS();
  if (t < 2.35 || t > 4.9) return null;
  const o = p(t, 2.4, 2.6) * (1 - p(t, 4.55, 4.8));
  const s = 400 * F.ks;
  const name = spr(t, 3.35, { damping: 14 });
  return (
    <AbsoluteFill style={{ opacity: o }}>
      <Sequence from={Math.round(2.4 * 30)} layout="none">
        <div style={{ position: "absolute", left: F.cx - s / 2, top: F.cy - 140 * F.ky - s / 2, width: s, height: s, filter: "drop-shadow(0 0 60px rgba(242,178,51,.35))" }}>
          <Lottie animationData={loaderDark as never} loop={false} style={{ width: s, height: s }} />
        </div>
      </Sequence>
      <div style={{ position: "absolute", left: 0, width: F.W, top: F.cy + 150 * F.ky, textAlign: "center", fontFamily: FONT, fontWeight: 800, fontSize: 96 * F.ks, color: "#fff", letterSpacing: "-0.04em", opacity: Math.min(1, name * 1.5), transform: `translateY(${(1 - name) * 40}px)`, filter: name < 0.9 ? `blur(${(1 - name) * 14}px)` : undefined }}>
        SolutionTee <span style={GOLD_TEXT}>CBT</span>
      </div>
      <KText text="Learn. Think. *Solve.*" at={3.7} y={F.cy + 290 * F.ky} size={56} color="#C9D6EA" accent="#F7C65A" />
      <Star4 x={F.cx + 300 * F.ks} y={F.cy - 380 * F.ky} size={130} at={2.7} />
      <Star4 x={F.cx - 330 * F.ks} y={F.cy + 60 * F.ky} size={80} at={2.95} spin={-30} />
      <Star4 x={F.cx + 360 * F.ks} y={F.cy + 420 * F.ky} size={60} at={3.2} />
    </AbsoluteFill>
  );
};

// ------------------------------------------------------------------ 4.8–24 s: four chapters

const Chapter: React.FC<{ a: number; b: number; word: string; line: string; screen: string; side: 1 | -1; size: number; children?: React.ReactNode; back?: string }> = ({ a, b, word, line, screen, side, size, children, back }) => {
  const F = useF();
  const t = useS();
  if (t < a - 0.1 || t > b + 0.1) return null;
  const k = spr(t, a + 0.15, { damping: 16, stiffness: 80 });
  const drift = p(t, a, b, (v) => v);
  const out = p(t, b - 0.35, b, easeInOut);
  const pw = 620 * F.ks * (F.tall ? 1 : 0.8);
  return (
    <AbsoluteFill style={{ opacity: 1 - out, filter: out > 0 ? `blur(${out * 16}px)` : undefined }}>
      <KText text={`*${line}*`} at={a + 0.05} y={F.cy - 700 * F.ky} size={64} color="#fff" accent="#F7C65A" serifScale={1} />
      <GoldWord word={word} at={a + 0.15} y={F.cy - 470 * F.ky} size={size} out={b - 0.35} />
      {back && (
        <Phone src={back} width={pw * 0.8} x={F.cx - side * 250 * F.ks} y={F.cy + 330 * F.ky + (1 - k) * 600} rx={10} ry={side * 26} rz={-side * 8} opacity={0.55 * k} shadow={false} />
      )}
      <Phone src={screen} width={pw} x={F.cx + side * 60 * F.ks} y={F.cy + 300 * F.ky + (1 - k) * 1000 - drift * 50} rx={lerp(24, 10, k)} ry={side * lerp(-34, -16, k) - side * drift * 10} rz={side * lerp(-10, -3, k)} />
      {children}
      <Star4 x={F.cx - side * 400 * F.ks} y={F.cy - 260 * F.ky} size={110} at={a + 0.5} out={b - 0.3} />
      <Star4 x={F.cx + side * 420 * F.ks} y={F.cy + 760 * F.ky} size={70} at={a + 0.8} out={b - 0.3} spin={-40} />
    </AbsoluteFill>
  );
};

const Chip: React.FC<{ x: number; y: number; at: number; out: number; children: React.ReactNode; tone?: "gold" | "red" | "green" }> = ({ x, y, at, out, children, tone = "gold" }) => {
  const t = useS();
  const F = useF();
  const k = spr(t, at, { damping: 10, stiffness: 160 });
  const o = 1 - p(t, out, out + 0.25);
  if (k <= 0.001 || o <= 0) return null;
  const bg = tone === "red" ? "#E5484D" : tone === "green" ? "#16A34A" : "linear-gradient(135deg,#FFE29A,#F2B233)";
  const fg = tone === "gold" ? C.navy : "#fff";
  return (
    <div style={{ position: "absolute", left: x, top: y, transform: `translate(-50%,-50%) scale(${k}) translateY(${Math.sin(t * 2 + x) * 8}px)`, opacity: o, padding: `${18 * F.ks}px ${30 * F.ks}px`, borderRadius: 999, background: bg, color: fg, fontFamily: FONT, fontWeight: 800, fontSize: 40 * F.ks, whiteSpace: "nowrap", boxShadow: "0 24px 50px -16px rgba(0,0,0,.8)" }}>{children}</div>
  );
};

const Chapters: React.FC = () => {
  const F = useF();
  const t = useS();
  const live = Math.floor(t * 1.66) % 2;
  return (
    <>
      <Chapter a={4.8} b={9.6} word="PRACTISE" line="real JAMB-style CBT" screen="screens/cbt.jpg" side={1} size={230}>
        <Chip x={F.cx - 250 * F.ks} y={F.cy - 40 * F.ky} at={6.2} out={9.2}>1:12:38 left</Chip>
        <Chip x={F.cx + 300 * F.ks} y={F.cy + 640 * F.ky} at={7.4} out={9.2} tone="green">✓ Correct</Chip>
      </Chapter>
      <Chapter a={9.6} b={14.4} word="UNDERSTAND" line="every answer explained" screen="screens/ai.jpg" side={-1} size={170}>
        <Chip x={F.cx + 250 * F.ks} y={F.cy - 40 * F.ky} at={11.0} out={14.0}>✦ AI tutor</Chip>
        <Chip x={F.cx - 280 * F.ks} y={F.cy + 640 * F.ky} at={12.2} out={14.0} tone="green">x = 2 or 3 ✓</Chip>
      </Chapter>
      <Chapter a={14.4} b={19.2} word="COMPETE" line="duels, games, leaderboards" screen="screens/04_duel.jpg" back="screens/15_ranks.jpg" side={1} size={250}>
        <Chip x={F.cx - 260 * F.ks} y={F.cy - 40 * F.ky} at={15.8} out={18.8}>+35 XP</Chip>
        <Chip x={F.cx + 300 * F.ks} y={F.cy + 640 * F.ky} at={17.0} out={18.8} tone="green">You won! ▲ Rank 3</Chip>
      </Chapter>
      <Chapter a={19.2} b={24.0} word="LIVE" line="classes with real teachers" screen="screens/class_live.jpg" side={-1} size={330}>
        <Chip x={F.cx + 250 * F.ks} y={F.cy - 40 * F.ky} at={20.6} out={23.6} tone="red">{live ? "●" : "○"} LIVE NOW</Chip>
        <Chip x={F.cx - 280 * F.ks} y={F.cy + 640 * F.ky} at={21.8} out={23.6}>1,248 watching</Chip>
      </Chapter>
    </>
  );
};

// ------------------------------------------------------------------ 24–26.4 s: wall of screens

const WALL = ["cbt", "ai", "leader", "01_hub", "study", "result", "class_live", "04_duel", "store_community", "15_ranks", "class_list", "12_victory"];

const Wall: React.FC = () => {
  const F = useF();
  const t = useS();
  if (t < 23.9 || t > 26.5) return null;
  const k = p(t, 24.0, 26.4, (v) => v);
  const o = p(t, 23.9, 24.2) * (1 - p(t, 26.2, 26.45));
  const w = 280, h = (w * SCREEN.h) / SCREEN.w;
  return (
    <AbsoluteFill style={{ opacity: o, perspective: 1600 }}>
      <div style={{ position: "absolute", left: F.cx, top: F.cy, transformStyle: "preserve-3d", transform: `translate(-50%,-50%) rotateX(${lerp(48, 38, k)}deg) rotateZ(${lerp(-24, -18, k)}deg) translateY(${-k * 600}px) scale(${lerp(1.3, 1.1, k)})` }}>
        {Array.from({ length: 6 }).map((_, col) =>
          Array.from({ length: 6 }).map((_, row) => {
            const i = col * 6 + row;
            const lift = Math.max(0, Math.sin((t - 24) * 2 + i)) * 30;
            return (
              <div key={i} style={{ position: "absolute", left: (col - 3) * (w + 50), top: (row - 3) * (h + 50) + (col % 2) * h * 0.4, width: w, height: h, borderRadius: 40, overflow: "hidden", border: "6px solid #1b2232", boxShadow: "0 40px 60px -20px rgba(0,0,0,.9)", transform: `translateZ(${lift}px)` }}>
                <Img src={staticFile(`screens/${WALL[i % WALL.length]}.jpg`)} style={{ width: "100%", height: "100%" }} />
              </div>
            );
          }),
        )}
      </div>
      <AbsoluteFill style={{ background: "radial-gradient(ellipse at 50% 50%, rgba(3,6,13,.85) 0%, rgba(3,6,13,.4) 50%, rgba(3,6,13,.1) 100%)" }} />
      <KText text="Everything you need." at={24.15} y={F.cy - 90 * F.ky} size={100} color="#fff" />
      <KText text="*One app.*" at={24.6} y={F.cy + 100 * F.ky} size={170} color="#fff" accent="#F7C65A" serifScale={1} />
    </AbsoluteFill>
  );
};

// ------------------------------------------------------------------ 26.4–30 s: end card

const Ender: React.FC = () => {
  const t = useS();
  if (t < 26.3) return null;
  return (
    <AbsoluteFill style={{ opacity: p(t, 26.3, 26.55) }}>
      <EndCard at={26.4} />
    </AbsoluteFill>
  );
};

export const AdScreen: React.FC = () => (
  <AbsoluteFill>
    <Audio src={sfile("audio/pack_C.wav")} />
    <GoldStage />
    <Hook />
    <Brand />
    <Chapters />
    <Wall />
    <Ender />
    <Flash at={2.4} color="#FFE7A8" max={0.55} dur={0.4} />
    {[4.8, 9.6, 14.4, 19.2, 24.0].map((a) => <Flash key={a} at={a} color="#FFE7A8" max={0.22} dur={0.3} />)}
    <Flash at={26.35} max={0.7} dur={0.35} />
  </AbsoluteFill>
);

void rnd;
void SERIF;
