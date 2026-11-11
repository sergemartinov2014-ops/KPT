"""Synthetic night-sound generator for Somnia.

The generator is intentionally *not* a claim about real-world accuracy: it
exists to pin feature definitions, train an initial model and run measurable
experiments before labelled nights are available.

Classes: ``snore``, ``talk``, ``movement``, ``ambient``.

CLI::

    python -m tools.somnia_audio.synth --out tools/somnia_audio/data/synth --per-class 10
"""

from __future__ import annotations

import argparse
import csv
import math
from dataclasses import dataclass
from pathlib import Path

import numpy as np

from .features import SAMPLE_RATE, write_wav

CLASSES = ("snore", "talk", "movement", "ambient")


# ---------------------------------------------------------------- helpers


def _rng(seed: int) -> np.random.Generator:
    return np.random.default_rng(seed)


def _seconds(value: float) -> int:
    return int(round(value * SAMPLE_RATE))


def _pink_noise(n: int, rng: np.random.Generator) -> np.ndarray:
    white = rng.standard_normal(n)
    spectrum = np.fft.rfft(white)
    freqs = np.fft.rfftfreq(n, 1.0 / SAMPLE_RATE)
    shape = 1.0 / np.sqrt(np.maximum(freqs, 20.0))
    shaped = np.fft.irfft(spectrum * shape, n)
    return shaped / (np.max(np.abs(shaped)) + 1e-9)


def _band_noise(
    n: int,
    rng: np.random.Generator,
    low: float,
    high: float,
    soft: float = 1.0,
) -> np.ndarray:
    white = rng.standard_normal(n)
    spectrum = np.fft.rfft(white)
    freqs = np.fft.rfftfreq(n, 1.0 / SAMPLE_RATE)
    low_mask = 1.0 / (1.0 + np.exp(np.clip(-(freqs - low) / max(1.0, soft), -60.0, 60.0)))
    high_mask = 1.0 / (1.0 + np.exp(np.clip((freqs - high) / max(1.0, soft), -60.0, 60.0)))
    shaped = np.fft.irfft(spectrum * low_mask * high_mask, n)
    return shaped / (np.max(np.abs(shaped)) + 1e-9)


def _lowpass(signal: np.ndarray, cutoff: float) -> np.ndarray:
    spectrum = np.fft.rfft(signal)
    freqs = np.fft.rfftfreq(signal.size, 1.0 / SAMPLE_RATE)
    mask = 1.0 / (1.0 + (freqs / max(20.0, cutoff)) ** 2)
    return np.fft.irfft(spectrum * mask, signal.size)


def _envelope_pulses(
    n: int,
    rng: np.random.Generator,
    rate: float,
    attack: float = 0.02,
    release: float = 0.20,
    jitter: float = 0.08,
    duty: float = 0.55,
) -> np.ndarray:
    """Asymmetric pulse envelope at ``rate`` Hz (breathing or syllable rate)."""
    envelope = np.zeros(n)
    period = 1.0 / max(0.05, rate)
    start = rng.uniform(0.0, period * 0.5)
    time = np.arange(n) / SAMPLE_RATE
    index = 0
    while True:
        onset = start + index * period + rng.normal(0.0, jitter)
        if onset > time[-1]:
            break
        length = period * duty * rng.uniform(0.7, 1.3)
        a = max(1, int(attack * SAMPLE_RATE))
        r = max(1, int(release * SAMPLE_RATE * rng.uniform(0.7, 1.4)))
        width = max(a + r + 4, int(length * SAMPLE_RATE))
        local = np.zeros(width)
        local[:a] = np.linspace(0.0, 1.0, a, endpoint=False)
        local[a : a + r] = np.linspace(1.0, 0.0, r, endpoint=False) ** 1.7
        begin = max(0, int(onset * SAMPLE_RATE))
        end = min(n, begin + width)
        if begin >= n:
            break
        envelope[begin:end] = np.maximum(envelope[begin:end], local[: end - begin])
        index += 1
    return envelope


def _harmonic_buzz(
    n: int,
    rng: np.random.Generator,
    f0: float,
    formants: tuple[float, float, float],
    max_hz: float = 4500.0,
    jitter_hz: float = 1.5,
) -> np.ndarray:
    """Glottal-ish harmonic series shaped by three formants."""
    time = np.arange(n, dtype=np.float64) / SAMPLE_RATE
    # A slow, smooth F0 contour.
    contour = f0 * (
        1.0
        + 0.03 * np.sin(2 * math.pi * rng.uniform(0.15, 0.5) * time + rng.uniform(0, 6))
    )
    phase = 2 * math.pi * np.cumsum(contour) / SAMPLE_RATE
    output = np.zeros(n)
    harmonic = 1
    while harmonic * f0 <= max_hz and harmonic <= 80:
        frequency = harmonic * f0 + rng.normal(0.0, jitter_hz)
        weight = 1.0 / harmonic
        for formant in formants:
            weight += 2.2 * math.exp(-((frequency - formant) / 260.0) ** 2)
        output += weight * np.sin(harmonic * phase + rng.uniform(0, 2 * math.pi))
        harmonic += 1
    return output / (np.max(np.abs(output)) + 1e-9)


def _room_noise(duration: float, rng: np.random.Generator, level_db: float) -> np.ndarray:
    n = _seconds(duration)
    noise = _pink_noise(n, rng)
    time = np.arange(n) / SAMPLE_RATE
    hum = (
        0.25 * np.sin(2 * math.pi * 50.0 * time)
        + 0.12 * np.sin(2 * math.pi * 100.0 * time + 0.7)
        + 0.05 * np.sin(2 * math.pi * 150.0 * time + 1.1)
    )
    mix = noise + 0.10 * hum
    mix = _lowpass(mix, rng.uniform(3500.0, 7500.0))
    amplitude = 10.0 ** (level_db / 20.0)
    return mix * amplitude / (np.sqrt(np.mean(mix**2)) + 1e-9)


def _distance(signal: np.ndarray, meters: float) -> np.ndarray:
    attenuation = 1.0 / max(0.3, meters)
    cutoff = 8000.0 / max(1.0, meters**0.8)
    return _lowpass(signal, cutoff) * attenuation


def _fit(signal: np.ndarray, seconds: float) -> np.ndarray:
    n = _seconds(seconds)
    if signal.size >= n:
        return signal[:n]
    return np.pad(signal, (0, n - signal.size))


# ---------------------------------------------------------------- classes


def _snore(duration: float, rng: np.random.Generator) -> np.ndarray:
    time = np.arange(_seconds(duration)) / SAMPLE_RATE
    breathing_rate = rng.uniform(0.22, 0.55)
    envelope = _envelope_pulses(
        time.size,
        rng,
        breathing_rate,
        attack=rng.uniform(0.08, 0.25),
        release=rng.uniform(0.25, 0.65),
        duty=rng.uniform(0.45, 0.7),
    )
    f0 = rng.uniform(45.0, 105.0)
    formants = (
        rng.uniform(420.0, 700.0),
        rng.uniform(1150.0, 1800.0),
        rng.uniform(2300.0, 3200.0),
    )
    buzz = _harmonic_buzz(time.size, rng, f0, formants)
    turbulence = _band_noise(time.size, rng, 250.0, 2600.0) * 0.35
    body = buzz + turbulence
    flutter = 0.85 + 0.15 * np.sin(
        2 * math.pi * rng.uniform(18.0, 35.0) * time + rng.uniform(0, 6)
    )
    return body * envelope * flutter


def _talk(duration: float, rng: np.random.Generator, whisper: bool) -> np.ndarray:
    time = np.arange(_seconds(duration)) / SAMPLE_RATE
    syllable_rate = rng.uniform(2.0, 6.0)
    envelope = _envelope_pulses(
        time.size,
        rng,
        syllable_rate,
        attack=rng.uniform(0.01, 0.05),
        release=rng.uniform(0.04, 0.14),
        jitter=0.015,
        duty=rng.uniform(0.5, 0.85),
    )
    if whisper:
        formants = (
            rng.uniform(450.0, 850.0),
            rng.uniform(1000.0, 2200.0),
            rng.uniform(2300.0, 3400.0),
        )
        output = np.zeros(time.size)
        for formant, width in zip(formants, (180.0, 260.0, 340.0)):
            output += _band_noise(
                time.size, rng, formant - width, formant + width
            ) * rng.uniform(0.5, 1.0)
        output = output / (np.max(np.abs(output)) + 1e-9)
    else:
        f0 = rng.uniform(90.0, 240.0)
        formants = (
            rng.uniform(500.0, 850.0),
            rng.uniform(1000.0, 2100.0),
            rng.uniform(2300.0, 3300.0),
        )
        output = _harmonic_buzz(time.size, rng, f0, formants)
        # Fricatives: short broadband bursts between syllables.
        fricative = _band_noise(time.size, rng, 2500.0, 7500.0)
        gate = (envelope > 0.05).astype(float)
        output = output + 0.18 * fricative * gate
    # Slow prosodic level changes.
    contour = 0.75 + 0.25 * np.sin(
        2 * math.pi * rng.uniform(0.15, 0.4) * time + rng.uniform(0, 6)
    )
    return output * envelope * contour


def _movement(duration: float, rng: np.random.Generator) -> np.ndarray:
    time = np.arange(_seconds(duration)) / SAMPLE_RATE
    output = np.zeros(time.size)
    bursts = int(rng.integers(1, 5))
    for _ in range(bursts):
        length = rng.uniform(0.08, 0.9)
        begin = rng.uniform(0.0, max(0.01, duration - length))
        start = int(begin * SAMPLE_RATE)
        end = min(time.size, start + int(length * SAMPLE_RATE))
        if end <= start:
            continue
        burst = _band_noise(end - start, rng, rng.uniform(900.0, 3500.0), 7800.0)
        attack = max(1, int(0.004 * SAMPLE_RATE))
        release = max(1, int(0.10 * SAMPLE_RATE))
        width = end - start
        envelope = np.ones(width)
        envelope[: min(attack, width)] = np.linspace(0, 1, min(attack, width))
        if width > release:
            envelope[-release:] = np.linspace(1, 0, release) ** 1.8
        output[start:end] += burst * envelope * rng.uniform(0.4, 1.0)
    # Occasional low thump (bed frame, phone on nightstand).
    if rng.random() < 0.45:
        start = int(rng.uniform(0.0, max(0.01, duration - 0.5)) * SAMPLE_RATE)
        n = min(time.size - start, _seconds(0.5))
        if n > 0:
            t = np.arange(n) / SAMPLE_RATE
            thump = np.sin(2 * math.pi * rng.uniform(55.0, 110.0) * t) * np.exp(
                -t * rng.uniform(12.0, 25.0)
            )
            output[start : start + n] += 0.35 * thump
    return output


def _ambient(duration: float, rng: np.random.Generator) -> np.ndarray:
    n = _seconds(duration)
    fan = _pink_noise(n, rng)
    time = np.arange(n) / SAMPLE_RATE
    hum = 0.3 * np.sin(2 * math.pi * rng.choice([50.0, 60.0]) * time)
    # Slow, shallow level drift.
    drift = 0.9 + 0.1 * np.sin(2 * math.pi * rng.uniform(0.02, 0.1) * time)
    output = _lowpass(fan + hum, rng.uniform(1800.0, 5000.0)) * drift
    return output / (np.max(np.abs(output)) + 1e-9)


# ---------------------------------------------------------------- assembly


@dataclass(frozen=True)
class Clip:
    samples: np.ndarray
    label: str
    event_start_s: float
    event_end_s: float
    seed: int


def generate_event(label: str, rng: np.random.Generator) -> tuple[np.ndarray, float]:
    if label == "snore":
        duration = rng.uniform(4.0, 12.0)
        return _fit(_snore(duration, rng), duration), duration
    if label == "talk":
        duration = rng.uniform(2.0, 8.0)
        whisper = rng.random() < 0.25
        return _fit(_talk(duration, rng, whisper), duration), duration
    if label == "movement":
        duration = rng.uniform(0.8, 5.0)
        return _fit(_movement(duration, rng), duration), duration
    if label == "ambient":
        duration = rng.uniform(3.0, 10.0)
        return _fit(_ambient(duration, rng), duration), duration
    raise ValueError(f"unknown class {label!r}")


def generate_clip(label: str, seed: int) -> Clip:
    """Build a clip the same way the recorder does: 2 s pre-roll + event + 3 s tail."""
    rng = _rng(seed)
    event, event_duration = generate_event(label, rng)
    pre_roll = 2.0 + rng.uniform(0.0, 0.8)
    tail = 3.0 + rng.uniform(0.0, 0.8)
    pad = rng.uniform(0.0, 0.6)
    total = pre_roll + pad + event_duration + tail
    room_level = rng.uniform(-62.0, -38.0)
    room = _room_noise(total, rng, room_level)
    event_level = rng.uniform(0.02, 0.28)
    event = event / (np.max(np.abs(event)) + 1e-9) * event_level
    event = _distance(event, rng.uniform(0.3, 1.5))
    start = _seconds(pre_roll + pad)
    assembled = room.copy()
    end = min(assembled.size, start + event.size)
    assembled[start:end] += event[: end - start]
    # A light room reverb tail (a few early reflections).
    if rng.random() < 0.5:
        reflection = event * rng.uniform(0.08, 0.22)
        delay = int(rng.uniform(0.015, 0.06) * SAMPLE_RATE)
        shifted = np.zeros_like(assembled)
        if start + delay < assembled.size:
            available = min(reflection.size, assembled.size - start - delay)
            shifted[start + delay : start + delay + available] = reflection[:available]
        assembled += shifted

    peak = np.max(np.abs(assembled))
    if peak > 0.98:
        assembled *= 0.98 / peak
    return Clip(
        samples=assembled.astype(np.float32),
        label=label,
        event_start_s=pre_roll + pad,
        event_end_s=pre_roll + pad + event_duration,
        seed=seed,
    )


def generate_dataset(per_class: int, seed: int = 42) -> list[Clip]:
    clips: list[Clip] = []
    for class_index, label in enumerate(CLASSES):
        for index in range(per_class):
            clips.append(generate_clip(label, seed + class_index * 100_000 + index))
    return clips


def write_dataset(directory: str | Path, per_class: int, seed: int = 42) -> None:
    directory = Path(directory)
    directory.mkdir(parents=True, exist_ok=True)
    rows = []
    for clip in generate_dataset(per_class, seed):
        name = f"{clip.label}_{clip.seed}.wav"
        write_wav(directory / name, clip.samples)
        rows.append(
            {
                "file": name,
                "label": clip.label,
                "event_start_s": f"{clip.event_start_s:.3f}",
                "event_end_s": f"{clip.event_end_s:.3f}",
                "seed": clip.seed,
            }
        )
    with (directory / "labels.csv").open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)
    print(f"wrote {len(rows)} clips to {directory}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, default=Path("tools/somnia_audio/data/synth"))
    parser.add_argument("--per-class", type=int, default=10)
    parser.add_argument("--seed", type=int, default=42)
    args = parser.parse_args()
    write_dataset(args.out, args.per_class, args.seed)


if __name__ == "__main__":
    main()
