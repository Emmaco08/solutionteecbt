import React from "react";
import { AbsoluteFill, Audio, staticFile as sfile } from "remotion";
import { Phone } from "../components";
import { Burst, C, Cursor, EndCard, ExamLogos, FONT, Flash, KText, LogoReveal, PromptBar, SERIF, WarmStage, easeInOut, easeOut, lerp, p, rnd, spr, typed, useF, useS } from "./kit";

// Ad A, "If JAMB was tomorrow" (D-182): 21 s, warm glow launch style, 120 BPM (a beat every 0.5 s).
export const TOMORROW_SECONDS = 21;

/** A scene that blurs and zooms in at [a] and out at [b]. */
const Shot: React.FC<{ a: number; b: number; children: React.ReactNode; zin?: number; zout?: number; first?: boolean }> = ({ a, b, children, zin = 1.08, zout = 0.94, first }) => {
  const t = useS();
  if (t < a - 0.02 || t > b + 0.02) return null;
  const ki = first ? 1 : p(t, a, a + 0.32);
  const ko = p(t, b - 0.28, b, easeInOut);
  const s = lerp(zin, 1, ki) * lerp(1, zout, ko);
  const blur = (1 - ki) * 14 + ko * 14;
  return <AbsoluteFill style={{ opacity: Math.min(ki * 1.6, 1) * (1 - ko), transform: `scale(${s})`, filter: blur > 0.3 ? `blur(${blur}px)` : undefined }}>{children}</AbsoluteFill>;
};

// ------------------------------------------------------------------ 0–1.5 s: the hook

const Calendar: React.FC<{ x: number; y: number; flip: number; w?: number }> = ({ x, y, flip, w = 520 }) => {
  const t = useS();
  const F = useF();
  const W = w * F.ks, H = W * 1.02;
  const k = p(t, flip, flip + 0.45, easeOut);
  const fall = p(t, flip + 0.25, flip + 0.9, (v) => v * v);
  const page = (word: string, color: string, sub: string) => (
    <div style={{ position: "absolute", inset: 0, top: H * 0.24, background: "#fff", borderRadius: `0 0 ${W * 0.08}px ${W * 0.08}px`, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center" }}>
      <div style={{ fontFamily: FONT, fontWeight: 800, fontSize: W * 0.165, color, letterSpacing: "-0.04em" }}>{word}</div>
      <div style={{ fontFamily: FONT, fontWeight: 700, fontSize: W * 0.06, color: "#8A97AD", marginTop: W * 0.02, letterSpacing: "0.12em" }}>{sub}</div>
    </div>
  );
  return (
    <div style={{ position: "absolute", left: x - W / 2, top: y - H / 2, width: W, height: H, perspective: 1600, transform: `rotate(${-4 + Math.sin(t * 2) * 1.2}deg)` }}>
      <div style={{ position: "absolute", inset: 0, borderRadius: W * 0.08, background: "#fff", boxShadow: "0 50px 90px -40px rgba(120,80,10,.55)" }} />
      <div style={{ position: "absolute", left: 0, right: 0, top: 0, height: H * 0.24, background: C.navy, borderRadius: `${W * 0.08}px ${W * 0.08}px 0 0`, display: "grid", placeItems: "center" }}>
        <div style={{ fontFamily: FONT, fontWeight: 800, color: "#fff", fontSize: W * 0.072, letterSpacing: "0.16em" }}>EXAM DAY</div>
        {[0.25, 0.75].map((r) => (
          <div key={r} style={{ position: "absolute", top: -W * 0.035, left: W * r - W * 0.03, width: W * 0.06, height: W * 0.12, borderRadius: 99, background: "#C9D3E3", border: `${W * 0.012}px solid ${C.navy}` }} />
        ))}
      </div>
      {page("TOMORROW", C.red, "JAMB · UTME")}
      {fall < 1 && (
        <div style={{ position: "absolute", inset: 0, transformOrigin: "50% 24%", transform: `translateY(${fall * 700}px) rotateX(${-k * 70}deg) rotate(${fall * 18}deg)`, opacity: 1 - fall }}>
          {page("SOMEDAY", "#9AA6BC", "NO RUSH")}
        </div>
      )}
    </div>
  );
};

const Hook: React.FC = () => {
  const F = useF();
  return (
    <Shot a={0} b={1.55} first zout={0.9}>
      <Calendar x={F.cx} y={F.cy - 300 * F.ky} flip={0.62} />
      <KText text="If JAMB was / *tomorrow…*" at={0} y={F.cy + 380 * F.ky} size={118} stagger={0.05} dur={0.3} serifScale={1.22} accent={C.red} />
    </Shot>
  );
};

// ------------------------------------------------------------------ 1.5–3 s: would you be ready?

const Clock: React.FC<{ x: number; y: number; r: number; at: number }> = ({ x, y, r, at }) => {
  const t = useS();
  const k = spr(t, at, { damping: 13 });
  const tick = Math.floor((t - at) * 2); // a tick on every beat
  const sec = (tick * 6 + p(t % 0.5, 0, 0.08) * 6) % 360;
  return (
    <svg style={{ position: "absolute", left: x - r, top: y - r, width: r * 2, height: r * 2, transform: `scale(${k})`, opacity: 0.16 }} viewBox="-100 -100 200 200">
      <circle r="94" fill="none" stroke={C.navy} strokeWidth="6" />
      {Array.from({ length: 12 }).map((_, i) => (
        <line key={i} x1="0" y1="-80" x2="0" y2={i % 3 ? -86 : -72} stroke={C.navy} strokeWidth={i % 3 ? 3 : 6} transform={`rotate(${i * 30})`} />
      ))}
      <line x1="0" y1="8" x2="0" y2="-50" stroke={C.navy} strokeWidth="7" strokeLinecap="round" transform="rotate(-60)" />
      <line x1="0" y1="12" x2="0" y2="-74" stroke={C.red} strokeWidth="3.5" strokeLinecap="round" transform={`rotate(${sec + 200})`} />
      <circle r="6" fill={C.red} />
    </svg>
  );
};

const Ready: React.FC = () => {
  const F = useF();
  const t = useS();
  const beat = Math.max(0, Math.sin(((t - 1.5) % 0.5) / 0.5 * Math.PI)) * 0.025;
  return (
    <Shot a={1.5} b={3.0}>
      <Clock x={F.cx} y={F.cy} r={460 * F.ks} at={1.52} />
      <div style={{ position: "absolute", inset: 0, transform: `scale(${1 + beat})` }}>
        <KText text="would you / be *ready?*" at={1.55} y={F.cy} size={150} stagger={0.09} serifScale={1.2} />
      </div>
    </Shot>
  );
};

// ------------------------------------------------------------------ 3–4.5 s: reading alone

const SUBJECTS = [
  ["Use of English", "#2563B3"], ["Mathematics", "#E5484D"], ["Physics", "#7C3AED"], ["Chemistry", "#16A34A"],
  ["Biology", "#F2B233"], ["Economics", "#0EA5E9"], ["Literature", "#DB2777"], ["Government", "#0B1F44"],
] as const;

const NoteCard: React.FC<{ i: number; label: string; color: string }> = ({ i, label, color }) => {
  const t = useS();
  const F = useF();
  const at = 3.05 + i * 0.09;
  const k = spr(t, at, { damping: 12, stiffness: 150 });
  const boom = p(t, 4.15, 4.6, (v) => v * v);
  const ang = rnd(i + 3) * Math.PI * 2;
  const tx = (rnd(i) - 0.5) * 420 * F.ks + Math.cos(ang) * boom * 1400;
  const ty = (rnd(i + 11) - 0.5) * 520 * F.ky + Math.sin(ang) * boom * 1600;
  const rot = (rnd(i + 5) - 0.5) * 40 + boom * (rnd(i + 2) - 0.5) * 220;
  const w = 470 * F.ks;
  return (
    <div style={{ position: "absolute", left: F.cx - w / 2, top: F.cy + 120 * F.ky - w * 0.32, width: w, transform: `translate(${tx * k}px, ${ty * k + (1 - k) * 900}px) rotate(${rot * k}deg) scale(${lerp(0.6, 1, k)})`, opacity: Math.min(1, k * 2), filter: boom > 0 ? `blur(${boom * 10}px)` : undefined }}>
      <div style={{ background: "#fff", borderRadius: 28, padding: 30 * F.ks, boxShadow: "0 30px 60px -28px rgba(80,60,20,.5)", border: "2px solid rgba(11,31,68,.05)" }}>
        <div style={{ display: "flex", alignItems: "center", gap: 18 }}>
          <div style={{ width: 58 * F.ks, height: 58 * F.ks, borderRadius: 16, background: color, color: "#fff", display: "grid", placeItems: "center", fontFamily: FONT, fontWeight: 800, fontSize: 30 * F.ks }}>{label[0]}</div>
          <div style={{ fontFamily: FONT, fontWeight: 800, fontSize: 38 * F.ks, color: C.navy }}>{label}</div>
        </div>
        {[0.95, 0.8, 0.88].map((wv, j) => (
          <div key={j} style={{ height: 14 * F.ks, width: `${wv * 100}%`, marginTop: 18 * F.ks, borderRadius: 9, background: "#E8EDF5" }} />
        ))}
      </div>
    </div>
  );
};

const Reading: React.FC = () => {
  const F = useF();
  return (
    <Shot a={3.0} b={4.55}>
      {SUBJECTS.map(([l, c], i) => <NoteCard key={l} i={i} label={l} color={c} />)}
      <KText text="Reading alone / *won't do it.*" at={3.1} y={F.cy - 640 * F.ky} size={104} stagger={0.08} />
    </Shot>
  );
};

// ------------------------------------------------------------------ 4.5–5.5 s: you need practice

const Practice: React.FC = () => {
  const F = useF();
  const t = useS();
  const z = lerp(1, 1.12, p(t, 4.5, 5.5, (v) => v));
  return (
    <Shot a={4.5} b={5.5} zout={1.4}>
      <div style={{ position: "absolute", inset: 0, transform: `scale(${z})` }}>
        <KText text="You need" at={4.52} y={F.cy - 150 * F.ky} size={110} />
        <KText text="*practice.*" at={4.75} y={F.cy + 60 * F.ky} size={250} serifScale={1.0} />
      </div>
    </Shot>
  );
};

// ------------------------------------------------------------------ 5.5–7 s: the logo

const Brand: React.FC = () => {
  const F = useF();
  return (
    <Shot a={5.5} b={7.3}>
      <LogoReveal at={5.55} y={F.cy - 40 * F.ky} size={420} width={900} hold={0.6} />
      <KText text="Learn. Think. *Solve.*" at={6.35} y={F.cy + 170 * F.ky} size={72} />
    </Shot>
  );
};

// ------------------------------------------------------------------ 7–10 s: the real CBT feel

const CbtOverlay: React.FC = () => {
  const t = useS();
  const tap = 8.55;
  const sel = p(t, tap, tap + 0.2);
  const secs = 38 - Math.max(0, Math.floor(t - 7.2));
  const rip = t >= tap && t < tap + 0.6 ? (t - tap) / 0.6 : -1;
  const ok = spr(t, tap + 0.15, { damping: 10 });
  return (
    <>
      {/* timer that really counts down */}
      <div style={{ position: "absolute", left: 512, top: 141, width: 296, height: 116, borderRadius: 58, background: "#EDF1F7", display: "flex", alignItems: "center", justifyContent: "center", gap: 14, fontFamily: FONT, fontWeight: 700, fontSize: 60, color: C.navy }}>
        <div style={{ width: 20, height: 20, borderRadius: 99, background: Math.floor(t * 2) % 2 ? C.navy : C.red }} />
        1:12:{String(secs).padStart(2, "0")}
      </div>
      {/* option A turns green */}
      <div style={{ position: "absolute", left: 51, top: 757, width: 1070, height: 196, borderRadius: 76, border: `6px solid rgba(22,163,74,${sel})`, background: `rgba(34,197,94,${0.13 * sel})` }} />
      {ok > 0 && (
        <div style={{ position: "absolute", left: 1000, top: 810, width: 90, height: 90, borderRadius: 99, background: "#16A34A", display: "grid", placeItems: "center", transform: `scale(${ok})` }}>
          <svg width={54} height={54} viewBox="0 0 24 24"><path d="M5 12.5l4.5 4.5L19 7.5" stroke="#fff" strokeWidth={3.2} fill="none" strokeLinecap="round" strokeLinejoin="round" /></svg>
        </div>
      )}
      {rip >= 0 && <div style={{ position: "absolute", left: 360 - 120, top: 855 - 120, width: 240, height: 240, borderRadius: 999, background: "rgba(37,99,179,.25)", transform: `scale(${0.3 + rip * 1.4})`, opacity: 1 - rip }} />}
    </>
  );
};

const Cbt: React.FC = () => {
  const F = useF();
  const t = useS();
  const k = spr(t, 7.3, { damping: 15, stiffness: 90 });
  const push = p(t, 8.3, 9.9, easeInOut);
  const pw = 600 * F.ks * (F.tall ? 1 : 0.86);
  return (
    <Shot a={7.3} b={10.0}>
      <KText text="The *real* CBT feel" at={7.35} y={F.cy - 720 * F.ky} size={96} />
      <KText text="Timed like exam day · JAMB, WAEC & NECO" at={7.6} y={F.cy - 600 * F.ky} size={34} weight={600} color="#5B6B86" stagger={0.025} />
      <Phone src="screens/cbt.jpg" width={pw} x={F.cx} y={F.cy + 170 * F.ky + (1 - k) * 900} rx={lerp(18, 6, k)} ry={lerp(-28, -10, k) + push * 10} rz={lerp(-6, 0, k)} scale={lerp(1, 1.18, push)}>
        <CbtOverlay />
      </Phone>
      <Cursor keys={[[8.0, F.W + 80, F.cy + 520 * F.ky], [8.5, F.cx - 120 * F.ks, F.cy - 120 * F.ky]]} clicks={[8.55]} from={8.0} to={9.4} size={70} />
    </Shot>
  );
};

// ------------------------------------------------------------------ 10–12.5 s: every answer explained

const Explain: React.FC = () => {
  const F = useF();
  const t = useS();
  const k = spr(t, 10.05, { damping: 14 });
  const w = 900 * F.ks;
  const lines: [string, number, boolean][] = [
    ["x² − 5x + 6 = 0", 10.45, false],
    ["(x − 2)(x − 3) = 0", 10.95, false],
    ["x = 2  or  x = 3", 11.5, true],
  ];
  return (
    <Shot a={10.0} b={12.5}>
      <KText text="Every answer / *explained.*" at={10.05} y={F.cy - 640 * F.ky} size={112} />
      <div style={{ position: "absolute", left: F.cx - w / 2, top: F.cy - 270 * F.ky, width: w, transform: `translateY(${(1 - k) * 300}px) rotate(${(1 - k) * 5}deg)`, opacity: Math.min(1, k * 2) }}>
        <div style={{ background: "#fff", borderRadius: 40, padding: 50 * F.ks, boxShadow: "0 50px 100px -40px rgba(120,80,10,.5)" }}>
          <div style={{ display: "flex", alignItems: "center", gap: 18 }}>
            <div style={{ padding: "10px 24px", borderRadius: 99, background: "#DCFCE7", color: "#15803D", fontFamily: FONT, fontWeight: 800, fontSize: 30 * F.ks }}>✓ Correct · A</div>
            <div style={{ fontFamily: FONT, fontWeight: 700, fontSize: 30 * F.ks, color: "#7B88A1" }}>Explanation</div>
          </div>
          <div style={{ fontFamily: FONT, fontWeight: 600, fontSize: 34 * F.ks, color: "#55627A", marginTop: 26 * F.ks }}>Factorise: find two numbers that multiply to 6 and add to −5.</div>
          {lines.map(([s, at, hot], i) => {
            const shown = typed(t, at, s, 30);
            const hk = hot ? p(t, at + 0.5, at + 0.8) : 0;
            return (
              <div key={i} style={{ marginTop: 22 * F.ks, padding: `${12 * F.ks}px ${22 * F.ks}px`, borderRadius: 18, background: hot ? `rgba(34,197,94,${0.14 * hk})` : "transparent", fontFamily: SERIF, fontStyle: "italic", fontSize: 76 * F.ks, color: C.navy, minHeight: 80 * F.ks, opacity: t >= at ? 1 : 0 }}>
                {shown}
              </div>
            );
          })}
        </div>
      </div>
    </Shot>
  );
};

// ------------------------------------------------------------------ 12.5–14.5 s: AI tutor

const Tutor: React.FC = () => {
  const F = useF();
  const t = useS();
  const send = 13.45;
  const up = p(t, send, send + 0.35, easeOut);
  const ans = "Osmosis is water moving through a thin skin, from where there is more water to where there is less. Like a dry raisin swelling in water.";
  const k = spr(t, send + 0.2, { damping: 14 });
  const w = 920 * F.ks;
  return (
    <Shot a={12.5} b={14.5}>
      <KText text="Stuck? Ask the / *AI tutor.*" at={12.52} y={F.cy - 660 * F.ky} size={104} />
      <PromptBar x={F.cx} y={F.cy - 300 * F.ky - up * 40 * F.ky} w={w} at={12.75} text="Explain osmosis like I'm 12" cps={32} send={send} />
      {t > send + 0.1 && (
        <div style={{ position: "absolute", left: F.cx - w / 2, top: F.cy - 170 * F.ky, width: w, transform: `translateY(${(1 - k) * 80}px) scale(${lerp(0.9, 1, k)})`, opacity: Math.min(1, k * 2), transformOrigin: "50% 0" }}>
          <div style={{ background: C.navy, borderRadius: 40, padding: 44 * F.ks, boxShadow: "0 40px 80px -30px rgba(11,31,68,.6)" }}>
            <div style={{ display: "flex", alignItems: "center", gap: 14, marginBottom: 18 }}>
              <div style={{ width: 52 * F.ks, height: 52 * F.ks, borderRadius: 16, background: C.gold, display: "grid", placeItems: "center", color: C.navy, fontSize: 30 * F.ks, fontWeight: 800 }}>✦</div>
              <div style={{ fontFamily: FONT, fontWeight: 800, fontSize: 32 * F.ks, color: C.gold }}>SolutionTee AI</div>
            </div>
            <div style={{ fontFamily: FONT, fontWeight: 600, fontSize: 42 * F.ks, lineHeight: 1.35, color: "#fff", minHeight: 290 * F.ks }}>{typed(t, send + 0.35, ans, 120)}</div>
          </div>
        </div>
      )}
    </Shot>
  );
};

// ------------------------------------------------------------------ 14.5–16.5 s: score

const ScoreOverlay: React.FC = () => {
  const t = useS();
  const k = p(t, 14.85, 15.75, easeOut);
  const v = Math.round(287 * k);
  const R = 268, L = 2 * Math.PI * R;
  return (
    <div style={{ position: "absolute", left: 585 - 330, top: 665 - 330, width: 660, height: 660, borderRadius: 999, background: "#0E2148" }}>
      <svg width={660} height={660} viewBox="-330 -330 660 660" style={{ position: "absolute", inset: 0 }}>
        <circle r={R} fill="none" stroke="rgba(255,255,255,.12)" strokeWidth={52} />
        <circle r={R} fill="none" stroke={C.gold} strokeWidth={52} strokeLinecap="round" strokeDasharray={`${L * (v / 400)} ${L}`} transform="rotate(-90)" />
      </svg>
      <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", fontFamily: FONT, color: "#fff" }}>
        <div style={{ fontWeight: 800, fontSize: 190, lineHeight: 1, letterSpacing: "-0.04em" }}>{v}</div>
        <div style={{ fontWeight: 600, fontSize: 48, opacity: 0.8 }}>out of 400</div>
      </div>
    </div>
  );
};

const Score: React.FC = () => {
  const F = useF();
  const t = useS();
  const k = spr(t, 14.5, { damping: 14, stiffness: 100 });
  const pw = 560 * F.ks * (F.tall ? 1 : 0.86);
  const bump = spr(t, 15.75, { damping: 8, stiffness: 300 });
  return (
    <Shot a={14.5} b={16.5}>
      <KText text="Track your score." at={14.55} y={F.cy - 700 * F.ky} size={92} />
      <KText text="*Beat it.*" at={14.85} y={F.cy - 580 * F.ky} size={130} serifScale={1} />
      <Phone src="screens/result.jpg" width={pw} x={F.cx} y={F.cy + 200 * F.ky + (1 - k) * 800} rx={8} ry={lerp(24, 8, k)} rz={lerp(5, 0, k)} scale={1 + (t > 15.75 ? (1 - bump) * 0.04 : 0)}>
        <ScoreOverlay />
      </Phone>
      <Burst at={15.75} x={F.cx} y={F.cy - 100 * F.ky} n={110} />
      <Flash at={15.75} max={0.35} />
    </Shot>
  );
};

// ------------------------------------------------------------------ 16.5–18 s: all three exams

const Exams: React.FC = () => {
  const F = useF();
  return (
    <Shot a={16.5} b={18.0}>
      <KText text="JAMB. WAEC. NECO." at={16.52} y={F.cy - 380 * F.ky} size={96} stagger={0.12} />
      <ExamLogos y={F.cy} at={16.6} h={170} step={0.18} />
      <KText text="All three. *One app.*" at={17.1} y={F.cy + 380 * F.ky} size={92} />
    </Shot>
  );
};

export const AdTomorrow: React.FC = () => (
  <AbsoluteFill>
    <Audio src={sfile("audio/pack_A.wav")} />
    <WarmStage />
    <Hook />
    <Ready />
    <Reading />
    <Practice />
    <Brand />
    <Cbt />
    <Explain />
    <Tutor />
    <Score />
    <Exams />
    <Ender />
  </AbsoluteFill>
);

const Ender: React.FC = () => {
  const t = useS();
  if (t < 17.95) return null;
  return (
    <AbsoluteFill style={{ opacity: p(t, 17.95, 18.25) }}>
      <EndCard at={18.0} />
    </AbsoluteFill>
  );
};
