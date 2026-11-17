import React from "react";
import { AbsoluteFill, Audio, Img, staticFile } from "remotion";
import { Phone } from "../components";
import { Burst, EndCard, ExamLogos, Flash, KText, WarmStage, useF, useS } from "../pack/kit";
import { Bars, BigTimer, C, Callout, FONT, Ico, Pill, ScoreRing, Shot, easeOut, lerp, p, spr } from "./fkit";

// Feature ad 2: the full JAMB mock, "Sit JAMB before JAMB" (D-184). 19 s, warm cream, 120 BPM.
export const MOCK_SECONDS = 19;

// ------------------------------------------------------------------ 0–3.2 s: the hook

const Hook: React.FC = () => {
  const F = useF();
  const t = useS();
  const k = spr(t, 0.5, { damping: 10, stiffness: 140 });
  const box = 260 * F.ks;
  return (
    <Shot a={0} b={1.6} first>
      <KText text="What if you could" at={0} y={F.cy - 560 * F.ky} size={92} stagger={0.04} dur={0.28} />
      <KText text="*sit JAMB*" at={0.18} y={F.cy - 330 * F.ky} size={250} serifScale={1} />
      <div style={{ position: "absolute", left: F.cx - box / 2, top: F.cy + 30 * F.ky, width: box, height: box, borderRadius: 50, background: "#fff", display: "grid", placeItems: "center", transform: `scale(${k}) rotate(${(1 - k) * -20 - 6}deg)`, boxShadow: "0 40px 80px -30px rgba(80,60,20,.5)" }}>
        <Img src={staticFile("brand/jamb.png")} style={{ width: box * 0.82, height: box * 0.82, objectFit: "contain" }} />
      </div>
      <KText text="before JAMB?" at={0.7} y={F.cy + 470 * F.ky} size={130} />
    </Shot>
  );
};

const Same: React.FC = () => {
  const F = useF();
  const rows: [string, string, number][] = [["Same subjects.", "book", 1.65], ["Same timer.", "timer", 2.15], ["Same screen.", "grid", 2.65]];
  return (
    <Shot a={1.6} b={3.2}>
      {rows.map(([s, icon, at], i) => (
        <React.Fragment key={s}>
          <Pill x={F.cx - 360 * F.ks} y={F.cy + (i - 1) * 260 * F.ky} at={at} bg={i === 1 ? C.gold : C.navy} fg={i === 1 ? C.navy : "#fff"} size={46} bob={false}>
            <Ico n={icon} size={60 * F.ks} color={i === 1 ? C.navy : "#fff"} stroke={2.2} />
          </Pill>
          <KText text={s} at={at + 0.05} y={F.cy + (i - 1) * 260 * F.ky} size={104} align="left" x={F.cx - 250 * F.ks} width={F.W} />
        </React.Fragment>
      ))}
    </Shot>
  );
};

// ------------------------------------------------------------------ 3.2–7.2 s: every tool, labelled on the real screen

const Tools: React.FC = () => {
  const F = useF();
  const t = useS();
  const k = spr(t, 3.2, { damping: 15, stiffness: 110 });
  const pw = 420 * F.ks * (F.tall ? 1 : 0.8);
  const px = F.cx, py = F.cy + 150 * F.ky;
  // where a point of the 1170 × 2532 screenshot lands on the frame (the phone is nearly flat here)
  const pad = pw * 0.034, sw = pw - pad * 2, kk = sw / 1170, sh = sw * (2532 / 1170);
  const at = (sx: number, sy: number): [number, number] => [px - pw / 2 + pad + sx * kk, py - (sh + pad * 2) / 2 + pad + sy * kk];
  const L = F.cx - pw / 2 - 18 * F.ks, R = F.cx + pw / 2 + 18 * F.ks;
  return (
    <Shot a={3.2} b={7.2}>
      <KText text="Every tool you get / *on exam day.*" at={3.25} y={F.cy - 770 * F.ky} size={92} />
      <Phone src="screens/cbt.jpg" width={pw} x={px} y={py + (1 - k) * 900} rx={lerp(14, 0, k)} ry={0} rz={lerp(-8, 0, k)} />
      {k > 0.95 && (
        <>
          <Callout at={3.7} from={at(660, 198)} to={[R, at(660, 198)[1] - 90 * F.ky]} label="Live timer" icon="timer" size={27} />
          <Callout at={4.15} from={at(380, 390)} to={[L, at(380, 390)[1] - 40 * F.ky]} label="All 4 subjects" icon="book" size={27} />
          <Callout at={4.6} from={at(300, 855)} to={[R, at(300, 855)[1] + 40 * F.ky]} label="Tap to answer" icon="check" size={27} />
          <Callout at={5.1} from={at(440, 2395)} to={[L, at(440, 2395)[1] - 260 * F.ky]} label="Calculator" icon="calc" size={27} />
          <Callout at={5.55} from={at(575, 2395)} to={[R, at(575, 2395)[1] - 300 * F.ky]} label="Jump anywhere" icon="grid" size={27} />
          <Callout at={6.0} from={at(710, 2395)} to={[R, at(710, 2395)[1] - 120 * F.ky]} label="Flag & review" icon="flag" size={27} />
        </>
      )}
    </Shot>
  );
};

// ------------------------------------------------------------------ 7.2–9.2 s: time up

const TimeUp: React.FC = () => {
  const F = useF();
  const t = useS();
  const stamp = spr(t, 8.25, { damping: 9, stiffness: 220 });
  return (
    <Shot a={7.2} b={9.2}>
      <KText text="Time up?" at={7.25} y={F.cy - 640 * F.ky} size={110} />
      <BigTimer at={7.3} from={9} rate={9.5} x={F.cx} y={F.cy - 160 * F.ky} size={230 * F.ks} color={C.navy} warnBelow={5} />
      {stamp > 0.01 && (
        <div style={{ position: "absolute", left: F.cx, top: F.cy - 160 * F.ky, transform: `translate(-50%,-50%) rotate(-10deg) scale(${lerp(2.2, 1, stamp)})`, opacity: Math.min(1, stamp * 1.5), padding: "14px 40px", border: "10px solid #E5484D", borderRadius: 24, color: "#E5484D", fontFamily: FONT, fontWeight: 800, fontSize: 120 * F.ks, background: "rgba(251,247,239,.85)", letterSpacing: "0.04em" }}>TIME UP</div>
      )}
      <Pill x={F.cx} y={F.cy + 200 * F.ky} at={8.45} bg="#22C55E" fg="#fff" icon="check" size={44}>Submitted automatically</Pill>
      <KText text="*It submits itself,* / just like the real thing." at={8.5} y={F.cy + 520 * F.ky} size={78} />
      <Flash at={8.25} max={0.35} color="#FFE1E1" />
    </Shot>
  );
};

// ------------------------------------------------------------------ 9.2–12 s: score in seconds

const Result: React.FC = () => {
  const F = useF();
  const w = 860 * F.ks;
  return (
    <Shot a={9.2} b={12.0}>
      <KText text="Your score / *in seconds.*" at={9.25} y={F.cy - 760 * F.ky} size={100} />
      <ScoreRing at={9.6} dur={1.0} x={F.cx} y={F.cy - 300 * F.ky} r={190 * F.ks} value={287} max={400} dark />
      <Burst at={10.6} x={F.cx} y={F.cy - 300 * F.ky} n={80} power={0.8} />
      <Bars at={10.0} x={F.cx - w / 2} y={F.cy + 0 * F.ky} w={w} title="Score by subject" rows={[["Use of English", 78, 100], ["Mathematics", 64, 100], ["Physics", 70, 100], ["Chemistry", 75, 100]]} />
    </Shot>
  );
};

// ------------------------------------------------------------------ 12–14.5 s: what to fix

const Fix: React.FC = () => {
  const F = useF();
  const t = useS();
  const w = 880 * F.ks;
  const items: [string, string, string][] = [["Quadratic equations", "Mathematics · 3 wrong", "#E5484D"], ["Motion and forces", "Physics · 2 wrong", C.gold], ["Organic chemistry", "Chemistry · 2 wrong", C.gold]];
  return (
    <Shot a={12.0} b={14.5}>
      <KText text="Know exactly / *what to fix.*" at={12.05} y={F.cy - 680 * F.ky} size={104} />
      {items.map(([a, b, col], i) => {
        const k = spr(t, 12.35 + i * 0.18, { damping: 13 });
        const done = t > 13.4 + i * 0.25;
        return (
          <div key={a} style={{ position: "absolute", left: F.cx - w / 2, top: F.cy + (-280 + i * 230) * F.ky, width: w, transform: `translateX(${(1 - k) * 600}px)`, opacity: Math.min(1, k * 2) }}>
            <div style={{ display: "flex", alignItems: "center", gap: 24, background: "#fff", borderRadius: 34, padding: `${28 * F.ks}px ${32 * F.ks}px`, boxShadow: "0 30px 60px -30px rgba(80,60,20,.45)", fontFamily: FONT }}>
              <div style={{ width: 22, height: 22, borderRadius: 99, background: done ? "#22C55E" : col, flexShrink: 0 }} />
              <div style={{ flex: 1 }}>
                <div style={{ fontWeight: 800, fontSize: 40 * F.ks, color: C.navy }}>{a}</div>
                <div style={{ fontWeight: 600, fontSize: 30 * F.ks, color: "#7B88A1" }}>{b}</div>
              </div>
              <div style={{ padding: `${14 * F.ks}px ${26 * F.ks}px`, borderRadius: 99, background: done ? "#DCFCE7" : C.navy, color: done ? "#15803D" : "#fff", fontWeight: 800, fontSize: 30 * F.ks, whiteSpace: "nowrap" }}>{done ? "✓ Practised" : "Practise →"}</div>
            </div>
          </div>
        );
      })}
    </Shot>
  );
};

// ------------------------------------------------------------------ 14.5–16 s: all three exams

const Exams: React.FC = () => {
  const F = useF();
  return (
    <Shot a={14.5} b={16.1}>
      <KText text="JAMB, WAEC & NECO" at={14.55} y={F.cy - 360 * F.ky} size={96} />
      <ExamLogos y={F.cy} at={14.65} h={170} step={0.15} />
      <KText text="mocks. *One app.*" at={15.0} y={F.cy + 360 * F.ky} size={96} />
    </Shot>
  );
};

export const FeatMock: React.FC = () => (
  <AbsoluteFill>
    <Audio src={staticFile("audio/feat_cbt.wav")} />
    <WarmStage />
    <Hook />
    <Same />
    <Tools />
    <TimeUp />
    <Result />
    <Fix />
    <Exams />
    <End />
  </AbsoluteFill>
);

const End: React.FC = () => {
  const t = useS();
  if (t < 15.95) return null;
  return (
    <AbsoluteFill style={{ opacity: p(t, 15.95, 16.25) }}>
      <EndCard at={16.0} cta="Start practising free" />
    </AbsoluteFill>
  );
};

void easeOut;
