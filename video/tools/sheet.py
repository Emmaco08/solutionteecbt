"""Contact sheet of out/stills/*.jpg (review aid). python tools/sheet.py out/sheet.jpg [cols]"""
import glob, sys
from PIL import Image, ImageDraw
fs = sorted(glob.glob("out/stills/*.jpg"))
cols = int(sys.argv[2]) if len(sys.argv) > 2 else 5
w, h = 324, 576
rows = (len(fs) + cols - 1) // cols
sheet = Image.new("RGB", (cols * w, rows * (h + 26)), "white")
d = ImageDraw.Draw(sheet)
for i, f in enumerate(fs):
    im = Image.open(f).resize((w, h))
    x, y = (i % cols) * w, (i // cols) * (h + 26)
    sheet.paste(im, (x, y + 26))
    d.text((x + 6, y + 6), f.split("/")[-1], fill="black")
sheet.save(sys.argv[1], quality=85)
