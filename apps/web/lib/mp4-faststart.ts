// MP4 "fast start" in the browser (like qt-faststart / ffmpeg -movflags +faststart), D-057.
// Phones can only start a video once they have its index (the `moov` box). Many editors write it at the END, so on a
// slow network the student waits for the whole file. This moves `moov` before the media data and fixes the chunk
// offsets inside it. Only the index is read into memory; the media itself stays a slice of the original File.

type Box = { type: string; start: number; size: number; header: number };

async function readBytes(file: Blob, start: number, len: number) {
  return new Uint8Array(await file.slice(start, start + len).arrayBuffer());
}

async function topBoxes(file: Blob): Promise<Box[]> {
  const out: Box[] = [];
  let pos = 0;
  while (pos + 8 <= file.size && out.length < 64) {
    const h = await readBytes(file, pos, 16);
    const dv = new DataView(h.buffer);
    let size = dv.getUint32(0);
    const type = String.fromCharCode(h[4]!, h[5]!, h[6]!, h[7]!);
    let header = 8;
    if (size === 1) { size = Number(dv.getBigUint64(8)); header = 16; }
    else if (size === 0) size = file.size - pos;
    if (size < header) throw new Error("bad box");
    out.push({ type, start: pos, size, header });
    pos += size;
  }
  return out;
}

const CONTAINERS = new Set(["moov", "trak", "mdia", "minf", "stbl", "edts", "dinf", "udta", "mvex", "moof", "traf"]);

/** Adds `delta` to every chunk offset (stco / co64) inside a moov box. Returns false if a 32-bit offset would overflow. */
function patchOffsets(moov: Uint8Array, delta: number): boolean {
  const dv = new DataView(moov.buffer, moov.byteOffset, moov.byteLength);
  const walk = (from: number, to: number): boolean => {
    let p = from;
    while (p + 8 <= to) {
      let size = dv.getUint32(p);
      const type = String.fromCharCode(moov[p + 4]!, moov[p + 5]!, moov[p + 6]!, moov[p + 7]!);
      let header = 8;
      if (size === 1) { size = Number(dv.getBigUint64(p + 8)); header = 16; }
      if (size < header || p + size > to) return true; // stop on anything odd; leave the rest untouched
      if (CONTAINERS.has(type)) {
        if (!walk(p + header, p + size)) return false;
      } else if (type === "stco") {
        const n = dv.getUint32(p + 12);
        for (let i = 0; i < n; i++) {
          const at = p + 16 + i * 4;
          const v = dv.getUint32(at) + delta;
          if (v > 0xffffffff) return false;
          dv.setUint32(at, v);
        }
      } else if (type === "co64") {
        const n = dv.getUint32(p + 12);
        for (let i = 0; i < n; i++) {
          const at = p + 16 + i * 8;
          dv.setBigUint64(at, dv.getBigUint64(at) + BigInt(delta));
        }
      }
      p += size;
    }
    return true;
  };
  return walk(8, moov.length);
}

/**
 * Returns a fast-start copy of an MP4 (as a Blob made of slices, so big files are not loaded into memory),
 * or the original file when it is already fast-start or cannot be changed safely.
 */
export async function faststart(file: File): Promise<{ blob: Blob; changed: boolean }> {
  try {
    const boxes = await topBoxes(file);
    const moovI = boxes.findIndex((b) => b.type === "moov");
    const mdatI = boxes.findIndex((b) => b.type === "mdat");
    if (moovI < 0 || mdatI < 0 || moovI < mdatI) return { blob: file, changed: false };
    const moovBox = boxes[moovI]!;
    if (moovBox.header !== 8 || moovBox.size > 64 * 1024 * 1024) return { blob: file, changed: false };
    const moov = await readBytes(file, moovBox.start, moovBox.size);
    // moov goes right before the first mdat: everything from there on moves forward by moov's size.
    if (!patchOffsets(moov, moovBox.size)) return { blob: file, changed: false };
    const parts: BlobPart[] = [];
    boxes.forEach((b, i) => {
      if (i === moovI) return;
      if (i === mdatI) parts.push(moov);
      parts.push(file.slice(b.start, b.start + b.size));
    });
    return { blob: new Blob(parts, { type: file.type || "video/mp4" }), changed: true };
  } catch {
    return { blob: file, changed: false };
  }
}

/** True when the MP4's index comes before its media (it can start playing while downloading). */
export async function isFaststart(file: Blob) {
  try {
    const boxes = await topBoxes(file);
    const moovI = boxes.findIndex((b) => b.type === "moov");
    const mdatI = boxes.findIndex((b) => b.type === "mdat");
    return moovI >= 0 && (mdatI < 0 || moovI < mdatI);
  } catch {
    return true;
  }
}
