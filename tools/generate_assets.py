#!/usr/bin/env python3
"""Generates every pixel-art asset for Ashen Wilds (requires Pillow).
Run:  python3 tools/generate_assets.py
All sprites are drawn procedurally, so you can edit colours/shapes and regenerate,
or replace any PNG with your own art (keep the same file name and frame layout)."""
import os, math, random
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
A = os.path.join(ROOT, "assets")
OUTL = (28, 20, 34, 255)


def C(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


def mk(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def save(img, sub, name):
    d = os.path.join(A, sub)
    os.makedirs(d, exist_ok=True)
    img.save(os.path.join(d, name))


def outline(img, col=OUTL):
    w, h = img.size
    src = img.load()
    out = img.copy()
    o = out.load()
    for y in range(h):
        for x in range(w):
            if src[x, y][3] < 128:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h and src[nx, ny][3] > 200:
                        o[x, y] = col
                        break
    return out


def strip(frames):
    w, h = frames[0].size
    s = mk(w * len(frames), h)
    for i, f in enumerate(frames):
        s.paste(f, (i * w, 0))
    return s


# ---------------------------------------------------------------- CHARACTERS
DIRS = ["down", "up", "side"]
ANIMS = [("idle", 2), ("walk", 4), ("run", 4), ("attack", 4), ("cast", 4)]
PAL = {
    "knight": dict(skin=C("#f0c4a0"), hair=C("#5a3a26"), main=C("#c43434"), dark=C("#8c1e28"),
                   pants=C("#464660"), boots=C("#3c281e"), metal=C("#b0b8c8"), sleeve=C("#c43434")),
    "ranger": dict(skin=C("#ebbe96"), hair=C("#2e6e3c"), main=C("#468c50"), dark=C("#285a32"),
                   pants=C("#6e5032"), boots=C("#463220"), metal=C("#8a6a3a"), sleeve=C("#468c50")),
    "mage": dict(skin=C("#f0c8aa"), hair=C("#ddddf0"), main=C("#5064dc"), dark=C("#323c96"),
                 pants=C("#323c96"), boots=C("#322850"), metal=C("#ffd84a"), sleeve=C("#5064dc")),
}
PAL["warrior"] = dict(PAL["knight"])
PAL["assassin"] = dict(skin=C("#e0b896"), hair=C("#3a2a4a"), main=C("#4a3a5a"), dark=C("#2a2038"),
                       pants=C("#2a2a38"), boots=C("#1e1a28"), metal=C("#9a8ab0"), sleeve=C("#4a3a5a"))
PAL["priest"] = dict(skin=C("#f0c8aa"), hair=C("#e8c860"), main=C("#f0eef8"), dark=C("#bdb4dc"),
                     pants=C("#bdb4dc"), boots=C("#6a5a90"), metal=C("#ffd84a"), sleeve=C("#f0eef8"))
PAL["merchant"] = dict(skin=C("#e8b890"), hair=C("#6a3a20"), main=C("#3c8c5a"), dark=C("#28603c"),
                       pants=C("#6e4a2a"), boots=C("#3c281e"), metal=C("#ffd84a"), sleeve=C("#3c8c5a"))
PAL["smith"] = dict(skin=C("#d8a07a"), hair=C("#2a1a12"), main=C("#8a6a4a"), dark=C("#5e4630"),
                    pants=C("#3a3a44"), boots=C("#2a2a30"), metal=C("#9aa0b0"), sleeve=C("#d8a07a"))
EYE = C("#1e1828")


def R(d, x0, y0, x1, y1, c):
    d.rectangle((x0, y0, x1, y1), fill=c)


def arm(d, sx, sy, hx, hy, col, skin):
    d.line((sx, sy, hx, hy), fill=col, width=2)
    d.rectangle((hx, hy, hx + 1, hy + 1), fill=skin)


def draw_char(st, di, anim, f):
    P = PAL[st]
    img = mk(32, 32)
    d = ImageDraw.Draw(img)
    d.ellipse((9, 26, 22, 30), fill=(0, 0, 0, 70))
    if anim == "idle":
        bob, sw = [0, 1][f], 0
    elif anim in ("walk", "run"):
        amp = 3 if anim == "run" else 2
        bob = [0, -1, 0, -1][f] * (2 if anim == "run" else 1)
        sw = [0, 1, 0, -1][f] * amp
    else:
        bob, sw = [0, -1, -1, 0][f], 0
    mage = st in ("mage", "priest")
    knight = st in ("knight", "warrior")
    ranger = st in ("ranger", "assassin")
    side = DIRS[di] == "side"
    back = DIRS[di] == "up"

    # pose tables ------------------------------------------------------
    if side:
        if anim == "attack":
            fh = [(11, 13), (12, 9), (25, 17), (22, 19)][f]
            bh = (14, 21)
        elif anim == "cast":
            fh = [(19, 17), (22, 15), (25, 14), (23, 15)][f]
            bh = [(18, 18), (20, 16), (23, 15), (21, 16)][f]
        else:
            fh, bh = (16 + sw, 21 + bob), (16 - sw, 21 + bob)
        # back arm
        arm(d, 16, 16 + bob, bh[0], bh[1], P["dark"], P["skin"])
        # legs
        if not mage:
            R(d, 14 - sw, 22, 16 - sw, 27 - (1 if sw > 0 else 0), P["pants"])
            R(d, 14 - sw, 26, 16 - sw, 27, P["boots"])
            R(d, 15 + sw, 22, 17 + sw, 27 - (1 if sw < 0 else 0), P["pants"])
            R(d, 15 + sw, 26, 17 + sw, 27, P["boots"])
        else:
            R(d, 13 - sw, 25, 15 - sw, 27, P["boots"])
            R(d, 16 + sw, 25, 18 + sw, 27, P["boots"])
        # torso
        if mage:
            R(d, 11, 14 + bob, 20, 24, P["main"])
            R(d, 11, 24, 20, 24, P["dark"])
            R(d, 11, 20 + bob, 20, 20 + bob, P["metal"])
        else:
            R(d, 12, 14 + bob, 19, 21 + bob, P["main"])
            R(d, 12, 20 + bob, 19, 20 + bob, P["dark"])
            if knight:
                R(d, 14, 15 + bob, 18, 18 + bob, P["metal"])
            if ranger:
                R(d, 11, 14 + bob, 13, 22 + bob, P["dark"])
        # head
        R(d, 11, 5 + bob, 20, 13 + bob, P["skin"])
        d.point((17, 10 + bob), fill=EYE)
        d.point((18, 10 + bob), fill=EYE)
        R(d, 11, 4 + bob, 20, 7 + bob, P["hair"])
        R(d, 11, 7 + bob, 14, 11 + bob, P["hair"])
        if knight:
            R(d, 10, 3 + bob, 21, 7 + bob, P["metal"])
            R(d, 10, 7 + bob, 13, 10 + bob, P["metal"])
            R(d, 12, 0 + bob, 13, 3 + bob, C("#d03030"))
        if ranger:
            R(d, 10, 3 + bob, 21, 7 + bob, P["hair"])
            R(d, 10, 7 + bob, 14, 13 + bob, P["hair"])
        if st == "mage":
            R(d, 9, 6 + bob, 22, 7 + bob, P["dark"])
            d.polygon([(11, 6 + bob), (20, 6 + bob), (14, 0)], fill=P["main"])
            d.point((14, 3), fill=P["metal"])
        arm(d, 16, 16 + bob, fh[0], fh[1], P["sleeve"], P["skin"])
    else:
        if anim == "attack":
            rh = [(24, 12), (23, 8), (18, 21), (21, 19)][f]
            lh = (9, 21)
        elif anim == "cast":
            lh = [(13, 19), (11, 13), (10, 8), (12, 11)][f]
            rh = (31 - lh[0], lh[1])
        else:
            lh, rh = (9, 21 + bob + sw), (22, 21 + bob - sw)
        ll, rl = max(0, sw), max(0, -sw)
        if not mage:
            R(d, 12, 22, 14, 27 - ll, P["pants"])
            R(d, 12, 26 - ll, 14, 27 - ll, P["boots"])
            R(d, 17, 22, 19, 27 - rl, P["pants"])
            R(d, 17, 26 - rl, 19, 27 - rl, P["boots"])
        else:
            R(d, 12, 26 - ll, 14, 27 - ll, P["boots"])
            R(d, 17, 26 - rl, 19, 27 - rl, P["boots"])
        if mage:
            R(d, 10, 14 + bob, 21, 24, P["main"])
            R(d, 10, 24, 21, 24, P["dark"])
            R(d, 10, 20 + bob, 21, 20 + bob, P["metal"])
        else:
            R(d, 11, 14 + bob, 20, 21 + bob, P["main"])
            R(d, 11, 20 + bob, 20, 20 + bob, P["dark"])
            if knight and not back:
                R(d, 13, 15 + bob, 18, 18 + bob, P["metal"])
        if ranger and back:
            R(d, 11, 14 + bob, 20, 24, P["dark"])
        arm(d, 10, 16 + bob, lh[0], lh[1], P["sleeve"], P["skin"])
        arm(d, 21, 16 + bob, rh[0], rh[1], P["sleeve"], P["skin"])
        # head
        R(d, 11, 5 + bob, 20, 13 + bob, P["skin"])
        if back:
            R(d, 11, 4 + bob, 20, 12 + bob, P["hair"])
        else:
            d.point((13, 10 + bob), fill=EYE)
            d.point((18, 10 + bob), fill=EYE)
            R(d, 11, 4 + bob, 20, 7 + bob, P["hair"])
            R(d, 11, 7 + bob, 12, 9 + bob, P["hair"])
            R(d, 19, 7 + bob, 20, 9 + bob, P["hair"])
        if knight:
            R(d, 10, 3 + bob, 21, 7 + bob, P["metal"])
            if back:
                R(d, 10, 7 + bob, 21, 12 + bob, P["metal"])
            R(d, 15, 0 + bob, 16, 3 + bob, C("#d03030"))
        if ranger:
            R(d, 10, 3 + bob, 21, 7 + bob, P["hair"])
            R(d, 10, 7 + bob, 11, 13 + bob, P["hair"])
            R(d, 20, 7 + bob, 21, 13 + bob, P["hair"])
            if back:
                R(d, 10, 7 + bob, 21, 13 + bob, P["hair"])
        if st == "mage":
            R(d, 9, 6 + bob, 22, 7 + bob, P["dark"])
            d.polygon([(11, 6 + bob), (20, 6 + bob), (15, 0)], fill=P["main"])
            d.point((15, 3), fill=P["metal"])
    if st == "assassin" and not back:
        if side:
            R(d, 15, 11 + bob, 20, 13 + bob, C("#2a2030"))
        else:
            R(d, 12, 11 + bob, 19, 13 + bob, C("#2a2030"))
    if st == "priest":
        if side:
            R(d, 11, 4 + bob, 20, 4 + bob, P["metal"])
        else:
            R(d, 11, 4 + bob, 20, 5 + bob, P["metal"])
            d.point((15, 2 + bob), fill=C("#fff6b0"))
            d.point((16, 2 + bob), fill=C("#fff6b0"))
    if st == "warrior":
        if side:
            R(d, 10, 17, 14, 25, C("#8a8f9c"))
            R(d, 11, 18, 13, 24, C("#c43434"))
        else:
            R(d, 3, 17, 9, 26, C("#8a8f9c"))
            R(d, 4, 18, 8, 25, C("#c43434"))
            d.point((6, 21), fill=C("#ffd23a"))
    if st == "merchant":
        R(d, 10, 3 + bob, 21, 6 + bob, C("#c8782a"))
        R(d, 8, 6 + bob, 23, 6 + bob, C("#a85e1c"))
    if st == "smith" and not back:
        if side:
            R(d, 15, 16 + bob, 19, 23, C("#4a4a54"))
        else:
            R(d, 13, 16 + bob, 18, 23, C("#4a4a54"))
    return outline(img)


def make_characters():
    for st in PAL:
        sheet = mk(128, 32 * 3 * len(ANIMS))
        row = 0
        for anim, n in ANIMS:
            for di in range(3):
                for f in range(n):
                    sheet.paste(draw_char(st, di, anim, f), (f * 32, row * 32))
                row += 1
        save(sheet, "characters", st + ".png")


# ---------------------------------------------------------------- MOBS
def slime(f):
    im = mk(32, 32)
    d = ImageDraw.Draw(im)
    sq = [0, 2, 0, -2][f]
    w, h = 18 + sq * 2, 12 - sq
    d.ellipse((9, 28, 23, 30), fill=(0, 0, 0, 70))
    d.ellipse((16 - w // 2, 28 - h, 16 + w // 2, 28), fill=C("#60c860"))
    d.ellipse((16 - w // 2 + 2, 28 - h + 2, 16 + w // 2 - 3, 28 - h // 2), fill=C("#7edc78"))
    d.ellipse((12, 28 - h + 2, 15, 28 - h + 4), fill=C("#c8f8c0"))
    ey = 28 - h // 2 - 1
    for ex in (12, 18):
        d.rectangle((ex, ey, ex + 1, ey + 2), fill=EYE)
    return outline(im)


def goblin(f):
    im = mk(32, 32)
    d = ImageDraw.Draw(im)
    bob = [0, -1, 0, -1][f]
    sw = [0, 2, 0, -2][f]
    d.ellipse((9, 26, 22, 30), fill=(0, 0, 0, 70))
    sk, dk = C("#6aa84a"), C("#4a7c34")
    R(d, 13 - sw, 23, 15 - sw, 27, dk)
    R(d, 17 + sw, 23, 19 + sw, 27, sk)
    R(d, 13, 15 + bob, 20, 23 + bob, C("#78502e"))
    R(d, 13, 21 + bob, 20, 22 + bob, C("#4a3220"))
    R(d, 13, 6 + bob, 21, 14 + bob, sk)
    d.polygon([(13, 8 + bob), (8, 6 + bob), (13, 11 + bob)], fill=sk)
    d.polygon([(21, 8 + bob), (25, 5 + bob), (21, 11 + bob)], fill=sk)
    d.point((19, 9 + bob), fill=C("#e03030"))
    d.point((16, 9 + bob), fill=C("#e03030"))
    R(d, 17, 12 + bob, 20, 12 + bob, C("#f0f0d0"))
    d.line((19, 17 + bob, 24, 15 + bob + sw // 2), fill=sk, width=2)
    R(d, 23, 9 + bob + sw // 2, 25, 18 + bob + sw // 2, C("#7a5230"))
    R(d, 22, 9 + bob + sw // 2, 26, 11 + bob + sw // 2, C("#5a3a20"))
    return outline(im)


def wolf(f):
    im = mk(32, 32)
    d = ImageDraw.Draw(im)
    sw = [0, 2, 0, -2][f]
    bob = [0, -1, 0, -1][f]
    g, dk, lt = C("#787d8c"), C("#505564"), C("#aaaec0")
    d.ellipse((6, 26, 26, 30), fill=(0, 0, 0, 70))
    for i, x in enumerate((9, 12, 19, 22)):
        off = sw if i % 2 == 0 else -sw
        d.line((x, 22, x + off, 27), fill=dk if i in (0, 2) else g, width=2)
    d.polygon([(8, 16 + bob), (1, 12 + bob + sw // 2), (3, 18 + bob), (8, 20 + bob)], fill=g)
    d.ellipse((6, 13 + bob, 24, 24 + bob), fill=g)
    d.ellipse((9, 20 + bob, 21, 24 + bob), fill=lt)
    d.ellipse((21, 11 + bob, 30, 20 + bob), fill=g)
    R(d, 28, 15 + bob, 31, 18 + bob, dk)
    d.point((31, 15 + bob), fill=(0, 0, 0, 255))
    d.polygon([(22, 12 + bob), (24, 7 + bob), (26, 12 + bob)], fill=dk)
    d.point((26, 14 + bob), fill=C("#ffd040"))
    return outline(im)


def deer(f):
    im = mk(32, 32)
    d = ImageDraw.Draw(im)
    sw = [0, 3, 0, -3][f]
    bob = [0, -1, 0, -1][f]
    br, dk, lt = C("#a06a3a"), C("#74482a"), C("#e8d8b0")
    d.ellipse((6, 26, 26, 30), fill=(0, 0, 0, 70))
    for i, x in enumerate((9, 11, 19, 21)):
        off = sw if i % 2 == 0 else -sw
        d.line((x, 21, x + off, 28), fill=dk if i in (0, 2) else br, width=2)
    d.ellipse((7, 11 + bob, 23, 22 + bob), fill=br)
    d.ellipse((9, 18 + bob, 21, 22 + bob), fill=lt)
    for (sx, sy) in ((11, 14), (15, 13), (18, 16), (13, 17)):
        d.point((sx, sy + bob), fill=lt)
    d.polygon([(20, 14 + bob), (24, 6 + bob), (27, 8 + bob), (23, 16 + bob)], fill=br)
    R(d, 24, 4 + bob, 29, 8 + bob, br)
    R(d, 28, 6 + bob, 30, 8 + bob, dk)
    d.point((26, 5 + bob), fill=EYE)
    for pts in (((25, 4), (24, 0)), ((24, 2), (22, 1)), ((27, 4), (28, 0)), ((28, 2), (30, 1))):
        d.line((pts[0][0], pts[0][1] + bob, pts[1][0], pts[1][1] + bob), fill=C("#e0d0a0"), width=1)
    R(d, 5, 13 + bob, 7, 15 + bob, lt)
    return outline(im)


def make_mobs():
    for name, fn in (("slime", slime), ("goblin", goblin), ("wolf", wolf), ("deer", deer)):
        save(strip([fn(i) for i in range(4)]), "mobs", name + ".png")


# ---------------------------------------------------------------- SPELLS
def fire_proj(f):
    im = mk(32, 32)
    d = ImageDraw.Draw(im)
    tip = [0, 3, 1, 4][f]
    d.polygon([(tip, 16), (14, 8), (14, 24)], fill=C("#e8452a"))
    d.polygon([(5 + tip // 2, 16), (15, 11), (15, 21)], fill=C("#ff8a2a"))
    d.ellipse((13, 8, 28, 24), fill=C("#ff8a2a"))
    d.ellipse((15, 10, 27, 22), fill=C("#ffd23a"))
    d.ellipse((19, 13, 26, 19), fill=C("#fff6b0"))
    r = random.Random(f)
    for _ in range(4):
        d.point((r.randint(2, 12), r.randint(10, 22)), fill=C("#ffd23a"))
    return im


def fire_hit(f):
    im = mk(48, 48)
    d = ImageDraw.Draw(im)
    r = [8, 15, 20, 23, 24][f]
    a = [255, 255, 235, 170, 90][f]
    d.ellipse((24 - r, 24 - r, 24 + r, 24 + r), fill=C("#d83a1e", a))
    r2 = int(r * 0.76)
    d.ellipse((24 - r2, 24 - r2, 24 + r2, 24 + r2), fill=C("#ff8a2a", a))
    if f <= 2:
        r3 = int(r * 0.5)
        d.ellipse((24 - r3, 24 - r3, 24 + r3, 24 + r3), fill=C("#ffe060", a))
    else:
        for (dx, dy) in ((-8, -10), (6, -12), (0, -16)):
            d.ellipse((24 + dx - 5, 24 + dy - 5 - f * 2, 24 + dx + 5, 24 + dy + 5 - f * 2), fill=C("#505050", 90))
    rr = random.Random(f + 10)
    for _ in range(8):
        ang = rr.random() * 6.28
        dist = r + rr.randint(0, 4)
        d.rectangle((24 + math.cos(ang) * dist, 24 + math.sin(ang) * dist,
                     24 + math.cos(ang) * dist + 1, 24 + math.sin(ang) * dist + 1), fill=C("#ffd23a", a))
    return im


def water_proj(f):
    im = mk(32, 32)
    d = ImageDraw.Draw(im)
    w = [0, 1, 0, -1][f]
    d.polygon([(2, 16), (13, 10), (13, 22)], fill=C("#3a8ee0", 200))
    d.ellipse((12 - w, 8, 28 + w, 24), fill=C("#3a8ee0"))
    d.ellipse((14, 10, 26, 22), fill=C("#62b4f2"))
    d.ellipse((17, 11, 22, 15), fill=C("#d8f2ff"))
    d.point((6 + f * 2, 12), fill=C("#9ad0f8"))
    d.point((8 + f, 21), fill=C("#9ad0f8"))
    return im


def water_hit(f):
    im = mk(48, 48)
    d = ImageDraw.Draw(im)
    r = [6, 12, 17, 20, 22][f]
    a = [255, 255, 220, 160, 90][f]
    d.ellipse((24 - r, 24 - r * 0.6, 24 + r, 24 + r * 0.6), outline=C("#bfe6ff", a), width=2)
    if f < 4:
        d.ellipse((24 - r // 2, 24 - r // 3, 24 + r // 2, 24 + r // 3), fill=C("#3a8ee0", a // 2))
    for i in range(7):
        ang = i * 0.9
        dist = r * 0.9
        x = 24 + math.cos(ang) * dist
        y = 24 + math.sin(ang) * dist * 0.6 - math.sin(f / 4 * 3.14) * 10
        d.rectangle((x, y, x + 1, y + 2), fill=C("#62b4f2", a))
    return im


def earth_hit(f):
    im = mk(48, 48)
    d = ImageDraw.Draw(im)
    h = [6, 18, 28, 28, 12][f]
    a = [255, 255, 255, 255, 140][f]
    d.ellipse((8, 40, 40, 47), fill=C("#6a5a40", 150))
    for cx, hh in ((14, h * 0.6), (34, h * 0.6), (24, h)):
        d.polygon([(cx - 6, 44), (cx, 44 - hh), (cx + 6, 44)], fill=C("#8a6b45", a))
        d.polygon([(cx, 44 - hh), (cx + 6, 44), (cx + 1, 44)], fill=C("#a98a5c", a))
        if hh > 14:
            d.polygon([(cx - 2, 44 - hh + 6), (cx, 44 - hh), (cx + 2, 44 - hh + 6)], fill=C("#c8c0a8", a))
    rr = random.Random(f)
    for _ in range(5):
        x, y = rr.randint(8, 38), rr.randint(34, 44) - f * 2
        d.rectangle((x, y, x + 2, y + 2), fill=C("#9a8a68", 200))
    return im


def wind_proj(f):
    im = mk(32, 32)
    d = ImageDraw.Draw(im)
    for i, y in enumerate((11, 16, 21)):
        s = (f * 3 + i * 5) % 12
        d.line((2 + s, y, 10 + s, y), fill=C("#d8f6ff", 150), width=1)
    d.arc((6, 3, 30, 29), -65, 65, fill=C("#e8fbff"), width=3)
    d.arc((2, 6, 26, 26), -50, 50, fill=C("#8fdcf0"), width=2)
    d.arc((10, 7, 30, 25), -35, 35, fill=C("#ffffff"), width=1)
    return im


def wind_hit(f):
    im = mk(48, 48)
    d = ImageDraw.Draw(im)
    a = [255, 255, 220, 150, 80][f]
    for k in range(3):
        r = 5 + f * 4 + k * 4
        st = f * 55 + k * 120
        d.arc((24 - r, 24 - r, 24 + r, 24 + r), st, st + 120, fill=C("#e8fbff", a), width=2)
    return im


def arcane_proj(f):
    im = mk(32, 32)
    d = ImageDraw.Draw(im)
    d.polygon([(4 + f, 16), (14, 11), (14, 21)], fill=C("#8a4dff", 170))
    d.ellipse((12, 9, 27, 23), fill=C("#8a4dff"))
    d.ellipse((15, 11, 25, 21), fill=C("#c9a4ff"))
    d.ellipse((18, 13, 23, 18), fill=C("#ffffff"))
    d.point((8 + f * 2, 10 + f), fill=C("#d6b8ff"))
    return im


def make_spells():
    save(strip([fire_proj(i) for i in range(4)]), "spells", "fire_proj.png")
    save(strip([fire_hit(i) for i in range(5)]), "spells", "fire_hit.png")
    save(strip([water_proj(i) for i in range(4)]), "spells", "water_proj.png")
    save(strip([water_hit(i) for i in range(5)]), "spells", "water_hit.png")
    save(strip([earth_hit(i) for i in range(5)]), "spells", "earth_hit.png")
    save(strip([earth_hit(i) for i in range(4)]), "spells", "earth_proj.png")  # icon only
    save(strip([wind_proj(i) for i in range(4)]), "spells", "wind_proj.png")
    save(strip([wind_hit(i) for i in range(5)]), "spells", "wind_hit.png")
    save(strip([arcane_proj(i) for i in range(4)]), "spells", "arcane_proj.png")


# ---------------------------------------------------------------- TILES
def speck_tile(base, specks, n, seed):
    r = random.Random(seed)
    im = Image.new("RGBA", (16, 16), base)
    px = im.load()
    for _ in range(n):
        px[r.randrange(16), r.randrange(16)] = r.choice(specks)
    return im


def make_tiles():
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
    d.line((2, 3, 6, 6), fill=C("#555b6a"))
    d.line((9, 10, 13, 13), fill=C("#555b6a"))
    deep = Image.new("RGBA", (16, 16), (10, 30, 90, 110))
    shore = mk(16, 16)
    r = random.Random(9)
    sp = shore.load()
    for i in range(16):
        for (x, y) in ((i, 0), (i, 15), (0, i), (15, i)):
            sp[x, y] = (255, 255, 255, 70)
    for _ in range(10):
        sp[r.randrange(16), r.randrange(16)] = (255, 255, 255, 110)
    ts = mk(16 * 8, 16)
    for i, t in enumerate((grass, grass2, forest, dirt, sand, stone, deep, shore)):
        ts.paste(t, (i * 16, 0))
    save(ts, "tiles", "tileset.png")

    for name, off in (("water_a", 0), ("water_b", 4)):
        im = Image.new("RGBA", (16, 16), C("#3b78c0"))
        d = ImageDraw.Draw(im)
        for (x, y) in ((1, 3), (9, 8), (4, 13), (12, 1)):
            xx = (x + off) % 16
            d.line((xx, y, min(15, xx + 3), y), fill=C("#6aa6e0"))
        for (x, y) in ((7, 5), (2, 10)):
            d.point(((x + off) % 16, y), fill=C("#2f68ae"))
        save(im, "tiles", name + ".png")

    dec = mk(16 * 6, 16)
    d = ImageDraw.Draw(dec)

    def flower(ox, petal, center):
        d.point((ox + 8, 10), fill=C("#2f7a3a"))
        d.point((ox + 8, 11), fill=C("#2f7a3a"))
        for (dx, dy) in ((0, -1), (-1, 0), (1, 0), (0, 1)):
            d.point((ox + 8 + dx, 8 + dy), fill=petal)
        d.point((ox + 8, 8), fill=center)
    flower(0, C("#e84a4a"), C("#ffe060"))
    flower(16, C("#ffd23a"), C("#e08a20"))
    flower(32, C("#f4f4f4"), C("#ffd23a"))
    for (x, y) in ((6, 9), (7, 8), (9, 9), (8, 10), (10, 8)):  # tuft
        d.line((48 + x, y, 48 + x, y + 3), fill=C("#3e8e3a"))
    d.rectangle((64 + 7, 10, 64 + 8, 12), fill=C("#f0e8d8"))  # mushroom
    d.ellipse((64 + 5, 7, 64 + 10, 10), fill=C("#d03a3a"))
    d.point((64 + 7, 8), fill=C("#ffffff"))
    for (x, y) in ((5, 10), (9, 8), (8, 12)):  # pebbles
        d.rectangle((80 + x, y, 80 + x + 1, y + 1), fill=C("#9a9faa"))
    save(dec, "tiles", "decor.png")


# ---------------------------------------------------------------- WORLD PROPS
def tree_oak():
    im = mk(32, 48)
    d = ImageDraw.Draw(im)
    d.ellipse((6, 41, 26, 47), fill=(0, 0, 0, 60))
    d.rectangle((13, 28, 18, 45), fill=C("#6b4423"))
    d.rectangle((13, 28, 14, 45), fill=C("#85582f"))
    d.rectangle((11, 43, 20, 45), fill=C("#6b4423"))
    d.ellipse((2, 4, 29, 33), fill=C("#2f7a3a"))
    d.ellipse((4, 3, 24, 26), fill=C("#3f9b45"))
    d.ellipse((7, 5, 17, 14), fill=C("#5cbf5a"))
    r = random.Random(3)
    for _ in range(14):
        d.point((r.randint(6, 26), r.randint(8, 28)), fill=C("#2a6a34"))
    return outline(im)


def tree_pine():
    im = mk(32, 48)
    d = ImageDraw.Draw(im)
    d.ellipse((8, 41, 24, 47), fill=(0, 0, 0, 60))
    d.rectangle((14, 34, 17, 45), fill=C("#5e3c20"))
    for (top, bot, w, col) in ((20, 38, 12, "#236b3a"), (11, 29, 10, "#2c8446"), (2, 20, 8, "#38a056")):
        d.polygon([(16, top), (16 - w, bot), (16 + w, bot)], fill=C(col))
    d.polygon([(16, 2), (16, 20), (24, 20)], fill=C("#38a056"))
    d.polygon([(16, 11), (16, 29), (26, 29)], fill=C("#349050"))
    return outline(im)


def stump():
    im = mk(16, 16)
    d = ImageDraw.Draw(im)
    d.ellipse((2, 11, 14, 15), fill=(0, 0, 0, 60))
    d.rectangle((4, 7, 11, 13), fill=C("#6b4423"))
    d.ellipse((3, 5, 12, 9), fill=C("#c49a62"))
    d.ellipse((5, 6, 10, 8), fill=C("#a77c46"))
    return outline(im)


def rock_base(body, hi, dark):
    im = mk(24, 20)
    d = ImageDraw.Draw(im)
    d.ellipse((1, 14, 22, 19), fill=(0, 0, 0, 60))
    d.ellipse((1, 5, 22, 17), fill=body)
    d.ellipse((2, 11, 21, 17), fill=dark)
    d.ellipse((4, 6, 14, 12), fill=hi)
    return im, d


def rocks():
    im, d = rock_base(C("#8a8f9c"), C("#b0b5c2"), C("#6c717e"))
    save(outline(im), "world", "rock.png")
    im, d = rock_base(C("#8a8f9c"), C("#b0b5c2"), C("#6c717e"))
    for (x, y) in ((8, 9), (14, 10), (11, 13), (17, 13), (6, 13)):
        d.rectangle((x, y, x + 2, y + 1), fill=C("#e0925a"))
        d.point((x, y), fill=C("#ffd0a0"))
    save(outline(im), "world", "iron_ore.png")
    im, d = rock_base(C("#656a76"), C("#8a8f9c"), C("#4e5360"))
    for (x, y) in ((8, 8), (13, 9), (10, 12), (16, 12)):
        d.rectangle((x, y, x + 3, y + 2), fill=C("#22222a"))
        d.point((x, y), fill=C("#5a5a66"))
    save(outline(im), "world", "coal_ore.png")


def house():
    im = mk(64, 64)
    d = ImageDraw.Draw(im)
    d.ellipse((4, 54, 60, 63), fill=(0, 0, 0, 60))
    d.rectangle((7, 28, 56, 60), fill=C("#b98a55"))
    for x in range(10, 56, 6):
        d.line((x, 29, x, 59), fill=C("#9a6e3e"))
    d.rectangle((7, 56, 56, 60), fill=C("#7a7f8a"))
    d.rectangle((46, 8, 52, 24), fill=C("#7a7f8a"))
    d.polygon([(0, 31), (32, 3), (63, 31)], fill=C("#a8402e"))
    for y in range(10, 31, 5):
        d.line((int(32 - (y - 3) * 1.1), y, int(32 + (y - 3) * 1.1), y), fill=C("#8c3224"))
    d.rectangle((27, 41, 37, 60), fill=C("#5a3a20"))
    d.point((35, 51), fill=C("#ffd84a"))
    d.rectangle((12, 38, 21, 47), fill=C("#9ad0f0"))
    d.line((16, 38, 16, 47), fill=C("#5a3a20"))
    d.line((12, 42, 21, 42), fill=C("#5a3a20"))
    d.rectangle((43, 38, 52, 47), fill=C("#9ad0f0"))
    d.line((47, 38, 47, 47), fill=C("#5a3a20"))
    d.line((43, 42, 52, 42), fill=C("#5a3a20"))
    return outline(im)


def fence():
    im = mk(16, 16)
    d = ImageDraw.Draw(im)
    for x in (1, 12):
        d.rectangle((x, 4, x + 2, 14), fill=C("#8a6238"))
    d.rectangle((0, 6, 15, 7), fill=C("#a77c46"))
    d.rectangle((0, 10, 15, 11), fill=C("#a77c46"))
    return outline(im)


def signpost():
    im = mk(16, 24)
    d = ImageDraw.Draw(im)
    d.rectangle((7, 8, 8, 20), fill=C("#6b4423"))
    d.rectangle((1, 2, 14, 10), fill=C("#b98a55"))
    d.line((3, 5, 12, 5), fill=C("#6b4423"))
    d.line((3, 7, 10, 7), fill=C("#6b4423"))
    return outline(im)


def campfire_frame(f):
    im = mk(16, 16)
    d = ImageDraw.Draw(im)
    d.ellipse((1, 10, 14, 15), fill=C("#6c717e"))
    d.ellipse((3, 11, 12, 14), fill=(40, 30, 30, 255))
    d.line((3, 13, 12, 10), fill=C("#6b4423"), width=2)
    d.line((3, 10, 12, 13), fill=C("#85582f"), width=2)
    h = [6, 8, 7, 9][f % 4]
    d.polygon([(8, 11 - h), (4, 11), (12, 11)], fill=C("#e8452a"))
    d.polygon([(8, 12 - h + 2), (5, 11), (11, 11)], fill=C("#ff9a2a"))
    d.polygon([(8, 12 - h + 5), (6, 11), (10, 11)], fill=C("#ffe060"))
    return outline(im)


def make_world():
    save(tree_oak(), "world", "tree_oak.png")
    save(tree_pine(), "world", "tree_pine.png")
    save(stump(), "world", "stump.png")
    rocks()
    save(house(), "world", "house.png")
    save(fence(), "world", "fence.png")
    save(signpost(), "world", "signpost.png")
    save(strip([campfire_frame(i) for i in range(3)]), "world", "campfire.png")


# ---------------------------------------------------------------- ITEMS
def blade(col, edge, top, guard):
    im = mk(16, 32)
    d = ImageDraw.Draw(im)
    d.rectangle((6, top + 2, 9, 21), fill=col)
    d.rectangle((7, top + 1, 8, 21), fill=edge)
    d.rectangle((7, top, 8, top + 1), fill=edge)
    d.rectangle((3, 22, 12, 23), fill=guard)
    d.rectangle((7, 24, 8, 28), fill=C("#6b4423"))
    d.rectangle((6, 29, 9, 30), fill=guard)
    return outline(im)


def spear():
    im = mk(16, 32)
    d = ImageDraw.Draw(im)
    d.rectangle((7, 9, 8, 30), fill=C("#8a6238"))
    d.polygon([(8, 0), (12, 10), (4, 10)], fill=C("#c8d0e0"))
    d.polygon([(8, 0), (12, 10), (8, 10)], fill=C("#9aa4b8"))
    d.rectangle((6, 11, 9, 12), fill=C("#c43434"))
    return outline(im)


def bow():
    im = mk(16, 32)
    d = ImageDraw.Draw(im)
    d.arc((0, 4, 15, 30), 180, 360, fill=C("#8a5a2a"), width=2)
    d.line((1, 17, 14, 17), fill=C("#e8e8e8"))
    d.line((8, 17, 8, 5), fill=C("#c8a070"))
    d.polygon([(8, 1), (6, 6), (10, 6)], fill=C("#c8d0e0"))
    d.rectangle((6, 15, 6, 17), fill=C("#c43434"))
    d.rectangle((10, 15, 10, 17), fill=C("#c43434"))
    return outline(im)


def wand():
    im = mk(16, 32)
    d = ImageDraw.Draw(im)
    d.rectangle((7, 10, 8, 30), fill=C("#6b3f7a"))
    d.rectangle((6, 12, 9, 13), fill=C("#ffd84a"))
    d.ellipse((3, 0, 12, 9), fill=C("#3ab0e8"))
    d.ellipse((5, 2, 10, 7), fill=C("#9ae6ff"))
    d.point((7, 4), fill=(255, 255, 255, 255))
    return outline(im)


def pickaxe(head, handle="#8a6238"):
    im = mk(16, 32)
    d = ImageDraw.Draw(im)
    d.rectangle((7, 6, 8, 30), fill=C(handle))
    d.polygon([(0, 9), (3, 3), (8, 1), (13, 3), (15, 9), (12, 6), (8, 5), (4, 6)], fill=head)
    d.rectangle((6, 4, 9, 6), fill=head)
    return outline(im)


def axe(head, handle="#8a6238"):
    im = mk(16, 32)
    d = ImageDraw.Draw(im)
    d.rectangle((7, 5, 8, 30), fill=C(handle))
    d.polygon([(8, 3), (14, 1), (15, 11), (8, 9)], fill=head)
    d.line((14, 2, 15, 10), fill=C("#eef2ff"), width=1)
    return outline(im)


def hammer():
    im = mk(16, 32)
    d = ImageDraw.Draw(im)
    d.rectangle((7, 10, 8, 30), fill=C("#8a6238"))
    d.rectangle((2, 1, 13, 10), fill=C("#7a8090"))
    d.rectangle((2, 1, 13, 3), fill=C("#a4aaba"))
    d.rectangle((2, 5, 13, 6), fill=C("#5a6070"))
    return outline(im)


def icon(draw_fn):
    im = mk(16, 16)
    d = ImageDraw.Draw(im)
    draw_fn(d)
    return outline(im)


def make_items():
    save(blade(C("#c8d0e0"), C("#eef2ff"), 4, C("#d8a93a")), "items", "sword.png")
    save(blade(C("#6a7ea8"), C("#9ad6ff"), 1, C("#7a7f8a")), "items", "iron_sword.png")
    save(spear(), "items", "spear.png")
    save(bow(), "items", "bow.png")
    save(wand(), "items", "wand.png")
    save(pickaxe(C("#9aa0b0")), "items", "pickaxe.png")
    save(pickaxe(C("#6a7ea8")), "items", "iron_pickaxe.png")
    save(axe(C("#9aa0b0")), "items", "axe.png")
    save(axe(C("#6a7ea8")), "items", "iron_axe.png")
    save(hammer(), "items", "hammer.png")

    def wood(d):
        d.rectangle((2, 6, 13, 9), fill=C("#85582f"))
        d.ellipse((1, 6, 4, 9), fill=C("#c49a62"))
        d.rectangle((3, 10, 14, 13), fill=C("#6b4423"))
        d.ellipse((2, 10, 5, 13), fill=C("#c49a62"))

    def stone(d):
        d.ellipse((2, 6, 9, 13), fill=C("#8a8f9c"))
        d.ellipse((7, 4, 14, 12), fill=C("#a4a9b6"))
        d.ellipse((4, 8, 13, 14), fill=C("#7b8190"))

    def iron_ore(d):
        stone(d)
        for (x, y) in ((5, 8), (10, 7), (8, 11)):
            d.rectangle((x, y, x + 1, y + 1), fill=C("#e0925a"))

    def coal(d):
        d.ellipse((2, 6, 9, 13), fill=C("#33333c"))
        d.ellipse((7, 4, 14, 12), fill=C("#22222a"))
        d.point((4, 8), fill=C("#6a6a76"))
        d.point((10, 6), fill=C("#6a6a76"))

    def ingot(d):
        d.polygon([(2, 12), (4, 6), (13, 6), (15, 12)], fill=C("#c8d0e0"))
        d.polygon([(2, 12), (15, 12), (14, 14), (3, 14)], fill=C("#7a8296"))
        d.line((5, 7, 12, 7), fill=C("#ffffff"))

    def meat(d, col, hi):
        d.ellipse((2, 2, 11, 10), fill=col)
        d.ellipse((4, 3, 8, 6), fill=hi)
        d.rectangle((9, 9, 13, 12), fill=C("#f0e8d8"))
        d.ellipse((11, 10, 14, 14), fill=C("#f0e8d8"))

    def hide(d):
        d.polygon([(2, 4), (8, 2), (14, 5), (13, 12), (7, 14), (3, 11)], fill=C("#c49a62"))
        d.polygon([(4, 5), (8, 4), (12, 6), (11, 11), (7, 12), (5, 10)], fill=C("#d8b27a"))

    def arrow(d):
        d.line((1, 8, 13, 8), fill=C("#c8a070"))
        d.polygon([(15, 8), (12, 6), (12, 10)], fill=C("#c8d0e0"))
        d.polygon([(1, 8), (3, 5), (4, 8)], fill=C("#c43434"))
        d.polygon([(1, 8), (3, 11), (4, 8)], fill=C("#c43434"))

    def gel(d):
        d.ellipse((2, 5, 13, 14), fill=C("#60c860"))
        d.ellipse((4, 6, 8, 9), fill=C("#c8f8c0"))

    def potion(d):
        d.rectangle((6, 1, 9, 4), fill=C("#c8a070"))
        d.polygon([(6, 4), (9, 4), (13, 10), (11, 14), (4, 14), (2, 10)], fill=C("#d8f0ff"))
        d.polygon([(3, 10), (12, 10), (11, 14), (4, 14)], fill=C("#e84a6a"))

    def armor(d, c1, c2):
        d.polygon([(3, 2), (6, 4), (9, 4), (12, 2), (14, 6), (12, 8), (12, 14), (3, 14), (3, 8), (1, 6)], fill=c1)
        d.rectangle((5, 6, 10, 13), fill=c2)

    save(icon(wood), "items", "wood.png")
    save(icon(stone), "items", "stone.png")
    save(icon(iron_ore), "items", "iron_ore.png")
    save(icon(coal), "items", "coal.png")
    save(icon(ingot), "items", "iron_ingot.png")
    save(icon(lambda d: meat(d, C("#e87a8a"), C("#f8b0b8"))), "items", "meat.png")
    save(icon(lambda d: meat(d, C("#a85a2a"), C("#d08a50"))), "items", "cooked_meat.png")
    save(icon(hide), "items", "hide.png")
    save(icon(arrow), "items", "arrow.png")
    save(icon(gel), "items", "gel.png")
    save(icon(potion), "items", "potion.png")
    save(icon(lambda d: armor(d, C("#c49a62"), C("#a77c46"))), "items", "leather_armor.png")
    save(icon(lambda d: armor(d, C("#b0b8c8"), C("#7a8296"))), "items", "iron_armor.png")
    save(campfire_frame(1), "items", "campfire.png")



# ---------------------------------------------------------------- BOSSES
def boss_goblin_king(f):
    im = mk(64, 64)
    d = ImageDraw.Draw(im)
    bob = [0, -1, 0, -1][f]
    sw = [0, 3, 0, -3][f]
    sk, dk, lt = C("#6aa84a"), C("#4a7c34"), C("#8cc866")
    gold = C("#ffd23a")
    d.ellipse((10, 54, 54, 63), fill=(0, 0, 0, 70))
    R(d, 22 - sw, 46, 30 - sw, 57, dk)
    R(d, 34 + sw, 46, 42 + sw, 57, sk)
    R(d, 18, 26 + bob, 46, 50 + bob, C("#a02828"))
    R(d, 18, 26 + bob, 46, 30 + bob, C("#e8e0d0"))
    R(d, 18, 46 + bob, 46, 50 + bob, C("#7a1c1c"))
    R(d, 26, 32 + bob, 38, 45 + bob, C("#d8b890"))
    d.line((18, 33 + bob, 9, 41 + bob - sw // 2), fill=dk, width=5)
    R(d, 22, 8 + bob, 44, 28 + bob, sk)
    R(d, 24, 10 + bob, 42, 13 + bob, lt)
    d.polygon([(22, 14 + bob), (8, 9 + bob), (22, 23 + bob)], fill=sk)
    d.polygon([(44, 14 + bob), (58, 8 + bob), (44, 23 + bob)], fill=sk)
    for ex in (28, 36):
        R(d, ex, 16 + bob, ex + 3, 19 + bob, C("#e02828"))
        d.point((ex + 1, 17 + bob), fill=(255, 255, 255, 255))
    R(d, 28, 23 + bob, 38, 25 + bob, C("#2a1a1a"))
    R(d, 29, 21 + bob, 30, 26 + bob, C("#f4f0e0"))
    R(d, 36, 21 + bob, 37, 26 + bob, C("#f4f0e0"))
    d.polygon([(22, 10 + bob), (22, 1 + bob), (28, 6 + bob), (33, 0 + bob), (38, 6 + bob), (44, 1 + bob), (44, 10 + bob)], fill=gold)
    d.point((33, 5 + bob), fill=C("#e02828"))
    d.line((44, 33 + bob, 53, 35 + bob + sw // 2), fill=sk, width=5)
    R(d, 51, 12 + bob + sw // 2, 58, 46 + bob + sw // 2, C("#7a5230"))
    R(d, 49, 12 + bob + sw // 2, 60, 20 + bob + sw // 2, C("#5a3a20"))
    for yy in (14, 18):
        d.point((48, yy + bob + sw // 2), fill=C("#c8d0e0"))
        d.point((61, yy + bob + sw // 2), fill=C("#c8d0e0"))
    return outline(im)


def boss_treant(f):
    im = mk(64, 64)
    d = ImageDraw.Draw(im)
    bob = [0, -1, 0, -1][f]
    sw = [0, 3, 0, -3][f]
    br, dk = C("#7a5230"), C("#54361e")
    d.ellipse((8, 54, 56, 63), fill=(0, 0, 0, 70))
    d.polygon([(20, 50), (12 - sw, 60), (24, 58)], fill=dk)
    d.polygon([(44, 50), (52 + sw, 60), (40, 58)], fill=dk)
    d.polygon([(28, 52), (26 + sw, 62), (36, 56)], fill=dk)
    R(d, 18, 22 + bob, 46, 54 + bob, br)
    for x in (22, 28, 34, 40):
        d.line((x, 24 + bob, x + 1, 52 + bob), fill=dk)
    d.line((18, 32 + bob, 4, 42 + bob + sw), fill=br, width=5)
    d.line((46, 32 + bob, 60, 40 + bob - sw), fill=br, width=5)
    for (x, y) in ((4, 42 + sw), (60, 40 - sw), (8, 38 + sw), (56, 36 - sw)):
        d.ellipse((x - 4, y - 4 + bob, x + 4, y + 4 + bob), fill=C("#3f9b45"))
    for (cx, cy, r) in ((14, 16, 11), (32, 8, 13), (50, 16, 11), (24, 20, 9), (42, 20, 9)):
        d.ellipse((cx - r, cy - r + bob, cx + r, cy + r + bob), fill=C("#2f7a3a"))
    for (cx, cy, r) in ((32, 9, 8), (16, 15, 6), (48, 15, 6)):
        d.ellipse((cx - r, cy - r + bob, cx + r, cy + r + bob), fill=C("#4cae50"))
    for ex in (25, 35):
        R(d, ex, 32 + bob, ex + 4, 36 + bob, C("#ffe060"))
        d.point((ex + 2, 34 + bob), fill=(255, 255, 255, 255))
    R(d, 27, 42 + bob, 37, 46 + bob, C("#2a1a10"))
    d.point((22, 28 + bob), fill=C("#5cbf5a"))
    d.point((40, 46 + bob), fill=C("#5cbf5a"))
    return outline(im)


def boss_golem(f):
    im = mk(64, 64)
    d = ImageDraw.Draw(im)
    bob = [0, -1, 0, -1][f]
    sw = [0, 2, 0, -2][f]
    st, lt, dk = C("#7b8190"), C("#a4aaba"), C("#575c6a")
    d.ellipse((8, 54, 56, 63), fill=(0, 0, 0, 70))
    R(d, 20, 44, 30, 58 - max(0, sw), dk)
    R(d, 34, 44, 44, 58 - max(0, -sw), dk)
    R(d, 16, 22 + bob, 48, 48 + bob, st)
    R(d, 16, 22 + bob, 48, 26 + bob, lt)
    R(d, 6, 24 + bob, 18, 40 + bob, st)
    R(d, 46, 24 + bob, 58, 40 + bob, st)
    R(d, 4, 38 + bob + sw, 18, 54 + bob + sw, lt)
    R(d, 46, 38 + bob - sw, 60, 54 + bob - sw, lt)
    R(d, 24, 8 + bob, 40, 24 + bob, st)
    R(d, 24, 8 + bob, 40, 11 + bob, lt)
    for ex in (27, 35):
        R(d, ex, 14 + bob, ex + 3, 17 + bob, C("#ffb020"))
    d.ellipse((26, 30 + bob, 38, 42 + bob), fill=C("#ff8a20"))
    d.ellipse((29, 33 + bob, 35, 39 + bob), fill=C("#ffe080"))
    for pts in (((20, 26), (24, 34)), ((44, 28), (40, 36)), ((22, 44), (28, 40)), ((42, 44), (36, 41))):
        d.line((pts[0][0], pts[0][1] + bob, pts[1][0], pts[1][1] + bob), fill=C("#3a3e4a"))
    for (x, y) in ((18, 30), (44, 44), (30, 24)):
        R(d, x, y + bob, x + 3, y + 1 + bob, C("#4a8a3a"))
    return outline(im)


def boulder_proj(f):
    im = mk(32, 32)
    d = ImageDraw.Draw(im)
    d.ellipse((8, 8, 24, 24), fill=C("#7b8190"))
    d.ellipse((10, 10, 20, 20), fill=C("#9aa0b0"))
    a = f * 1.57
    for k in range(3):
        x = 16 + math.cos(a + k * 2.1) * 6
        y = 16 + math.sin(a + k * 2.1) * 6
        d.rectangle((x - 1, y - 1, x + 2, y + 2), fill=C("#575c6a"))
    return outline(im)


def thorn_proj(f):
    im = mk(32, 32)
    d = ImageDraw.Draw(im)
    w = [0, 1, 0, -1][f]
    d.polygon([(26, 16), (10, 12 + w), (10, 20 - w)], fill=C("#5cbf5a"))
    d.polygon([(26, 16), (10, 16), (10, 20 - w)], fill=C("#3f9b45"))
    d.rectangle((4, 13, 10, 19), fill=C("#7a5230"))
    d.point((14, 11 + w), fill=C("#c8f0a0"))
    return outline(im)


def make_bosses():
    for name, fn in (("boss_goblin_king", boss_goblin_king), ("boss_treant", boss_treant), ("boss_golem", boss_golem)):
        save(strip([fn(i) for i in range(4)]), "mobs", name + ".png")
    save(strip([boulder_proj(i) for i in range(4)]), "spells", "boulder_proj.png")
    save(strip([thorn_proj(i) for i in range(4)]), "spells", "thorn_proj.png")


# ---------------------------------------------------------------- BOSS ITEMS
def cleaver():
    im = mk(16, 32)
    d = ImageDraw.Draw(im)
    d.polygon([(5, 4), (8, 0), (11, 4), (11, 21), (5, 21)], fill=C("#c8d0e0"))
    d.rectangle((7, 4, 8, 20), fill=C("#c03030"))
    d.rectangle((9, 4, 10, 20), fill=C("#eef2ff"))
    d.rectangle((2, 22, 13, 24), fill=C("#ffd23a"))
    d.rectangle((7, 25, 8, 29), fill=C("#6b4423"))
    d.rectangle((6, 29, 9, 30), fill=C("#c03030"))
    return outline(im)


def ember_blade():
    im = mk(16, 32)
    d = ImageDraw.Draw(im)
    d.rectangle((6, 3, 9, 21), fill=C("#e8e0d0"))
    d.rectangle((7, 2, 8, 21), fill=C("#fff4c0"))
    d.polygon([(10, 4), (14, 8), (10, 10)], fill=C("#ff8a2a"))
    d.polygon([(10, 12), (14, 16), (10, 18)], fill=C("#e8452a"))
    d.polygon([(5, 7), (2, 11), (5, 13)], fill=C("#ff8a2a"))
    d.rectangle((3, 22, 12, 23), fill=C("#c05020"))
    d.rectangle((7, 24, 8, 28), fill=C("#4a2a1a"))
    d.rectangle((6, 29, 9, 30), fill=C("#ffd23a"))
    return outline(im)


def longbow():
    im = mk(16, 32)
    d = ImageDraw.Draw(im)
    d.arc((0, 2, 15, 30), 180, 360, fill=C("#4a8a3a"), width=3)
    d.line((1, 16, 14, 16), fill=C("#f0f8e0"))
    for x in (4, 8, 12):
        d.line((x if x == 8 else 8, 16, x, 4), fill=C("#c8a070"))
    d.polygon([(8, 0), (6, 5), (10, 5)], fill=C("#c8d0e0"))
    d.point((2, 15), fill=C("#9be26a"))
    d.point((13, 15), fill=C("#9be26a"))
    return outline(im)


def maul():
    im = mk(16, 32)
    d = ImageDraw.Draw(im)
    d.rectangle((7, 12, 8, 30), fill=C("#6b4423"))
    d.rectangle((1, 0, 14, 13), fill=C("#7b8190"))
    d.rectangle((1, 0, 14, 3), fill=C("#a4aaba"))
    d.rectangle((1, 5, 14, 6), fill=C("#ffd23a"))
    d.rectangle((1, 10, 14, 11), fill=C("#ffd23a"))
    d.rectangle((6, 7, 9, 9), fill=C("#ff8a20"))
    return outline(im)


def hstaff():
    im = mk(16, 32)
    d = ImageDraw.Draw(im)
    pts = [(8, 30), (7, 24), (9, 18), (7, 12), (8, 8)]
    d.line(pts, fill=C("#7a5230"), width=2)
    d.ellipse((3, 0, 12, 9), fill=C("#3f9b45"))
    d.ellipse((5, 2, 10, 7), fill=C("#9be26a"))
    d.point((7, 4), fill=(255, 255, 255, 255))
    d.polygon([(3, 12), (0, 9), (6, 11)], fill=C("#4cae50"))
    d.polygon([(12, 16), (15, 13), (10, 15)], fill=C("#4cae50"))
    return outline(im)


def titan_pick():
    im = mk(16, 32)
    d = ImageDraw.Draw(im)
    d.rectangle((7, 6, 8, 30), fill=C("#8a6238"))
    d.polygon([(0, 9), (3, 3), (8, 1), (13, 3), (15, 9), (12, 6), (8, 5), (4, 6)], fill=C("#5a7a9a"))
    d.rectangle((6, 4, 9, 6), fill=C("#7aa0c8"))
    d.point((2, 7), fill=C("#c8f0ff"))
    d.point((13, 7), fill=C("#c8f0ff"))
    return outline(im)


def make_boss_items():
    save(cleaver(), "items", "kingsbane_cleaver.png")
    save(ember_blade(), "items", "ember_blade.png")
    save(longbow(), "items", "wardens_longbow.png")
    save(maul(), "items", "titan_maul.png")
    save(hstaff(), "items", "heartwood_staff.png")
    save(titan_pick(), "items", "titan_pick.png")

    def crown(d):
        d.polygon([(2, 12), (2, 4), (5, 8), (8, 2), (11, 8), (14, 4), (14, 12)], fill=C("#ffd23a"))
        d.rectangle((2, 11, 13, 13), fill=C("#d8a020"))
        d.point((8, 9), fill=C("#e02828"))

    def fang(d):
        d.polygon([(4, 2), (12, 2), (9, 14), (7, 14)], fill=C("#f4f0e0"))
        d.polygon([(9, 2), (12, 2), (9, 14)], fill=C("#c8c0a8"))

    def heartwood(d):
        d.rectangle((2, 6, 13, 10), fill=C("#9a6a3a"))
        d.ellipse((1, 6, 5, 10), fill=C("#d8a868"))
        d.rectangle((3, 11, 14, 14), fill=C("#7a5230"))
        d.point((8, 8), fill=C("#9be26a"))
        d.point((6, 12), fill=C("#9be26a"))

    def sap(d):
        d.polygon([(8, 1), (13, 9), (11, 14), (5, 14), (3, 9)], fill=C("#5cd860"))
        d.polygon([(8, 4), (11, 9), (6, 11)], fill=C("#b8f8a0"))

    def core(d):
        d.ellipse((2, 2, 13, 13), fill=C("#575c6a"))
        d.ellipse((4, 4, 11, 11), fill=C("#ff8a20"))
        d.ellipse((6, 6, 9, 9), fill=C("#ffe080"))

    def shard(d):
        d.polygon([(8, 0), (12, 8), (9, 15), (4, 10)], fill=C("#7aa0c8"))
        d.polygon([(8, 0), (12, 8), (8, 9)], fill=C("#c8f0ff"))

    def armor(d, c1, c2):
        d.polygon([(3, 2), (6, 4), (9, 4), (12, 2), (14, 6), (12, 8), (12, 14), (3, 14), (3, 8), (1, 6)], fill=c1)
        d.rectangle((5, 6, 10, 13), fill=c2)

    def tome(d, cover, mark):
        d.rectangle((2, 1, 13, 14), fill=cover)
        d.rectangle((2, 1, 4, 14), fill=C("#3a2a20"))
        d.rectangle((13, 2, 13, 13), fill=C("#f4f0e0"))
        d.ellipse((6, 5, 11, 10), fill=mark)

    for nm, fn in (("goblin_crown", crown), ("king_fang", fang), ("heartwood", heartwood), ("living_sap", sap),
                   ("golem_core", core), ("titan_shard", shard)):
        save(icon(fn), "items", nm + ".png")
    save(icon(lambda d: armor(d, C("#3f9b45"), C("#7a5230"))), "items", "warden_mail.png")
    save(icon(lambda d: armor(d, C("#7b8190"), C("#ff8a20"))), "items", "titan_plate.png")
    save(icon(lambda d: tome(d, C("#c03030"), C("#ff8a2a"))), "items", "tome_fire.png")
    save(icon(lambda d: tome(d, C("#2a6ac0"), C("#9ad8ff"))), "items", "tome_water.png")
    save(icon(lambda d: tome(d, C("#7a5a30"), C("#c8b080"))), "items", "tome_earth.png")
    save(icon(lambda d: tome(d, C("#3a9aa8"), C("#e8fbff"))), "items", "tome_wind.png")


if __name__ == "__main__":
    make_characters()
    make_mobs()
    make_spells()
    make_tiles()
    make_world()
    make_items()
    make_bosses()
    make_boss_items()
    import generate_assets_v2
    generate_assets_v2.make_all()
    print("assets generated in", A)
