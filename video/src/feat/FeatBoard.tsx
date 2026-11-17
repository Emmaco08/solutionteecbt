import React from "react";
import { AbsoluteFill, Audio, staticFile } from "remotion";
import { Burst, EndCard, Flash, GoldStage, KText, Star4, useF, useS } from "../pack/kit";
import { C, FONT, Ico, Pill, Shot, easeInOut, easeOut, lerp, p, rnd, spr } from "./fkit";

// Feature ad 6: Leaderboards and weekly challenges, "Who's the best JAMB student in Nigeria?" (D-184). 19 s, dark gold.
export const BOARD_SECONDS = 19;
const GOLD = "#F7C65A";

const NAMES = ["Chiamaka O.", "Abdullahi M.", "Temiloluwa A.", "Ifeoma N.", "Oluwaseun B.", "Zainab Y.", "Ebuka C.", "Halima S.", "Tobi A.", "Grace E.", "Musa I.", "Kelechi U."];
const STATES = ["Anambra", "Kano", "Lagos", "Enugu", "Oyo", "Kaduna", "Rivers", "Kwara", "Ogun", "Edo", "Plateau", "Imo"];

const Row: React.FC<{ rank: number; name: string; sub: string; score: number; you?: boolean; w: number }> = ({ rank, name, sub, score, you, w }) => {
  const F = useF();
  return (
    <div style={{ width: w, display: "flex", alignItems: "center", gap: 22, padding: `${18 * F.ks}px ${26 * F.ks}px`, borderRadius: 26, background: you ? "linear-gradient(90deg,#F7C65A,#E0A12A)" : "rgba(255,255,255,.06)", border: you ? "none" : "1.5px solid rgba(255,255,255,.08)", fontFamily: FONT, boxShadow: you ? "0 0 60px rgba(247,198,90,.45)" : undefined }}>
      <div style={{ width: 90 * F.ks, fontWeight: 800, fontSize: 38 * F.ks, color: you ? C.navy : "#AFC0DD", fontVariantNumeric: "tabular-nums" }}>#{rank}</div>
      <div style={{ width: 66 * F.ks, height: 66 * F.ks, borderRadius: 99, background: you ? C.navy : `hsl(${(rank * 47) % 360} 45% 45%)`, color: you ? GOLD : "#fff", display: "grid", placeItems: "center", fontWeight: 800, fontSize: 26 * F.ks }}>{you ? "YOU" : name.split(" ").map((s) => s[0]).join("")}</div>
      <div style={{ flex: 1 }}>
        <div style={{ fontWeight: 800, fontSize: 36 * F.ks, color: you ? C.navy : "#fff" }}>{name}</div>
        <div style={{ fontWeight: 600, fontSize: 26 * F.ks, color: you ? "rgba(11,31,68,.7)" : "#8A97B4" }}>{sub}</div>
      </div>
      <div style={{ fontWeight: 800, fontSize: 40 * F.ks, color: you ? C.navy : "#fff", fontVariantNumeric: "tabular-nums" }}>{score}</div>
    </div>
  );
};

// ------------------------------------------------------------------ 0–3.2 s: hook

const Hook: React.FC = () => {
  const F = useF();
  const t = useS();
  const beam = p(t, 1.7, 2.2, easeOut);
  return (
    <>
      <Shot a={0} b={1.6} first>
        <KText text="Who's the best" at={0} y={F.cy - 380 * F.ky} size={110} color="#fff" stagger={0.05} dur={0.3} />
        <KText text="JAMB student" at={0.2} y={F.cy - 230 * F.ky} size={130} color="#fff" />
        <KText text="*in Nigeria?*" at={0.45} y={F.cy - 40 * F.ky} size={170} color="#fff" accent={GOLD} serifScale={1} />
        {[2, 1, 3].map((n, i) => {
          const h = (n === 1 ? 340 : n === 2 ? 250 : 190) * F.ky;
          const k = spr(t, 0.5 + i * 0.12, { damping: 13 });
          const w = 230 * F.ks;
          return (
            <div key={n} style={{ position: "absolute", left: F.cx + (i - 1) * (w + 14) - w / 2, top: F.H - h * k - 60 * F.ky, width: w, height: h, borderRadius: "22px 22px 0 0", background: n === 1 ? "linear-gradient(180deg,#F7C65A,#9A6410)" : "linear-gradient(180deg,#3B4A6B,#1A2238)", display: "flex", justifyContent: "center", paddingTop: 20, fontFamily: FONT, fontWeight: 800, fontSize: 90 * F.ks, color: n === 1 ? C.navy : "#AFC0DD" }}>{n}</div>
          );
        })}
      </Shot>
      <Shot a={1.6} b={3.2}>
        <div style={{ position: "absolute", left: F.cx - 260 * F.ks, top: -100, width: 520 * F.ks, height: F.H * 0.75, background: "linear-gradient(180deg, rgba(255,240,200,.0), rgba(255,240,200,.28))", clipPath: "polygon(35% 0, 65% 0, 100% 100%, 0 100%)", opacity: beam }} />
        <div style={{ position: "absolute", left: F.cx - 160 * F.ks, top: F.cy - 300 * F.ky, width: 320 * F.ks, height: 320 * F.ks, borderRadius: 99, background: C.navy, border: `10px solid ${GOLD}`, display: "grid", placeItems: "center", fontFamily: FONT, fontWeight: 800, fontSize: 100 * F.ks, color: GOLD, transform: `scale(${spr(t, 1.9, { damping: 9 })})`, boxShadow: "0 0 120px rgba(247,198,90,.5)" }}>YOU</div>
        <div style={{ position: "absolute", left: F.cx - 90 * F.ks, top: F.cy - 470 * F.ky, transform: `translateY(${(1 - spr(t, 2.2, { damping: 10 })) * -300}px) rotate(-8deg)` }}>
          <Ico n="trophy" size={180 * F.ks} color={C.navy} stroke={1.3} fill={GOLD} />
        </div>
        <KText text="It could be *you.*" at={2.1} y={F.cy + 260 * F.ky} size={130} color="#fff" accent={GOLD} serifScale={1.1} />
        <Star4 x={F.cx + 280 * F.ks} y={F.cy - 380 * F.ky} size={100} at={2.3} />
        <Star4 x={F.cx - 300 * F.ks} y={F.cy - 60 * F.ky} size={70} at={2.45} />
      </Shot>
    </>
  );
};

// ------------------------------------------------------------------ 3.2–6.4 s: your rank climbs

const Climb: React.FC = () => {
  const F = useF();
  const t = useS();
  const k = p(t, 3.7, 5.9, easeInOut);
  const rank = Math.round(lerp(128, 7, k));
  const w = 900 * F.ks;
  const rh = 128 * F.ky * (F.tall ? 1 : 1.04);
  const rows = 7;
  // the board scrolls up as you pass people; your row stays in the middle
  const scroll = (lerp(128, 7, k) % 1) * rh;
  return (
    <Shot a={3.2} b={6.4}>
      <KText text="Practise. Score. *Climb.*" at={3.25} y={F.cy - 760 * F.ky} size={92} color="#fff" accent={GOLD} serifScale={1.1} />
      <div style={{ position: "absolute", left: F.cx - w / 2, top: F.cy - 560 * F.ky, width: w, height: rh * rows, overflow: "hidden", maskImage: "linear-gradient(180deg, transparent, #000 15%, #000 85%, transparent)" }}>
        {Array.from({ length: rows + 1 }).map((_, i) => {
          const r = rank - 3 + i;
          if (i === 3 || r < 1) return null;
          const n = (r * 7 + 3) % NAMES.length;
          return (
            <div key={r} style={{ position: "absolute", left: 0, top: i * rh - scroll + 8, opacity: 0.85 }}>
              <Row rank={r} name={NAMES[n]} sub={STATES[n]} score={Math.max(180, 372 - r)} w={w} />
            </div>
          );
        })}
      </div>
      <div style={{ position: "absolute", left: F.cx - w / 2, top: F.cy - 560 * F.ky + 3 * rh + 8, transform: `scale(1.04)` }}>
        <Row rank={rank} name="Tolu A." sub="Oyo · you" score={Math.round(lerp(241, 365, k))} you w={w} />
      </div>
      <Pill x={F.cx} y={F.cy + 470 * F.ky} at={4.2} bg="#22C55E" fg="#fff" icon="arrowUp" size={44}>{128 - rank} places up this week</Pill>
    </Shot>
  );
};

// ------------------------------------------------------------------ 6.4–9 s: Nigeria or your state

const Scope: React.FC = () => {
  const F = useF();
  const t = useS();
  const state = t > 7.6;
  const sw = p(t, 7.6, 7.85, easeInOut);
  const w = 800 * F.ks;
  const podium: [number, string, string][] = state ? [[2, "Tobi A.", "Ibadan"], [1, "Zainab Y.", "Ogbomoso"], [3, "Musa I.", "Oyo"]] : [[2, "Abdullahi M.", "Kano"], [1, "Chiamaka O.", "Anambra"], [3, "Temiloluwa A.", "Lagos"]];
  return (
    <Shot a={6.4} b={9.0}>
      <KText text="Top of Nigeria." at={6.45} y={F.cy - 760 * F.ky} size={100} color="#fff" />
      <KText text="*Or top of your state.*" at={6.75} y={F.cy - 630 * F.ky} size={88} color="#fff" accent={GOLD} serifScale={1} />
      <div style={{ position: "absolute", left: F.cx - w / 2, top: F.cy - 470 * F.ky, width: w, height: 110 * F.ks, borderRadius: 99, background: "rgba(255,255,255,.08)", border: "1.5px solid rgba(255,255,255,.12)", fontFamily: FONT }}>
        <div style={{ position: "absolute", top: 8, bottom: 8, left: lerp(8, w / 2, sw), width: w / 2 - 8, borderRadius: 99, background: GOLD }} />
        {["Nigeria", "My state (Oyo)"].map((s, i) => (
          <div key={s} style={{ position: "absolute", top: 0, bottom: 0, left: (i * w) / 2, width: w / 2, display: "grid", placeItems: "center", fontWeight: 800, fontSize: 38 * F.ks, color: (i === 1) === state ? C.navy : "#fff" }}>{s}</div>
        ))}
      </div>
      {podium.map(([n, name, place], i) => {
        const h = (n === 1 ? 420 : n === 2 ? 330 : 260) * F.ky;
        const k = spr(t, (state ? 7.75 : 6.7) + i * 0.1, { damping: 12 });
        const pw = 280 * F.ks;
        const x = F.cx + (i - 1) * (pw + 20) - pw / 2;
        return (
          <React.Fragment key={`${state}-${n}`}>
            <div style={{ position: "absolute", left: x, top: F.cy + 650 * F.ky - h * k, width: pw, height: h * k, borderRadius: "26px 26px 0 0", background: n === 1 ? "linear-gradient(180deg,#F7C65A,#9A6410)" : "linear-gradient(180deg,#3B4A6B,#1A2238)", display: "flex", justifyContent: "center", paddingTop: 16, fontFamily: FONT, fontWeight: 800, fontSize: 80 * F.ks, color: n === 1 ? C.navy : "#AFC0DD" }}>{n}</div>
            <div style={{ position: "absolute", left: x, width: pw, top: F.cy + 650 * F.ky - h * k - 230 * F.ky, textAlign: "center", opacity: k, fontFamily: FONT }}>
              <div style={{ width: 120 * F.ks, height: 120 * F.ks, margin: "0 auto", borderRadius: 99, background: `hsl(${n * 70 + (state ? 40 : 0)} 50% 45%)`, border: n === 1 ? `6px solid ${GOLD}` : "4px solid rgba(255,255,255,.3)", display: "grid", placeItems: "center", color: "#fff", fontWeight: 800, fontSize: 40 * F.ks }}>{name.split(" ").map((s) => s[0]).join("")}</div>
              <div style={{ marginTop: 10, fontWeight: 800, fontSize: 32 * F.ks, color: "#fff" }}>{name}</div>
              <div style={{ fontWeight: 600, fontSize: 24 * F.ks, color: "#8A97B4" }}>{place}</div>
            </div>
          </React.Fragment>
        );
      })}
    </Shot>
  );
};

// ------------------------------------------------------------------ 9–11.6 s: weekly challenge

const Challenge: React.FC = () => {
  const F = useF();
  const t = useS();
  const k = spr(t, 9.15, { damping: 13 });
  const w = 900 * F.ks;
  const left = Math.max(0, 2 * 3600 + 14 * 60 - Math.floor((t - 9.2) * 1));
  const pulse = (t * 1.4) % 1;
  return (
    <Shot a={9.0} b={11.6}>
      <KText text="A new challenge / *every week.*" at={9.05} y={F.cy - 720 * F.ky} size={100} color="#fff" accent={GOLD} />
      <div style={{ position: "absolute", left: F.cx - w / 2, top: F.cy - 430 * F.ky, width: w, transform: `translateY(${(1 - k) * 400}px) rotate(${(1 - k) * 6}deg)`, opacity: Math.min(1, k * 2) }}>
        <div style={{ borderRadius: 44, padding: 46 * F.ks, background: "linear-gradient(150deg,#1B3F8C,#0B1F44)", border: `2px solid rgba(247,198,90,.45)`, boxShadow: "0 50px 100px -40px rgba(0,0,0,.9)", fontFamily: FONT, color: "#fff" }}>
          <div style={{ display: "flex", alignItems: "center", gap: 14, fontWeight: 800, fontSize: 30 * F.ks, color: "#7CF0A9" }}>
            <div style={{ position: "relative", width: 20, height: 20 }}>
              <div style={{ position: "absolute", inset: 0, borderRadius: 99, background: "#22C55E", transform: `scale(${1 + pulse * 1.5})`, opacity: 1 - pulse }} />
              <div style={{ position: "absolute", inset: 0, borderRadius: 99, background: "#22C55E" }} />
            </div>
            LIVE NOW
          </div>
          <div style={{ fontWeight: 800, fontSize: 70 * F.ks, marginTop: 14, letterSpacing: "-0.03em" }}>Weekly JAMB challenge</div>
          <div style={{ display: "flex", gap: 30, marginTop: 14, fontWeight: 600, fontSize: 32 * F.ks, color: "#AFC0DD" }}>
            <span>40 questions</span><span>·</span><span style={{ fontVariantNumeric: "tabular-nums" }}>ends in {Math.floor(left / 3600)}h {String(Math.floor((left % 3600) / 60)).padStart(2, "0")}m {String(left % 60).padStart(2, "0")}s</span>
          </div>
          <div style={{ marginTop: 34 * F.ks, display: "flex", alignItems: "center", gap: 18, padding: `${22 * F.ks}px ${26 * F.ks}px`, borderRadius: 28, background: "rgba(247,198,90,.12)", border: "1.5px solid rgba(247,198,90,.4)" }}>
            <Ico n="trophy" size={60 * F.ks} color={GOLD} stroke={2} />
            <div>
              <div style={{ fontWeight: 800, fontSize: 38 * F.ks, color: GOLD }}>Rewards for the top 10*</div>
              <div style={{ fontWeight: 600, fontSize: 26 * F.ks, color: "#AFC0DD" }}>Same questions for everyone</div>
            </div>
          </div>
          <div style={{ marginTop: 30 * F.ks, height: 104 * F.ks, borderRadius: 99, background: "linear-gradient(135deg,#FFE29A,#F2B233)", display: "grid", placeItems: "center", fontWeight: 800, fontSize: 44 * F.ks, color: C.navy, transform: `scale(${t > 10.6 && t < 10.75 ? 0.95 : 1})` }}>Join free →</div>
        </div>
      </div>
      <Pill x={F.cx} y={F.cy + 540 * F.ky} at={10.0} bg="#fff" icon="bolt" size={38}>Students across Nigeria playing</Pill>
      <div style={{ position: "absolute", left: 0, width: F.W, top: F.cy + 680 * F.ky, textAlign: "center", fontFamily: FONT, fontWeight: 600, fontSize: 26 * F.ks, color: "#8A97B4", opacity: p(t, 10.2, 10.4) }}>*Eligibility and terms apply.</div>
    </Shot>
  );
};

// ------------------------------------------------------------------ 11.6–14 s: badges and streak

const BADGES: [string, string][] = [["fire", "#FF7A45"], ["trophy", GOLD], ["bolt", "#8FB8FF"], ["star", "#7CF0A9"], ["book", "#C79BFF"], ["shield", "#FF8FA3"]];

const Badges: React.FC = () => {
  const F = useF();
  const t = useS();
  const days = Math.min(12, Math.floor(lerp(0, 12.9, p(t, 12.4, 13.4))));
  const s = 230 * F.ks;
  return (
    <Shot a={11.6} b={14.0}>
      <KText text="Earn badges." at={11.65} y={F.cy - 760 * F.ky} size={110} color="#fff" />
      <KText text="*Keep your streak.*" at={11.9} y={F.cy - 620 * F.ky} size={100} color="#fff" accent={GOLD} serifScale={1} />
      {BADGES.map(([icon, col], i) => {
        const k = spr(t, 11.9 + i * 0.1, { damping: 9, stiffness: 180 });
        const x = F.cx + ((i % 3) - 1) * (s + 30 * F.ks) - s / 2;
        const y = F.cy - 400 * F.ky + Math.floor(i / 3) * (s + 30 * F.ky);
        const flip = Math.max(0, 1 - k) * 180;
        return (
          <div key={i} style={{ position: "absolute", left: x, top: y, width: s, height: s, transform: `perspective(800px) rotateY(${flip}deg) scale(${lerp(0.5, 1, k)})`, opacity: Math.min(1, k * 2) }}>
            <svg width={s} height={s} viewBox="-50 -50 100 100" style={{ position: "absolute", inset: 0 }}>
              <path d="M0 -46 L40 -23 L40 23 L0 46 L-40 23 L-40 -23 Z" fill={col} opacity=".2" stroke={col} strokeWidth="4" />
            </svg>
            <div style={{ position: "absolute", inset: 0, display: "grid", placeItems: "center" }}>
              {icon === "star" ? <Ico n="sparkle" size={s * 0.42} color={col} stroke={2} fill={col} /> : <Ico n={icon} size={s * 0.42} color={col} stroke={2} />}
            </div>
          </div>
        );
      })}
      <div style={{ position: "absolute", left: 0, width: F.W, top: F.cy + 330 * F.ky, display: "flex", justifyContent: "center", alignItems: "center", gap: 20, fontFamily: FONT, opacity: p(t, 12.3, 12.5) }}>
        <Ico n="fire" size={110 * F.ks} color="#FF7A45" stroke={1.6} fill="rgba(255,122,69,.35)" />
        <div style={{ fontWeight: 800, fontSize: 120 * F.ks, color: "#fff", fontVariantNumeric: "tabular-nums" }}>{days}</div>
        <div style={{ fontWeight: 700, fontSize: 44 * F.ks, color: "#AFC0DD" }}>day<br />streak</div>
      </div>
      <Burst at={13.4} x={F.cx} y={F.cy + 380 * F.ky} n={60} power={0.7} />
    </Shot>
  );
};

// ------------------------------------------------------------------ 14–16 s: fair play

const Fair: React.FC = () => {
  const F = useF();
  const t = useS();
  const k = spr(t, 14.1, { damping: 10 });
  return (
    <Shot a={14.0} b={16.1}>
      <div style={{ position: "absolute", left: F.cx - 170 * F.ks, top: F.cy - 520 * F.ky, transform: `scale(${k})` }}>
        <Ico n="shield" size={340 * F.ks} color="#7CF0A9" stroke={1.4} fill="rgba(124,240,169,.12)" />
      </div>
      <KText text="Fair-play checks" at={14.3} y={F.cy + 60 * F.ky} size={110} color="#fff" />
      <KText text="*keep the board honest.*" at={14.55} y={F.cy + 210 * F.ky} size={92} color="#fff" accent="#7CF0A9" serifScale={1} />
      <Pill x={F.cx} y={F.cy + 450 * F.ky} at={15.0} bg="#fff" icon="check" size={36}>Every score earned, not copied</Pill>
      {Array.from({ length: 8 }).map((_, i) => <Star4 key={i} x={F.cx + (rnd(i) - 0.5) * 900 * F.ks} y={F.cy + (rnd(i + 3) - 0.5) * 1300 * F.ky} size={30 + rnd(i + 1) * 40} at={14.2 + i * 0.1} />)}
    </Shot>
  );
};

export const FeatBoard: React.FC = () => (
  <AbsoluteFill>
    <Audio src={staticFile("audio/feat_board.wav")} />
    <GoldStage />
    <Hook />
    <Climb />
    <Scope />
    <Challenge />
    <Badges />
    <Fair />
    <End />
    <Flash at={1.6} color="#FFE7A8" max={0.3} />
  </AbsoluteFill>
);

const End: React.FC = () => {
  const t = useS();
  if (t < 15.95) return null;
  return (
    <AbsoluteFill style={{ opacity: p(t, 15.95, 16.25) }}>
      <EndCard at={16.0} cta="Join this week's challenge" />
    </AbsoluteFill>
  );
};
