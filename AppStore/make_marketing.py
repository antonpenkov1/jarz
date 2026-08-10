#!/usr/bin/env python3
"""Compose App Store marketing screenshots for Jarz: paper background,
serif headline, device-framed screenshot.

Usage: make_marketing.py [ipad]
  default → 1284x2778 (iPhone 6.5") from /tmp/jarz-raw/
  ipad    → 2064x2752 (iPad 13")   from /tmp/jarz-raw-ipad/
"""
import sys
from PIL import Image, ImageDraw, ImageFont, ImageFilter

IPAD = len(sys.argv) > 1 and sys.argv[1] == "ipad"
W, H = (2064, 2752) if IPAD else (1284, 2778)
PAPER = (247, 246, 242)
INK = (23, 22, 20)
SECONDARY = (133, 130, 120)
HAIRLINE = (220, 217, 207)

SERIF = "/System/Library/Fonts/NewYork.ttf"
SANS = "/System/Library/Fonts/SFNS.ttf"

if IPAD:
    RAW_DIR = "/tmp/jarz-raw-ipad"
    OUT_DIR = "marketing-ipad"
    SHOTS = [
        ("home", "Plan forward, not backward.", "home"),
        ("food", "Food lives day by day.", "food"),
        ("recap", "Plan vs reality, every payday.", "recap"),
        ("income", "Split every paycheck into jars.", "income"),
    ]
else:
    RAW_DIR = "/tmp/jarz-raw"
    OUT_DIR = "marketing"
    SHOTS = [
        ("tab0", "Plan forward,\nnot backward.", "home"),
        ("food", "Food lives\nday by day.", "food"),
        ("recap", "Plan vs reality,\nevery payday.", "recap"),
        ("transfer", "Move money\nin one step.", "transfer"),
        ("tab1", "Split every paycheck\ninto jars.", "income"),
        ("tab2", "Reality check,\none tap away.", "revision"),
    ]

def tracked_text(draw, pos, text, font, fill, tracking):
    x, y = pos
    for ch in text:
        draw.text((x, y), ch, font=font, fill=fill)
        x += draw.textlength(ch, font=font) + tracking

def rounded_screenshot(path, target_w, radius):
    img = Image.open(path).convert("RGB")
    scale = target_w / img.width
    img = img.resize((target_w, int(img.height * scale)), Image.LANCZOS)
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, img.width - 1, img.height - 1],
                                           radius=radius, fill=255)
    return img, mask

def compose(shot, headline, name):
    canvas = Image.new("RGB", (W, H), PAPER)
    draw = ImageDraw.Draw(canvas)

    label_font = ImageFont.truetype(SANS, 40 if IPAD else 34)
    tracked_text(draw, (96, 150), "J A R Z", label_font, SECONDARY, 6)

    serif = ImageFont.truetype(SERIF, 132 if IPAD else 118)
    y = 280 if IPAD else 250
    for line in headline.split("\n"):
        draw.text((92, y), line, font=serif, fill=INK)
        y += 160 if IPAD else 142

    # Device frame: screenshot with rounded corners, hairline border, soft shadow.
    shot_w = 1440 if IPAD else 1000
    img, mask = rounded_screenshot(f"{RAW_DIR}/{shot}.png", shot_w, 110)
    x = (W - shot_w) // 2
    top = y + 100

    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        [x + 8, top + 26, x + shot_w + 8, top + img.height + 26],
        radius=110, fill=(30, 28, 24, 70))
    shadow = shadow.filter(ImageFilter.GaussianBlur(38))
    canvas.paste(Image.alpha_composite(canvas.convert("RGBA"), shadow).convert("RGB"), (0, 0))

    canvas.paste(img, (x, top), mask)
    border = ImageDraw.Draw(canvas)
    border.rounded_rectangle([x, top, x + shot_w - 1, top + img.height - 1],
                             radius=110, outline=HAIRLINE, width=3)

    canvas.save(f"/Users/antonpenkov/Documents/Toloka/Synthetic App Build/Jarz/AppStore/{OUT_DIR}/{name}.png")
    print(name, "ok")

import os
os.makedirs(f"/Users/antonpenkov/Documents/Toloka/Synthetic App Build/Jarz/AppStore/{OUT_DIR}", exist_ok=True)
for shot, headline, name in SHOTS:
    compose(shot, headline, name)
