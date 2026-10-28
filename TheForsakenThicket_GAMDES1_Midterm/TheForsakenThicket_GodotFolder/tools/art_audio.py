"""Procedural sound effects + two music loops (22.05 kHz mono 16-bit WAV).
Original audio made from code, so there are no licence issues."""
import wave, struct, math, random, os
from art_common import GEN, out_dir

SR = 22050
rnd = random.Random(5)


def write(name, samples, folder="audio"):
    p = os.path.join(out_dir(folder), name)
    with wave.open(p, "w") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", max(-32767, min(32767, int(s * 32767)))) for s in samples))


def env(i, n, a=0.01, r=0.2):
    t = i / SR; dur = n / SR
    if t < a: return t / a
    if t > dur - r: return max(0, (dur - t) / r)
    return 1.0


def tone(freq, dur, kind="square", vol=0.4, slide=0.0, a=0.005, r=0.1, duty=0.5):
    n = int(dur * SR); out = []; ph = 0.0
    for i in range(n):
        f = freq + slide * (i / n)
        ph += f / SR
        x = ph % 1.0
        if kind == "square": v = 1.0 if x < duty else -1.0
        elif kind == "tri": v = 4 * abs(x - 0.5) - 1
        elif kind == "saw": v = 2 * x - 1
        elif kind == "noise": v = rnd.uniform(-1, 1)
        else: v = math.sin(2 * math.pi * x)
        out.append(v * vol * env(i, n, a, r))
    return out


def mix(*tracks):
    n = max(len(t) for t in tracks)
    out = [0.0] * n
    for t in tracks:
        for i, v in enumerate(t): out[i] += v
    return [max(-1, min(1, v)) for v in out]


def seq(*parts):
    out = []
    for p in parts: out += p
    return out


def lowpass(x, k=0.2):
    y = []; p = 0.0
    for v in x:
        p += (v - p) * k; y.append(p)
    return y


def sfx():
    write("attack.wav", mix(lowpass(tone(0, 0.18, "noise", 0.5, a=0.01, r=0.15), 0.35), tone(500, 0.12, "tri", 0.2, slide=-320, r=0.1)))
    write("hit.wav", mix(lowpass(tone(0, 0.14, "noise", 0.7, r=0.12), 0.25), tone(140, 0.12, "sine", 0.6, slide=-60, r=0.1)))
    write("hurt.wav", mix(tone(190, 0.28, "saw", 0.35, slide=-110, r=0.2), lowpass(tone(0, 0.2, "noise", 0.3), 0.3)))
    write("skill.wav", tone(420, 0.28, "square", 0.25, slide=650, r=0.2, duty=0.25))
    write("skill_hit.wav", mix(lowpass(tone(0, 0.2, "noise", 0.5, r=0.18), 0.4), tone(700, 0.15, "tri", 0.3, slide=-500)))
    write("dodge.wav", lowpass(tone(0, 0.22, "noise", 0.55, a=0.04, r=0.18), 0.18))
    write("pickup.wav", seq(tone(880, 0.06, "square", 0.22, r=0.03), tone(1320, 0.1, "square", 0.22, r=0.06)))
    write("gather.wav", mix(lowpass(tone(0, 0.1, "noise", 0.7, r=0.08), 0.3), tone(180, 0.1, "square", 0.25, slide=-80, r=0.08)))
    write("break.wav", mix(lowpass(tone(0, 0.35, "noise", 0.8, r=0.3), 0.3), tone(120, 0.3, "sine", 0.5, slide=-60, r=0.25)))
    write("till.wav", lowpass(tone(0, 0.18, "noise", 0.6, r=0.15), 0.2))
    write("plant.wav", seq(tone(300, 0.07, "tri", 0.3, r=0.05), tone(380, 0.09, "tri", 0.3, r=0.06)))
    write("water.wav", lowpass(tone(0, 0.5, "noise", 0.35, a=0.1, r=0.3), 0.12))
    write("harvest.wav", seq(tone(660, 0.07, "square", 0.2, r=0.04), tone(880, 0.07, "square", 0.2, r=0.04), tone(1100, 0.12, "square", 0.2, r=0.08)))
    write("craft.wav", seq(tone(1000, 0.05, "square", 0.25, r=0.03), tone(0, 0.03, "square", 0.0), tone(1000, 0.05, "square", 0.25, r=0.03), tone(1500, 0.2, "tri", 0.3, r=0.15)))
    write("quest.wav", seq(tone(523, 0.12, "square", 0.22), tone(659, 0.12, "square", 0.22), tone(784, 0.12, "square", 0.22), tone(1046, 0.35, "square", 0.22, r=0.3)))
    write("gate.wav", mix(lowpass(tone(0, 1.0, "noise", 0.6, a=0.1, r=0.5), 0.1), tone(70, 1.0, "saw", 0.3, slide=-20, r=0.5)))
    write("ui_click.wav", tone(700, 0.05, "square", 0.2, r=0.03))
    write("ui_deny.wav", tone(160, 0.18, "square", 0.25, slide=-30, r=0.1))
    write("talk.wav", tone(420, 0.04, "square", 0.12, r=0.02))
    write("drink.wav", seq(tone(300, 0.08, "sine", 0.4, slide=200, r=0.05), tone(380, 0.08, "sine", 0.4, slide=200, r=0.05), tone(460, 0.1, "sine", 0.4, slide=150, r=0.08)))
    write("sleep.wav", seq(tone(392, 0.25, "tri", 0.25, r=0.2), tone(330, 0.25, "tri", 0.25, r=0.2), tone(262, 0.5, "tri", 0.25, r=0.4)))
    write("shrine.wav", mix(seq(tone(784, 0.18, "sine", 0.3, r=0.1), tone(988, 0.18, "sine", 0.3, r=0.1), tone(1318, 0.5, "sine", 0.3, r=0.4)), seq(tone(392, 0.9, "sine", 0.15, r=0.5))))
    write("alert.wav", tone(900, 0.1, "square", 0.18, slide=300, r=0.06))
    write("slam.wav", mix(lowpass(tone(0, 0.5, "noise", 0.9, r=0.4), 0.15), tone(60, 0.5, "sine", 0.8, slide=-25, r=0.4)))
    write("die.wav", mix(tone(260, 0.8, "saw", 0.3, slide=-200, r=0.6), lowpass(tone(0, 0.8, "noise", 0.3, r=0.6), 0.2)))
    write("win.wav", seq(tone(523, 0.15, "square", 0.22), tone(659, 0.15, "square", 0.22), tone(784, 0.15, "square", 0.22), tone(1046, 0.15, "square", 0.22), tone(784, 0.15, "square", 0.22), tone(1046, 0.6, "square", 0.22, r=0.5)))
    write("equip.wav", seq(tone(500, 0.06, "square", 0.2), tone(750, 0.1, "square", 0.2, r=0.06)))


NOTE = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def hz(n, octave=4):
    return 440.0 * 2 ** ((NOTE[n[0]] + (1 if n.endswith("#") else 0) - 9 + (octave - 4) * 12) / 12)


def music(name, bpm, chords, melody_notes, mode_vol=0.16, bass_oct=2, lead_kind="tri", seed=1):
    r = random.Random(seed)
    beat = 60.0 / bpm
    bars = len(chords)
    total = int(bars * 4 * beat * SR)
    out = [0.0] * total
    def add(wave_, start):
        s = int(start * SR)
        for i, v in enumerate(wave_):
            if s + i < total: out[s + i] += v
    for b, chord in enumerate(chords):
        t0 = b * 4 * beat
        root = chord[0]
        add(tone(hz(root, bass_oct), 2 * beat, "tri", 0.28, a=0.01, r=beat * 0.6), t0)
        add(tone(hz(root, bass_oct), 2 * beat, "tri", 0.28, a=0.01, r=beat * 0.6), t0 + 2 * beat)
        for k, n in enumerate(chord):
            add(tone(hz(n, 3), 4 * beat, "sine", mode_vol * 0.6, a=0.15, r=beat * 1.5), t0)
        # melody: 8 eighth notes picked from the scale, with rests
        scale = melody_notes
        prev = r.randrange(len(scale))
        for e in range(8):
            if r.random() < 0.35: continue
            prev = max(0, min(len(scale) - 1, prev + r.choice([-2, -1, -1, 0, 1, 1, 2])))
            add(tone(hz(scale[prev], 5), beat * 0.9, lead_kind, mode_vol, a=0.01, r=beat * 0.5), t0 + e * beat / 2)
    peak = max(abs(v) for v in out) or 1
    write(name, [v / peak * 0.8 for v in out], folder="audio")


def run():
    sfx()
    # calm ranch theme (C major pentatonic, 84 bpm)
    music("bgm_ranch.wav", 84, [["C", "E", "G"], ["A", "C", "E"], ["F", "A", "C"], ["G", "B", "D"]] * 2,
          ["C", "D", "E", "G", "A"], seed=3)
    # danger theme (A minor, faster)
    music("bgm_danger.wav", 112, [["A", "C", "E"], ["F", "A", "C"], ["G", "B", "D"], ["E", "G", "B"]] * 2,
          ["A", "C", "D", "E", "G"], lead_kind="square", mode_vol=0.1, seed=9)
