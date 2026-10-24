"""Spell book icons (assets/items/book_t_<element>.png). Run: python3 tools/generate_assets_v3.py"""
from PIL import Image, ImageDraw
import os
COL = {"fire": (240, 120, 40), "water": (80, 160, 240), "earth": (190, 150, 90), "wind": (170, 240, 250), "light": (255, 240, 140), "dark": (150, 90, 220)}
os.makedirs("assets/items", exist_ok=True)
for el, c in COL.items():
    im = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    dark = tuple(int(v * 0.55) for v in c)
    d.rectangle([2, 2, 13, 14], fill=(30, 20, 30, 255))
    d.rectangle([3, 3, 12, 13], fill=dark + (255,))
    d.rectangle([3, 3, 4, 13], fill=tuple(int(v * 0.35) for v in c) + (255,))
    d.rectangle([12, 4, 12, 12], fill=(235, 225, 200, 255))
    d.rectangle([7, 6, 10, 10], fill=c + (255,))
    d.rectangle([8, 5, 9, 11], fill=c + (255,))
    d.rectangle([6, 7, 11, 9], fill=c + (255,))
    im.save("assets/items/book_t_%s.png" % el)
print("ok")
