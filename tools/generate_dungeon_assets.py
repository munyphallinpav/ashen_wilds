"""Sprites for dungeon monster spawners (assets/world/spawner_<biome>.png) and the Mimic (assets/mobs/mimic.png).
Run from the project root: python3 tools/generate_dungeon_assets.py"""
from PIL import Image, ImageDraw
import random

def hexc(h): h = h.lstrip('#'); return tuple(int(h[i:i+2], 16) for i in (0, 2, 4)) + (255,)
OUT = hexc('#1a1216')

def mimic_frame(f):
    im = Image.new('RGBA', (32, 32), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    bounce = [0, -2, 0, -1][f]
    open_ = [2, 5, 7, 4][f]
    y0 = 14 + bounce
    # body
    d.rectangle([5, y0 + 6, 26, y0 + 15], fill=hexc('#8a5a2c'), outline=OUT)
    d.rectangle([5, y0 + 11, 26, y0 + 12], fill=hexc('#c99a3c'))
    d.rectangle([14, y0 + 9, 17, y0 + 14], fill=hexc('#e8c050'), outline=OUT)
    # mouth gap
    d.rectangle([6, y0 + 3 - open_ // 2, 25, y0 + 6], fill=hexc('#5a0f1a'))
    for x in range(7, 25, 3):   # lower teeth
        d.polygon([(x, y0 + 6), (x + 1, y0 + 3), (x + 2, y0 + 6)], fill=hexc('#f4f0e0'))
    d.rectangle([11, y0 + 4, 20, y0 + 5], fill=hexc('#d0507a'))  # tongue
    # lid (lifts with open_)
    ly = y0 - open_
    d.rectangle([5, ly - 6, 26, ly + 2], fill=hexc('#a06a34'), outline=OUT)
    d.rectangle([5, ly - 2, 26, ly - 1], fill=hexc('#c99a3c'))
    for x in range(7, 25, 3):   # upper teeth
        d.polygon([(x, ly + 2), (x + 1, ly + 5), (x + 2, ly + 2)], fill=hexc('#f4f0e0'))
    # eyes
    d.rectangle([10, ly - 5, 12, ly - 3], fill=hexc('#ffe040')); d.rectangle([19, ly - 5, 21, ly - 3], fill=hexc('#ffe040'))
    d.point((11, ly - 4), fill=OUT); d.point((20, ly - 4), fill=OUT)
    # feet
    d.rectangle([7, y0 + 16, 11, y0 + 17], fill=hexc('#5a3a1c')); d.rectangle([20, y0 + 16, 24, y0 + 17], fill=hexc('#5a3a1c'))
    return im

def mimic():
    sheet = Image.new('RGBA', (128, 32), (0, 0, 0, 0))
    for f in range(4): sheet.alpha_composite(mimic_frame(f), (f * 32, 0))
    sheet.save('assets/mobs/mimic.png')

SPAWNERS = {   # biome: (stone, crystal, glow, shape)
    'lava': ('#4a3030', '#ff7a20', '#ffc060', 'vent'),
    'forest': ('#4a3a24', '#5ac850', '#b8f080', 'roots'),
    'mushroom': ('#443a60', '#d090ff', '#f0d0ff', 'pod'),
    'plains': ('#6a6a70', '#e8d060', '#fff0a0', 'totem'),
    'beach': ('#2a5a6a', '#50d0e0', '#b0f4ff', 'hive'),
    'cave': ('#3a3a44', '#c0c8d8', '#ffffff', 'altar'),
}

def spawner(biome):
    stone, cry, glow, shape = [hexc(c) if c.startswith('#') else c for c in SPAWNERS[biome]]
    rnd = random.Random(hash(biome) & 0xffff)
    im = Image.new('RGBA', (32, 32), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    d.ellipse([3, 24, 28, 31], fill=(0, 0, 0, 80))
    # pedestal (3 tiers)
    d.rectangle([6, 22, 25, 28], fill=stone, outline=OUT)
    d.rectangle([8, 18, 23, 22], fill=tuple(min(255, c + 18) for c in stone[:3]) + (255,), outline=OUT)
    d.rectangle([6, 28, 25, 28], fill=OUT)
    for x in range(7, 25, 4): d.line([x, 23, x, 27], fill=tuple(max(0, c - 22) for c in stone[:3]) + (255,))
    cx = 15
    if shape in ('vent', 'hive'):
        d.polygon([(10, 18), (21, 18), (19, 9), (12, 9)], fill=cry, outline=OUT)
        d.polygon([(13, 9), (18, 9), (16, 3)], fill=glow, outline=OUT)
    elif shape in ('roots', 'pod'):
        d.ellipse([8, 4, 23, 19], fill=cry, outline=OUT)
        d.ellipse([11, 6, 16, 11], fill=glow)
        for x in (7, 24): d.line([x, 18, x + (-2 if x < 15 else 2), 12], fill=hexc('#2a6a2a') if shape == 'roots' else hexc('#7a50b0'), width=2)
    elif shape == 'totem':
        d.rectangle([11, 4, 20, 18], fill=stone, outline=OUT)
        d.rectangle([13, 8, 14, 10], fill=cry); d.rectangle([17, 8, 18, 10], fill=cry)
        d.rectangle([13, 13, 18, 14], fill=cry)
    else:
        d.polygon([(15, 3), (22, 12), (15, 19), (8, 12)], fill=cry, outline=OUT)
        d.polygon([(15, 5), (19, 12), (15, 12)], fill=glow)
    im.save('assets/world/spawner_%s.png' % biome)

if __name__ == '__main__':
    mimic()
    for b in SPAWNERS: spawner(b)
