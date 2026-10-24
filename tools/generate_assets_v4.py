"""Town art: cobblestone, shop buildings, fountain, lamps, barrels, crates, flower beds, benches, banners.
Run from the project root: python3 tools/generate_assets_v4.py"""
from PIL import Image, ImageDraw
import random, os
os.makedirs("assets/world", exist_ok=True)
os.makedirs("assets/tiles", exist_ok=True)
K = (24, 18, 26, 255)


def C(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


def shade(c, f):
    return tuple(min(255, int(v * f)) for v in c[:3]) + (255,)


# ---------------------------------------------------------------- cobblestone (two variants side by side)
random.seed(4)
cob = Image.new("RGBA", (32, 16))
d = ImageDraw.Draw(cob)
for v in range(2):
    ox = v * 16
    base = C("#8d857a")
    d.rectangle([ox, 0, ox + 15, 15], fill=shade(base, 0.72))
    for ry, (y0, y1) in enumerate([(0, 4), (5, 9), (10, 14)]):
        x = ox + (0 if ry % 2 == 0 else -3) + random.randint(0, 1)
        while x < ox + 16:
            w = random.randint(4, 6)
            c = shade(base, random.uniform(0.92, 1.18))
            x0, x1 = max(x, ox), min(x + w - 1, ox + 15)
            if x1 >= x0:
                d.rectangle([x0, y0, x1, y1], fill=c)
                d.line([x0, y0, x1, y0], fill=shade(c, 1.12))
            x += w + 1
cob.save("assets/tiles/cobble.png")


# ---------------------------------------------------------------- buildings 64x64 (feet at y=61)
def building(name, roof, wall, awning, sym):
    im = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.ellipse([6, 56, 58, 63], fill=(0, 0, 0, 55))
    # walls
    d.rectangle([7, 30, 56, 60], fill=K)
    d.rectangle([8, 31, 55, 59], fill=wall)
    for x in range(12, 55, 8):
        d.line([x, 32, x, 56], fill=shade(wall, 0.85))
    d.rectangle([8, 55, 55, 59], fill=C("#7c7c88"))
    # roof
    d.polygon([(2, 33), (32, 4), (62, 33)], fill=K)
    d.polygon([(5, 32), (32, 7), (59, 32)], fill=roof)
    for i, y in enumerate(range(12, 32, 5)):
        d.line([(32 - (y - 7) * 1.08 + 1, y), (32 + (y - 7) * 1.08 - 1, y)], fill=shade(roof, 0.72))
    d.line([(5, 32), (59, 32)], fill=shade(roof, 0.6))
    # chimney
    d.rectangle([44, 8, 51, 22], fill=K)
    d.rectangle([45, 9, 50, 21], fill=C("#7a7a86"))
    # windows
    for wx in (12, 42):
        d.rectangle([wx, 38, wx + 9, 47], fill=K)
        d.rectangle([wx + 1, 39, wx + 8, 46], fill=C("#9ad0f5"))
        d.line([wx + 4, 39, wx + 4, 46], fill=K)
        d.line([wx + 1, 42, wx + 8, 42], fill=K)
    # door
    d.rectangle([26, 41, 37, 59], fill=K)
    d.rectangle([27, 42, 36, 59], fill=C("#5b3a1e"))
    d.rectangle([34, 51, 35, 52], fill=C("#f0c040"))
    # awning over door
    for i, x in enumerate(range(22, 42, 4)):
        d.rectangle([x, 36, x + 3, 40], fill=awning if i % 2 == 0 else C("#f2ead8"))
    d.line([22, 41, 41, 41], fill=K)
    # hanging sign
    d.rectangle([47, 33, 48, 36], fill=K)
    d.rectangle([44, 35, 56, 45], fill=K)
    d.rectangle([45, 36, 55, 44], fill=C("#d7b27a"))
    cx, cy = 50, 40
    if sym == "sword":
        d.line([cx, cy - 3, cx, cy + 3], fill=C("#d8d8e8")); d.line([cx - 2, cy + 1, cx + 2, cy + 1], fill=C("#8a5a20"))
    elif sym == "anvil":
        d.rectangle([cx - 3, cy - 2, cx + 3, cy], fill=K); d.rectangle([cx - 1, cy, cx + 1, cy + 3], fill=K)
    elif sym == "potion":
        d.rectangle([cx - 2, cy, cx + 2, cy + 3], fill=C("#e04868")); d.rectangle([cx - 1, cy - 3, cx + 1, cy - 1], fill=C("#d8d8e8"))
    elif sym == "star":
        d.line([cx - 3, cy, cx + 3, cy], fill=C("#7040c0")); d.line([cx, cy - 3, cx, cy + 3], fill=C("#7040c0")); d.point([cx - 1, cy - 1, cx + 1, cy + 1], fill=C("#7040c0"))
    elif sym == "bread":
        d.ellipse([cx - 3, cy - 2, cx + 3, cy + 2], fill=C("#c88a3a"))
    elif sym == "gem":
        d.polygon([(cx, cy - 3), (cx + 3, cy), (cx, cy + 3), (cx - 3, cy)], fill=C("#40c8e8"))
    elif sym == "flag":
        d.line([cx - 2, cy - 3, cx - 2, cy + 3], fill=K); d.polygon([(cx - 1, cy - 3), (cx + 3, cy - 1), (cx - 1, cy + 1)], fill=C("#d03030"))
    im.save("assets/world/bld_%s.png" % name)


building("guild", C("#3a62b8"), C("#c8a070"), C("#3a62b8"), "flag")
building("gear", C("#b03a2e"), C("#c8a070"), C("#b03a2e"), "sword")
building("smith", C("#5c5c6a"), C("#b08c64"), C("#d86a20"), "anvil")
building("potion", C("#7a3aa8"), C("#c8a880"), C("#7a3aa8"), "potion")
building("magic", C("#2c3a78"), C("#a890b8"), C("#4a2a90"), "star")
building("food", C("#d8782a"), C("#d8b080"), C("#e8c040"), "bread")
building("artifact", C("#c8a020"), C("#8a7a9a"), C("#6a2a8a"), "gem")


# ---------------------------------------------------------------- fountain 48x40
im = Image.new("RGBA", (48, 40), (0, 0, 0, 0))
d = ImageDraw.Draw(im)
d.ellipse([2, 22, 46, 39], fill=(0, 0, 0, 60))
d.ellipse([3, 18, 45, 36], fill=K)
d.ellipse([4, 19, 44, 34], fill=C("#a8a8b8"))
d.ellipse([7, 21, 41, 32], fill=C("#4aa0e0"))
d.ellipse([11, 23, 37, 30], fill=C("#7ac8f5"))
d.rectangle([21, 8, 27, 26], fill=K)
d.rectangle([22, 9, 26, 25], fill=C("#b8b8c8"))
d.ellipse([16, 4, 32, 12], fill=K)
d.ellipse([17, 5, 31, 11], fill=C("#a8a8b8"))
d.rectangle([23, 0, 25, 6], fill=C("#bfe6ff"))
for x in (19, 29):
    d.line([24, 4, x, 11], fill=C("#bfe6ff"))
im.save("assets/world/fountain.png")

# lamp post 12x30
im = Image.new("RGBA", (12, 30), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
d.ellipse([2, 26, 9, 29], fill=(0, 0, 0, 60))
d.rectangle([5, 8, 6, 27], fill=K); d.rectangle([4, 25, 7, 28], fill=K)
d.rectangle([2, 1, 9, 9], fill=K); d.rectangle([3, 2, 8, 8], fill=C("#ffd860")); d.rectangle([4, 3, 7, 7], fill=C("#fff4b0"))
d.polygon([(1, 2), (6, -1 + 1), (10, 2)], fill=K)
im.save("assets/world/lamp.png")

# barrel 12x14, crate 14x14
im = Image.new("RGBA", (12, 14), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
d.ellipse([1, 11, 11, 14], fill=(0, 0, 0, 60))
d.rounded_rectangle([1, 1, 10, 12], 2, fill=K); d.rounded_rectangle([2, 2, 9, 11], 2, fill=C("#9a6a38"))
d.line([2, 4, 9, 4], fill=C("#5a5a64")); d.line([2, 9, 9, 9], fill=C("#5a5a64")); d.line([5, 2, 5, 11], fill=C("#7a4c24"))
im.save("assets/world/barrel.png")
im = Image.new("RGBA", (14, 14), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
d.ellipse([1, 11, 13, 14], fill=(0, 0, 0, 60))
d.rectangle([1, 2, 12, 12], fill=K); d.rectangle([2, 3, 11, 11], fill=C("#b88a4c"))
d.line([2, 3, 11, 11], fill=C("#8a5e2c")); d.line([11, 3, 2, 11], fill=C("#8a5e2c"))
im.save("assets/world/crate.png")

# flower bed 28x12
random.seed(9)
im = Image.new("RGBA", (28, 12), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
d.rounded_rectangle([0, 3, 27, 11], 2, fill=K); d.rounded_rectangle([1, 4, 26, 10], 2, fill=C("#6a4a2a"))
for i in range(11):
    x, y = random.randint(3, 24), random.randint(1, 7)
    d.line([x, y + 2, x, y + 4], fill=C("#3c8a3c"))
    d.rectangle([x - 1, y, x + 1, y + 1], fill=random.choice([C("#f0507a"), C("#f8d848"), C("#f8f8f8"), C("#a070f0")]))
im.save("assets/world/flowerbed.png")

# bench 24x12
im = Image.new("RGBA", (24, 12), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
d.ellipse([1, 9, 23, 12], fill=(0, 0, 0, 50))
d.rectangle([1, 1, 22, 5], fill=K); d.rectangle([2, 2, 21, 4], fill=C("#a8743c"))
d.rectangle([1, 6, 22, 8], fill=K); d.rectangle([2, 6, 21, 7], fill=C("#c08a4c"))
for x in (3, 19):
    d.rectangle([x, 8, x + 1, 11], fill=K)
im.save("assets/world/bench.png")

# gate banner 12x30 (red with gold trim)
im = Image.new("RGBA", (12, 30), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
d.rectangle([5, 0, 6, 29], fill=K); d.rectangle([0, 1, 11, 3], fill=K)
d.rectangle([1, 4, 10, 20], fill=K); d.rectangle([2, 4, 9, 19], fill=C("#b02828"))
d.polygon([(2, 19), (5, 24), (9, 19)], fill=K); d.polygon([(3, 19), (5, 22), (8, 19)], fill=C("#b02828"))
d.rectangle([4, 8, 7, 13], fill=C("#f0c040")); d.rectangle([5, 7, 6, 14], fill=C("#f0c040"))
im.save("assets/world/banner.png")
print("ok")
