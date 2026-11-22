"""Tawfeeq app icon: a gold dawn rising from a parchment desk line, its rays doubling as NFC waves."""
import math
import sys
from PIL import Image, ImageDraw, ImageFilter

S = 1024
out = sys.argv[1]

def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))

top, bottom = (14, 104, 99), (8, 52, 54)
img = Image.new("RGBA", (S, S))
px = img.load()
for y in range(S):
    c = lerp(top, bottom, y / (S - 1))
    for x in range(S):
        px[x, y] = c + (255,)

cx, horizon = 512, 650
gold = (234, 188, 98, 255)
parchment = (247, 243, 236, 255)

# Dawn glow.
glow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
ImageDraw.Draw(glow).ellipse((cx - 330, horizon - 330, cx + 330, horizon + 330), fill=(240, 190, 100, 90))
glow = glow.filter(ImageFilter.GaussianBlur(120))
# Keep the dawn above the desk line; fade it out below.
fade = Image.new("L", (S, S), 0)
fd = ImageDraw.Draw(fade)
for y in range(S):
    v = 255 if y < horizon else max(0, int(255 * (1 - (y - horizon) / 90)))
    fd.line((0, y, S, y), fill=v)
glow.putalpha(Image.composite(glow.split()[3], Image.new("L", (S, S), 0), fade))
img = Image.alpha_composite(img, glow)

# Sun (upper half only, sitting on the desk line).
sun = Image.new("RGBA", (S, S), (0, 0, 0, 0))
r = 150
ImageDraw.Draw(sun).ellipse((cx - r, horizon - r, cx + r, horizon + r), fill=gold)
mask = Image.new("L", (S, S), 0)
ImageDraw.Draw(mask).rectangle((0, 0, S, horizon), fill=255)
img.paste(sun, (0, 0), Image.composite(sun, Image.new("RGBA", (S, S)), mask).split()[3])

d = ImageDraw.Draw(img)

# Rays / NFC waves: two arcs over the sun.
w = 42
for radius in (232, 318):
    box = (cx - radius, horizon - radius, cx + radius, horizon + radius)
    d.arc(box, start=205, end=335, fill=parchment, width=w)
    for ang in (205, 335):
        a = math.radians(ang)
        mx = cx + (radius - w / 2) * math.cos(a)
        my = horizon + (radius - w / 2) * math.sin(a)
        d.ellipse((mx - w / 2 + 1, my - w / 2 + 1, mx + w / 2 - 1, my + w / 2 - 1), fill=parchment)

# The desk: a rounded parchment line.
lw, lh = 600, 44
d.rounded_rectangle((cx - lw / 2, horizon, cx + lw / 2, horizon + lh), radius=lh / 2, fill=parchment)

img.convert("RGB").save(out, "PNG")
print("saved", out)
