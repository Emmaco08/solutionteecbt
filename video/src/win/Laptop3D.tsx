import React, { useEffect, useMemo, useRef, useState } from "react";
import * as THREE from "three";
import { RoundedBoxGeometry } from "three/examples/jsm/geometries/RoundedBoxGeometry.js";
import { RGBELoader } from "three/examples/jsm/loaders/RGBELoader.js";
import { useThree } from "@react-three/fiber";
import { ThreeCanvas } from "@remotion/three";
import { continueRender, delayRender, staticFile, useVideoConfig } from "remotion";
import { brushed, fade, grille, legends } from "./textures";

// A photoreal laptop for the Windows advert (D-186 v2): real 3D in three.js, lit by a CC0 studio HDRI (Poly Haven),
// aluminium body, recessed keyboard with keycaps, trackpad, hinged lid, glossy bezel, glass reflection, soft shadows.
// Units are centimetres. The laptop sits on the floor (y = 0), centred on x, its hinge towards -z.

export const LAP = { W: 32, D: 22, H: 1.25, SW: 30.2, SH: 17.0, side: 0.9, top: 1.0, chin: 2.1, T: 0.5 };
export const LID_H = LAP.SH + LAP.top + LAP.chin;
const HINGE = { y: LAP.H, z: -LAP.D / 2 + 0.55 };

/** Lid angle (radians about x) for open = 0 (closed) … 1 (open, leaning back 14°). */
export const lidAngle = (open: number) => THREE.MathUtils.degToRad(THREE.MathUtils.lerp(90, -14, open));

/** World position of a point on the screen: u, v in 0..1 from the screenshot's top-left. */
export const screenPoint = (u: number, v: number, open = 1, x0 = 0): THREE.Vector3 => {
  const local = new THREE.Vector3((u - 0.5) * LAP.SW, LAP.chin + (1 - v) * LAP.SH, 0.2);
  local.applyAxisAngle(new THREE.Vector3(1, 0, 0), lidAngle(open));
  return local.add(new THREE.Vector3(x0, HINGE.y, HINGE.z));
};

export type Cam = { pos: [number, number, number]; look: [number, number, number]; fov: number; shift?: [number, number] };

/** Where a world point lands on the frame (pixels), for laying 2D labels over the 3D picture. */
export const project = (cam: Cam, W: number, H: number, p: THREE.Vector3): [number, number] => {
  const c = new THREE.PerspectiveCamera(cam.fov, W / H, 5, 800);
  c.position.set(...cam.pos);
  c.lookAt(...cam.look);
  if (cam.shift) c.setViewOffset(W, H, -cam.shift[0], -cam.shift[1], W, H);
  c.updateProjectionMatrix();
  c.updateMatrixWorld();
  const v = p.clone().project(c);
  return [((v.x + 1) / 2) * W, ((1 - v.y) / 2) * H];
};

// ------------------------------------------------------------------ loading (textures and the HDRI, once each)

const texCache = new Map<string, Promise<THREE.Texture>>();
const loadTex = (src: string, srgb = true) => {
  const key = `${src}|${srgb}`;
  if (!texCache.has(key)) {
    texCache.set(
      key,
      new THREE.TextureLoader().loadAsync(staticFile(src)).then((t) => {
        t.colorSpace = srgb ? THREE.SRGBColorSpace : THREE.NoColorSpace;
        t.anisotropy = 8;
        return t;
      }),
    );
  }
  return texCache.get(key)!;
};

const useTex = (src: string | undefined, srgb = true) => {
  const advance = useThree((st) => st.advance);
  const [tex, setTex] = useState<THREE.Texture | null>(null);
  const handle = useRef<number | null>(null);
  useEffect(() => {
    if (!src) return;
    handle.current = delayRender(`texture ${src}`);
    loadTex(src, srgb).then(setTex);
  }, [src, srgb]);
  // draw once the material has the picture, then let Remotion take the frame
  useEffect(() => {
    if (tex && handle.current !== null) {
      advance(performance.now());
      continueRender(handle.current);
      handle.current = null;
    }
  }, [tex, advance]);
  return tex;
};

let hdrCache: Promise<THREE.DataTexture> | null = null;
const Env: React.FC<{ file?: string; intensity?: number }> = ({ file = "hdri/studio_small_09.hdr", intensity = 1 }) => {
  const { gl, scene, advance } = useThree();
  useEffect(() => {
    const h = delayRender("hdri");
    hdrCache = hdrCache ?? new RGBELoader().loadAsync(staticFile(file));
    hdrCache.then((hdr) => {
      hdr.mapping = THREE.EquirectangularReflectionMapping;
      const pm = new THREE.PMREMGenerator(gl);
      const env = pm.fromEquirectangular(hdr).texture;
      scene.environment = env;
      scene.environmentIntensity = intensity;
      scene.environmentRotation = new THREE.Euler(0, -0.6, 0);
      pm.dispose();
      advance(performance.now());
      continueRender(h);
    });
  }, [gl, scene, file, intensity, advance]);
  return null;
};

/** Points the camera, with an optional offset so the subject sits where the layout wants it. */
const CamRig: React.FC<{ cam: Cam }> = ({ cam }) => {
  const { camera, size } = useThree();
  const c = camera as THREE.PerspectiveCamera;
  c.fov = cam.fov;
  c.near = 5;
  c.far = 800;
  c.position.set(...cam.pos);
  c.lookAt(...cam.look);
  if (cam.shift) c.setViewOffset(size.width, size.height, -cam.shift[0], -cam.shift[1], size.width, size.height);
  else c.clearViewOffset();
  c.updateProjectionMatrix();
  return null;
};

// ------------------------------------------------------------------ materials and geometry, made once

const M = {
  alu: new THREE.MeshPhysicalMaterial({ color: "#c9ced6", metalness: 1, roughness: 0.42, anisotropy: 0.55, clearcoat: 0.12, clearcoatRoughness: 0.35 }),
  notch: new THREE.MeshStandardMaterial({ color: "#8d94a0", metalness: 1, roughness: 0.5 }),
  port: new THREE.MeshStandardMaterial({ color: "#07080b", roughness: 0.7, metalness: 0.2 }),
  aluDark: new THREE.MeshPhysicalMaterial({ color: "#aab0b9", metalness: 1, roughness: 0.42 }),
  pad: new THREE.MeshPhysicalMaterial({ color: "#a9afb8", metalness: 0.9, roughness: 0.34, clearcoat: 0.35, clearcoatRoughness: 0.25 }),
  well: new THREE.MeshStandardMaterial({ color: "#2c3036", roughness: 0.6, metalness: 0.7 }),
  key: new THREE.MeshStandardMaterial({ color: "#17191e", roughness: 0.55, metalness: 0.05 }),
  bezel: new THREE.MeshPhysicalMaterial({ color: "#050608", roughness: 0.22, metalness: 0, clearcoat: 1, clearcoatRoughness: 0.06 }),
  glass: new THREE.MeshPhysicalMaterial({ color: "#000000", roughness: 0.03, metalness: 0, transparent: true, opacity: 1, blending: THREE.AdditiveBlending, depthWrite: false, envMapIntensity: 0.06 }),
  hinge: new THREE.MeshStandardMaterial({ color: "#2a2d33", roughness: 0.45, metalness: 0.8 }),
  cam: new THREE.MeshStandardMaterial({ color: "#11151c", roughness: 0.1, metalness: 0.5 }),
  feet: new THREE.MeshStandardMaterial({ color: "#222", roughness: 0.9 }),
};

const G = {
  base: new RoundedBoxGeometry(LAP.W, LAP.H, LAP.D, 5, 0.42),
  lid: new RoundedBoxGeometry(LAP.W, LID_H, LAP.T, 5, 0.22),
  well: new RoundedBoxGeometry(28.2, 0.08, 11.6, 3, 0.04),
  pad: new RoundedBoxGeometry(12.4, 0.03, 7.8, 3, 0.012),
  key: new RoundedBoxGeometry(1, 1, 1, 3, 0.16),
  bezel: new THREE.PlaneGeometry(LAP.W - 0.36, LID_H - 0.36),
  screen: new THREE.PlaneGeometry(LAP.SW, LAP.SH),
  hinge: new THREE.CylinderGeometry(0.42, 0.42, 26, 32),
};

/** Puts the procedural textures on the materials (once; needs the browser's canvas). */
let textured = false;
const applyTextures = () => {
  if (textured || typeof document === "undefined") return;
  const b = brushed();
  M.alu.roughnessMap = b;
  M.alu.bumpMap = b;
  M.alu.bumpScale = 0.6;
  M.alu.needsUpdate = true;
  M.aluDark.roughnessMap = b;
  M.aluDark.needsUpdate = true;
  textured = true;
};

/** The keyboard: rows of keycap widths (in key units), the classic laptop layout. */
const ROWS: { w: number[]; d: number }[] = [
  { w: Array(14).fill(14.5 / 14), d: 0.75 },
  { w: [...Array(13).fill(1), 1.5], d: 1 },
  { w: [1.5, ...Array(13).fill(1)], d: 1 },
  { w: [1.75, ...Array(11).fill(1), 1.75], d: 1 },
  { w: [2.25, ...Array(10).fill(1), 2.25], d: 1 },
  { w: [1, 1, 1.25, 1.25, 5.5, 1.25, 1.25, 1, 1], d: 1 },
];
const U = 1.82;
const GAP = 0.3;

const Keyboard: React.FC = () => {
  const mesh = useMemo(() => {
    const keys: THREE.Matrix4[] = [];
    let z = -LAP.D / 2 + 2.2;
    for (const r of ROWS) {
      const dz = r.d * U;
      let x = -(14.5 * U) / 2;
      for (const w of r.w) {
        const kw = w * U - GAP;
        const m = new THREE.Matrix4().compose(new THREE.Vector3(x + (w * U) / 2, LAP.H + 0.07, z + dz / 2), new THREE.Quaternion(), new THREE.Vector3(kw, 0.2, dz - GAP));
        keys.push(m);
        x += w * U;
      }
      z += dz;
    }
    const im = new THREE.InstancedMesh(G.key, M.key, keys.length);
    keys.forEach((m, i) => im.setMatrixAt(i, m));
    im.castShadow = true;
    im.receiveShadow = true;
    return im;
  }, []);
  const lg = useMemo(() => (typeof document === "undefined" ? null : legends(ROWS, U)), []);
  const z0 = -LAP.D / 2 + 2.2;
  return (
    <>
      <primitive object={mesh} />
      {/* printed labels on the keycap tops */}
      {lg && (
        <mesh rotation={[-Math.PI / 2, 0, 0]} position={[0, LAP.H + 0.19, z0 + lg.d / 2]} renderOrder={3}>
          <planeGeometry args={[lg.w, lg.d]} />
          <meshBasicMaterial map={lg.tex} transparent toneMapped={false} depthWrite={false} polygonOffset polygonOffsetFactor={-2} polygonOffsetUnits={-8} />
        </mesh>
      )}
      {/* speaker grilles either side of the keys */}
      {[-1, 1].map((sd) => (
        <mesh key={sd} rotation={[-Math.PI / 2, 0, 0]} position={[sd * 14.55, LAP.H + 0.012, z0 + 5.0]} renderOrder={2}>
          <planeGeometry args={[1.25, 9.6]} />
          <meshBasicMaterial map={grille()} transparent depthWrite={false} polygonOffset polygonOffsetFactor={-2} polygonOffsetUnits={-6} />
        </mesh>
      ))}
    </>
  );
};

/** Ports on the sides and the finger notch on the front edge. */
const Details: React.FC = () => (
  <>
    <mesh material={M.port} position={[-LAP.W / 2 + 0.04, LAP.H / 2 + 0.02, -4.2]}>
      <boxGeometry args={[0.12, 0.3, 0.9]} />
    </mesh>
    <mesh material={M.port} position={[-LAP.W / 2 + 0.04, LAP.H / 2 + 0.02, -2.6]}>
      <boxGeometry args={[0.12, 0.3, 0.9]} />
    </mesh>
    <mesh material={M.port} position={[-LAP.W / 2 + 0.04, LAP.H / 2, -0.4]}>
      <boxGeometry args={[0.12, 0.46, 1.3]} />
    </mesh>
    <mesh material={M.port} position={[LAP.W / 2 - 0.04, LAP.H / 2 + 0.02, -3.6]} rotation={[0, 0, Math.PI / 2]}>
      <cylinderGeometry args={[0.17, 0.17, 0.12, 20]} />
    </mesh>
    <mesh material={M.port} position={[LAP.W / 2 - 0.04, LAP.H / 2 + 0.02, -1.6]}>
      <boxGeometry args={[0.12, 0.3, 0.9]} />
    </mesh>
    <mesh material={M.notch} position={[0, LAP.H - 0.1, LAP.D / 2 - 0.05]}>
      <boxGeometry args={[3.8, 0.16, 0.14]} />
    </mesh>
  </>
);

/** A soft dark blot under the laptop (contact shadow), drawn once into a canvas. */
const blot = (() => {
  if (typeof document === "undefined") return null;
  const c = document.createElement("canvas");
  c.width = c.height = 256;
  const g = c.getContext("2d")!;
  const gr = g.createRadialGradient(128, 128, 10, 128, 128, 128);
  gr.addColorStop(0, "rgba(0,0,0,0.9)");
  gr.addColorStop(0.55, "rgba(0,0,0,0.45)");
  gr.addColorStop(1, "rgba(0,0,0,0)");
  g.fillStyle = gr;
  g.fillRect(0, 0, 256, 256);
  return new THREE.CanvasTexture(c);
})();

export type Screen = { src: string; opacity?: number; y?: number; scale?: number };

/**
 * The laptop. [open] 0 → 1 raises the lid; [on] 0 → 1 lights the screen (it flares a little as it comes on);
 * [screens] are stacked screenshots (later ones over earlier ones) with their own opacity, for cross-fades.
 */
export const LaptopModel: React.FC<{ open?: number; on?: number; screens: Screen[]; x?: number; rotY?: number; shadow?: number }> = ({ open = 1, on = 1, screens, x = 0, rotY = 0, shadow = 0.55 }) => {
  applyTextures();
  return (
    <group position={[x, 0, 0]} rotation={[0, rotY, 0]}>
      {/* contact shadow */}
      {blot && (
        <mesh rotation={[-Math.PI / 2, 0, 0]} position={[0, 0.02, 0.5]} renderOrder={-1}>
          <planeGeometry args={[LAP.W * 1.35, LAP.D * 1.4]} />
          <meshBasicMaterial map={blot} transparent opacity={shadow} depthWrite={false} polygonOffset polygonOffsetFactor={-1} polygonOffsetUnits={-4} />
        </mesh>
      )}
      {/* base */}
      <mesh geometry={G.base} material={M.alu} position={[0, LAP.H / 2, 0]} castShadow receiveShadow />
      <mesh geometry={G.well} material={M.well} position={[0, LAP.H - 0.02, -LAP.D / 2 + 2.0 + 5.6]} receiveShadow />
      <Keyboard />
      <Details />
      <mesh geometry={G.pad} material={M.pad} position={[0, LAP.H + 0.005, LAP.D / 2 - 1.3 - 3.9]} receiveShadow />
      <mesh geometry={G.hinge} material={M.hinge} position={[0, HINGE.y + 0.05, HINGE.z - 0.15]} rotation={[0, 0, Math.PI / 2]} castShadow />
      {/* lid, turning about the hinge */}
      <group position={[0, HINGE.y, HINGE.z]} rotation={[lidAngle(open), 0, 0]}>
        <mesh geometry={G.lid} material={M.alu} position={[0, LID_H / 2, -LAP.T / 2]} castShadow receiveShadow />
        <mesh geometry={G.bezel} material={M.bezel} position={[0, LID_H / 2, 0.03]} />
        <ScreenStack screens={screens} on={on} />
        <mesh material={M.cam} position={[0, LID_H - LAP.top / 2, 0.08]}>
          <circleGeometry args={[0.13, 24]} />
        </mesh>
        <mesh geometry={G.bezel} material={M.glass} position={[0, LID_H / 2, 0.45]} />
      </group>
    </group>
  );
};

const ScreenLayer: React.FC<{ s: Screen; on: number; i: number }> = ({ s, on, i }) => {
  const tex = useTex(s.src);
  const mat = useMemo(() => new THREE.MeshBasicMaterial({ toneMapped: false, transparent: true, depthWrite: false, polygonOffset: true, polygonOffsetFactor: -2, polygonOffsetUnits: -4 }), []);
  const t = useMemo(() => {
    if (!tex) return null;
    const c = tex.clone();
    c.needsUpdate = true;
    return c;
  }, [tex]);
  if (!t) return null;
  // a zoom inside the picture (scale > 1 around a point y from the top), used sparingly
  const sc = s.scale ?? 1;
  t.repeat.set(1 / sc, 1 / sc);
  t.offset.set(0.02 * (sc - 1) / sc, (1 - 1 / sc) * (1 - (s.y ?? 0.5)));
  mat.map = t;
  mat.opacity = s.opacity ?? 1;
  const flare = on < 1 ? 1 + (1 - on) * 1.6 : 1;
  mat.color.setScalar(Math.min(1, on * 1.4) * flare);
  return <mesh geometry={G.screen} material={mat} position={[0, LAP.chin + LAP.SH / 2, 0.16 + i * 0.06]} renderOrder={2 + i} />;
};

const ScreenStack: React.FC<{ screens: Screen[]; on: number }> = ({ screens, on }) => (
  <>
    <mesh geometry={G.screen} position={[0, LAP.chin + LAP.SH / 2, 0.09]}>
      <meshBasicMaterial color="#020306" polygonOffset polygonOffsetFactor={-1} polygonOffsetUnits={-2} />
    </mesh>
    {on > 0 && screens.map((s, i) => (s.opacity ?? 1) > 0 && <ScreenLayer key={s.src + i} s={s} on={on} i={i} />)}
  </>
);

/** A desktop monitor like the ones at a CBT centre: bezel, screen, neck and foot. */
export const MonitorModel: React.FC<{ x: number; z?: number; rotY?: number; src: string; drop?: number }> = ({ x, z = 0, rotY = 0, src, drop = 0 }) => {
  const tex = useTex(src);
  const w = 34, h = w * 9 / 16, b = 0.8;
  return (
    <group position={[x, drop, z]} rotation={[0, rotY, 0]}>
      {blot && (
        <mesh rotation={[-Math.PI / 2, 0, 0]} position={[0, 0.02 - drop, 0]}>
          <planeGeometry args={[24, 16]} />
          <meshBasicMaterial map={blot} transparent opacity={0.5 * Math.max(0, 1 - drop / 30)} depthWrite={false} />
        </mesh>
      )}
      <mesh position={[0, 0.4, 0]} material={M.aluDark} castShadow receiveShadow>
        <boxGeometry args={[16, 0.8, 11]} />
      </mesh>
      <mesh position={[0, 7, -2.5]} material={M.aluDark} castShadow>
        <boxGeometry args={[4, 13, 1.2]} />
      </mesh>
      <group position={[0, 14 + h / 2, -1.5]}>
        <mesh material={M.bezel} castShadow>
          <boxGeometry args={[w + b * 2, h + b * 2, 1.4]} />
        </mesh>
        {tex && (
          <mesh position={[0, 0, 0.78]}>
            <planeGeometry args={[w, h]} />
            <meshBasicMaterial map={tex} toneMapped={false} />
          </mesh>
        )}
        <mesh position={[0, 0, 0.95]} material={M.glass}>
          <planeGeometry args={[w + b * 2, h + b * 2]} />
        </mesh>
      </group>
    </group>
  );
};

/** A walnut desk top (CC0 texture, Poly Haven) that fades out at the edge into the page background. */
const Desk: React.FC<{ radius: number; tone?: number }> = ({ radius, tone = 1 }) => {
  const map = useTex("tex/walnut_Diffuse.jpg");
  const rough = useTex("tex/walnut_Rough.jpg", false);
  const nor = useTex("tex/walnut_nor_gl.jpg", false);
  const mat = useMemo(() => new THREE.MeshStandardMaterial({ transparent: true, roughness: 1, metalness: 0 }), []);
  if (!map || !rough || !nor) return null;
  for (const t of [map, rough, nor]) {
    t.wrapS = t.wrapT = THREE.RepeatWrapping;
    t.repeat.set(radius / 26, radius / 26);
  }
  mat.map = map;
  mat.roughnessMap = rough;
  mat.normalMap = nor;
  mat.normalScale.set(0.6, 0.6);
  mat.alphaMap = fade();
  mat.color.setRGB(tone, tone * 0.8, tone * 0.6); // a warmer, richer walnut than the grey-brown scan
  mat.needsUpdate = true;
  return (
    <mesh rotation={[-Math.PI / 2, 0, 0]} position={[0, -0.02, 0]} receiveShadow material={mat}>
      <circleGeometry args={[radius, 96]} />
    </mesh>
  );
};

/** The 3D stage: transparent canvas over the page background, studio light, soft shadows on an invisible floor. */
export const Stage3D: React.FC<{ cam: Cam; children: React.ReactNode; floor?: number; exposure?: number; desk?: number; deskTone?: number }> = ({ cam, children, floor = 0.32, exposure = 1.0, desk, deskTone }) => {
  const { width, height } = useVideoConfig();
  return (
    <ThreeCanvas
      width={width}
      height={height}
      style={{ position: "absolute", inset: 0 }}
      gl={{ antialias: true, alpha: true, toneMapping: THREE.ACESFilmicToneMapping, toneMappingExposure: exposure, preserveDrawingBuffer: true }}
      shadows={{ type: THREE.VSMShadowMap }}
      camera={{ fov: cam.fov, position: cam.pos, near: 5, far: 800 }}
    >
      <Env />
      <CamRig cam={cam} />
      <directionalLight
        position={[-30, 70, 40]}
        intensity={1.6}
        castShadow
        shadow-mapSize-width={2048}
        shadow-mapSize-height={2048}
        shadow-camera-left={-60}
        shadow-camera-right={60}
        shadow-camera-top={60}
        shadow-camera-bottom={-60}
        shadow-radius={14}
        shadow-blurSamples={20}
        shadow-bias={-0.0004}
      />
      <directionalLight position={[40, 30, 60]} intensity={0.5} />
      {desk ? (
        <Desk radius={desk} tone={deskTone} />
      ) : (
        <mesh rotation={[-Math.PI / 2, 0, 0]} position={[0, 0, 0]} receiveShadow>
          <planeGeometry args={[600, 600]} />
          <shadowMaterial opacity={floor} />
        </mesh>
      )}
      {children}
    </ThreeCanvas>
  );
};
