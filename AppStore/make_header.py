#!/usr/bin/env python3
"""App Store product-page header for Jarz (3840x1646): paper background,
serif headline on the left, three framed app screens on the right.

Usage: make_header.py <raw_screenshots_dir> [out.png]
Expects home.png, food.png, recap.png in the raw dir (simulator captures).
"""
import os
import sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont

W, H = 3840, 1646
PAPER = (247, 246, 242)
INK = (23, 22, 20)
SECONDARY = (133, 130, 120)
GREEN = (26, 107, 77)
HAIRLINE = (220, 217, 207)

SERIF = "/System/Library/Fonts/NewYork.ttf"
SANS = "/System/Library/Fonts/SFNS.ttf"


def framed(path, width, radius):
    img = Image.open(path).convert("RGB")
    img = img.resize((width, int(img.height * width / img.width)), Image.LANCZOS)
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, img.width - 1, img.height - 1], radius=radius, fill=255)
    return img, mask


def place(canvas, path, x, top, width, radius=86):
    img, mask = framed(path, width, radius)
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        [x + 10, top + 30, x + width + 10, top + img.height + 30], radius=radius, fill=(30, 28, 24, 60))
    shadow = shadow.filter(ImageFilter.GaussianBlur(40))
    canvas.alpha_composite(shadow)
    canvas.paste(img, (x, top), mask)
    ImageDraw.Draw(canvas).rounded_rectangle(
        [x, top, x + width - 1, top + img.height - 1], radius=radius, outline=HAIRLINE, width=3)


def tracked(draw, xy, text, font, fill, tracking):
    x, y = xy
    for ch in text:
        draw.text((x, y), ch, font=font, fill=fill)
        x += draw.textlength(ch, font=font) + tracking


def main():
    raw = sys.argv[1]
    out = sys.argv[2] if len(sys.argv) > 2 else os.path.join(os.path.dirname(__file__), "header", "header-3840x1646.png")
    os.makedirs(os.path.dirname(out), exist_ok=True)

    canvas = Image.new("RGBA", (W, H), PAPER + (255,))
    draw = ImageDraw.Draw(canvas)

    left = 300
    tracked(draw, (left, 470), "JARZ", ImageFont.truetype(SANS, 52), SECONDARY, 22)
    serif = ImageFont.truetype(SERIF, 172)
    y = 560
    for line in ["Plan your money", "into jars."]:
        draw.text((left, y), line, font=serif, fill=INK)
        y += 200
    draw.text((left, y + 40), "Split every paycheck. Food planned day by day.",
              font=ImageFont.truetype(SANS, 58), fill=SECONDARY)

    # Three screens, the middle one raised; bottoms bleed past the canvas edge.
    phone_w = 620
    xs = [1800, 2470, 3140]
    tops = [420, 300, 420]
    for name, x, top in zip(["food", "home", "recap"], xs, tops):
        place(canvas, os.path.join(raw, f"{name}.png"), x, top, phone_w)

    canvas.convert("RGB").save(out)
    print("written", out)


if __name__ == "__main__":
    main()
