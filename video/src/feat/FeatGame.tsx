import React from "react";
import { AbsoluteFill, Audio, staticFile } from "remotion";
import { Phone } from "../components";
import { Burst, EndCard, Flash, Star4, useF, useS } from "../pack/kit";
import { ArenaStage, C, FONT, GAME, Ico, Pill, Shot, lerp, p, rnd, spr } from "./fkit";

// Feature ad 3: Game Zone, "Battle your friends instead" (D-184). 19 s, stadium purple, game font, 128 BPM feel.
export const GAME_SECONDS = 19;

/** Big game-style word: chunky font, outline and drop shadow, springs in. */
const Boom: React.FC<{ text: string; at: number; y: number; size: number; color?: string; out?: number; rot?: number }> = ({ text, at, y, size, color = "#fff", out, rot = -4 }) => {
  const t = useS();
  const F = useF();
  const k = spr(t, at, { damping: 9, stiffness: 200 });
  const o = out === undefined ? 1 : 1 - p(t, out, out + 0.2);
  if (k <= 0.001 || o <= 0) return null;
  const s = size * F.ks;
  return (
    <div style={{ position: "absolute", left: 0, width: F.W, top: y, transform: `translateY(-50%) scale(${k}) rotate(${rot * k}deg)`, textAlign: "center", fontFamily: GAME, fontSize: s, lineHeight: 0.95, color, WebkitTextStroke: `${s * 0.035}px #12093A`, textShadow: `0 ${s * 0.06}px 0 #12093A, 0 ${s * 0.12}px ${s * 0.2}px rgba(0,0,0,.45)`, opacity: o, whiteSpace: "pre-line" }}>
      {text}
    </div>
  );
};

// ------------------------------------------------------------------ 0–3 s: hook

const Hook: React.FC = () => {
  const F = useF();
  const t = useS();
  const sleepy = Math.sin(t * 4) * 6;
  return (
    <>
      <Shot a={0} b={1.6} first>
        <div style={{ position: "absolute", left: F.cx - 170 * F.ks, top: F.cy - 520 * F.ky, transform: `rotate(${sleepy}deg) scale(${spr(t, 0.05, { damping: 9 })})` }}>
          <Ico n="book" size={340 * F.ks} color="#B9A8FF" stroke={1.5} fill="rgba(185,168,255,.12)" />
        </div>
        {[0, 1, 2].map((i) => {
          const d = (t * 1.2 + i * 0.33) % 1;
          return <div key={i} style={{ position: "absolute", left: F.cx + 160 * F.ks + d * 80, top: F.cy - 560 * F.ky - d * 200, fontFamily: GAME, fontSize: (40 + i * 16) * F.ks, color: "#B9A8FF", opacity: Math.sin(d * Math.PI) }}>z</div>;
        })}
        <Boom text="Bored of" at={0} y={F.cy + 120 * F.ky} size={140} />
        <Boom text="reading?" at={0.15} y={F.cy + 290 * F.ky} size={170} color="#B9A8FF" rot={3} />
      </Shot>
      <Shot a={1.6} b={3.0} zin={1.3}>
        <Boom text={"Battle your\nfriends"} at={1.62} y={F.cy - 250 * F.ky} size={150} />
        <Boom text="INSTEAD!" at={2.0} y={F.cy + 140 * F.ky} size={210} color="#FFD65A" rot={-6} />
        <div style={{ position: "absolute", left: F.cx - 90 * F.ks, top: F.cy + 330 * F.ky, transform: `scale(${spr(t, 2.15, { damping: 7 })}) rotate(12deg)` }}>
          <Ico n="bolt" size={180 * F.ks} color="#12093A" stroke={1.2} fill="#FFD65A" />
        </div>
        <Flash at={2.0} color="#FFD65A" max={0.4} />
      </Shot>
    </>
  );
};

// ------------------------------------------------------------------ 3–5.2 s: match found

const Versus: React.FC = () => {
  const F = useF();
  const t = useS();
  const l = spr(t, 3.0, { damping: 14, stiffness: 160 });
  const r = spr(t, 3.12, { damping: 14, stiffness: 160 });
  const vs = spr(t, 3.45, { damping: 7, stiffness: 260 });
  const pw = 560 * F.ks * (F.tall ? 1 : 0.8);
  return (
    <Shot a={3.0} b={5.2}>
      <div style={{ position: "absolute", left: 0, top: 0, width: F.W * 0.6, height: F.H, background: "linear-gradient(160deg,#2563B3,#1B3F8C)", clipPath: "polygon(0 0,100% 0,70% 100%,0 100%)", transform: `translateX(${(1 - l) * -F.W}px)` }} />
      <div style={{ position: "absolute", right: 0, top: 0, width: F.W * 0.6, height: F.H, background: "linear-gradient(160deg,#E5484D,#A3243B)", clipPath: "polygon(30% 0,100% 0,100% 100%,0 100%)", transform: `translateX(${(1 - r) * F.W}px)` }} />
      <Phone src="screens/03_vs.jpg" width={pw} x={F.cx} y={F.cy + 120 * F.ky + (1 - l) * 600} rx={6} ry={lerp(30, 10, l)} rz={-4} />
      <div style={{ position: "absolute", left: F.cx - 160 * F.ks, top: F.cy - 640 * F.ky, width: 320 * F.ks, height: 320 * F.ks, transform: `scale(${vs}) rotate(${(1 - vs) * 40}deg)`, display: "grid", placeItems: "center", fontFamily: GAME, fontSize: 220 * F.ks, color: "#FFD65A", WebkitTextStroke: `8px #12093A`, textShadow: "0 12px 0 #12093A" }}>VS</div>
      <Boom text="MATCH FOUND!" at={3.75} y={F.cy + 820 * F.ky} size={110} color="#fff" rot={-3} />
      <Flash at={3.45} color="#fff" max={0.5} />
    </Shot>
  );
};

// ------------------------------------------------------------------ 5.2–8.6 s: how a duel works

const Duel: React.FC = () => {
  const F = useF();
  const t = useS();
  const k = spr(t, 5.2, { damping: 15, stiffness: 110 });
  const pw = 540 * F.ks * (F.tall ? 1 : 0.78);
  const tick = Math.max(0, 11 - Math.floor((t - 5.4) * 3));
  return (
    <Shot a={5.2} b={8.6}>
      <Boom text="Same question." at={5.25} y={F.cy - 800 * F.ky} size={92} rot={0} />
      <Boom text="Same time." at={5.55} y={F.cy - 690 * F.ky} size={92} color="#B9A8FF" rot={0} />
      <Phone src="screens/04_duel.jpg" width={pw} x={F.cx} y={F.cy + 160 * F.ky + (1 - k) * 900} rx={8} ry={lerp(-24, -8, k)} rz={2} />
      <Pill x={F.cx + 300 * F.ks} y={F.cy - 450 * F.ky} at={5.9} bg="#12093A" fg="#FFD65A" icon="timer" size={42}>{tick}s</Pill>
      <Pill x={F.cx - 300 * F.ks} y={F.cy + 100 * F.ky} at={6.7} bg="#22C55E" fg="#fff" icon="check" size={42}>+120 YOU</Pill>
      <Pill x={F.cx + 300 * F.ks} y={F.cy + 300 * F.ky} at={7.0} bg="#E5484D" fg="#fff" size={40}>✗ KEMI wrong</Pill>
      <Pill x={F.cx - 280 * F.ks} y={F.cy + 520 * F.ky} at={7.35} bg="#FFD65A" fg="#12093A" icon="fire" size={42}>x3 NITRO</Pill>
      <Boom text={"Fastest right\nanswer wins!"} at={7.65} y={F.cy + 800 * F.ky} size={92} color="#FFD65A" rot={-2} />
    </Shot>
  );
};

// ------------------------------------------------------------------ 8.6–11 s: game modes

const MODES: [string, string, string][] = [
  ["JAMB Duel", "1 vs 1 · live", "#2563B3"],
  ["Reading Clash", "read fast, answer faster", "#16A34A"],
  ["Speed Rush", "race the clock", "#E5484D"],
  ["Survival", "one wrong and you're out", "#7C3AED"],
  ["VS AI", "beat the bot", "#0EA5E9"],
  ["Play a friend", "share your code", "#F2994A"],
];

const Modes: React.FC = () => {
  const F = useF();
  const t = useS();
  const gap = 34 * F.ks;
  const cw = 440 * F.ks, ch = 300 * F.ky * (F.tall ? 1 : 1.2);
  const top = F.cy - 480 * F.ky;
  return (
    <Shot a={8.6} b={11.0}>
      <Boom text="Pick your battle" at={8.65} y={F.cy - 720 * F.ky} size={112} rot={-2} />
      {MODES.map(([name, sub, col], i) => {
        const k = spr(t, 8.85 + i * 0.1, { damping: 10, stiffness: 170 });
        const cx = F.cx + (i % 2 ? gap / 2 : -cw - gap / 2);
        const cy = top + Math.floor(i / 2) * (ch + gap);
        const bob = Math.sin((t - 9) * 3 + i) * 6;
        return (
          <div key={name} style={{ position: "absolute", left: cx, top: cy + bob, width: cw, height: ch, transform: `scale(${k}) rotate(${(1 - k) * (i % 2 ? 14 : -14) + (i % 2 ? 2 : -2)}deg)`, opacity: Math.min(1, k * 2), borderRadius: 40, background: `linear-gradient(160deg, ${col}, #12093A 150%)`, border: "6px solid #fff", boxShadow: "0 30px 60px -20px rgba(0,0,0,.7)", padding: 30 * F.ks, display: "flex", flexDirection: "column", justifyContent: "flex-end" }}>
            <div style={{ fontFamily: GAME, fontSize: 70 * F.ks, color: "#fff", lineHeight: 1, textShadow: "0 5px 0 rgba(0,0,0,.35)" }}>{name}</div>
            <div style={{ fontFamily: FONT, fontWeight: 700, fontSize: 28 * F.ks, color: "rgba(255,255,255,.88)", marginTop: 10 }}>{sub}</div>
          </div>
        );
      })}
    </Shot>
  );
};

// ------------------------------------------------------------------ 11–13.4 s: victory

const Victory: React.FC = () => {
  const F = useF();
  const t = useS();
  const k = spr(t, 11.0, { damping: 13, stiffness: 120 });
  const pw = 540 * F.ks * (F.tall ? 1 : 0.78);
  return (
    <Shot a={11.0} b={13.4}>
      <Boom text="VICTORY!" at={11.15} y={F.cy - 740 * F.ky} size={190} color="#FFD65A" />
      <Phone src="screens/12_victory.jpg" width={pw} x={F.cx} y={F.cy + 200 * F.ky + (1 - k) * 900} rx={8} ry={lerp(26, 8, k)} rz={-3} />
      <Burst at={11.4} x={F.cx} y={F.cy - 300 * F.ky} n={120} power={1.1} />
      <Pill x={F.cx - 300 * F.ks} y={F.cy - 380 * F.ky} at={11.7} bg="#FFD65A" fg="#12093A" icon="sparkle" size={44}>+35 XP</Pill>
      <Pill x={F.cx + 290 * F.ks} y={F.cy + 420 * F.ky} at={12.0} bg="#fff" fg="#12093A" icon="arrowUp" size={42}>Rank up!</Pill>
      <Star4 x={F.cx + 360 * F.ks} y={F.cy - 520 * F.ky} size={110} at={11.5} color="#FFD65A" />
      <Star4 x={F.cx - 380 * F.ks} y={F.cy + 160 * F.ky} size={80} at={11.8} color="#FFD65A" />
      <Flash at={11.15} color="#FFD65A" max={0.45} />
    </Shot>
  );
};

// ------------------------------------------------------------------ 13.4–16 s: climb the ranks

const RANKS: [string, string, string][] = [["BRONZE", "#CD8A4F", "#7A4A22"], ["SILVER", "#D9E1EC", "#7C8899"], ["GOLD", "#FFD65A", "#B07A12"], ["DIAMOND", "#8FE3FF", "#2F7FB8"]];

const Ranks: React.FC = () => {
  const F = useF();
  const t = useS();
  const step = Math.min(3, Math.max(0, Math.floor((t - 13.6) / 0.5)));
  const pop = spr(t, 13.6 + step * 0.5, { damping: 8, stiffness: 240 });
  const [name, a, b] = RANKS[step];
  const s = 420 * F.ks;
  return (
    <Shot a={13.4} b={16.1}>
      <Boom text="Climb the ranks" at={13.45} y={F.cy - 720 * F.ky} size={120} />
      <div style={{ position: "absolute", left: F.cx - s / 2, top: F.cy - s / 2 - 60 * F.ky, width: s, height: s, transform: `scale(${lerp(0.75, 1, pop)}) rotate(${(1 - pop) * 20}deg)` }}>
        <svg width={s} height={s} viewBox="-50 -55 100 110">
          <defs>
            <linearGradient id="rk" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stopColor={a} /><stop offset="1" stopColor={b} /></linearGradient>
          </defs>
          <path d="M0 -50 L42 -32 L42 8 C42 32 22 46 0 54 C-22 46 -42 32 -42 8 L-42 -32 Z" fill="url(#rk)" stroke="#12093A" strokeWidth="5" />
          <path d="M0 -26 L7 -8 L26 -8 L11 4 L17 22 L0 11 L-17 22 L-11 4 L-26 -8 L-7 -8 Z" fill="#fff" opacity=".9" />
        </svg>
      </div>
      <Boom text={name} at={13.6 + step * 0.5} y={F.cy + 300 * F.ky} size={150} color={a} rot={0} />
      <div style={{ position: "absolute", left: 0, width: F.W, top: F.cy + 470 * F.ky, display: "flex", justifyContent: "center", gap: 18 }}>
        {RANKS.map(([n, c], i) => (
          <div key={n} style={{ width: 120 * F.ks, height: 16, borderRadius: 9, background: i <= step ? c : "rgba(255,255,255,.18)" }} />
        ))}
      </div>
      {[0, 1, 2, 3].map((i) => <Flash key={i} at={13.6 + i * 0.5} color="#fff" max={0.18} dur={0.2} />)}
      {Array.from({ length: 10 }).map((_, i) => (
        <Star4 key={i} x={F.cx + (rnd(i) - 0.5) * 900 * F.ks} y={F.cy + (rnd(i + 4) - 0.6) * 900 * F.ky} size={30 + rnd(i + 2) * 50} at={13.7 + i * 0.12} color="#FFD65A" />
      ))}
    </Shot>
  );
};

export const FeatGame: React.FC = () => (
  <AbsoluteFill>
    <Audio src={staticFile("audio/feat_game.wav")} />
    <ArenaStage />
    <Hook />
    <Versus />
    <Duel />
    <Modes />
    <Victory />
    <Ranks />
    <End />
  </AbsoluteFill>
);

const End: React.FC = () => {
  const t = useS();
  if (t < 15.95) return null;
  return (
    <AbsoluteFill style={{ opacity: p(t, 15.95, 16.25) }}>
      <EndCard at={16.0} cta="Battle a friend now" />
    </AbsoluteFill>
  );
};

void C;
