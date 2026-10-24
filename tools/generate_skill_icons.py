"""Per-skill icons (assets/skillicons/<skill_id>.png, 32x32): element-coloured orb (actives) or plaque (passives)
with a glyph that shows what the skill does. Input: tools/skills_dump.json (id -> name/elem/type/cls/t/bonus).
Run from project root: python3 tools/generate_skill_icons.py"""
import json, math, os
from PIL import Image, ImageDraw, ImageFilter

S = 32
PAL = {"fire": (240, 110, 40), "water": (70, 150, 240), "earth": (176, 130, 70), "wind": (150, 230, 235),
       "light": (255, 232, 120), "dark": (140, 80, 210), "none": (170, 175, 190)}
WHITE = (250, 250, 250, 255)
os.makedirs("assets/skillicons", exist_ok=True)
data = json.load(open("tools/skills_dump.json"))


def shade(c, f):
    return tuple(max(0, min(255, int(v * f))) for v in c[:3])


def poly_pts(cx, cy, r, n, rot=0.0, inner=None):
    pts = []
    for i in range(n * (2 if inner else 1)):
        a = rot + i * math.pi * 2 / (n * (2 if inner else 1))
        rr = r if (not inner or i % 2 == 0) else inner
        pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr))
    return pts


# ---- glyphs: draw white shapes on a transparent layer --------------------------------------------------
def g_arc(d):
    d.arc((4, 4, 28, 28), 200, 340, fill=WHITE, width=4)
    d.arc((7, 9, 25, 27), 205, 335, fill=WHITE, width=2)
    d.polygon([(22, 6), (27, 10), (23, 11)], fill=WHITE)


def g_nova(d):
    d.ellipse((9, 9, 23, 23), outline=WHITE, width=3)
    for i in range(8):
        a = i * math.pi / 4
        d.line((16 + math.cos(a) * 10, 16 + math.sin(a) * 10, 16 + math.cos(a) * 14, 16 + math.sin(a) * 14), fill=WHITE, width=2)
    d.ellipse((14, 14, 18, 18), fill=WHITE)


def g_proj(d):
    d.line((6, 26, 22, 10), fill=WHITE, width=3)
    d.polygon([(26, 6), (26, 16), (16, 6)], fill=WHITE)
    d.line((5, 20, 11, 26), fill=WHITE, width=1)
    d.line((9, 17, 14, 22), fill=WHITE, width=1)


def g_tgt(d):
    d.ellipse((7, 7, 25, 25), outline=WHITE, width=2)
    d.line((16, 3, 16, 12), fill=WHITE, width=2)
    d.line((16, 20, 16, 29), fill=WHITE, width=2)
    d.line((3, 16, 12, 16), fill=WHITE, width=2)
    d.line((20, 16, 29, 16), fill=WHITE, width=2)
    d.ellipse((14, 14, 18, 18), fill=WHITE)


def g_zone(d):
    for i in range(10):
        a = i * math.pi / 5
        d.arc((5, 5, 27, 27), math.degrees(a), math.degrees(a) + 20, fill=WHITE, width=3)
    d.ellipse((13, 13, 19, 19), fill=WHITE)


def g_buff(d):
    d.polygon([(16, 5), (26, 15), (20, 15), (20, 20), (12, 20), (12, 15), (6, 15)], fill=WHITE)
    d.polygon([(16, 14), (24, 22), (19, 22), (19, 27), (13, 27), (13, 22), (8, 22)], fill=WHITE)


def g_heal(d):
    d.rectangle((12, 5, 20, 27), fill=WHITE)
    d.rectangle((5, 12, 27, 20), fill=WHITE)


def g_cleanse(d):
    d.polygon([(16, 4), (23, 15), (23, 20), (16, 27), (9, 20), (9, 15)], fill=WHITE)
    d.line((22, 5, 22, 11), fill=WHITE, width=2); d.line((19, 8, 25, 8), fill=WHITE, width=2)


def g_dash(d):
    d.polygon([(28, 16), (17, 6), (17, 12), (8, 12), (8, 20), (17, 20), (17, 26)], fill=WHITE)
    d.line((2, 10, 9, 10), fill=WHITE, width=2); d.line((2, 22, 9, 22), fill=WHITE, width=2)


def g_slash3(d):
    for o in (-7, 0, 7):
        d.line((7 + o, 26, 21 + o, 6), fill=WHITE, width=3)


def g_fireball(d):
    d.ellipse((13, 5, 27, 19), fill=WHITE)
    d.polygon([(15, 14), (4, 27), (20, 21)], fill=WHITE)
    d.polygon([(11, 10), (3, 14), (13, 17)], fill=WHITE)


def g_lance(d):
    d.polygon([(27, 5), (22, 13), (13, 22), (9, 27), (6, 26), (5, 23), (10, 19), (19, 10)], fill=WHITE)
    d.line((8, 14, 18, 24), fill=WHITE, width=2)


def g_meteor(d):
    d.ellipse((14, 12, 28, 26), fill=WHITE)
    d.polygon([(16, 14), (3, 5), (12, 18)], fill=WHITE)
    d.polygon([(14, 18), (4, 14), (13, 22)], fill=WHITE)


def g_shield(d):
    d.polygon([(6, 5), (26, 5), (26, 17), (16, 28), (6, 17)], fill=WHITE)


def g_whirl(d):
    d.arc((5, 5, 27, 27), 20, 300, fill=WHITE, width=4)
    d.arc((10, 10, 22, 22), 200, 480, fill=WHITE, width=3)
    d.polygon([(27, 14), (30, 22), (22, 20)], fill=WHITE)


def g_rain(d):
    for x, y in ((6, 4), (14, 8), (22, 4), (10, 17), (19, 15), (26, 14)):
        d.line((x, y, x - 4, y + 11), fill=WHITE, width=2)
        d.polygon([(x - 4, y + 13), (x - 6, y + 9), (x - 2, y + 9)], fill=WHITE)


def g_volley(d):
    for a in (-0.5, 0, 0.5):
        x2 = 16 + math.sin(a) * 15
        y2 = 28 - math.cos(a) * 24
        d.line((16, 28, x2, y2 + 2), fill=WHITE, width=2)
        d.polygon([(x2, y2 - 2), (x2 - 3, y2 + 3), (x2 + 3, y2 + 3)], fill=WHITE)


def g_bolt(d):
    d.polygon([(19, 3), (8, 17), (14, 17), (11, 29), (24, 13), (17, 13)], fill=WHITE)


def g_curse(d):
    d.ellipse((7, 4, 25, 20), fill=WHITE)
    d.rectangle((11, 18, 21, 27), fill=WHITE)


def g_book(d):
    d.polygon([(4, 10), (15, 12), (15, 28), (4, 26)], fill=WHITE)
    d.polygon([(17, 12), (28, 10), (28, 26), (17, 28)], fill=WHITE)
    d.polygon([(16, 2), (18, 6), (22, 7), (18, 8), (16, 12), (14, 8), (10, 7), (14, 6)], fill=WHITE)


def g_smoke(d):
    for x, y, r in ((10, 19, 6), (20, 19, 7), (15, 12, 7), (8, 24, 4), (24, 24, 4)):
        d.ellipse((x - r, y - r, x + r, y + r), fill=WHITE)


def g_heart(d):
    d.ellipse((5, 6, 17, 18), fill=WHITE); d.ellipse((15, 6, 27, 18), fill=WHITE)
    d.polygon([(6, 14), (26, 14), (16, 28)], fill=WHITE)


def g_drop(d):
    d.polygon([(16, 3), (25, 17), (25, 20), (16, 29), (7, 20), (7, 17)], fill=WHITE)
    d.ellipse((7, 14, 25, 29), fill=WHITE)


def g_sword(d):
    d.polygon([(25, 4), (28, 7), (14, 21), (11, 18)], fill=WHITE)
    d.line((8, 15, 17, 24), fill=WHITE, width=3)
    d.line((8, 24, 4, 28), fill=WHITE, width=3)


def g_chev(d):
    for x in (4, 13):
        d.polygon([(x, 6), (x + 8, 16), (x, 26), (x + 5, 26), (x + 13, 16), (x + 5, 6)], fill=WHITE)


def g_star(d):
    d.polygon(poly_pts(16, 16, 13, 5, -math.pi / 2, 5.5), fill=WHITE)


def g_clover(d):
    for x, y in ((11, 11), (21, 11), (11, 21), (21, 21)):
        d.ellipse((x - 6, y - 6, x + 6, y + 6), fill=WHITE)
    d.line((16, 16, 25, 29), fill=WHITE, width=2)


def g_regen(d):
    d.rectangle((13, 5, 19, 27), fill=WHITE); d.rectangle((5, 13, 27, 19), fill=WHITE)
    d.ellipse((2, 2, 30, 30), outline=WHITE, width=2)


def g_ring(d):
    d.ellipse((5, 5, 27, 27), outline=WHITE, width=4)
    d.polygon([(16, 1), (20, 6), (16, 10), (12, 6)], fill=WHITE)


def g_stat(d):
    d.polygon([(16, 3), (28, 16), (16, 29), (4, 16)], fill=WHITE)


def g_wing(d):
    d.polygon([(4, 24), (10, 8), (28, 4), (22, 12), (28, 12), (20, 18), (24, 20), (12, 26)], fill=WHITE)


GLYPH = {"arc": g_arc, "nova": g_nova, "proj": g_proj, "tgt": g_tgt, "zone": g_zone, "buff": g_buff, "heal": g_heal,
         "cleanse": g_cleanse, "dash": g_dash, "dashhit": g_dash, "slash3": g_slash3, "fireball": g_fireball,
         "lance": g_lance, "meteor": g_meteor, "shield": g_shield, "whirl": g_whirl, "rain": g_rain, "volley": g_volley,
         "bolt": g_bolt, "curse": g_curse, "book": g_book, "smoke": g_smoke, "heart": g_heart, "drop": g_drop,
         "sword": g_sword, "chev": g_chev, "star": g_star, "clover": g_clover, "regen": g_regen, "ring": g_ring,
         "stat": g_stat, "wing": g_wing}
HAND = {"a_flurry": "slash3", "a_shadow": "dash", "a_smoke": "smoke", "c_mend": "heal", "m_fire": "fireball",
        "m_lance": "lance", "m_meteor": "meteor", "p_bless": "buff", "p_curse": "curse", "p_smite": "bolt",
        "r_pierce": "proj", "r_rain": "rain", "r_volley": "volley", "w_bash": "shield", "w_cleave": "arc", "w_whirl": "whirl"}
BONUS = [("mag_atk", "star"), ("hp_regen", "regen"), ("mp_regen", "regen"), ("hp_pct", "heart"), ("heal_pct", "regen"), ("mp_pct", "drop"),
         ("atk", "sword"), ("def", "shield"), ("move", "wing"), ("aspd", "bolt"), ("crit", "star"), ("drop", "clover"),
         ("luck", "clover"), ("res_", "ring"), ("str", "sword"), ("dex", "bolt"), ("int", "star"), ("mind", "drop"), ("vit", "heart")]


def glyph_for(sid, v):
    if v["cls"] == "tome":
        return "book"
    if sid in HAND:
        return HAND[sid]
    if v["type"] == "active":
        return v["t"] if v["t"] in GLYPH else "star"
    for key, g in BONUS:
        if any(b.startswith(key) or key in b for b in v["bonus"]):
            return g
    return "stat"


def orb(col, passive):
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    for r in range(15, 0, -1):
        t = r / 15.0
        c = tuple(int(a * (0.45 + 0.55 * (1 - t))) for a in col)
        if passive:
            d.rounded_rectangle((16 - r, 16 - r, 15 + r, 15 + r), radius=max(2, r // 3), fill=c + (255,))
        else:
            d.ellipse((16 - r, 16 - r, 15 + r, 15 + r), fill=c + (255,))
    # rim + highlight
    if passive:
        d.rounded_rectangle((1, 1, 30, 30), radius=5, outline=shade(col, 0.35) + (255,), width=1)
    else:
        d.ellipse((0, 0, 31, 31), outline=shade(col, 0.35) + (255,), width=1)
    d.ellipse((6, 4, 14, 9), fill=(255, 255, 255, 60))
    return im


def make(sid, v):
    el = v["elem"]
    col = PAL.get(el, PAL["none"])
    if v["type"] == "passive" and el == "none":
        col = (205, 170, 80)
    base = orb(col, v["type"] == "passive")
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    GLYPH[glyph_for(sid, v)](ImageDraw.Draw(layer))
    # outline (dilate alpha) then tint glyph slightly toward the element colour
    alpha = layer.split()[3]
    outline = alpha.filter(ImageFilter.MaxFilter(3))
    shadow = Image.new("RGBA", (S, S), shade(col, 0.2) + (255,))
    base.paste(shadow, (0, 0), outline)
    tint = tuple(int(255 * 0.82 + c * 0.18) for c in col)
    fill = Image.new("RGBA", (S, S), tint + (255,))
    base.paste(fill, (0, 0), alpha)
    base.save("assets/skillicons/%s.png" % sid)


for sid, v in data.items():
    make(sid, v)
print("icons", len(data))
