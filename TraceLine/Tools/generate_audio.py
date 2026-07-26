#!/usr/bin/env python3
"""Generates TraceLine's sound effects procedurally.

The game ships no recorded assets by design — the icon, art and levels are all made in
code, and the audio is too. These are short synthesized cues matching the minimal neon
aesthetic: soft sine tones with clean envelopes, no samples, no libraries beyond numpy.

Re-run after changing a cue:

    python3 Tools/generate_audio.py

Writes TraceLine/Resources/Audio/*.caf-equivalent WAVs (16-bit PCM, 44.1kHz, mono).
"""

import math
import struct
import wave
from pathlib import Path

import numpy as np

RATE = 44_100


def envelope(n, attack=0.005, release=0.08):
    """A click-free amplitude envelope: quick attack, exponential release."""
    env = np.ones(n)
    a = int(attack * RATE)
    r = int(release * RATE)
    if a > 0:
        env[:a] = np.linspace(0, 1, a)
    if r > 0:
        env[-r:] = np.linspace(1, 0, r) ** 2
    return env


def tone(freq, dur, *, kind="sine", vol=0.6, attack=0.005, release=None):
    n = int(dur * RATE)
    t = np.arange(n) / RATE
    if kind == "sine":
        wave_ = np.sin(2 * np.pi * freq * t)
    elif kind == "triangle":
        wave_ = 2 * np.abs(2 * (t * freq - np.floor(t * freq + 0.5))) - 1
    elif kind == "sweep":       # freq is (start, end)
        f0, f1 = freq
        inst = np.linspace(f0, f1, n)
        phase = 2 * np.pi * np.cumsum(inst) / RATE
        wave_ = np.sin(phase)
    elif kind == "noise":
        wave_ = np.random.uniform(-1, 1, n)
    else:
        raise ValueError(kind)
    rel = release if release is not None else min(0.12, dur * 0.6)
    return wave_ * envelope(n, attack, rel) * vol


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[:len(p)] += p
    return out


def pad(sig, dur):
    n = int(dur * RATE)
    if len(sig) >= n:
        return sig[:n]
    return np.concatenate([sig, np.zeros(n - len(sig))])


def write(name, sig):
    sig = np.clip(sig, -1, 1)
    data = (sig * 32767).astype("<i2").tobytes()
    out = Path(__file__).resolve().parent.parent / "TraceLine/Resources/Audio" / f"{name}.wav"
    out.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(out), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data)
    print(f"wrote {out.name}  ({len(sig)/RATE*1000:.0f}ms)")


# --- The cues -------------------------------------------------------------------------

# tap: a soft, short blip. Menu and button feedback.
write("tap", tone(660, 0.05, vol=0.35, release=0.045))

# nearMiss: a quiet high tick — you skimmed a hazard.
write("nearMiss", tone(1180, 0.04, vol=0.22, release=0.035))

# cut: a short bright downward zap — the line was severed.
write("cut", mix(
    tone((1400, 500), 0.14, kind="sweep", vol=0.4),
    tone(220, 0.14, kind="triangle", vol=0.12, release=0.12),
))

# fail: a soft descending two-tone. Not harsh — a sigh, not a buzzer.
write("fail", pad(mix(
    tone(392, 0.16, kind="triangle", vol=0.4, release=0.14),
    np.concatenate([np.zeros(int(0.12 * RATE)),
                    tone(294, 0.28, kind="triangle", vol=0.4, release=0.24)]),
), 0.42))

# win: a rising major arpeggio (C–E–G–C), bright and clean.
notes = [523.25, 659.25, 783.99, 1046.50]
parts = []
for i, f in enumerate(notes):
    delay = int(i * 0.075 * RATE)
    parts.append(np.concatenate([np.zeros(delay),
                                 tone(f, 0.32, vol=0.34, release=0.28)]))
write("win", pad(mix(*parts), 0.62))

print("\nGenerated 5 cues.")
