import React from "react";
import { AbsoluteFill, Audio, staticFile } from "remotion";
import { Phone } from "../components";
import { EndCard, Flash, KText, useF, useS } from "../pack/kit";
import { BigTimer, C, DeepStage, FONT, Ico, Notif, Pill, Shot, easeInOut, lerp, p, spr } from "./fkit";

// Feature ad 4: Live classes, "The best JAMB class is in your pocket" (D-184). 19 s, dark with red LIVE accents.
export const LIVE_SECONDS = 19;
const RED = "#FF4D5A";

const LiveDot: React.FC<{ size: number }> = ({ size }) => {
  const t = useS();
  const k = (t * 1.4) % 1;
  return (
    <div style={{ position: "relative", width: size, height: size }}>
      <div style={{ position: "absolute", inset: 0, borderRadius: 99, background: RED, transform: `scale(${1 + k * 1.6})`, opacity: 1 - k }} />
      <div style={{ position: "absolute", inset: 0, borderRadius: 99, background: RED, boxShadow: `0 0 ${size}px ${RED}` }} />
    </div>
  );
};

// ------------------------------------------------------------------ 0–3.2 s: hook

const Hook: React.FC = () => {
  const F = useF();
  const t = useS();
  const k = spr(t, 0.1, { damping: 13 });
  const w = 330 * F.ks, h = w * 2.05;
  return (
    <>
      <Shot a={0} b={1.6} first>
        <KText text="A front-row JAMB class" at={0} y={F.cy - 620 * F.ky} size={100} color="#fff" stagger={0.05} dur={0.3} />
        <div style={{ position: "absolute", left: F.cx - w / 2, top: F.cy - h / 2 + 40 * F.ky, width: w, height: h, borderRadius: w * 0.16, border: "10px solid #2A3247", background: "linear-gradient(160deg,#1B2A55,#0B1530)", transform: `translateY(${(1 - k) * 500}px) rotate(${(1 - k) * 12 - 4}deg)`, boxShadow: `0 0 120px rgba(255,77,90,.35)`, display: "grid", placeItems: "center" }}>
          <div style={{ display: "flex", alignItems: "center", gap: 16, padding: "14px 26px", borderRadius: 99, background: "rgba(255,77,90,.15)", fontFamily: FONT, fontWeight: 800, fontSize: 40 * F.ks, color: RED }}>
            <LiveDot size={22} /> LIVE
          </div>
        </div>
        <KText text="*is in your pocket.*" at={0.5} y={F.cy + 620 * F.ky} size={120} color="#fff" accent="#FFD27A" serifScale={1} />
      </Shot>
      <Shot a={1.6} b={3.2} zin={1.4}>
        <div style={{ position: "absolute", left: 0, width: F.W, top: F.cy - 220 * F.ky, display: "flex", justifyContent: "center", alignItems: "center", gap: 40 * F.ks, transform: `scale(${spr(t, 1.62, { damping: 9, stiffness: 220 })})` }}>
          <LiveDot size={90 * F.ks} />
          <div style={{ fontFamily: FONT, fontWeight: 800, fontSize: 300 * F.ks, color: "#fff", letterSpacing: "-0.06em", lineHeight: 1 }}>LIVE</div>
        </div>
        <KText text="Real teachers." at={2.0} y={F.cy + 110 * F.ky} size={110} color="#fff" />
        <KText text="*Real time.*" at={2.3} y={F.cy + 270 * F.ky} size={130} color="#fff" accent={RED} serifScale={1} />
        <Flash at={1.62} color={RED} max={0.35} />
      </Shot>
    </>
  );
};

// ------------------------------------------------------------------ 3.2–6 s: the class in the app

const InApp: React.FC = () => {
  const F = useF();
  const t = useS();
  const k = spr(t, 3.2, { damping: 15, stiffness: 100 });
  const pw = 560 * F.ks * (F.tall ? 1 : 0.8);
  return (
    <Shot a={3.2} b={6.0}>
      <KText text="Your class, / *one tap away.*" at={3.25} y={F.cy - 760 * F.ky} size={96} color="#fff" accent="#FFD27A" />
      <Phone src="screens/class_live.jpg" width={pw} x={F.cx} y={F.cy + 190 * F.ky + (1 - k) * 900} rx={8} ry={lerp(-26, -10, k)} rz={-2} />
      <Pill x={F.cx + 280 * F.ks} y={F.cy - 300 * F.ky} at={3.8} bg={RED} fg="#fff" size={40}>● LIVE NOW</Pill>
      <Pill x={F.cx - 290 * F.ks} y={F.cy - 20 * F.ky} at={4.15} icon="book" size={38}>JAMB subjects</Pill>
      <Pill x={F.cx + 280 * F.ks} y={F.cy + 300 * F.ky} at={4.5} bg="#FFD27A" icon="clock" size={38}>Full programmes</Pill>
      <Pill x={F.cx - 270 * F.ks} y={F.cy + 640 * F.ky} at={4.85} bg="#22C55E" fg="#fff" icon="play" size={38}>Tap to join</Pill>
    </Shot>
  );
};

// ------------------------------------------------------------------ 6–8.6 s: timetable and countdown

const Timetable: React.FC = () => {
  const F = useF();
  const t = useS();
  const days = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"];
  const on = [0, 2, 4];
  const cw = 128 * F.ks;
  return (
    <Shot a={6.0} b={8.6}>
      <KText text="Know exactly / *when to show up.*" at={6.05} y={F.cy - 720 * F.ky} size={96} color="#fff" accent="#FFD27A" />
      <div style={{ position: "absolute", left: 0, width: F.W, top: F.cy - 380 * F.ky, display: "flex", justifyContent: "center", gap: 12 * F.ks }}>
        {days.map((d, i) => {
          const k = spr(t, 6.3 + i * 0.07, { damping: 12 });
          const hot = on.includes(i);
          return (
            <div key={d} style={{ width: cw, height: 200 * F.ky * (F.tall ? 1 : 1.25), borderRadius: 28, background: hot ? "linear-gradient(170deg,#FF4D5A,#B21E34)" : "rgba(255,255,255,.07)", border: hot ? "none" : "1.5px solid rgba(255,255,255,.12)", display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 10, transform: `translateY(${(1 - k) * 200}px)`, opacity: Math.min(1, k * 2), fontFamily: FONT }}>
              <div style={{ fontWeight: 800, fontSize: 30 * F.ks, color: hot ? "#fff" : "#8A97B4" }}>{d}</div>
              {hot && <div style={{ fontWeight: 700, fontSize: 24 * F.ks, color: "#fff", textAlign: "center", lineHeight: 1.2 }}>6–8<br />pm</div>}
            </div>
          );
        })}
      </div>
      <div style={{ position: "absolute", left: 0, width: F.W, top: F.cy + 60 * F.ky, textAlign: "center", fontFamily: FONT, fontWeight: 700, fontSize: 40 * F.ks, color: "#AFC0DD", opacity: p(t, 6.9, 7.1) }}>Next class starts in</div>
      <div style={{ opacity: p(t, 7.0, 7.2) }}>
        <BigTimer at={7.0} from={2 * 3600 + 14 * 60 + 9} x={F.cx} y={F.cy + 230 * F.ky} size={170 * F.ks} />
      </div>
      <Pill x={F.cx} y={F.cy + 470 * F.ky} at={7.4} bg="#FFD27A" icon="pin" size={36}>e.g. Mon, Wed & Fri</Pill>
    </Shot>
  );
};

// ------------------------------------------------------------------ 8.6–11 s: reminders

const Reminders: React.FC = () => {
  const F = useF();
  const list: [string, string][] = [
    ["Class in 2 hours", "Physics: Motion and forces"],
    ["Class in 1 hour", "Get your notebook ready"],
    ["Class in 30 minutes", "Physics: Motion and forces"],
    ["Class in 10 minutes", "Find a quiet spot"],
    ["We are LIVE now!", "Tap to join the class"],
  ];
  return (
    <Shot a={8.6} b={11.0}>
      <KText text="Never miss a class." at={8.65} y={F.cy - 760 * F.ky} size={100} color="#fff" />
      {list.map(([a, b], i) => (
        <Notif key={a} at={8.95 + i * 0.32} y={F.cy - 600 * F.ky + i * 200 * F.ky} title={a} body={b} icon={i === 4 ? "play" : "bell"} tint={i === 4 ? RED : "#FFD27A"} />
      ))}
      <KText text="*Reminders before every class.*" at={10.3} y={F.cy + 760 * F.ky} size={72} color="#fff" accent="#FFD27A" serifScale={1} />
    </Shot>
  );
};

// ------------------------------------------------------------------ 11–13.4 s: recordings

const Recording: React.FC = () => {
  const F = useF();
  const t = useS();
  const k = spr(t, 11.05, { damping: 14 });
  const w = 900 * F.ks, h = w * 0.56;
  const play = p(t, 11.9, 13.2, (v) => v);
  return (
    <Shot a={11.0} b={13.4}>
      <KText text="Missed it?" at={11.05} y={F.cy - 680 * F.ky} size={110} color="#fff" />
      <KText text="*Watch the recording.*" at={11.3} y={F.cy - 540 * F.ky} size={96} color="#fff" accent="#FFD27A" serifScale={1} />
      <div style={{ position: "absolute", left: F.cx - w / 2, top: F.cy - 330 * F.ky, width: w, transform: `scale(${lerp(0.8, 1, k)})`, opacity: Math.min(1, k * 2) }}>
        <div style={{ height: h, borderRadius: 36, overflow: "hidden", position: "relative", background: "linear-gradient(135deg,#1B3F8C,#0B1F44)", boxShadow: "0 40px 80px -30px rgba(0,0,0,.8)" }}>
          <div style={{ position: "absolute", left: 50, top: 50, fontFamily: FONT, fontWeight: 800, fontSize: 60 * F.ks, color: "#fff", lineHeight: 1.05 }}>Motion and<br />forces</div>
          <div style={{ position: "absolute", left: 50, top: 210 * F.ks, fontFamily: FONT, fontWeight: 600, fontSize: 30 * F.ks, color: "#AFC0DD" }}>JAMB Marathon Class · Session 4</div>
          <svg style={{ position: "absolute", right: 40, bottom: 70, opacity: 0.35 }} width={300 * F.ks} height={200 * F.ks} viewBox="0 0 300 200"><path d="M10 180 Q 150 -40 290 180" stroke="#FFD27A" strokeWidth="6" fill="none" strokeDasharray="12 10" /><circle cx={10 + play * 280} cy={180 - Math.sin(play * Math.PI) * 140} r="16" fill="#FFD27A" /></svg>
          <div style={{ position: "absolute", left: "50%", top: "50%", width: 150 * F.ks, height: 150 * F.ks, marginLeft: -75 * F.ks, marginTop: -75 * F.ks, borderRadius: 99, background: "rgba(255,255,255,.92)", display: "grid", placeItems: "center", transform: `scale(${t > 11.85 ? 1 - p(t, 11.85, 12.1) * 0.25 : 1})`, opacity: 1 - p(t, 12.0, 12.3) }}>
            <Ico n="play" size={70 * F.ks} color={C.navy} fill={C.navy} />
          </div>
          <div style={{ position: "absolute", left: 30, right: 30, bottom: 26, height: 10, borderRadius: 9, background: "rgba(255,255,255,.2)" }}>
            <div style={{ width: `${8 + play * 60}%`, height: "100%", borderRadius: 9, background: RED }} />
          </div>
        </div>
      </div>
      <Pill x={F.cx} y={F.cy + 330 * F.ky} at={12.2} bg="#fff" icon="video" size={38}>Recordings after every class</Pill>
    </Shot>
  );
};

// ------------------------------------------------------------------ 13.4–16 s: pay once

const PayOnce: React.FC = () => {
  const F = useF();
  const t = useS();
  const split = p(t, 14.3, 15.0, easeInOut);
  const w = 330 * F.ks, h = 210 * F.ks;
  return (
    <Shot a={13.4} b={16.1}>
      <KText text="Pay once." at={13.45} y={F.cy - 700 * F.ky} size={130} color="#fff" />
      <KText text="*Every session.*" at={13.75} y={F.cy - 550 * F.ky} size={110} color="#fff" accent="#FFD27A" serifScale={1} />
      {Array.from({ length: 8 }).map((_, i) => {
        const col = i % 2, row = Math.floor(i / 2);
        const tx = lerp(0, (col ? 1 : -1) * (w / 2 + 16 * F.ks), split);
        const ty = lerp(0, (row - 1.5) * (h + 22 * F.ky), split);
        const live = i === 3;
        return (
          <div key={i} style={{ position: "absolute", left: F.cx - w / 2 + tx, top: F.cy + 120 * F.ky - h / 2 + ty, width: w, height: h, borderRadius: 26, background: live ? "linear-gradient(160deg,#FF4D5A,#B21E34)" : "linear-gradient(160deg,#20305C,#121D3D)", border: "1.5px solid rgba(255,255,255,.14)", padding: 20 * F.ks, fontFamily: FONT, color: "#fff", opacity: i === 0 || split > 0.05 ? 1 : 0, transform: `rotate(${(1 - split) * (i - 3.5) * 3}deg)`, boxShadow: "0 20px 40px -20px rgba(0,0,0,.8)" }}>
            <div style={{ fontWeight: 600, fontSize: 24 * F.ks, opacity: 0.75 }}>Session {i + 1}</div>
            <div style={{ fontWeight: 800, fontSize: 32 * F.ks, marginTop: 6 }}>{["English", "Maths", "Physics", "Chemistry", "Biology", "Economics", "Government", "Mock review"][i]}</div>
            <div style={{ marginTop: 10, fontWeight: 700, fontSize: 22 * F.ks, color: live ? "#fff" : "#7CF0A9" }}>{live ? "● LIVE" : "✓ Included"}</div>
          </div>
        );
      })}
      {split < 0.05 && (
        <div style={{ position: "absolute", left: F.cx - w / 2, top: F.cy + 120 * F.ky - h / 2, width: w, height: h, borderRadius: 26, background: "linear-gradient(135deg,#FFE29A,#F2B233)", display: "grid", placeItems: "center", fontFamily: FONT, fontWeight: 800, fontSize: 40 * F.ks, color: C.navy, transform: `scale(${spr(t, 13.7, { damping: 10 })})` }}>One payment</div>
      )}
      <Flash at={14.3} color="#FFD27A" max={0.25} />
    </Shot>
  );
};

export const FeatLive: React.FC = () => (
  <AbsoluteFill>
    <Audio src={staticFile("audio/feat_live.wav")} />
    <DeepStage base="#0B0812" a="rgba(255,77,90,.40)" b="rgba(242,178,51,.22)" dust="#FFB1B8" />
    <Hook />
    <InApp />
    <Timetable />
    <Reminders />
    <Recording />
    <PayOnce />
    <End />
  </AbsoluteFill>
);

const End: React.FC = () => {
  const t = useS();
  if (t < 15.95) return null;
  return (
    <AbsoluteFill style={{ opacity: p(t, 15.95, 16.25) }}>
      <EndCard at={16.0} cta="See this month's classes" />
    </AbsoluteFill>
  );
};
