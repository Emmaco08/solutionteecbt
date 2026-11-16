import React from "react";
import { AbsoluteFill, Audio, staticFile as sfile, Img, staticFile } from "remotion";
import { Phone, SCREEN } from "../components";
import { C, EndCard, FONT, Flash, KText, SERIF, easeInOut, easeOut, lerp, p, rnd, spr, useF, useS } from "./kit";

// Ad B, "Stop scrolling" (D-182): 15.5 s, Swiss bold type on flat colour blocks (reference 2), a cut on every beat at
// 120 BPM.
export const STOP_SECONDS = 15.5;

const RED = "#E5484D";
const CREAM = "#F7F3EA";

/** A flat colour block that wipes up from the bottom at [a] and is shown until [b]. */
const Block: React.FC<{ a: number; b: number; color: string; children?: React.ReactNode; from?: "bottom" | "left" | "right" | "top" }> = ({ a, b, color, children, from = "bottom" }) => {
  const t = useS();
  if (t < a || t >= b) return null;
  const k = p(t, a, a + 0.16, easeOut);
  const clip = from === "bottom" ? `inset(${(1 - k) * 100}% 0 0 0)` : from === "top" ? `inset(0 0 ${(1 - k) * 100}% 0)` : from === "left" ? `inset(0 ${(1 - k) * 100}% 0 0)` : `inset(0 0 0 ${(1 - k) * 100}%)`;
  return <AbsoluteFill style={{ background: color, clipPath: clip }}>{children}</AbsoluteFill>;
};

/** One giant word, left aligned, sliding up out of a mask. */
const Big: React.FC<{ text: string; at: number; y: number; size: number; color: string; accent?: string; x?: number; align?: "left" | "center" }> = ({ text, at, y, size, color, accent, x = 70, align = "left" }) => {
  const F = useF();
  return <KText text={text} at={at} y={y} size={size} color={color} accent={accent ?? color} mode="mask" align={align} x={align === "left" ? x : undefined} width={F.W - (align === "left" ? x * 2 : 120)} stagger={0.06} lh={0.92} tracking={-0.055} serifScale={1.05} />;
};

// ------------------------------------------------------------------ 0–2 s: STOP / SCROLLING. / Start scoring.

const Hook: React.FC = () => {
  const F = useF();
  const t = useS();
  const jolt = t < 0.5 ? Math.sin(t * 90) * Math.exp(-t * 8) * 14 : 0;
  return (
    <>
      <Block a={0} b={0.5} color={RED}>
        <div style={{ position: "absolute", inset: 0, transform: `translateX(${jolt}px)` }}>
          <KText text="STOP" at={0} y={F.cy} size={330} color="#fff" mode="pop" weight={800} tracking={-0.06} />
        </div>
      </Block>
      <Block a={0.5} b={1.0} color={CREAM}>
        <Big text="SCROLL-" at={0.5} y={F.cy - 110 * F.ky} size={250} color={C.navy} />
        <Big text="ING." at={0.58} y={F.cy + 110 * F.ky} size={250} color={C.navy} />
      </Block>
      <Block a={1.0} b={2.0} color={C.gold}>
        <Big text="Start" at={1.0} y={F.cy - 140 * F.ky} size={230} color={C.navy} />
        <Big text="*scoring.*" at={1.12} y={F.cy + 110 * F.ky} size={250} color={C.navy} />
        <ScoreTicker at={1.3} />
      </Block>
    </>
  );
};

const ScoreTicker: React.FC<{ at: number }> = ({ at }) => {
  const F = useF();
  const t = useS();
  const k = spr(t, at, { damping: 12 });
  const v = Math.round(lerp(180, 312, p(t, at, at + 0.6)));
  return (
    <div style={{ position: "absolute", right: 70, top: F.cy + 330 * F.ky, transform: `scale(${k}) rotate(-4deg)`, transformOrigin: "100% 50%", background: C.navy, color: "#fff", borderRadius: 26, padding: `${18 * F.ks}px ${34 * F.ks}px`, fontFamily: FONT, fontWeight: 800, fontSize: 64 * F.ks, display: "flex", gap: 16, alignItems: "baseline" }}>
      {v}<span style={{ fontSize: 34 * F.ks, opacity: 0.6 }}>/400</span><span style={{ color: "#3DDC97", fontSize: 40 * F.ks }}>▲</span>
    </div>
  );
};

// ------------------------------------------------------------------ 2–3.5 s: JAMB · WAEC · NECO

const Exam: React.FC<{ a: number; name: string; file: string; bg: string; fg: string; from: "left" | "right" | "bottom" }> = ({ a, name, file, bg, fg, from }) => {
  const F = useF();
  const t = useS();
  const k = spr(t, a + 0.04, { damping: 11, stiffness: 180 });
  const box = 500 * F.ks;
  return (
    <Block a={a} b={a + 0.5} color={bg} from={from}>
      <div style={{ position: "absolute", left: F.cx - box / 2, top: F.cy - 230 * F.ky - box / 2, width: box, height: box, borderRadius: 60, background: "#fff", display: "grid", placeItems: "center", transform: `scale(${k}) rotate(${(1 - k) * 12}deg)`, boxShadow: "0 40px 80px -30px rgba(0,0,0,.4)" }}>
        <Img src={staticFile(`brand/${file}.png`)} style={{ width: box * 0.86, height: box * 0.86, objectFit: "contain" }} />
      </div>
      <Big text={name} at={a + 0.02} y={F.cy + 260 * F.ky} size={240} color={fg} align="center" />
    </Block>
  );
};

// ------------------------------------------------------------------ 3.5–5 s: One app, four coloured cards

const CARDS = [
  ["Past questions", "Real CBT, timed", C.navy, "#fff"],
  ["AI tutor", "Ask anything, any time", C.blue, "#fff"],
  ["Game Zone", "Duel friends live", C.gold, C.navy],
  ["Live classes", "Learn with teachers", RED, "#fff"],
] as const;

/** The phone's screen in its own 1170 × 2532 pixels: four coloured cards stacking in. */
const CardsScreen: React.FC<{ at: number }> = ({ at }) => {
  const t = useS();
  return (
    <div style={{ position: "absolute", inset: 0, background: "#fff", padding: "250px 70px 0" }}>
      <div style={{ fontFamily: FONT, fontWeight: 800, fontSize: 92, color: C.navy, letterSpacing: "-0.03em" }}>Hi, Tolu</div>
      <div style={{ fontFamily: FONT, fontWeight: 600, fontSize: 50, color: "#7B88A1", marginTop: 10 }}>What are we practising today?</div>
      {CARDS.map(([title, sub, bg, fg], i) => {
        const k = spr(t, at + 0.15 + i * 0.12, { damping: 13, stiffness: 170 });
        return (
          <div key={title} style={{ marginTop: i === 0 ? 70 : 36, height: 360, borderRadius: 60, background: bg, padding: "50px 60px", display: "flex", flexDirection: "column", justifyContent: "flex-end", transform: `translateX(${(1 - k) * 1200}px) rotate(${(1 - k) * 8}deg)` }}>
            <div style={{ fontFamily: FONT, fontWeight: 600, fontSize: 46, color: fg, opacity: 0.8 }}>{sub}</div>
            <div style={{ fontFamily: FONT, fontWeight: 800, fontSize: 104, color: fg, letterSpacing: "-0.04em", lineHeight: 1.05 }}>{title}</div>
          </div>
        );
      })}
    </div>
  );
};

const OneApp: React.FC = () => {
  const F = useF();
  const t = useS();
  const k = spr(t, 3.55, { damping: 14, stiffness: 110 });
  const pw = 560 * F.ks * (F.tall ? 1 : 0.8);
  return (
    <Block a={3.5} b={5.0} color={CREAM}>
      <Big text="One app." at={3.5} y={F.cy - 690 * F.ky} size={200} color={C.navy} align="center" />
      <Phone width={pw} x={F.cx} y={F.cy + 210 * F.ky + (1 - k) * 1100} rx={10} ry={lerp(-30, -14, k) + Math.sin(t * 2) * 3} rz={lerp(-12, -5, k)} screenBg="#fff">
        <CardsScreen at={3.6} />
      </Phone>
    </Block>
  );
};

// ------------------------------------------------------------------ 5–11 s: four feature beats

const Feature: React.FC<{ a: number; b: number; word: string; sub: string; screen: string; bg: string; fg: string; from: "left" | "right" | "bottom" | "top"; tilt: number }> = ({ a, b, word, sub, screen, bg, fg, from, tilt }) => {
  const F = useF();
  const t = useS();
  const k = spr(t, a + 0.08, { damping: 15, stiffness: 120 });
  const drift = p(t, a, b, (v) => v);
  const pw = 600 * F.ks * (F.tall ? 1 : 0.78);
  return (
    <Block a={a} b={b} color={bg} from={from}>
      <Big text={word} at={a} y={F.cy - 640 * F.ky} size={word.length > 8 ? 168 : 210} color={fg} />
      <KText text={sub} at={a + 0.18} y={F.cy - 500 * F.ky} size={44} color={fg} weight={600} align="left" x={74} width={F.W - 140} mode="blur" />
      <Phone src={screen} width={pw} x={F.cx + 90 * F.ks + (1 - k) * 700} y={F.cy + 330 * F.ky - drift * 60} rx={8} ry={tilt * 1.6 - drift * 6} rz={tilt * 0.4} />
    </Block>
  );
};

const Features: React.FC = () => (
  <>
    <Feature a={5.0} b={6.5} word="Practise." sub="JAMB-style CBT, timed like exam day" screen="screens/cbt.jpg" bg={C.navy} fg="#fff" from="right" tilt={-14} />
    <Feature a={6.5} b={8.0} word="Understand." sub="Every answer explained. AI tutor on call." screen="screens/ai.jpg" bg={C.blue} fg="#fff" from="left" tilt={14} />
    <Feature a={8.0} b={9.5} word="Compete." sub="Duel students across Nigeria, live" screen="screens/04_duel.jpg" bg={C.gold} fg={C.navy} from="bottom" tilt={-14} />
    <Feature a={9.5} b={11.0} word="Climb." sub="Leaderboards that reward the top" screen="screens/leader.jpg" bg={RED} fg="#fff" from="top" tilt={14} />
  </>
);

// ------------------------------------------------------------------ 11–12.5 s: the wall of screens

const WALL = ["cbt", "ai", "leader", "01_hub", "study", "result", "class_live", "04_duel", "store_community", "15_ranks", "challenge_cash", "class_list"];

const Wall: React.FC = () => {
  const F = useF();
  const t = useS();
  if (t < 11 || t >= 12.5) return null;
  const d = t - 11;
  const w = 300, h = (w * SCREEN.h) / SCREEN.w;
  const enter = p(t, 11, 11.25);
  return (
    <AbsoluteFill style={{ background: C.navy, overflow: "hidden", clipPath: `inset(0 0 0 ${(1 - enter) * 100}%)` }}>
      <div style={{ position: "absolute", left: F.cx, top: F.cy, transform: `translate(-50%,-50%) rotate(-14deg) scale(${lerp(1.15, 1.0, p(t, 11, 12.5, easeInOut))})` }}>
        {Array.from({ length: 5 }).map((_, col) => (
          <div key={col} style={{ position: "absolute", left: (col - 2) * (w + 40) - w / 2, top: -h * 2.2 + (col % 2 ? 1 : -1) * d * 260 + (col % 2 ? -h * 0.5 : 0), display: "flex", flexDirection: "column", gap: 40 }}>
            {Array.from({ length: 5 }).map((_, row) => (
              <div key={row} style={{ width: w, height: h, borderRadius: 44, overflow: "hidden", border: "8px solid #1d2a44", boxShadow: "0 30px 60px -20px rgba(0,0,0,.6)" }}>
                <Img src={staticFile(`screens/${WALL[(col * 5 + row * 3) % WALL.length]}.jpg`)} style={{ width: "100%", height: "100%" }} />
              </div>
            ))}
          </div>
        ))}
      </div>
      <AbsoluteFill style={{ background: "radial-gradient(ellipse at 50% 50%, rgba(11,31,68,.82) 0%, rgba(11,31,68,.35) 55%, rgba(11,31,68,.1) 100%)" }} />
      <KText text="Your whole" at={11.1} y={F.cy - 110 * F.ky} size={150} color="#fff" mode="mask" />
      <KText text="*exam prep.*" at={11.25} y={F.cy + 90 * F.ky} size={170} color="#fff" accent={C.gold} mode="mask" serifScale={1.05} />
    </AbsoluteFill>
  );
};

// ------------------------------------------------------------------ 12.5–15.5 s: end card

const Ender: React.FC = () => {
  const t = useS();
  if (t < 12.5) return null;
  return (
    <AbsoluteFill style={{ clipPath: `inset(${(1 - p(t, 12.5, 12.7, easeOut)) * 100}% 0 0 0)` }}>
      <EndCard at={12.5} cta="Download free" />
    </AbsoluteFill>
  );
};

export const AdStop: React.FC = () => (
  <AbsoluteFill style={{ background: CREAM }}>
    <Audio src={sfile("audio/pack_B.wav")} />
    <Hook />
    <Exam a={2.0} name="JAMB" file="jamb" bg={C.blue} fg="#fff" from="right" />
    <Exam a={2.5} name="WAEC" file="waec" bg={CREAM} fg={C.navy} from="left" />
    <Exam a={3.0} name="NECO" file="neco" bg={C.navy} fg="#fff" from="bottom" />
    <OneApp />
    <Features />
    <Wall />
    <Ender />
    {[0.5, 1.0, 2.0, 3.5, 5.0, 11.0].map((a) => <Flash key={a} at={a} max={0.25} dur={0.18} />)}
  </AbsoluteFill>
);

void rnd;
void SERIF;
