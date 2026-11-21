import * as THREE from "three";

// Procedural textures for the 3D laptop (D-186 v3): drawn once into canvases, so there are no files to license.

const canvas = (w: number, h: number) => {
  const c = document.createElement("canvas");
  c.width = w;
  c.height = h;
  return [c, c.getContext("2d")!] as const;
};

/** A seeded random, so every frame of the video draws the same texture. */
const rng = (seed: number) => () => {
  seed = (seed * 16807) % 2147483647;
  return (seed - 1) / 2147483646;
};

let brushedTex: THREE.CanvasTexture | null = null;
/**
 * Brushed aluminium: thousands of fine horizontal streaks of slightly different brightness. Used as the roughness
 * map (streaks catch the light differently) and the bump map (a faint grain you can see in close-ups).
 */
export const brushed = () => {
  if (brushedTex) return brushedTex;
  const [c, g] = canvas(1024, 1024);
  const r = rng(7);
  g.fillStyle = "rgb(200,200,200)";
  g.fillRect(0, 0, 1024, 1024);
  for (let i = 0; i < 9000; i++) {
    const y = r() * 1024;
    const x = r() * 1024 - 200;
    const len = 80 + r() * 700;
    const v = 150 + r() * 105;
    g.strokeStyle = `rgba(${v},${v},${v},${0.12 + r() * 0.3})`;
    g.lineWidth = 0.6 + r() * 1.2;
    g.beginPath();
    g.moveTo(x, y);
    g.lineTo(x + len, y + (r() - 0.5) * 0.8);
    g.stroke();
  }
  const t = new THREE.CanvasTexture(c);
  t.wrapS = t.wrapT = THREE.RepeatWrapping;
  t.repeat.set(2, 2);
  t.anisotropy = 8;
  brushedTex = t;
  return t;
};

/** Labels on each key, row by row, matching ROWS in Laptop3D (empty string = no label). */
export const LEGENDS: string[][] = [
  ["esc", "F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9", "F10", "F11", "F12", "⏻"],
  ["`", "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "=", "⌫"],
  ["tab", "Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P", "[", "]", "\\"],
  ["caps", "A", "S", "D", "F", "G", "H", "J", "K", "L", ";", "'", "enter"],
  ["shift", "Z", "X", "C", "V", "B", "N", "M", ",", ".", "/", "shift"],
  ["ctrl", "fn", "alt", "", "", "alt", "ctrl", "◀", "▶"],
];

/**
 * One transparent picture of all the key labels, laid out to sit exactly on the keycap tops: white print, the small
 * labels top-left like a real laptop, letters centred.
 */
export const legends = (rows: { w: number[]; d: number }[], U: number) => {
  const totalW = 14.5 * U;
  const totalD = rows.reduce((a, r) => a + r.d * U, 0);
  const pxPerCm = 90;
  const [c, g] = canvas(Math.round(totalW * pxPerCm), Math.round(totalD * pxPerCm));
  g.fillStyle = "rgba(235,238,244,0.92)";
  g.textBaseline = "middle";
  let z = 0;
  rows.forEach((r, ri) => {
    const dz = r.d * U;
    let x = 0;
    r.w.forEach((w, ki) => {
      const label = LEGENDS[ri]?.[ki] ?? "";
      const kx = (x + (w * U) / 2) * pxPerCm;
      const kz = (z + dz / 2) * pxPerCm;
      if (label) {
        const word = label.length > 1 && !/^F\d+$/.test(label) && label !== "⏻" && label !== "⌫";
        const size = ri === 0 ? 0.36 : word ? 0.3 : 0.5;
        g.font = `600 ${Math.round(size * pxPerCm)}px Arial, "DejaVu Sans", sans-serif`;
        if (word && w > 1.2) {
          g.textAlign = "left";
          g.fillText(label, (x + 0.35) * pxPerCm, (z + dz * 0.32) * pxPerCm);
        } else {
          g.textAlign = "center";
          g.fillText(label, kx, kz);
        }
      }
      x += w * U;
    });
    z += dz;
  });
  const t = new THREE.CanvasTexture(c);
  t.anisotropy = 8;
  t.colorSpace = THREE.SRGBColorSpace;
  return { tex: t, w: totalW, d: totalD };
};

let grilleTex: THREE.CanvasTexture | null = null;
/** Speaker grille: a grid of tiny round holes on transparent. */
export const grille = () => {
  if (grilleTex) return grilleTex;
  const [c, g] = canvas(160, 1000);
  g.fillStyle = "rgba(10,12,16,0.85)";
  for (let y = 10; y < 1000; y += 16) {
    for (let x = 10 + ((y / 16) % 2) * 8; x < 160; x += 16) {
      g.beginPath();
      g.arc(x, y, 3.6, 0, Math.PI * 2);
      g.fill();
    }
  }
  grilleTex = new THREE.CanvasTexture(c);
  return grilleTex;
};

let fadeTex: THREE.CanvasTexture | null = null;
/** Round soft edge for the desk, so the table fades into the page background like a product photo. */
export const fade = () => {
  if (fadeTex) return fadeTex;
  const [c, g] = canvas(512, 512);
  const gr = g.createRadialGradient(256, 256, 0, 256, 256, 256);
  gr.addColorStop(0, "#fff");
  gr.addColorStop(0.55, "#fff");
  gr.addColorStop(1, "#000");
  g.fillStyle = gr;
  g.fillRect(0, 0, 512, 512);
  fadeTex = new THREE.CanvasTexture(c);
  return fadeTex;
};
