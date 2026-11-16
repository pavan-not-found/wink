"""Synthesises the launch film's sound: a soft chord bed plus sounds on the visible actions.
Run: python3 launch/tools/score.py launch/film/assets/audio/score.wav"""
import sys, wave, numpy as np
SR = 44100
DUR = 25.0
n = int(SR * DUR)
t = np.arange(n) / SR
out = np.zeros(n)

def note(freq):
    return 440.0 * 2 ** ((freq - 69) / 12)

def pad(start, length, midi_notes, gain=0.05):
    i0, i1 = int(start * SR), min(n, int((start + length) * SR))
    tt = np.arange(i1 - i0) / SR
    env = np.minimum(1, tt / 1.2) * np.minimum(1, (length - tt) / 1.5)
    env = np.clip(env, 0, 1) ** 1.5
    sig = np.zeros_like(tt)
    for m in midi_notes:
        f = note(m)
        sig += np.sin(2 * np.pi * f * tt) + 0.25 * np.sin(2 * np.pi * 2 * f * tt + 0.3)
        sig += 0.5 * np.sin(2 * np.pi * f * 1.003 * tt)  # slight chorus
    out[i0:i1] += gain * env * sig / len(midi_notes)

def tick(at, freq=2400, gain=0.12, decay=0.012):
    i0 = int(at * SR); L = int(0.06 * SR)
    tt = np.arange(L) / SR
    out[i0:i0 + L] += gain * np.exp(-tt / decay) * np.sin(2 * np.pi * freq * tt)

def click(at):
    i0 = int(at * SR); L = int(0.05 * SR)
    tt = np.arange(L) / SR
    noise = np.random.default_rng(int(at * 1000)).standard_normal(L)
    out[i0:i0 + L] += 0.10 * np.exp(-tt / 0.006) * noise
    tick(at, 1500, 0.10, 0.02)

def thud(at):
    i0 = int(at * SR); L = int(0.5 * SR)
    tt = np.arange(L) / SR
    f = 95 * np.exp(-tt * 3)
    out[i0:i0 + L] += 0.35 * np.exp(-tt / 0.09) * np.sin(2 * np.pi * np.cumsum(f) / SR)

def chime(at, gain=0.14):
    i0 = int(at * SR); L = int(2.5 * SR)
    tt = np.arange(L) / SR
    sig = sum(a * np.sin(2 * np.pi * note(m) * tt) for m, a in [(76, 1), (83, 0.6), (88, 0.35)])
    out[i0:i0 + L] += gain * np.exp(-tt / 0.7) * np.minimum(1, tt / 0.005) * sig

# chord bed: Fmaj9 → Am7 → Cmaj7 → Fmaj9 resolving on the end card
pad(0.0, 7.2, [53, 57, 60, 64, 67])
pad(6.4, 7.0, [57, 60, 64, 67])
pad(12.8, 8.2, [48, 52, 55, 59, 62])
pad(20.2, 4.8, [53, 57, 60, 64, 69], gain=0.055)

# actions (times match index.html)
thud(3.65); thud(14.75)
click(8.55); click(11.85)
for i in range(5): tick(9.8 + i * 0.2)
chime(21.45)

# gentle room: two feedback echoes
for delay, g in [(0.083, 0.25), (0.137, 0.18)]:
    d = int(delay * SR); out[d:] += g * out[:-d]

out /= max(1e-9, np.abs(out).max()) / 0.8
fade = int(0.8 * SR); out[-fade:] *= np.linspace(1, 0, fade)
pcm = (out * 32767).astype(np.int16)
with wave.open(sys.argv[1], "wb") as w:
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(pcm.tobytes())
print("wrote", sys.argv[1])
