"""Procedural audio: music loops (assets/music/*.ogg) and sound effects (assets/sfx/*.ogg).
Needs numpy + ffmpeg. Run from the project root: python3 tools/generate_audio.py"""
import numpy as np, subprocess, os, random, wave, sys
SR = 22050
rng = np.random.default_rng(7)

def midi(n): return 440.0 * 2 ** ((n - 69) / 12.0)
def t_(d): return np.arange(int(d * SR)) / SR
def env(n, a=0.01, d=0.1, s=0.7, r=0.1):
    e = np.ones(n)
    a_, d_, r_ = int(a * SR), int(d * SR), int(r * SR)
    a_ = max(1, min(a_, n)); e[:a_] = np.linspace(0, 1, a_)
    d_ = min(d_, n - a_)
    if d_ > 0: e[a_:a_ + d_] = np.linspace(1, s, d_)
    e[a_ + d_:] = s
    r_ = min(r_, n)
    if r_ > 0: e[-r_:] *= np.linspace(1, 0, r_)
    return e
def lp(x, cutoff):
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.zeros_like(x); p = 0.0
    # simple one-pole via lfilter-free loop (vectorised chunks are overkill; arrays are short)
    from scipy.signal import lfilter
    return lfilter([1 - a], [1, -a], x)
def hp(x, cutoff): return x - lp(x, cutoff)

def tone(f, d, wave='sine', vib=0.0, harm=None):
    t = t_(d)
    ph = 2 * np.pi * f * t + (vib * np.sin(2 * np.pi * 5.0 * t) if vib else 0)
    if wave == 'sine': y = np.sin(ph)
    elif wave == 'tri': y = 2 / np.pi * np.arcsin(np.sin(ph))
    elif wave == 'saw': y = 2 * ((f * t) % 1.0) - 1
    elif wave == 'square': y = np.sign(np.sin(ph))
    elif wave == 'fm': y = np.sin(ph + 2.2 * np.sin(2 * np.pi * f * 3.5 * t) * np.exp(-3 * t))
    else: y = np.sin(ph)
    return y

def inst_pluck(f, d):
    y = tone(f, d, 'tri') * 0.7 + tone(f * 2, d, 'sine') * 0.25
    return y * np.exp(-t_(d) * 5.5) 
def inst_bell(f, d):
    y = tone(f, d, 'fm')
    return y * np.exp(-t_(d) * 2.2)
def inst_flute(f, d):
    y = tone(f, d, 'sine', vib=0.6) + 0.18 * tone(f * 2, d, 'sine') + 0.05 * rng.standard_normal(int(d * SR))
    return y * env(len(y), 0.06, 0.1, 0.8, 0.12)
def inst_pad(f, d):
    y = sum(tone(f * m, d, 'saw') for m in (0.996, 1.0, 1.004)) / 3
    y = lp(y, min(1400, f * 3.2))
    return y * env(len(y), 0.5, 0.3, 0.8, 0.6)
def inst_bass(f, d, wave='tri'):
    y = tone(f, d, wave) + 0.4 * tone(f * 2, d, 'sine')
    return lp(y, 600) * env(len(y), 0.01, 0.15, 0.7, 0.08)
def inst_brass(f, d):
    y = lp(tone(f, d, 'saw') + tone(f * 1.005, d, 'saw'), 1800) * 0.5
    return y * env(len(y), 0.05, 0.12, 0.8, 0.1)
def kick(d=0.25):
    t = t_(d); f = 120 * np.exp(-t * 18) + 40
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 11)
def snare(d=0.2):
    t = t_(d); return (hp(rng.standard_normal(len(t)), 1500) * 0.7 + np.sin(2 * np.pi * 190 * t) * 0.3) * np.exp(-t * 18)
def hat(d=0.06):
    t = t_(d); return hp(rng.standard_normal(len(t)), 5000) * np.exp(-t * 60) * 0.5
def shaker(d=0.08):
    t = t_(d); return hp(rng.standard_normal(len(t)), 4000) * np.exp(-t * 35) * 0.4

def place(buf, x, at):
    i = int(at * SR)
    n = min(len(x), len(buf) - i)
    if n > 0: buf[i:i + n] += x[:n]

SCALES = {'major': [0, 2, 4, 5, 7, 9, 11], 'minor': [0, 2, 3, 5, 7, 8, 10], 'dorian': [0, 2, 3, 5, 7, 9, 10],
          'phrygian': [0, 1, 3, 5, 7, 8, 10], 'lydian': [0, 2, 4, 6, 7, 9, 11], 'mixolydian': [0, 2, 4, 5, 7, 9, 10],
          'pent': [0, 2, 4, 7, 9], 'minpent': [0, 3, 5, 7, 10], 'whole': [0, 2, 4, 6, 8, 10], 'locrian': [0, 1, 3, 5, 6, 8, 10]}

def deg(scale, root, d):
    s = SCALES[scale]; o, i = divmod(d, len(s)); return root + 12 * o + s[i]

def make_track(name, root, scale, bpm, chords, pad=1.0, arp=None, melody=None, bass=None, drums=None, delay=0.3, seed=1, bars=16, lead='flute', mel_density=0.5, arp_inst='pluck'):
    r = random.Random(seed)
    beat = 60.0 / bpm; bar = beat * 4; total = bar * bars
    buf = np.zeros(int((total + 3.0) * SR))
    ilen = len(chords)
    for b in range(bars):
        ch = chords[b % ilen]
        t0 = b * bar
        tri = [deg(scale, root, ch + k) for k in (0, 2, 4)]
        if pad:
            for n in tri: place(buf, inst_pad(midi(n - 12), bar + 0.4) * 0.16 * pad, t0)
        if bass:
            for s in range(4 if bass != 'half' else 2):
                dur = beat if bass != 'half' else beat * 2
                place(buf, inst_bass(midi(tri[0] - 24), dur * 0.9) * 0.4, t0 + s * dur)
        if arp:
            order = [0, 1, 2, 1] if arp == 'up' else [0, 2, 1, 2]
            step = beat / 2 if arp != 'slow' else beat
            for s in range(int(bar / step)):
                n = tri[order[s % 4]] + (12 if s % 8 >= 4 and arp != 'slow' else 0)
                f = inst_bell if arp_inst == 'bell' else inst_pluck
                place(buf, f(midi(n), 0.9) * 0.22, t0 + s * step)
        if melody:
            pos = 0.0
            cur = ch + 4 + r.randrange(0, 3)
            while pos < bar - 0.01:
                if r.random() < mel_density + 0.25:
                    cur += r.choice([-2, -1, -1, 1, 1, 2, 0])
                    cur = max(ch - 1, min(ch + 9, cur))
                    ln = r.choice([beat, beat, beat * 2, beat * 1.5, beat * 0.5])
                    ln = min(ln, bar - pos)
                    n = deg(scale, root, cur) + 12
                    f = {'flute': inst_flute, 'bell': inst_bell, 'brass': inst_brass, 'pluck': inst_pluck}[lead]
                    place(buf, f(midi(n), ln * 1.05) * 0.26, t0 + pos)
                    pos += ln
                else:
                    pos += beat * 0.5
        if drums:
            for s in range(8):
                tt = t0 + s * beat / 2
                if drums in ('march', 'rock', 'slow'):
                    if s % 4 == 0: place(buf, kick() * 0.5, tt)
                    if s in (2, 6) and drums != 'slow': place(buf, snare() * 0.35, tt)
                    if drums == 'rock' or s % 2 == 0: place(buf, hat() * 0.5, tt)
                    if drums == 'slow' and s == 4: place(buf, snare() * 0.3, tt)
                if drums == 'shake' and s % 2 == 1: place(buf, shaker() * 0.5, tt)
                if drums == 'drip' and s == 3 and b % 2 == 0: place(buf, inst_bell(midi(root + 36), 1.2) * 0.12, tt)
    # delay (echo) for space
    if delay:
        d = int(beat * 0.75 * SR)
        for k in range(1, 5):
            buf[d * k:] += buf[:len(buf) - d * k] * (delay ** k)
    # seamless loop: fold the tail onto the head
    n = int(total * SR)
    out = buf[:n].copy(); tail = buf[n:]
    out[:len(tail)] += tail[:n]
    out = lp(out, 9000)
    out = out / (np.max(np.abs(out)) + 1e-9) * 0.85
    return out

def save(name, data, folder):
    path = f'assets/{folder}/{name}'
    pcm = (np.clip(data, -1, 1) * 32767).astype(np.int16)
    wavp = f'/tmp/{name}.wav'
    with wave.open(wavp, 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(pcm.tobytes())
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', wavp, '-c:a', 'libvorbis', '-q:a', '3', path + '.ogg'], check=True)
    os.remove(wavp)

def music():
    T = {
     'title':      dict(root=57, scale='minor', bpm=72, chords=[0, 5, 2, 4], arp='slow', arp_inst='bell', melody=True, lead='bell', mel_density=0.2, bass='half', delay=0.4, seed=3),
     'town':       dict(root=60, scale='major', bpm=112, chords=[0, 4, 5, 3], arp='up', melody=True, lead='flute', bass=True, drums='shake', delay=0.25, seed=5, mel_density=0.6),
     'wild_day':   dict(root=62, scale='pent', bpm=86, chords=[0, 2, 1, 3], arp='slow', melody=True, lead='flute', bass='half', delay=0.35, seed=8, mel_density=0.3),
     'wild_night': dict(root=57, scale='minpent', bpm=64, chords=[0, 2, 0, 3], arp='slow', arp_inst='bell', melody=False, bass='half', drums='drip', delay=0.45, seed=11),
     'boss':       dict(root=50, scale='minor', bpm=140, chords=[0, 5, 3, 4], arp='up', melody=True, lead='brass', bass=True, drums='rock', delay=0.2, seed=13, mel_density=0.6),
     'lava':       dict(root=52, scale='phrygian', bpm=100, chords=[0, 1, 0, 6], melody=True, lead='brass', mel_density=0.3, bass=True, drums='slow', delay=0.3, seed=17),
     'forest':     dict(root=55, scale='dorian', bpm=84, chords=[0, 3, 0, 4], arp='up', melody=True, lead='flute', bass='half', drums='shake', delay=0.35, seed=19, mel_density=0.4),
     'mushroom':   dict(root=60, scale='lydian', bpm=76, chords=[0, 1, 3, 1], arp='up', arp_inst='bell', melody=True, lead='bell', bass='half', delay=0.5, seed=23, mel_density=0.35),
     'plains':     dict(root=53, scale='mixolydian', bpm=80, chords=[0, 3, 4, 0], arp='up', melody=True, lead='pluck', bass='half', delay=0.35, seed=29, mel_density=0.4),
     'beach':      dict(root=58, scale='pent', bpm=70, chords=[0, 3, 1, 2], arp='slow', arp_inst='bell', melody=True, lead='bell', bass='half', delay=0.55, seed=31, mel_density=0.25),
     'cave':       dict(root=48, scale='locrian', bpm=60, chords=[0, 0, 1, 0], arp='slow', arp_inst='bell', melody=False, bass='half', drums='drip', delay=0.5, seed=37),
    }
    for k, v in T.items():
        print('music', k); sys.stdout.flush()
        save(k, make_track(k, **v), 'music')

# ------------------------------------------------------------ sfx
def noise(d): return rng.standard_normal(int(d * SR))
def sweep(f0, f1, d, wave='sine'):
    t = t_(d); f = np.linspace(f0, f1, len(t)); ph = 2 * np.pi * np.cumsum(f) / SR
    return np.sign(np.sin(ph)) if wave == 'square' else np.sin(ph)
def padd(a, b):
    n = max(len(a), len(b)); o = np.zeros(n); o[:len(a)] += a; o[:len(b)] += b; return o
def fx(name, data, vol=0.8):
    data = data / (np.max(np.abs(data)) + 1e-9) * vol
    save(name, data, 'sfx')

def sfx():
    t = lambda d: t_(d)
    fx('swing', hp(lp(noise(0.18), 4000), 800) * np.sin(np.linspace(0, np.pi, int(0.18 * SR))) ** 1.5)
    fx('hit', (lp(noise(0.12), 2500) + sweep(220, 70, 0.12) * 1.2) * np.exp(-t(0.12) * 25))
    fx('crit', (lp(noise(0.2), 4000) + sweep(500, 90, 0.2, 'square') * 0.5 + sweep(900, 300, 0.2) * 0.4) * np.exp(-t(0.2) * 14))
    fx('hurt', (sweep(320, 110, 0.22, 'square') * 0.6 + lp(noise(0.22), 1500) * 0.6) * np.exp(-t(0.22) * 9))
    fx('enemy_die', (sweep(300, 40, 0.4) + lp(noise(0.4), 1200) * 0.7) * np.exp(-t(0.4) * 7))
    fx('bow', (hp(lp(noise(0.14), 3000), 700) * 0.8 + sweep(900, 200, 0.14) * 0.5) * np.exp(-t(0.14) * 16))
    fx('gun', (lp(noise(0.2), 5000) * np.exp(-t(0.2) * 22) + sweep(150, 40, 0.2) * np.exp(-t(0.2) * 15)))
    fx('cast', (sweep(300, 1100, 0.3) * 0.6 + sweep(450, 1650, 0.3) * 0.3) * env(int(0.3 * SR), 0.03, 0.1, 0.8, 0.12))
    fx('magic_hit', (sweep(1200, 400, 0.25) * 0.6 + lp(noise(0.25), 3000) * 0.4) * np.exp(-t(0.25) * 12))
    fx('heal', sum(tone(f, 0.45, 'sine') * np.exp(-t(0.45) * 4) for f in (523, 659, 784, 1047)))
    fx('buff', sum(sweep(f, f * 1.5, 0.4) * 0.5 for f in (330, 495)) * env(int(0.4 * SR), 0.05, 0.1, 0.7, 0.2))
    fx('dash', hp(lp(noise(0.25), 3500), 300) * np.sin(np.linspace(0, np.pi, int(0.25 * SR))) ** 0.7 * 0.8)
    fx('coin', padd(tone(1319, 0.3, 'square') * 0.3 * np.exp(-t(0.3) * 12), np.concatenate([np.zeros(int(0.07 * SR)), tone(1760, 0.23, 'square') * 0.3 * np.exp(-t(0.23) * 12)])))
    fx('pickup', sweep(500, 1000, 0.12) * np.exp(-t(0.12) * 14))
    fx('levelup', np.concatenate([tone(f, 0.16, 'square') * 0.4 * np.exp(-np.linspace(0, 3, int(0.16 * SR))) for f in (523, 659, 784, 1047, 1319)] + [tone(1568, 0.5, 'tri') * np.exp(-t(0.5) * 4)]))
    fx('chest', np.concatenate([lp(noise(0.12), 900) * np.exp(-t(0.12) * 25) * 1.2, np.zeros(int(0.05 * SR)), sum(tone(f, 0.5, 'sine') * np.exp(-t(0.5) * 5) for f in (784, 988, 1175))]))
    fx('click', tone(900, 0.04, 'square') * np.exp(-t(0.04) * 70) * 0.8)
    fx('equip', (lp(noise(0.1), 3000) * np.exp(-t(0.1) * 30) + sweep(400, 250, 0.1) * 0.5))
    fx('buy', padd(tone(1000, 0.08, 'square') * np.exp(-t(0.08) * 25) * 0.4, np.concatenate([np.zeros(int(0.06 * SR)), tone(1500, 0.12, 'square') * np.exp(-t(0.12) * 20) * 0.4])))
    fx('error', tone(160, 0.2, 'square') * np.exp(-t(0.2) * 8) * 0.6)
    fx('portal', (sweep(200, 900, 0.9) * 0.5 + sweep(205, 910, 0.9) * 0.5) * env(int(0.9 * SR), 0.2, 0.2, 0.6, 0.4))
    fx('teleport', (sweep(1000, 150, 0.7) * 0.6 + lp(noise(0.7), 2500) * 0.3) * env(int(0.7 * SR), 0.02, 0.1, 0.7, 0.4))
    fx('boss_roar', (sweep(110, 50, 1.0, 'square') * 0.5 + lp(noise(1.0), 900) * 0.8) * env(int(1.0 * SR), 0.05, 0.3, 0.7, 0.4))
    fx('eat', lp(noise(0.25), 1800) * np.abs(np.sin(np.linspace(0, 12 * np.pi, int(0.25 * SR)))) * 0.8)
    fx('chop', (lp(noise(0.12), 1500) + sweep(180, 90, 0.12)) * np.exp(-t(0.12) * 20))
    fx('mine', (tone(1800, 0.15, 'sine') * 0.4 + hp(noise(0.15), 2000) * 0.4) * np.exp(-t(0.15) * 25))
    fx('spike', (hp(noise(0.12), 1500) + sweep(800, 300, 0.12) * 0.5) * np.exp(-t(0.12) * 25))
    fx('step', lp(noise(0.06), 900) * np.exp(-t(0.06) * 45) * 0.5, 0.35)
    fx('death', sweep(400, 60, 1.2) * np.exp(-t(1.2) * 3))

if __name__ == '__main__':
    what = sys.argv[1] if len(sys.argv) > 1 else 'all'
    if what in ('all', 'sfx'): sfx()
    if what in ('all', 'music'): music()
