"""Cut the background off a Flow character render (D-183): python tools/cutout.py IN OUT.png

Green screen (corners are green): chroma key with green-spill removal and soft edges.
Plain white studio: flood from the image edges through near-white pixels (white clothes touching the edge can be lost;
prefer green-screen renders for characters in white uniforms).
"""
import sys
from collections import deque

import numpy as np
from PIL import Image, ImageFilter


def green_key(a: np.ndarray) -> np.ndarray:
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    # how much greener than the other two channels the pixel is
    excess = g - np.maximum(r, b)
    alpha = 1.0 - np.clip((excess - 18.0) / 50.0, 0, 1)  # excess <= 18: solid, >= 68: background
    # spill removal: pull green down to the larger of red/blue on edge and spill pixels
    out = a.copy()
    out[..., 1] = np.minimum(g, np.maximum(r, b) + 6)
    return out, alpha


def white_flood(a: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    h, w, _ = a.shape
    lum = a.mean(axis=2)
    spread = a.max(axis=2) - a.min(axis=2)
    bg_like = (lum > 196) & (spread < 22)
    seen = np.zeros((h, w), bool)
    q = deque()
    for x in range(w):
        for y in (0, h - 1):
            if bg_like[y, x] and not seen[y, x]:
                seen[y, x] = True
                q.append((y, x))
    for y in range(h):
        for x in (0, w - 1):
            if bg_like[y, x] and not seen[y, x]:
                seen[y, x] = True
                q.append((y, x))
    while q:
        y, x = q.popleft()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and not seen[ny, nx] and bg_like[ny, nx]:
                seen[ny, nx] = True
                q.append((ny, nx))
    alpha = np.ones((h, w))
    alpha[seen] = np.clip((250 - lum[seen]) / 70.0, 0, 1) * 0.6
    out = a.copy()
    out[seen] = (20, 24, 34)
    return out, alpha


src, dst = sys.argv[1], sys.argv[2]
im = Image.open(src).convert("RGB")
a = np.asarray(im).astype(np.float32)
c = a[[0, 0, -1, -1], [0, -1, 0, -1]]
is_green = bool(np.mean(c[:, 1] - np.maximum(c[:, 0], c[:, 2])) > 40)
rgb, alpha = green_key(a) if is_green else white_flood(a)
al = Image.fromarray((alpha * 255).astype(np.uint8))
# shrink the matte by a pixel, then soften it, so no background colour rims the character
al = al.filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(0.9))
rgba = Image.fromarray(np.dstack([np.clip(rgb, 0, 255).astype(np.uint8), np.asarray(al)]), "RGBA")
bbox = rgba.getbbox()
if bbox:
    pad = 10
    w, h = rgba.size
    rgba = rgba.crop((max(0, bbox[0] - pad), max(0, bbox[1] - pad), min(w, bbox[2] + pad), min(h, bbox[3] + pad)))
rgba.save(dst)
print(dst, rgba.size, "green" if is_green else "white")
