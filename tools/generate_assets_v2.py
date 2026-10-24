#!/usr/bin/env python3
"""Second asset pass: monsters, bosses, skill effects, biome tiles, dungeon art, gear / loot icons.
Called automatically at the end of generate_assets.py."""
import os, math, random
from PIL import Image, ImageDraw
from generate_assets import (C, mk, save, outline, strip, R, EYE, A, blade, spear, bow, wand, hammer, icon, OUTL)

WHITE = (255, 255, 255, 255)


def sh(d, x0=7, x1=25, y0=26, y1=30):
    d.ellipse((x0, y0, x1, y1), fill=(0, 0, 0, 70))


def walk(f):
    return [0, -1, 0, -1][f], [0, 2, 0, -2][f]


# ================================================================ MONSTERS (32x32, facing right)
def tiger(f):
    im = mk(32, 32); d = ImageDraw.Draw(im); bob, sw = walk(f)
    o, dk, lt = C("#e08a2a"), C("#a85a1a"), C("#f4e0b8")
    sh(d, 5, 27)
    for i, x in enumerate((9, 12, 19, 22)):
        off = sw if i % 2 == 0 else -sw
        d.line((x, 22, x + off, 27), fill=dk if i in (0, 2) else o, width=2)
    d.polygon([(8, 16 + bob), (1, 13 + bob + sw // 2), (3, 19 + bob), (8, 20 + bob)], fill=o)
    d.ellipse((5, 12 + bob, 25, 24 + bob), fill=o)
    d.ellipse((9, 20 + bob, 22, 24 + bob), fill=lt)
    for x in (10, 14, 18, 22):
        d.line((x, 13 + bob, x - 1, 19 + bob), fill=C("#2a1a10"), width=1)
    d.ellipse((21, 10 + bob, 30, 20 + bob), fill=o)
    R(d, 28, 15 + bob, 31, 18 + bob, lt)
    d.point((31, 15 + bob), fill=(0, 0, 0, 255))
    d.polygon([(22, 11 + bob), (23, 7 + bob), (26, 11 + bob)], fill=dk)
    d.point((26, 13 + bob), fill=C("#ffe040"))
    return outline(im)


def bear(f):
    im = mk(32, 32); d = ImageDraw.Draw(im); bob, sw = walk(f)
    br, dk, lt = C("#6a4a2e"), C("#4a3220"), C("#a8845a")
    sh(d, 4, 28)
    for i, x in enumerate((8, 12, 19, 23)):
        off = sw if i % 2 == 0 else -sw
        d.line((x, 21, x + off, 27), fill=dk if i in (0, 2) else br, width=3)
    d.ellipse((3, 9 + bob, 25, 25 + bob), fill=br)
    d.ellipse((6, 11 + bob, 16, 18 + bob), fill=C("#7e5a38"))
    d.ellipse((20, 8 + bob, 31, 20 + bob), fill=br)
    d.ellipse((20, 5 + bob, 24, 9 + bob), fill=dk)
    d.ellipse((26, 5 + bob, 30, 9 + bob), fill=dk)
    d.ellipse((26, 13 + bob, 31, 19 + bob), fill=lt)
    d.point((30, 14 + bob), fill=(0, 0, 0, 255))
    d.point((26, 11 + bob), fill=C("#1e1828"))
    return outline(im)


def ogre(f):
    im = mk(32, 32); d = ImageDraw.Draw(im); bob, sw = walk(f)
    sk, dk = C("#b0885a"), C("#80603a")
    sh(d, 6, 26)
    R(d, 11 - sw, 22, 15 - sw, 28, dk)
    R(d, 17 + sw, 22, 21 + sw, 28, sk)
    d.ellipse((7, 9 + bob, 25, 26 + bob), fill=sk)
    d.ellipse((10, 14 + bob, 22, 24 + bob), fill=C("#c8a070"))
    R(d, 8, 22 + bob, 24, 25 + bob, C("#6a4a2a"))
    d.ellipse((11, 2 + bob, 22, 12 + bob), fill=sk)
    d.point((14, 6 + bob), fill=C("#d03030"))
    d.point((19, 6 + bob), fill=C("#d03030"))
    R(d, 13, 8 + bob, 20, 9 + bob, C("#5a3a20"))
    d.point((14, 10 + bob), fill=C("#f4f0e0"))
    d.point((19, 10 + bob), fill=C("#f4f0e0"))
    d.line((23, 14 + bob, 28, 13 + bob + sw // 2), fill=sk, width=3)
    R(d, 27, 4 + bob + sw // 2, 30, 17 + bob + sw // 2, C("#7a5230"))
    R(d, 26, 4 + bob + sw // 2, 31, 8 + bob + sw // 2, C("#5a3a20"))
    return outline(im)


def skeleton(f):
    im = mk(32, 32); d = ImageDraw.Draw(im); bob, sw = walk(f)
    b, dk = C("#ece6d4"), C("#9a9484")
    sh(d, 9, 23)
    d.line((14 - sw, 22, 14 - sw, 28), fill=b, width=2)
    d.line((18 + sw, 22, 18 + sw, 28), fill=b, width=2)
    R(d, 14, 14 + bob, 18, 22 + bob, dk)
    for y in (15, 17, 19, 21):
        R(d, 12, y + bob, 20, y + bob, b)
    R(d, 15, 12 + bob, 17, 14 + bob, b)
    d.ellipse((11, 2 + bob, 21, 12 + bob), fill=b)
    R(d, 13, 6 + bob, 15, 8 + bob, C("#1e1828"))
    R(d, 18, 6 + bob, 20, 8 + bob, C("#1e1828"))
    R(d, 14, 10 + bob, 19, 11 + bob, dk)
    d.line((20, 15 + bob, 25, 17 + bob + sw // 2), fill=b, width=2)
    d.line((26, 8 + bob + sw // 2, 26, 21 + bob + sw // 2), fill=C("#c8d0e0"), width=2)
    d.line((12, 15 + bob, 9, 20 + bob), fill=b, width=2)
    return outline(im)


def zombie(f):
    im = mk(32, 32); d = ImageDraw.Draw(im); bob, sw = walk(f)
    sk, dk = C("#7a9a6a"), C("#566e4a")
    sh(d, 9, 23)
    R(d, 13 - sw, 22, 15 - sw, 28, C("#4a4a5a"))
    R(d, 17 + sw, 22, 19 + sw, 28, C("#4a4a5a"))
    R(d, 12, 13 + bob, 20, 23 + bob, C("#6a5a4a"))
    R(d, 12, 19 + bob, 20, 20 + bob, C("#4a3a2a"))
    R(d, 13, 3 + bob, 21, 12 + bob, sk)
    d.point((16, 7 + bob), fill=C("#d8d040"))
    d.point((19, 7 + bob), fill=C("#d8d040"))
    R(d, 15, 10 + bob, 20, 10 + bob, dk)
    d.line((20, 15 + bob, 28, 15 + bob + sw // 2), fill=sk, width=2)
    d.line((19, 18 + bob, 27, 19 + bob - sw // 2), fill=dk, width=2)
    R(d, 12, 15 + bob, 13, 17 + bob, dk)
    return outline(im)


def treant_small(f):
    im = mk(32, 32); d = ImageDraw.Draw(im); bob, sw = walk(f)
    br, dk = C("#7a5230"), C("#54361e")
    sh(d, 6, 26)
    d.polygon([(11, 24), (8 - sw, 29), (14, 28)], fill=dk)
    d.polygon([(21, 24), (24 + sw, 29), (18, 28)], fill=dk)
    R(d, 11, 11 + bob, 21, 25 + bob, br)
    for x in (13, 16, 19):
        d.line((x, 12 + bob, x, 24 + bob), fill=dk)
    d.line((11, 16 + bob, 5, 21 + bob + sw), fill=br, width=3)
    d.line((21, 16 + bob, 27, 20 + bob - sw), fill=br, width=3)
    for (cx, cy, r) in ((10, 8, 6), (16, 5, 7), (22, 8, 6)):
        d.ellipse((cx - r, cy - r + bob, cx + r, cy + r + bob), fill=C("#2f7a3a"))
    d.ellipse((12, 3 + bob, 20, 9 + bob), fill=C("#4cae50"))
    R(d, 13, 14 + bob, 14, 16 + bob, C("#ffe060"))
    R(d, 18, 14 + bob, 19, 16 + bob, C("#ffe060"))
    R(d, 14, 19 + bob, 18, 20 + bob, C("#2a1a10"))
    return outline(im)


def dryad(f):
    im = mk(32, 32); d = ImageDraw.Draw(im); bob, sw = walk(f)
    sk, lf = C("#9fd89a"), C("#3f9b45")
    sh(d, 9, 23)
    R(d, 13 - sw, 24, 15 - sw, 28, sk)
    R(d, 17 + sw, 24, 19 + sw, 28, sk)
    d.polygon([(11, 15 + bob), (21, 15 + bob), (23, 25 + bob), (9, 25 + bob)], fill=C("#5cbf5a"))
    R(d, 9, 23 + bob, 23, 25 + bob, lf)
    R(d, 13, 4 + bob, 20, 13 + bob, sk)
    d.point((15, 8 + bob), fill=EYE)
    d.point((18, 8 + bob), fill=EYE)
    d.polygon([(11, 5 + bob), (14, 1 + bob), (17, 3 + bob), (20, 0 + bob), (23, 5 + bob), (21, 9 + bob), (11, 9 + bob)], fill=lf)
    d.point((13, 3 + bob), fill=C("#f4a0c0"))
    d.point((21, 4 + bob), fill=C("#f4a0c0"))
    d.line((21, 16 + bob, 26, 18 + bob), fill=sk, width=2)
    d.line((27, 6 + bob, 27, 26 + bob), fill=C("#7a5230"), width=2)
    d.ellipse((24, 2 + bob, 30, 8 + bob), fill=C("#9be26a"))
    return outline(im)


def lizard(f):
    im = mk(32, 32); d = ImageDraw.Draw(im); bob, sw = walk(f)
    g, dk, lt = C("#5a9a4a"), C("#3a6a30"), C("#c8d890")
    sh(d, 6, 26)
    d.polygon([(12, 20 + bob), (2, 24 + bob + sw // 2), (3, 27), (13, 24 + bob)], fill=dk)
    R(d, 13 - sw, 23, 15 - sw, 28, dk)
    R(d, 17 + sw, 23, 19 + sw, 28, g)
    R(d, 12, 12 + bob, 21, 24 + bob, g)
    R(d, 15, 14 + bob, 20, 23 + bob, lt)
    d.polygon([(17, 3 + bob), (27, 6 + bob), (27, 11 + bob), (17, 12 + bob)], fill=g)
    R(d, 24, 7 + bob, 28, 10 + bob, lt)
    d.point((22, 6 + bob), fill=C("#ffd040"))
    d.line((20, 15 + bob, 24, 16 + bob), fill=g, width=2)
    d.line((25, 4 + bob, 25, 27 + bob), fill=C("#8a6238"), width=2)
    d.polygon([(25, 1 + bob), (23, 6 + bob), (27, 6 + bob)], fill=C("#c8d0e0"))
    d.line((17, 8 + bob, 19, 5 + bob), fill=dk)
    return outline(im)


def mermaid(f):
    im = mk(32, 32); d = ImageDraw.Draw(im); bob, sw = walk(f)
    sk, tl, hr = C("#f0c8aa"), C("#2ab0b8"), C("#3a6ae0")
    d.ellipse((7, 27, 25, 31), fill=(40, 90, 160, 80))
    d.polygon([(12, 17 + bob), (20, 17 + bob), (19, 24 + bob), (15 + sw, 28), (8 + sw, 29), (12 + sw, 25), (13, 22 + bob)], fill=tl)
    d.polygon([(8 + sw, 29), (3 + sw, 26), (4 + sw, 30)], fill=C("#4ad0d8"))
    for y in (19, 22):
        R(d, 13, y + bob, 18, y + bob, C("#1a8a92"))
    R(d, 12, 10 + bob, 20, 17 + bob, sk)
    R(d, 12, 12 + bob, 20, 13 + bob, C("#e870a8"))
    R(d, 13, 2 + bob, 20, 10 + bob, sk)
    d.point((17, 6 + bob), fill=EYE)
    d.point((19, 6 + bob), fill=EYE)
    d.polygon([(12, 2 + bob), (20, 1 + bob), (21, 5 + bob), (21, 18 + bob), (17, 12 + bob), (12, 9 + bob)], fill=hr)
    R(d, 14, 3 + bob, 20, 5 + bob, hr)
    d.line((20, 13 + bob, 25, 11 + bob + sw // 2), fill=sk, width=2)
    d.line((26, 3 + bob + sw // 2, 26, 18 + bob + sw // 2), fill=C("#ffd23a"), width=1)
    d.polygon([(26, 1 + bob + sw // 2), (24, 5 + bob + sw // 2), (28, 5 + bob + sw // 2)], fill=C("#ffd23a"))
    return outline(im)


def vampire(f):
    im = mk(32, 32); d = ImageDraw.Draw(im); bob, sw = walk(f)
    sh(d, 8, 24)
    R(d, 13 - sw, 23, 15 - sw, 28, C("#2a2a3a"))
    R(d, 17 + sw, 23, 19 + sw, 28, C("#2a2a3a"))
    d.polygon([(9, 12 + bob), (23, 12 + bob), (27, 27), (5, 27)], fill=C("#2a1a3a"))
    d.polygon([(11, 12 + bob), (21, 12 + bob), (22, 26), (10, 26)], fill=C("#7a1a2a"))
    R(d, 12, 12 + bob, 20, 22 + bob, C("#1e1828"))
    R(d, 14, 13 + bob, 18, 18 + bob, C("#e8e0e8"))
    R(d, 13, 2 + bob, 20, 12 + bob, C("#e8dcd8"))
    R(d, 12, 1 + bob, 21, 5 + bob, C("#1e1828"))
    d.point((15, 7 + bob), fill=C("#ff2a2a"))
    d.point((18, 7 + bob), fill=C("#ff2a2a"))
    d.point((15, 10 + bob), fill=WHITE)
    d.point((18, 10 + bob), fill=WHITE)
    d.line((21, 16 + bob, 26, 18 + bob + sw // 2), fill=C("#e8dcd8"), width=2)
    return outline(im)


def phoenix(f):
    im = mk(32, 32); d = ImageDraw.Draw(im)
    bob = [0, -1, 0, 1][f]
    wy = [-8, -3, 4, -3][f]
    d.ellipse((8, 27, 24, 31), fill=(0, 0, 0, 50))
    d.polygon([(10, 16 + bob), (1, 12 + bob), (4, 19 + bob), (0, 25 + bob), (9, 20 + bob)], fill=C("#e8452a"))
    d.polygon([(10, 17 + bob), (3, 16 + bob), (5, 21 + bob), (9, 20 + bob)], fill=C("#ffd23a"))
    d.polygon([(14, 15 + bob), (20, 14 + bob), (22, 8 + bob + wy), (12, 6 + bob + wy)], fill=C("#ff8a2a"))
    d.polygon([(14, 15 + bob), (18, 14 + bob), (19, 9 + bob + wy), (13, 8 + bob + wy)], fill=C("#ffd23a"))
    d.ellipse((9, 11 + bob, 23, 21 + bob), fill=C("#e8452a"))
    d.ellipse((11, 14 + bob, 21, 21 + bob), fill=C("#ff9a2a"))
    d.ellipse((20, 7 + bob, 28, 15 + bob), fill=C("#ff8a2a"))
    d.polygon([(27, 10 + bob), (31, 12 + bob), (27, 13 + bob)], fill=C("#ffd23a"))
    d.point((25, 10 + bob), fill=EYE)
    d.polygon([(21, 7 + bob), (22, 3 + bob), (24, 7 + bob)], fill=C("#ffd23a"))
    d.line((15, 21 + bob, 15, 24 + bob), fill=C("#ffd23a"))
    d.line((19, 21 + bob, 19, 24 + bob), fill=C("#ffd23a"))
    return outline(im)


def wyvern(f):
    im = mk(48, 48); d = ImageDraw.Draw(im)
    bob = [0, -1, 0, 1][f]
    wy = [-14, -6, 4, -6][f]
    g, dk, lt = C("#4a8a5a"), C("#2e5a3a"), C("#c8e0a0")
    d.ellipse((8, 40, 40, 46), fill=(0, 0, 0, 60))
    d.polygon([(14, 26 + bob), (2, 34 + bob), (3, 38 + bob), (16, 32 + bob)], fill=dk)
    d.polygon([(2, 34 + bob), (0, 31 + bob), (6, 33 + bob)], fill=C("#d8c040"))
    d.polygon([(18, 22 + bob), (34, 20 + bob), (30, 4 + bob + wy), (10, 2 + bob + wy)], fill=C("#6a3a7a"))
    d.polygon([(18, 22 + bob), (30, 20 + bob), (26, 8 + bob + wy), (14, 6 + bob + wy)], fill=C("#8a52a0"))
    d.line((18, 22 + bob, 10, 2 + bob + wy), fill=dk, width=2)
    d.ellipse((10, 20 + bob, 36, 36 + bob), fill=g)
    d.ellipse((14, 27 + bob, 32, 36 + bob), fill=lt)
    d.line((18, 35 + bob, 17, 41), fill=dk, width=2)
    d.line((27, 35 + bob, 28, 41), fill=dk, width=2)
    d.polygon([(32, 24 + bob), (38, 14 + bob), (42, 16 + bob), (36, 26 + bob)], fill=g)
    d.polygon([(36, 12 + bob), (46, 16 + bob), (44, 22 + bob), (36, 20 + bob)], fill=g)
    d.polygon([(36, 12 + bob), (35, 7 + bob), (39, 11 + bob)], fill=C("#d8c040"))
    d.point((41, 15 + bob), fill=C("#ff4a2a"))
    R(d, 44, 18 + bob, 46, 20 + bob, lt)
    return outline(im)


def dragon(f):
    im = mk(48, 48); d = ImageDraw.Draw(im)
    bob = [0, -1, 0, -1][f]
    wy = [-12, -4, 4, -4][f]
    rd, dk, lt = C("#c03a2a"), C("#7a1e1e"), C("#f0c070")
    d.ellipse((6, 41, 42, 47), fill=(0, 0, 0, 60))
    d.polygon([(12, 28 + bob), (0, 38 + bob), (2, 42 + bob), (14, 36 + bob)], fill=dk)
    d.polygon([(0, 38 + bob), (-1, 34 + bob), (5, 37 + bob)], fill=C("#f0c070"))
    d.polygon([(14, 24 + bob), (32, 22 + bob), (28, 4 + bob + wy), (6, 4 + bob + wy)], fill=C("#7a1e1e"))
    d.polygon([(14, 24 + bob), (28, 22 + bob), (24, 8 + bob + wy), (10, 8 + bob + wy)], fill=C("#a02a2a"))
    d.ellipse((8, 22 + bob, 36, 40 + bob), fill=rd)
    d.ellipse((12, 30 + bob, 32, 40 + bob), fill=lt)
    d.line((16, 38 + bob, 15, 44), fill=dk, width=3)
    d.line((29, 38 + bob, 30, 44), fill=dk, width=3)
    d.polygon([(30, 28 + bob), (36, 12 + bob), (41, 14 + bob), (36, 30 + bob)], fill=rd)
    d.polygon([(34, 8 + bob), (47, 12 + bob), (45, 20 + bob), (34, 18 + bob)], fill=rd)
    d.polygon([(34, 8 + bob), (32, 2 + bob), (38, 7 + bob)], fill=C("#f0e8d0"))
    d.polygon([(38, 8 + bob), (38, 1 + bob), (42, 8 + bob)], fill=C("#f0e8d0"))
    d.point((41, 12 + bob), fill=C("#ffe040"))
    R(d, 44, 15 + bob, 47, 17 + bob, C("#ff9a2a"))
    for x in (32, 36, 40):
        d.point((x, 11 + bob), fill=lt)
    return outline(im)


def make_monsters():
    for name, fn in (("tiger", tiger), ("bear", bear), ("ogre", ogre), ("skeleton", skeleton), ("zombie", zombie),
                     ("treant_s", treant_small), ("dryad", dryad), ("lizard", lizard), ("mermaid", mermaid),
                     ("vampire", vampire), ("phoenix", phoenix)):
        save(strip([fn(i) for i in range(4)]), "mobs", name + ".png")
    for name, fn in (("wyvern", wyvern), ("dragon", dragon)):
        save(strip([fn(i) for i in range(4)]), "mobs", name + ".png")


# ================================================================ NEW BOSSES (64x64)
def boss_inferno(f):
    im = mk(64, 64); d = ImageDraw.Draw(im)
    bob = [0, -1, 0, -1][f]
    wy = [-16, -6, 5, -6][f]
    rd, dk, lt = C("#b02a1a"), C("#5a1212"), C("#ffb050")
    d.ellipse((6, 54, 58, 63), fill=(0, 0, 0, 70))
    d.polygon([(16, 38 + bob), (0, 52 + bob), (3, 57 + bob), (20, 48 + bob)], fill=dk)
    d.polygon([(0, 52 + bob), (-2, 46 + bob), (7, 51 + bob)], fill=lt)
    d.polygon([(20, 32 + bob), (44, 30 + bob), (40, 4 + bob + wy), (8, 2 + bob + wy)], fill=C("#4a1010"))
    d.polygon([(20, 32 + bob), (40, 30 + bob), (34, 10 + bob + wy), (14, 8 + bob + wy)], fill=C("#8a2218"))
    d.line((20, 32 + bob, 8, 2 + bob + wy), fill=dk, width=3)
    d.ellipse((10, 30 + bob, 50, 54 + bob), fill=rd)
    d.ellipse((16, 40 + bob, 46, 54 + bob), fill=lt)
    for x in (22, 28, 34, 40):
        d.line((x, 42 + bob, x + 2, 52 + bob), fill=C("#d08a3a"))
    d.line((18, 52 + bob, 16, 60), fill=dk, width=4)
    d.line((40, 52 + bob, 42, 60), fill=dk, width=4)
    d.polygon([(44, 38 + bob), (50, 14 + bob), (57, 16 + bob), (52, 40 + bob)], fill=rd)
    d.polygon([(46, 8 + bob), (63, 14 + bob), (60, 26 + bob), (46, 24 + bob)], fill=rd)
    for (x0, x1) in ((46, 42), (52, 52)):
        d.polygon([(x0, 8 + bob), (x1 - 2, 0 + bob), (x0 + 5, 9 + bob)], fill=C("#f0e8d0"))
    d.point((55, 15 + bob), fill=C("#ffe040"))
    d.point((54, 15 + bob), fill=C("#ffe040"))
    R(d, 58, 20 + bob, 62, 22 + bob, C("#ff9a2a"))
    for x in (46, 49, 52, 55):
        d.point((x, 13 + bob), fill=lt)
    for (x, y) in ((24, 36), (34, 34), (30, 46)):
        d.rectangle((x, y + bob, x + 2, y + 1 + bob), fill=C("#ff7a20"))
    return outline(im)


def boss_fungal(f):
    im = mk(64, 64); d = ImageDraw.Draw(im)
    bob = [0, -1, 0, -1][f]
    sw = [0, 2, 0, -2][f]
    d.ellipse((8, 54, 56, 63), fill=(0, 0, 0, 70))
    R(d, 24, 30 + bob, 40, 56 + bob, C("#e8dcc0"))
    R(d, 24, 30 + bob, 28, 56 + bob, C("#cdbf9f"))
    d.polygon([(26, 54), (18 - sw, 62), (30, 60)], fill=C("#cdbf9f"))
    d.polygon([(38, 54), (46 + sw, 62), (34, 60)], fill=C("#cdbf9f"))
    d.ellipse((2, 4 + bob, 62, 40 + bob), fill=C("#7a2ac0"))
    d.ellipse((6, 8 + bob, 58, 36 + bob), fill=C("#9a4ae0"))
    for (x, y, r) in ((14, 18, 4), (26, 10, 5), (40, 12, 4), (50, 22, 4), (32, 24, 3), (18, 28, 3)):
        d.ellipse((x - r, y - r + bob, x + r, y + r + bob), fill=C("#e0c8ff"))
    for ex in (27, 36):
        R(d, ex, 38 + bob, ex + 3, 42 + bob, C("#ffe060"))
        d.point((ex + 1, 40 + bob), fill=EYE)
    R(d, 29, 46 + bob, 36, 48 + bob, C("#3a1a4a"))
    d.line((24, 36 + bob, 8, 46 + bob + sw), fill=C("#e8dcc0"), width=5)
    d.line((40, 36 + bob, 56, 44 + bob - sw), fill=C("#e8dcc0"), width=5)
    for (x, y) in ((8, 46 + sw), (56, 44 - sw)):
        d.ellipse((x - 5, y - 5 + bob, x + 5, y + 5 + bob), fill=C("#9a4ae0"))
    for (x, y) in ((12, 44), (50, 50), (6, 30), (58, 34)):
        d.rectangle((x, y + bob, x + 1, y + 1 + bob), fill=C("#b8f060"))
    return outline(im)


def boss_siren(f):
    im = mk(64, 64); d = ImageDraw.Draw(im)
    bob = [0, -1, 0, -1][f]
    sw = [0, 3, 0, -3][f]
    sk, tl, hr = C("#f0c8aa"), C("#1a8aa8"), C("#2a5ae0")
    d.ellipse((8, 56, 56, 63), fill=(30, 80, 150, 80))
    d.polygon([(22, 32 + bob), (42, 32 + bob), (40, 46 + bob), (34 + sw, 56), (20 + sw, 60), (26 + sw, 50), (24, 44 + bob)], fill=tl)
    d.polygon([(20 + sw, 60), (8 + sw, 54), (10 + sw, 63)], fill=C("#4ad0e8"))
    d.polygon([(34 + sw, 56), (46 + sw, 50), (44 + sw, 62)], fill=C("#4ad0e8"))
    for y in (36, 42, 48):
        d.line((25, y + bob, 40, y + bob), fill=C("#0e6a88"))
    R(d, 24, 18 + bob, 40, 33 + bob, sk)
    R(d, 24, 22 + bob, 40, 26 + bob, C("#e870a8"))
    d.ellipse((24, 4 + bob, 40, 20 + bob), fill=sk)
    d.polygon([(22, 6 + bob), (32, 0 + bob), (42, 6 + bob), (44, 30 + bob), (38, 18 + bob), (26, 18 + bob), (20, 30 + bob)], fill=hr)
    d.polygon([(26, 0 + bob), (28, -2 + bob), (30, 2 + bob), (32, -3 + bob), (34, 2 + bob), (36, -2 + bob), (38, 0 + bob), (36, 6 + bob), (28, 6 + bob)], fill=C("#ffd23a"))
    d.point((29, 12 + bob), fill=EYE)
    d.point((35, 12 + bob), fill=EYE)
    R(d, 29, 16 + bob, 34, 16 + bob, C("#c03a5a"))
    d.line((24, 26 + bob, 12, 22 + bob + sw // 2), fill=sk, width=3)
    d.line((40, 26 + bob, 50, 22 + bob - sw // 2), fill=sk, width=3)
    d.line((54, 4 + bob, 54, 40 + bob), fill=C("#ffd23a"), width=2)
    for x in (50, 54, 58):
        d.line((x, 4 + bob, x, 10 + bob), fill=C("#ffd23a"), width=2)
    d.line((50, 8 + bob, 58, 8 + bob), fill=C("#ffd23a"), width=2)
    return outline(im)


def make_new_bosses():
    for name, fn in (("boss_inferno", boss_inferno), ("boss_fungal", boss_fungal), ("boss_siren", boss_siren)):
        save(strip([fn(i) for i in range(4)]), "mobs", name + ".png")


# ================================================================ SKILL / COMBAT EFFECTS
def fxs(w, h, n, fn, sub, name):
    save(strip([fn(i, w, h, n) for i in range(n)]), sub, name)


def slash_arc(f, w, h, n):
    im = mk(w, h); d = ImageDraw.Draw(im)
    end = -58 + (f + 1) * 24
    a = [255, 255, 240, 170, 80][f]
    d.arc((-14, 2, 44, 46), -58, end, fill=(255, 255, 255, a), width=6)
    d.arc((-10, 6, 40, 42), -58, max(-58, end - 10), fill=(255, 255, 255, a), width=3)
    d.arc((-18, -2, 48, 50), -58 + 6, end - 6, fill=(255, 255, 255, a // 2), width=2)
    return im


def spin_fx(f, w, h, n):
    im = mk(w, h); d = ImageDraw.Draw(im)
    for k in range(4):
        st = f * 55 + k * 90
        d.arc((6, 6, 58, 58), st, st + 50, fill=(255, 255, 255, 230), width=4)
        d.arc((12, 12, 52, 52), st + 20, st + 60, fill=(255, 255, 255, 140), width=2)
    d.ellipse((24, 24, 40, 40), outline=(255, 255, 255, 80), width=1)
    return im


def bash_fx(f, w, h, n):
    im = mk(w, h); d = ImageDraw.Draw(im)
    r = [6, 12, 17, 21, 23][f]
    a = [255, 255, 220, 150, 70][f]
    d.ellipse((24 - r, 24 - r, 24 + r, 24 + r), outline=(255, 255, 255, a), width=3)
    for i in range(8):
        ang = i * math.pi / 4 + 0.2
        r0, r1 = r * 0.4, r * 1.15
        d.line((24 + math.cos(ang) * r0, 24 + math.sin(ang) * r0, 24 + math.cos(ang) * r1, 24 + math.sin(ang) * r1), fill=(255, 255, 255, a), width=2)
    if f < 3:
        d.ellipse((20, 20, 28, 28), fill=(255, 255, 255, 200))
    return im


def light_proj(f, w, h, n):
    im = mk(w, h); d = ImageDraw.Draw(im)
    d.ellipse((9, 9, 23, 23), fill=C("#ffe680", 120))
    d.ellipse((11, 11, 21, 21), fill=C("#fff0a0"))
    d.ellipse((13, 13, 19, 19), fill=WHITE)
    L = [7, 11, 8, 12][f]
    for ang in (0, 90, 180, 270):
        a = math.radians(ang + f * 22)
        d.line((16 + math.cos(a) * 6, 16 + math.sin(a) * 6, 16 + math.cos(a) * (6 + L * 0.6), 16 + math.sin(a) * (6 + L * 0.6)), fill=C("#ffe680"), width=1)
    d.polygon([(2 + f, 16), (10, 13), (10, 19)], fill=C("#ffe680", 150))
    return im


def light_hit(f, w, h, n):
    im = mk(w, h); d = ImageDraw.Draw(im)
    r = [6, 12, 17, 20, 22][f]
    a = [255, 255, 220, 150, 70][f]
    d.ellipse((24 - r, 24 - r, 24 + r, 24 + r), outline=C("#fff0a0", a), width=2)
    d.ellipse((24 - r // 2, 24 - r // 2, 24 + r // 2, 24 + r // 2), fill=C("#fff6c0", a // 2))
    L = 8 + f * 5
    d.line((24, 24 - L, 24, 24 + L), fill=C("#ffffff", a), width=2)
    d.line((24 - L, 24, 24 + L, 24), fill=C("#ffffff", a), width=2)
    return im


def dark_proj(f, w, h, n):
    im = mk(w, h); d = ImageDraw.Draw(im)
    d.ellipse((8, 8, 24, 24), fill=C("#6a2ab0", 150))
    d.ellipse((10, 10, 22, 22), fill=C("#2a1040"))
    d.ellipse((13, 13, 19, 19), fill=C("#0a0412"))
    d.ellipse((10, 10, 22, 22), outline=C("#b070ff"), width=1)
    for k in range(3):
        a = math.radians(f * 40 + k * 120)
        d.line((16, 16, 16 + math.cos(a) * 12, 16 + math.sin(a) * 12), fill=C("#9a4ae0", 190), width=2)
    d.polygon([(2 + f, 16), (9, 13), (9, 19)], fill=C("#6a2ab0", 150))
    return im


def dark_hit(f, w, h, n):
    im = mk(w, h); d = ImageDraw.Draw(im)
    r = [20, 17, 13, 9, 5][f]
    a = [180, 220, 255, 220, 130][f]
    d.ellipse((24 - r, 24 - r, 24 + r, 24 + r), fill=C("#1a0a2a", a), outline=C("#b070ff", a), width=2)
    for k in range(5):
        ang = math.radians(k * 72 + f * 30)
        rr = 8 + f * 3
        d.line((24 + math.cos(ang) * 6, 24 + math.sin(ang) * 6, 24 + math.cos(ang) * (r + 4), 24 + math.sin(ang) * (r + 4)), fill=C("#9a4ae0", a // 2), width=1)
    return im


def aura_fx(f, w, h, n):
    im = mk(w, h); d = ImageDraw.Draw(im)
    a = [180, 220, 240, 220, 160, 90][f]
    d.ellipse((6, 26, 42, 42), outline=(255, 255, 255, a), width=2)
    d.ellipse((12, 29, 36, 39), outline=(255, 255, 255, a // 2), width=1)
    rr = random.Random(f)
    for i in range(7):
        x = 10 + i * 4 + rr.randint(-1, 1)
        y = 36 - ((f * 5 + i * 7) % 30)
        d.rectangle((x, y, x + 1, y + 2), fill=(255, 255, 255, a))
    return im


def zone_fx(f, w, h, n):
    im = mk(w, h); d = ImageDraw.Draw(im)
    d.ellipse((3, 3, 60, 60), fill=(255, 255, 255, 40), outline=(255, 255, 255, 190), width=2)
    d.ellipse((12, 12, 51, 51), outline=(255, 255, 255, 110), width=1)
    for k in range(6):
        a = math.radians(f * 10 + k * 60)
        d.line((32 + math.cos(a) * 14, 32 + math.sin(a) * 14, 32 + math.cos(a) * 24, 32 + math.sin(a) * 24), fill=(255, 255, 255, 200), width=2)
        d.rectangle((32 + math.cos(a + 0.5) * 29, 32 + math.sin(a + 0.5) * 29, 32 + math.cos(a + 0.5) * 29 + 1, 32 + math.sin(a + 0.5) * 29 + 1), fill=(255, 255, 255, 230))
    return im


def heal_fx(f, w, h, n):
    im = mk(w, h); d = ImageDraw.Draw(im)
    a = [255, 255, 230, 190, 130, 60][f]
    for (x, y0) in ((8, 40), (22, 46), (15, 32)):
        y = y0 - f * 6
        d.rectangle((x - 1, y - 4, x + 1, y + 4), fill=C("#7aff9a", a))
        d.rectangle((x - 4, y - 1, x + 4, y + 1), fill=C("#7aff9a", a))
        d.point((x, y), fill=(255, 255, 255, a))
    return im


def arrowrain_fx(f, w, h, n):
    im = mk(w, h); d = ImageDraw.Draw(im)
    rr = random.Random(7)
    pts = [(rr.randint(10, 54), rr.randint(14, 56)) for _ in range(9)]
    for i, (x, y) in enumerate(pts):
        t = (f * 11 + i * 9) % 54
        yy = -6 + t
        if yy < 4:
            continue
        d.line((x - 3, yy - 9, x, yy), fill=C("#d8c090"), width=1)
        d.point((x, yy), fill=C("#e8f0ff"))
        if yy > 40:
            d.ellipse((x - 3, 40 + (i % 4) * 4, x + 3, 44 + (i % 4) * 4), outline=(255, 255, 255, 120))
    return im


def smoke_fx(f, w, h, n):
    im = mk(w, h); d = ImageDraw.Draw(im)
    a = [150, 190, 200, 170, 130, 90][f]
    rr = random.Random(3)
    for i in range(8):
        ang = rr.random() * 6.28
        dist = 8 + f * 2 + rr.randint(0, 14)
        r = 7 + (f % 3) + rr.randint(0, 5)
        x = 32 + math.cos(ang) * dist
        y = 32 + math.sin(ang) * dist * 0.8
        d.ellipse((x - r, y - r, x + r, y + r), fill=(235, 235, 235, a))
    return im


def ice_proj(f, w, h, n):
    im = mk(w, h); d = ImageDraw.Draw(im)
    d.polygon([(30, 16), (14, 11), (4, 16), (14, 21)], fill=C("#9ad8ff"))
    d.polygon([(30, 16), (14, 11), (4, 16)], fill=C("#d8f4ff"))
    d.line((6, 16, 28, 16), fill=WHITE)
    d.polygon([(2, 16), (-1 + f, 12), (2, 14)], fill=C("#9ad8ff", 150))
    for i in range(3):
        d.point((8 + i * 3 + f, 9 + i), fill=C("#d8f4ff"))
    return im


def bullet_proj(f, w, h, n):
    im = mk(w, h); d = ImageDraw.Draw(im)
    d.line((8 - f, 16, 22, 16), fill=C("#ffd860", 150), width=1)
    d.ellipse((20, 14, 25, 18), fill=C("#fff0a0"))
    d.point((22, 16), fill=WHITE)
    return im


def spore_proj(f, w, h, n):
    im = mk(w, h); d = ImageDraw.Draw(im)
    d.ellipse((9, 9, 23, 23), fill=C("#7ac040"))
    d.ellipse((11, 11, 21, 21), fill=C("#b8f060"))
    for k in range(4):
        a = math.radians(f * 30 + k * 90)
        d.rectangle((16 + math.cos(a) * 9, 16 + math.sin(a) * 9, 16 + math.cos(a) * 9 + 1, 16 + math.sin(a) * 9 + 1), fill=C("#e0ff90"))
    d.ellipse((14, 14, 18, 18), fill=WHITE)
    return im


def make_effects():
    S = "spells"
    fxs(48, 48, 5, slash_arc, S, "slash_hit.png")
    fxs(64, 64, 6, spin_fx, S, "spin_hit.png")
    fxs(48, 48, 5, bash_fx, S, "bash_hit.png")
    fxs(32, 32, 4, light_proj, S, "light_proj.png")
    fxs(48, 48, 5, light_hit, S, "light_hit.png")
    fxs(32, 32, 4, dark_proj, S, "dark_proj.png")
    fxs(48, 48, 5, dark_hit, S, "dark_hit.png")
    fxs(48, 48, 6, aura_fx, S, "aura_hit.png")
    fxs(64, 64, 6, zone_fx, S, "zone_hit.png")
    fxs(32, 48, 6, heal_fx, S, "heal_hit.png")
    fxs(64, 64, 6, arrowrain_fx, S, "rain_hit.png")
    fxs(64, 64, 6, smoke_fx, S, "smoke_hit.png")
    fxs(32, 32, 4, ice_proj, S, "ice_proj.png")
    fxs(32, 32, 4, bullet_proj, S, "bullet_proj.png")
    fxs(32, 32, 4, spore_proj, S, "spore_proj.png")
    im = mk(32, 48); d = ImageDraw.Draw(im)
    d.polygon([(16, 0), (8, 20), (24, 20)], fill=C("#ff8a2a", 160))
    d.polygon([(16, 6), (11, 22), (21, 22)], fill=C("#ffd23a", 200))
    d.ellipse((6, 20, 26, 40), fill=C("#6a5a4a"))
    d.ellipse((9, 22, 20, 33), fill=C("#8a7a68"))
    d.ellipse((8, 34, 22, 40), fill=C("#4a3a2e"))
    save(outline(im), S, "meteor.png")
    # element icons for the skill bar / skill tree
    cols = {"light": ("#fff0a0", "#ffd23a"), "dark": ("#7a3ac0", "#2a1040"), "fire": ("#ff8a2a", "#c83a1e"),
            "water": ("#62b4f2", "#2a6ac0"), "earth": ("#b09060", "#6a5a40"), "wind": ("#d8fbff", "#6ac8e0"), "none": ("#d0d0d8", "#7a7a88")}
    for k, (c1, c2) in cols.items():
        im = mk(16, 16); d = ImageDraw.Draw(im)
        d.ellipse((1, 1, 14, 14), fill=C(c2)); d.ellipse((3, 3, 12, 12), fill=C(c1)); d.ellipse((5, 4, 8, 7), fill=WHITE)
        save(outline(im), "items", "elem_" + k + ".png")


# ================================================================ TILES / WORLD
def speck(base, specks, n, seed):
    r = random.Random(seed)
    im = Image.new("RGBA", (16, 16), base)
    px = im.load()
    for _ in range(n):
        px[r.randrange(16), r.randrange(16)] = r.choice(specks)
    return im


def make_tiles():
    from generate_assets import speck_tile
    grass = speck_tile(C("#5aa045"), [C("#4a8f3a"), C("#6bb653"), C("#52973f")], 34, 1)
    grass2 = speck_tile(C("#5aa045"), [C("#4a8f3a"), C("#4a8f3a"), C("#6bb653")], 30, 2)
    px = grass2.load()
    for (x, y) in ((4, 5), (4, 4), (10, 11), (10, 10), (11, 10)):
        px[x, y] = C("#3e7e32")
    forest = speck_tile(C("#3d8040"), [C("#336e36"), C("#4a9248"), C("#2d6430")], 34, 3)
    dirt = speck_tile(C("#8e6a42"), [C("#7a5a38"), C("#a07a4e"), C("#6e5030")], 36, 4)
    sand = speck_tile(C("#e3cf94"), [C("#d2bb7c"), C("#f0e0aa"), C("#ccb272")], 26, 5)
    stone = speck_tile(C("#7b8190"), [C("#6c7282"), C("#8c92a2"), C("#5f6574")], 40, 6)
    d = ImageDraw.Draw(stone)
    d.line((2, 3, 6, 6), fill=C("#555b6a")); d.line((9, 10, 13, 13), fill=C("#555b6a"))
    deep = Image.new("RGBA", (16, 16), (10, 30, 90, 110))
    shore = mk(16, 16)
    r = random.Random(9); sp = shore.load()
    for i in range(16):
        for (x, y) in ((i, 0), (i, 15), (0, i), (15, i)):
            sp[x, y] = (255, 255, 255, 70)
    for _ in range(10):
        sp[r.randrange(16), r.randrange(16)] = (255, 255, 255, 110)
    mush = speck_tile(C("#3e3a5e"), [C("#4a4672"), C("#34304e"), C("#5a5488")], 36, 11)
    mush2 = speck_tile(C("#3e3a5e"), [C("#4a4672"), C("#6a58a0"), C("#34304e")], 30, 12)
    pm = mush2.load()
    for (x, y) in ((3, 4), (11, 9), (7, 13)):
        pm[x, y] = C("#c8a0ff")
    ash = speck_tile(C("#4a4448"), [C("#3c363a"), C("#5a5256"), C("#34302e")], 40, 13)
    pa = ash.load()
    for (x, y) in ((4, 4), (10, 11), (6, 9)):
        pa[x, y] = C("#c0481e")
    lava = Image.new("RGBA", (16, 16), C("#d8451a"))
    dl = ImageDraw.Draw(lava)
    rr = random.Random(21)
    for _ in range(8):
        x, y = rr.randrange(16), rr.randrange(16)
        dl.ellipse((x - 2, y - 1, x + 2, y + 1), fill=C("#ff9a2a"))
    for _ in range(5):
        x, y = rr.randrange(16), rr.randrange(16)
        dl.point((x, y), fill=C("#ffe080"))
    tiles = [grass, grass2, forest, dirt, sand, stone, deep, shore, mush, mush2, ash, lava]
    ts = mk(16 * len(tiles), 16)
    for i, t in enumerate(tiles):
        ts.paste(t, (i * 16, 0))
    save(ts, "tiles", "tileset.png")


def palm():
    im = mk(32, 48); d = ImageDraw.Draw(im)
    d.ellipse((6, 41, 26, 47), fill=(0, 0, 0, 60))
    d.line((16, 44, 14, 24), fill=C("#9a7a4a"), width=3)
    d.line((14, 24, 17, 12), fill=C("#9a7a4a"), width=3)
    for (x1, y1) in ((2, 14), (6, 6), (16, 3), (27, 7), (30, 15), (24, 20), (8, 20)):
        d.line((17, 12, x1, y1), fill=C("#3f9b45"), width=3)
        d.line((17, 12, (17 + x1) // 2, (12 + y1) // 2 - 1), fill=C("#6ac060"), width=1)
    d.ellipse((15, 11, 19, 15), fill=C("#6a4a2a"))
    return outline(im)


def shroom_tree():
    im = mk(32, 48); d = ImageDraw.Draw(im)
    d.ellipse((6, 41, 26, 47), fill=(0, 0, 0, 60))
    d.rectangle((13, 24, 19, 45), fill=C("#e8dcc0"))
    d.rectangle((13, 24, 14, 45), fill=C("#cdbf9f"))
    d.ellipse((1, 4, 31, 30), fill=C("#7a2ac0"))
    d.ellipse((3, 6, 29, 26), fill=C("#9a4ae0"))
    for (x, y, r) in ((9, 14, 3), (19, 9, 3), (23, 18, 2), (13, 20, 2)):
        d.ellipse((x - r, y - r, x + r, y + r), fill=C("#e0c8ff"))
    return outline(im)


def dead_tree():
    im = mk(32, 48); d = ImageDraw.Draw(im)
    d.ellipse((6, 41, 26, 47), fill=(0, 0, 0, 60))
    d.polygon([(13, 45), (15, 20), (17, 20), (19, 45)], fill=C("#3a2a26"))
    for (x1, y1, x2, y2) in ((16, 24, 5, 12), (16, 20, 26, 8), (16, 30, 27, 22), (10, 17, 4, 5), (22, 14, 25, 3)):
        d.line((x1, y1, x2, y2), fill=C("#3a2a26"), width=2)
    d.point((8, 16), fill=C("#c0481e"))
    d.point((24, 12), fill=C("#c0481e"))
    return outline(im)


def herb_bush():
    im = mk(16, 16); d = ImageDraw.Draw(im)
    d.ellipse((2, 11, 14, 15), fill=(0, 0, 0, 50))
    for (x, y, r) in ((5, 9, 4), (10, 9, 4), (8, 6, 4)):
        d.ellipse((x - r, y - r, x + r, y + r), fill=C("#3f9b45"))
    d.ellipse((6, 4, 10, 8), fill=C("#6ac060"))
    for (x, y) in ((4, 7), (11, 8), (8, 4)):
        d.point((x, y), fill=C("#f4a0c0"))
    return outline(im)


def mushroom_patch():
    im = mk(16, 16); d = ImageDraw.Draw(im)
    d.ellipse((2, 11, 14, 15), fill=(0, 0, 0, 50))
    for (x, y, r, c) in ((5, 9, 3, "#d03a3a"), (11, 10, 3, "#e8a0ff"), (8, 6, 3, "#e8c860")):
        d.rectangle((x - 1, y, x, y + 4), fill=C("#f0e8d8"))
        d.ellipse((x - r, y - r + 1, x + r, y + 1), fill=C(c))
        d.point((x - 1, y - 1), fill=WHITE)
    return outline(im)


def make_world():
    save(palm(), "world", "tree_palm.png")
    save(shroom_tree(), "world", "tree_shroom.png")
    save(dead_tree(), "world", "tree_dead.png")
    save(herb_bush(), "world", "herb_bush.png")
    save(mushroom_patch(), "world", "mushroom_patch.png")


# ================================================================ DUNGEON ART
BIOME_PAL = {
    "lava": ("#3a2420", "#4a2a24", "#1c1210", "#ff6a20"),
    "forest": ("#3a5a2c", "#44683a", "#223a1c", "#6ac060"),
    "mushroom": ("#4a3a6a", "#564478", "#2a2040", "#c8a0ff"),
    "plains": ("#6aa04a", "#74ac52", "#2f6a2a", "#a8e060"),
    "beach": ("#e3cf94", "#d8c488", "#4a7a98", "#8ae0f0"),
    "cave": ("#5a5a66", "#64646f", "#2a2a32", "#9aa0c8"),
}
BIOME_ORDER = ["lava", "forest", "mushroom", "plains", "beach", "cave"]


def dungeon_tiles():
    ts = mk(16 * 18, 16)
    for bi, b in enumerate(BIOME_ORDER):
        fa, fb, wl, ac = BIOME_PAL[b]
        for k, base in enumerate((fa, fb)):
            t = speck(C(base), [C(fa), C(fb), C(wl)], 22, bi * 10 + k)
            d = ImageDraw.Draw(t)
            rr = random.Random(bi * 5 + k)
            if b == "lava":
                for _ in range(2):
                    x, y = rr.randrange(2, 12), rr.randrange(2, 12)
                    d.line((x, y, x + 3, y + 2), fill=C(ac))
            elif b == "cave":
                d.line((2, 3, 7, 6), fill=C("#40404a")); d.line((9, 11, 13, 13), fill=C("#40404a"))
            elif b == "mushroom":
                for _ in range(2):
                    d.point((rr.randrange(16), rr.randrange(16)), fill=C(ac))
            elif b == "forest":
                for _ in range(3):
                    d.point((rr.randrange(16), rr.randrange(16)), fill=C(ac))
            ts.paste(t, ((bi * 3 + k) * 16, 0))
        w = speck(C(wl), [C(wl), C(wl), C(fa)], 14, bi + 77)
        d = ImageDraw.Draw(w)
        d.rectangle((0, 0, 15, 2), fill=C(ac, 90))
        d.rectangle((0, 13, 15, 15), fill=(0, 0, 0, 90))
        if b == "lava":
            d.line((3, 6, 8, 9), fill=C(ac)); d.line((10, 5, 12, 11), fill=C(ac))
        if b == "forest":
            for x in (3, 8, 12):
                d.line((x, 3, x, 12), fill=C("#1a2a14"))
        if b == "beach":
            d.ellipse((4, 5, 9, 10), fill=C("#6a9ab8")); d.ellipse((10, 8, 14, 12), fill=C("#c07a8a"))
        if b == "mushroom":
            d.ellipse((3, 5, 8, 9), fill=C("#6a3aa0")); d.ellipse((10, 8, 14, 12), fill=C("#8a52c8"))
        if b == "plains":
            d.ellipse((2, 4, 7, 9), fill=C("#3f9b45")); d.ellipse((9, 7, 14, 12), fill=C("#3f9b45"))
        if b == "cave":
            d.line((2, 7, 7, 10), fill=C("#44444e")); d.line((9, 5, 13, 9), fill=C("#44444e"))
        ts.paste(w, ((bi * 3 + 2) * 16, 0))
    save(ts, "tiles", "dungeon_tiles.png")


def portal(f, col):
    im = mk(32, 32); d = ImageDraw.Draw(im)
    d.ellipse((4, 26, 28, 31), fill=(0, 0, 0, 70))
    d.rectangle((3, 8, 7, 28), fill=C("#6a6f7c")); d.rectangle((25, 8, 29, 28), fill=C("#6a6f7c"))
    d.rectangle((3, 4, 29, 9), fill=C("#7e8492"))
    d.rectangle((3, 4, 29, 5), fill=C("#a4aaba"))
    d.rectangle((7, 9, 25, 28), fill=C("#0a0612"))
    rr = random.Random(f)
    for i in range(3):
        r = 3 + i * 3 + (f % 2)
        d.ellipse((16 - r, 19 - r - i, 16 + r, 19 + r + i), outline=C(col, 220 - i * 50), width=1)
    for _ in range(6):
        d.point((rr.randint(8, 24), rr.randint(10, 27)), fill=C(col))
    d.point((16, 19), fill=WHITE)
    return outline(im)


def exit_stairs(f):
    im = mk(32, 32); d = ImageDraw.Draw(im)
    d.ellipse((4, 26, 28, 31), fill=(0, 0, 0, 70))
    d.rectangle((6, 6, 26, 28), fill=C("#4a4a56"))
    for i in range(4):
        d.rectangle((8, 10 + i * 5, 24, 13 + i * 5), fill=C("#8a8f9c") if i % 2 == 0 else C("#6a6f7c"))
    y = 3 - (f % 2)
    d.polygon([(16, y), (21, y + 5), (11, y + 5)], fill=C("#9be26a"))
    return outline(im)


def chest(gold=False, opened=False):
    im = mk(16, 16); d = ImageDraw.Draw(im)
    wd, dk, tr = (C("#8a5a2a"), C("#5a3a1a"), C("#ffd23a" if gold else "#b0b8c8"))
    d.ellipse((1, 12, 15, 15), fill=(0, 0, 0, 60))
    d.rectangle((2, 7, 13, 13), fill=wd)
    d.rectangle((2, 12, 13, 13), fill=dk)
    d.rectangle((2, 9, 13, 9), fill=tr)
    if opened:
        d.rectangle((2, 2, 13, 5), fill=dk)
        d.rectangle((3, 6, 12, 7), fill=C("#1a1008"))
        if gold:
            d.rectangle((4, 5, 11, 6), fill=C("#ffd23a"))
    else:
        d.rectangle((2, 4, 13, 8), fill=wd)
        d.rectangle((2, 4, 13, 4), fill=C("#a87a42"))
        d.rectangle((2, 7, 13, 7), fill=tr)
        d.rectangle((7, 7, 8, 10), fill=C("#ffe680"))
    return outline(im)


def spikes(f):
    im = mk(16, 16); d = ImageDraw.Draw(im)
    d.rectangle((1, 6, 14, 14), fill=C("#2a2a32"))
    d.rectangle((1, 6, 14, 6), fill=C("#4a4a56"))
    holes = [(3, 8), (8, 8), (12, 8), (5, 11), (10, 11)]
    for (x, y) in holes:
        if f == 0:
            d.point((x, y), fill=C("#0a0a10"))
        elif f == 1:
            d.rectangle((x, y - 1, x, y), fill=C("#c8d0e0"))
        else:
            d.polygon([(x - 1, y + 1), (x, y - 5), (x + 1, y + 1)], fill=C("#e0e6f0"))
            d.point((x, y - 5), fill=WHITE)
    if f == 1:
        d.rectangle((1, 6, 14, 14), outline=C("#ff6a3a"))
    return outline(im)


def dart_trap():
    im = mk(16, 16); d = ImageDraw.Draw(im)
    d.rectangle((1, 2, 15, 14), fill=C("#5a5a66"))
    d.rectangle((1, 2, 15, 3), fill=C("#7a7a88"))
    d.rectangle((8, 6, 15, 10), fill=C("#1a1a22"))
    d.rectangle((9, 7, 15, 9), fill=C("#3a3a46"))
    d.point((3, 5), fill=C("#c03030")); d.point((3, 11), fill=C("#c03030"))
    return outline(im)


def make_dungeon():
    dungeon_tiles()
    cols = {"lava": "#ff6a20", "forest": "#6ac060", "mushroom": "#c8a0ff", "plains": "#fff0a0", "beach": "#6ae0f0", "cave": "#8aa8ff"}
    for b in BIOME_ORDER:
        save(strip([portal(i, cols[b]) for i in range(4)]), "world", "portal_" + b + ".png")
    save(strip([exit_stairs(i) for i in range(2)]), "world", "dungeon_exit.png")
    save(strip([chest(False, False), chest(False, True)]), "world", "chest.png")
    save(strip([chest(True, False), chest(True, True)]), "world", "chest_gold.png")
    save(strip([spikes(i) for i in range(3)]), "world", "spikes.png")
    save(dart_trap(), "world", "dart_trap.png")


# ================================================================ ITEM ICONS
def dagger():
    im = mk(16, 32); d = ImageDraw.Draw(im)
    d.polygon([(8, 10), (11, 14), (11, 21), (5, 21), (5, 14)], fill=C("#c8d0e0"))
    d.rectangle((7, 10, 8, 20), fill=C("#eef2ff"))
    d.rectangle((3, 22, 12, 23), fill=C("#6a4a8a"))
    d.rectangle((7, 24, 8, 28), fill=C("#3a2a4a"))
    d.rectangle((6, 29, 9, 30), fill=C("#6a4a8a"))
    return outline(im)


def grimoire():
    im = mk(16, 32); d = ImageDraw.Draw(im)
    d.rectangle((3, 8, 13, 26), fill=C("#5a2a7a"))
    d.rectangle((3, 8, 5, 26), fill=C("#3a1a52"))
    d.rectangle((13, 9, 13, 25), fill=C("#f4f0e0"))
    d.ellipse((6, 13, 12, 19), fill=C("#ffd23a"))
    d.ellipse((8, 15, 10, 17), fill=C("#5a2a7a"))
    for (x, y) in ((4, 10), (12, 10), (4, 24), (12, 24)):
        d.point((x, y), fill=C("#ffd23a"))
    return outline(im)


def gun():
    im = mk(16, 32); d = ImageDraw.Draw(im)
    d.rectangle((6, 4, 9, 22), fill=C("#5a6070"))
    d.rectangle((6, 4, 7, 22), fill=C("#8a90a0"))
    d.rectangle((5, 20, 10, 24), fill=C("#3a3f4a"))
    d.polygon([(6, 24), (10, 24), (11, 30), (7, 30)], fill=C("#6b4423"))
    d.rectangle((7, 3, 8, 5), fill=C("#c8d0e0"))
    d.point((12, 22), fill=C("#ffd23a"))
    return outline(im)


def armor16(kind):
    im = mk(16, 16); d = ImageDraw.Draw(im)
    if kind == "heavy":
        d.polygon([(2, 2), (6, 3), (10, 3), (14, 2), (15, 7), (13, 8), (13, 14), (3, 14), (3, 8), (1, 7)], fill=C("#a4aaba"))
        d.rectangle((5, 5, 10, 13), fill=C("#7a8296")); d.rectangle((7, 6, 8, 11), fill=C("#c43434"))
        d.rectangle((2, 3, 4, 4), fill=C("#d0d6e4")); d.rectangle((11, 3, 13, 4), fill=C("#d0d6e4"))
    elif kind == "light":
        d.polygon([(3, 2), (6, 4), (10, 4), (13, 2), (14, 7), (12, 8), (12, 14), (4, 14), (4, 8), (2, 7)], fill=C("#7a9ab8"))
        d.rectangle((5, 6, 10, 13), fill=C("#5a7a98")); d.line((5, 9, 10, 9), fill=C("#a8c8e0"))
    elif kind == "leather":
        d.polygon([(3, 2), (6, 4), (10, 4), (13, 2), (14, 7), (12, 8), (12, 14), (4, 14), (4, 8), (2, 7)], fill=C("#a8764a"))
        d.rectangle((5, 6, 10, 13), fill=C("#8a5a34")); d.line((8, 5, 8, 13), fill=C("#5a3a1a"))
        d.point((6, 8), fill=C("#d8b27a")); d.point((10, 8), fill=C("#d8b27a"))
    else:
        d.polygon([(8, 1), (12, 3), (13, 14), (3, 14), (4, 3)], fill=C("#4a5ad8"))
        d.rectangle((7, 4, 8, 14), fill=C("#323c96")); d.rectangle((3, 9, 13, 9), fill=C("#ffd84a"))
        d.polygon([(6, 1), (8, 5), (10, 1)], fill=C("#e0e0f0"))
    return outline(im)


def necklace():
    im = mk(16, 16); d = ImageDraw.Draw(im)
    d.arc((2, 0, 13, 12), 10, 170, fill=C("#d8c080"), width=1)
    d.polygon([(8, 8), (11, 11), (8, 15), (5, 11)], fill=C("#e84a6a"))
    d.polygon([(8, 8), (11, 11), (8, 11)], fill=C("#ff9aa8"))
    return outline(im)


def ring():
    im = mk(16, 16); d = ImageDraw.Draw(im)
    d.ellipse((3, 5, 12, 14), outline=C("#ffd23a"), width=2)
    d.polygon([(8, 1), (11, 4), (8, 7), (5, 4)], fill=C("#62b4f2"))
    d.point((7, 3), fill=WHITE)
    return outline(im)


def bracelet():
    im = mk(16, 16); d = ImageDraw.Draw(im)
    d.ellipse((2, 3, 13, 13), outline=C("#b0b8c8"), width=2)
    d.ellipse((6, 2, 10, 6), fill=C("#9be26a"))
    d.point((7, 3), fill=WHITE)
    return outline(im)


def potion(c_liq, c_hi, size):
    im = mk(16, 16); d = ImageDraw.Draw(im)
    d.rectangle((6, 1, 9, 3), fill=C("#c8a070"))
    d.rectangle((7, 3, 8, 5), fill=C("#d8f0ff"))
    if size == 1:
        d.polygon([(7, 5), (8, 5), (11, 11), (10, 14), (5, 14), (4, 11)], fill=C("#d8f0ff"))
        d.polygon([(5, 11), (10, 11), (10, 13), (5, 13)], fill=c_liq)
    elif size == 2:
        d.ellipse((3, 5, 12, 14), fill=C("#d8f0ff"))
        d.ellipse((4, 8, 11, 14), fill=c_liq)
    else:
        d.ellipse((2, 4, 13, 15), fill=C("#d8f0ff"))
        d.ellipse((3, 6, 12, 15), fill=c_liq)
        d.rectangle((6, 0, 9, 1), fill=C("#ffd23a"))
    d.point((5, 9), fill=c_hi)
    d.point((6, 8), fill=c_hi)
    return outline(im)


def bowl(c_soup, c_hi):
    im = mk(16, 16); d = ImageDraw.Draw(im)
    d.ellipse((1, 6, 14, 14), fill=C("#8a6238"))
    d.ellipse((2, 6, 13, 10), fill=c_soup)
    d.ellipse((4, 7, 8, 9), fill=c_hi)
    for x in (5, 8, 11):
        d.point((x, 4 - (x % 3)), fill=C("#ffffff", 140))
    return outline(im)


def herb():
    im = mk(16, 16); d = ImageDraw.Draw(im)
    for (x, y, ang) in ((8, 14, 0), (8, 14, -35), (8, 14, 35)):
        a = math.radians(ang - 90)
        ex, ey = 8 + math.cos(a) * 9, 14 + math.sin(a) * 9
        d.line((8, 14, ex, ey), fill=C("#3f9b45"), width=1)
        d.ellipse((ex - 2, ey - 2, ex + 2, ey + 2), fill=C("#6ac060"))
    d.point((8, 4), fill=C("#c8f0a0"))
    return outline(im)


def mushroom_icon():
    im = mk(16, 16); d = ImageDraw.Draw(im)
    d.rectangle((7, 8, 9, 14), fill=C("#f0e8d8"))
    d.ellipse((2, 2, 13, 10), fill=C("#d03a3a"))
    for (x, y) in ((5, 5), (9, 4), (11, 7)):
        d.point((x, y), fill=WHITE)
    return outline(im)


def loot(shape, c1, c2="#ffffff"):
    im = mk(16, 16); d = ImageDraw.Draw(im)
    a, b = C(c1), C(c2)
    if shape == "fang":
        d.polygon([(4, 2), (12, 2), (9, 14), (7, 14)], fill=a); d.polygon([(9, 2), (12, 2), (9, 14)], fill=b)
    elif shape == "claw":
        d.polygon([(3, 2), (7, 2), (13, 10), (11, 14), (9, 9), (5, 5)], fill=a); d.polygon([(7, 2), (10, 6), (7, 4)], fill=b)
    elif shape == "pelt":
        d.polygon([(2, 4), (8, 2), (14, 4), (13, 12), (8, 14), (3, 11)], fill=a)
        for (x, y) in ((5, 6), (9, 8), (7, 11), (11, 5)):
            d.point((x, y), fill=b)
    elif shape == "ear":
        d.polygon([(3, 13), (6, 2), (13, 10), (9, 14)], fill=a); d.polygon([(6, 6), (11, 10), (8, 12)], fill=b)
    elif shape == "tooth":
        d.rectangle((5, 2, 11, 9), fill=a); d.polygon([(5, 9), (11, 9), (8, 14)], fill=a); d.rectangle((6, 3, 7, 8), fill=b)
    elif shape == "bone":
        d.line((4, 12, 12, 4), fill=a, width=3)
        for (x, y) in ((3, 11), (5, 13), (11, 3), (13, 5)):
            d.ellipse((x - 1, y - 1, x + 2, y + 2), fill=a)
    elif shape == "flesh":
        d.ellipse((2, 4, 13, 13), fill=a)
        for (x, y) in ((5, 7), (9, 9), (7, 11)):
            d.rectangle((x, y, x + 1, y + 1), fill=b)
    elif shape == "bark":
        d.polygon([(3, 3), (13, 2), (14, 12), (4, 14)], fill=a)
        for x in (5, 8, 11):
            d.line((x, 3, x, 13), fill=b)
    elif shape == "petal":
        for ang in (0, 72, 144, 216, 288):
            r = math.radians(ang)
            d.ellipse((8 + math.cos(r) * 3 - 2, 8 + math.sin(r) * 3 - 2, 8 + math.cos(r) * 3 + 2, 8 + math.sin(r) * 3 + 2), fill=a)
        d.ellipse((6, 6, 10, 10), fill=b)
    elif shape == "scale":
        d.polygon([(8, 1), (14, 5), (14, 11), (8, 15), (2, 11), (2, 5)], fill=a)
        d.polygon([(8, 4), (11, 6), (11, 10), (8, 12), (5, 10), (5, 6)], fill=b)
    elif shape == "pearl":
        d.ellipse((3, 3, 13, 13), fill=a); d.ellipse((5, 5, 8, 8), fill=b)
    elif shape == "vial":
        d.rectangle((6, 1, 9, 4), fill=C("#c8a070")); d.polygon([(6, 4), (9, 4), (12, 9), (10, 14), (5, 14), (3, 9)], fill=C("#d8f0ff"))
        d.polygon([(4, 9), (11, 9), (10, 13), (5, 13)], fill=a)
    elif shape == "wing":
        d.polygon([(2, 13), (3, 3), (7, 6), (10, 2), (12, 7), (14, 5), (13, 13)], fill=a)
        d.line((3, 13, 3, 3), fill=b); d.line((3, 13, 10, 2), fill=b)
    elif shape == "feather":
        d.polygon([(3, 14), (6, 4), (12, 1), (13, 3), (10, 11)], fill=a)
        d.line((3, 14, 12, 2), fill=b)
        d.polygon([(8, 6), (12, 4), (10, 9)], fill=C("#ffd23a"))
    elif shape == "core":
        d.ellipse((2, 2, 13, 13), fill=C("#575c6a")); d.ellipse((4, 4, 11, 11), fill=a); d.ellipse((6, 6, 9, 9), fill=b)
    return outline(im)


LOOT = {
    "wolf_fang": ("fang", "#e8e4d8", "#b8b4a8"), "tiger_claw": ("claw", "#f0e8d0", "#ffffff"),
    "bear_pelt": ("pelt", "#6a4a2e", "#a8845a"), "goblin_ear": ("ear", "#6aa84a", "#c8d890"),
    "ogre_tooth": ("tooth", "#d8c8a0", "#f4f0e0"), "bone": ("bone", "#ece6d4", "#9a9484"),
    "rotten_flesh": ("flesh", "#7a9a6a", "#4a5e3a"), "bark": ("bark", "#7a5230", "#54361e"),
    "petal": ("petal", "#f4a0c0", "#ffe060"), "lizard_scale": ("scale", "#5a9a4a", "#9bd070"),
    "mermaid_pearl": ("pearl", "#dff4ff", "#ffffff"), "blood_vial": ("vial", "#b01830", "#ffffff"),
    "wyvern_wing": ("wing", "#6a3a7a", "#9a6ab0"), "dragon_scale": ("scale", "#c03a2a", "#ffb050"),
    "phoenix_feather": ("feather", "#ff8a2a", "#ffd23a"), "ember_core": ("core", "#ff7a20", "#ffe080"),
    "spore_core": ("core", "#9a4ae0", "#e0c8ff"), "siren_pearl": ("pearl", "#4ad0e8", "#ffffff"),
}


def make_items():
    I = "items"
    save(blade(C("#c8d0e0"), C("#eef2ff"), 4, C("#d8a93a")), I, "gear_sword.png")
    save(spear(), I, "gear_spear.png")
    save(hammer(), I, "gear_hammer.png")
    save(dagger(), I, "gear_dagger.png")
    save(wand(), I, "gear_wand.png")
    save(grimoire(), I, "gear_grimoire.png")
    save(bow(), I, "gear_bow.png")
    save(gun(), I, "gear_gun.png")
    for k in ("heavy", "light", "leather", "robe"):
        save(armor16(k), I, "gear_" + k + ".png")
    save(necklace(), I, "gear_necklace.png")
    save(ring(), I, "gear_ring.png")
    save(bracelet(), I, "gear_bracelet.png")
    for n in (1, 2, 3):
        save(potion(C("#e84a6a"), C("#ffd0d8"), n), I, "potion_hp_%d.png" % n)
        save(potion(C("#3a8ee0"), C("#d0eaff"), n), I, "potion_mp_%d.png" % n)
    save(bowl(C("#c8782a"), C("#e8a860")), I, "stew.png")
    save(bowl(C("#8a60c0"), C("#c8a0f0")), I, "mushroom_soup.png")
    save(herb(), I, "herb.png")
    save(mushroom_icon(), I, "mushroom.png")
    for k, (shape, c1, c2) in LOOT.items():
        save(loot(shape, c1, c2), I, k + ".png")


def make_all():
    make_monsters()
    make_new_bosses()
    make_effects()
    make_tiles()
    make_world()
    make_dungeon()
    make_items()


if __name__ == "__main__":
    make_all()
