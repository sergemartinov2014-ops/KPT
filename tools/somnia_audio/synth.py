"""Synthetic night-sound generator for Somnia.

This generator produces the four model classes with **physically grounded**
spectral shapes, a phone-microphone transfer path and a bedroom noise floor.
It exists because no labelled night recordings are available yet: the numbers
it supports are a pipeline check and a design tool, not a real-world accuracy
claim.

Design references (well-known acoustic properties, no dataset was used):

* A snore is a low-frequency, pulsed sound: energy is concentrated around
  50–500 Hz, the fundamental is 40–150 Hz, and the amplitude is modulated by the
  breathing cycle at roughly 0.15–0.8 Hz.  It is not a clean harmonic tone —
  tissue vibration adds broadband turbulence, which is why the spectral
  flatness of a real snore is much higher than a musical tone's.
* Speech has syllable modulation at 2–8 Hz, formant energy in 300–3000 Hz and
  fast spectral change between phonemes.
* Bed movement is a short (0.05–1 s) broadband transient, often with a low
  thump from the bed frame.
* A bedroom at night is a stationary noise floor (fan, fridge, traffic) with a
  slow level drift and mains hum.

The microphone path matters: an iPhone records through a high-pass around
60–100 Hz and an anti-alias/room low-pass well below 8 kHz, and the level of a
snore 1 m away is tens of dB below full scale.  `phone_path()` applies that
path to the mix, so the classifier sees levels and spectra that are comparable
to real device clips.

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


def _normalize(signal: np.ndarray) -> np.ndarray:
    return signal / (np.max(np.abs(signal)) + 1e-9)


def _freqs(n: int) -> np.ndarray:
    return np.fft.rfftfreq(n, 1.0 / SAMPLE_RATE)


def _pink_noise(n: int, rng: np.random.Generator) -> np.ndarray:
    white = rng.standard_normal(n)
    spectrum = np.fft.rfft(white)
    shape = 1.0 / np.sqrt(np.maximum(_freqs(n), 20.0))
    shaped = np.fft.irfft(spectrum * shape, n)
    return _normalize(shaped)


def _band_noise(
    n: int,
    rng: np.random.Generator,
    low: float,
    high: float,
    order: float = 2.0,
) -> np.ndarray:
    spectrum = np.fft.rfft(rng.standard_normal(n))
    freqs = _freqs(n)
    low_mask = 1.0 / (1.0 + (low / np.maximum(freqs, 1e-6)) ** order)
    high_mask = 1.0 / (1.0 + (freqs / high) ** order)
    return _normalize(np.fft.irfft(spectrum * low_mask * high_mask, n))


def _lowpass(signal: np.ndarray, cutoff: float, order: float = 2.0) -> np.ndarray:
    spectrum = np.fft.rfft(signal)
    return np.fft.irfft(spectrum / (1.0 + (_freqs(signal.size) / cutoff) ** order), signal.size)


def _highpass(signal: np.ndarray, cutoff: float, order: float = 2.0) -> np.ndarray:
    spectrum = np.fft.rfft(signal)
    freqs = _freqs(signal.size)
    return np.fft.irfft(
        spectrum * (freqs / cutoff) ** order / (1.0 + (freqs / cutoff) ** order),
        signal.size,
    )


def _pulses(
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
    time = np.arange(n) / SAMPLE_RATE
    onset = rng.uniform(0.0, period * 0.5)
    while onset < time[-1]:
        a = max(1, int(attack * SAMPLE_RATE))
        r = max(1, int(release * SAMPLE_RATE * rng.uniform(0.7, 1.4)))
        width = max(a + r + 4, int(period * duty * rng.uniform(0.7, 1.3) * SAMPLE_RATE))
        local = np.zeros(width)
        local[:a] = np.linspace(0.0, 1.0, a, endpoint=False) ** 1.4
        local[a : a + r] = np.linspace(1.0, 0.0, r, endpoint=False) ** 1.9
        begin = max(0, int(onset * SAMPLE_RATE))
        end = min(n, begin + width)
        if begin >= n:
            break
        envelope[begin:end] = np.maximum(envelope[begin:end], local[: end - begin])
        onset += period * rng.uniform(0.85, 1.15) + rng.normal(0.0, jitter)
    return envelope


def _harmonic_buzz(
    n: int,
    rng: np.random.Generator,
    f0: float,
    formants: tuple[float, ...],
    max_hz: float = 4500.0,
    tilt: float = 1.2,
) -> np.ndarray:
    """Glottal-ish harmonic series shaped by formants."""
    time = np.arange(n, dtype=np.float64) / SAMPLE_RATE
    contour = f0 * (
        1.0
        + 0.035
        * np.sin(2 * math.pi * rng.uniform(0.15, 0.5) * time + rng.uniform(0, 6))
    )
    phase = 2 * math.pi * np.cumsum(contour) / SAMPLE_RATE
    output = np.zeros(n)
    harmonic = 1
    while harmonic * f0 <= max_hz and harmonic <= 80:
        frequency = harmonic * f0
        weight = 1.0 / harmonic**tilt
        for formant in formants:
            weight += 2.0 * math.exp(-((frequency - formant) / 260.0) ** 2)
        output += weight * np.sin(harmonic * phase + rng.uniform(0, 2 * math.pi))
        harmonic += 1
    return _normalize(output)


def _room_noise(duration: float, rng: np.random.Generator, level_db: float) -> np.ndarray:
    n = _seconds(duration)
    noise = _pink_noise(n, rng)
    time = np.arange(n) / SAMPLE_RATE
    hum = (
        0.25 * np.sin(2 * math.pi * 50.0 * time)
        + 0.12 * np.sin(2 * math.pi * 100.0 * time + 0.7)
        + 0.05 * np.sin(2 * math.pi * 150.0 * time + 1.1)
    )
    mix = _lowpass(noise + 0.10 * hum, rng.uniform(3000.0, 7000.0))
    amplitude = 10.0 ** (level_db / 20.0)
    return mix * amplitude / (np.sqrt(np.mean(mix**2)) + 1e-9)


def _distance(signal: np.ndarray, meters: float) -> np.ndarray:
    """Distance attenuation plus air/room high-frequency loss."""
    attenuation = 1.0 / max(0.4, meters)
    cutoff = 6500.0 / max(1.0, meters**0.7)
    return _lowpass(signal, cutoff) * attenuation


def phone_path(signal: np.ndarray, rng: np.random.Generator | None = None) -> np.ndarray:
    """Apply the approximate iPhone recording path.

    The built-in microphone rolls off below ~70 Hz and above ~7 kHz; the DSP
    chain does not add gain (measurement mode disables AGC), so the level of
    the clip is whatever the room produced.
    """
    generator = rng if rng is not None else np.random.default_rng(0)
    out = _highpass(signal, generator.uniform(55.0, 95.0))
    out = _lowpass(out, generator.uniform(5600.0, 7100.0))
    return out


def _fit(signal: np.ndarray, seconds: float) -> np.ndarray:
    n = _seconds(seconds)
    if signal.size >= n:
        return signal[:n]
    return np.pad(signal, (0, n - signal.size))


# ---------------------------------------------------------------- classes


def _tilt(signal: np.ndarray, exponent: float, pivot: float = 100.0) -> np.ndarray:
    """Apply a 1/f^exponent spectral tilt (snore energy falls with frequency)."""
    if exponent <= 0:
        return signal
    spectrum = np.fft.rfft(signal)
    freqs = np.maximum(_freqs(signal.size), 20.0)
    return np.fft.irfft(spectrum * (freqs / pivot) ** (-exponent), signal.size)


def _snore(duration: float, rng: np.random.Generator) -> np.ndarray:
    """Low, pulsed, turbulent snore.

    Measured character of a real snore (see `test/fixtures` notes): spectral
    centroid of a few hundred Hz, most energy in 50–400 Hz, a fundamental near
    40–100 Hz, substantial broadband component (flatness is low but not tonal),
    and an envelope that follows the breath at ~0.15–0.8 Hz.
    """
    n = _seconds(duration)
    time = np.arange(n) / SAMPLE_RATE
    envelope = _pulses(
        n,
        rng,
        rng.uniform(0.13, 0.75),
        attack=rng.uniform(0.04, 0.30),
        release=rng.uniform(0.15, 0.75),
        jitter=rng.uniform(0.02, 0.12),
        duty=rng.uniform(0.30, 0.70),
    )

    f0 = rng.uniform(38.0, 100.0)
    f1 = rng.uniform(250.0, 650.0)
    f2 = rng.uniform(800.0, 1800.0)
    tone = _harmonic_buzz(
        n, rng, f0, (f1, f2, 2400.0), max_hz=rng.uniform(500.0, 1400.0)
    )

    # Turbulence through the soft-palate and pharynx resonances.
    turbulence = np.zeros(n)
    for center, width, gain in (
        (f1, rng.uniform(100.0, 220.0), 1.0),
        (f2, rng.uniform(200.0, 500.0), 0.5),
    ):
        turbulence += gain * _band_noise(n, rng, max(50.0, center - width), center + width)
    turbulence = _normalize(turbulence)
    roughness = _band_noise(n, rng, 60.0, 900.0)

    body = rng.uniform(0.35, 0.65) * tone + 0.9 * turbulence + 0.35 * roughness
    # A snore loses roughly 1/f of amplitude per octave: this is what puts its
    # spectral centroid in the low hundreds of Hz instead of in the mid band.
    body = _tilt(body, rng.uniform(1.0, 1.4))
    flutter = 0.85 + 0.15 * np.sin(
        2 * math.pi * rng.uniform(9.0, 38.0) * time + rng.uniform(0, 6)
    )
    return _lowpass(body * envelope * flutter, rng.uniform(2400.0, 6000.0))


def _talk(duration: float, rng: np.random.Generator, whisper: bool) -> np.ndarray:
    n = _seconds(duration)
    time = np.arange(n) / SAMPLE_RATE
    envelope = _pulses(
        n,
        rng,
        rng.uniform(2.0, 6.0),
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
        output = np.zeros(n)
        for formant, width in zip(formants, (180.0, 260.0, 340.0)):
            output += _band_noise(n, rng, formant - width, formant + width) * rng.uniform(0.5, 1.0)
        output = _normalize(output)
    else:
        f0 = rng.uniform(90.0, 240.0)
        formants = (
            rng.uniform(500.0, 850.0),
            rng.uniform(1000.0, 2100.0),
            rng.uniform(2300.0, 3300.0),
        )
        output = _harmonic_buzz(n, rng, f0, formants)
        fricative = _band_noise(n, rng, 2500.0, 7500.0)
        output = output + 0.18 * fricative * (envelope > 0.05)
    contour = 0.75 + 0.25 * np.sin(
        2 * math.pi * rng.uniform(0.15, 0.4) * time + rng.uniform(0, 6)
    )
    return output * envelope * contour


def _movement(duration: float, rng: np.random.Generator) -> np.ndarray:
    n = _seconds(duration)
    time = np.arange(n) / SAMPLE_RATE
    output = np.zeros(n)
    for _ in range(int(rng.integers(1, 5))):
        length = rng.uniform(0.08, 0.9)
        begin = int(rng.uniform(0.0, max(0.01, duration - length)) * SAMPLE_RATE)
        end = min(n, begin + _seconds(length))
        if end <= begin:
            continue
        burst = _band_noise(end - begin, rng, rng.uniform(900.0, 3500.0), 7800.0)
        width = end - begin
        envelope = np.ones(width)
        attack = max(1, int(0.004 * SAMPLE_RATE))
        release = max(1, int(0.10 * SAMPLE_RATE))
        envelope[: min(attack, width)] = np.linspace(0, 1, min(attack, width))
        if width > release:
            envelope[-release:] = np.linspace(1, 0, release) ** 1.8
        output[begin:end] += burst * envelope * rng.uniform(0.4, 1.0)
    if rng.random() < 0.45:
        begin = int(rng.uniform(0.0, max(0.01, duration - 0.5)) * SAMPLE_RATE)
        n_thump = min(n - begin, _seconds(0.5))
        if n_thump > 0:
            t = np.arange(n_thump) / SAMPLE_RATE
            thump = np.sin(2 * math.pi * rng.uniform(55.0, 110.0) * t) * np.exp(
                -t * rng.uniform(12.0, 25.0)
            )
            output[begin : begin + n_thump] += 0.35 * thump
    return output


def _breathing(duration: float, rng: np.random.Generator) -> np.ndarray:
    """Quiet, aperiodic-ish breathing: a hard negative for the snore class."""
    n = _seconds(duration)
    envelope = _pulses(
        n,
        rng,
        rng.uniform(0.10, 0.35),
        attack=rng.uniform(0.20, 0.60),
        release=rng.uniform(0.30, 1.0),
        jitter=rng.uniform(0.02, 0.10),
        duty=rng.uniform(0.25, 0.55),
    )
    hiss = _band_noise(n, rng, 200.0, 2600.0)
    return _lowpass(hiss * envelope, rng.uniform(2600.0, 6500.0))


def _ambient(duration: float, rng: np.random.Generator) -> np.ndarray:
    n = _seconds(duration)
    fan = _pink_noise(n, rng)
    time = np.arange(n) / SAMPLE_RATE
    hum = 0.3 * np.sin(2 * math.pi * rng.choice([50.0, 60.0]) * time)
    drift = 0.9 + 0.1 * np.sin(2 * math.pi * rng.uniform(0.02, 0.1) * time)
    output = _lowpass(fan + hum, rng.uniform(1800.0, 5000.0)) * drift
    return _normalize(output)


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
        duration = rng.uniform(3.0, 12.0)
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
    """Build a clip the way the recorder does: 2 s pre-roll + event + 3 s tail."""
    rng = _rng(seed)
    if label == "ambient" and rng.random() < 0.5:
        duration = rng.uniform(3.0, 10.0)
        event = _breathing(duration, rng)
        event_level = 10.0 ** (rng.uniform(-46.0, -32.0) / 20.0)
        event = _normalize(event) * event_level
    else:
        event, duration = generate_event(label, rng)
        event = _normalize(event) * rng.uniform(0.02, 0.30)

    pre_roll = 2.0 + rng.uniform(0.0, 0.8)
    tail = 3.0 + rng.uniform(0.0, 0.8)
    pad = rng.uniform(0.0, 0.6)
    total = pre_roll + pad + duration + tail
    room_level = rng.uniform(-70.0, -38.0)
    room = _room_noise(total, rng, room_level)

    event = _distance(event, rng.uniform(0.4, 1.5))
    start = _seconds(pre_roll + pad)
    assembled = room.copy()
    end = min(assembled.size, start + event.size)
    assembled[start:end] += event[: end - start]
    # A few early reflections; a bedroom is not an anechoic chamber.
    if rng.random() < 0.5:
        reflection = event * rng.uniform(0.08, 0.22)
        delay = _seconds(rng.uniform(0.015, 0.06))
        shifted = np.zeros_like(assembled)
        if start + delay < assembled.size:
            available = min(reflection.size, assembled.size - start - delay)
            shifted[start + delay : start + delay + available] = reflection[:available]
        assembled += shifted

    assembled = phone_path(assembled, rng)
    assembled = phone_path(assembled, rng) if rng.random() < 0.3 else assembled
    peak = np.max(np.abs(assembled))
    if peak > 0.97:
        assembled *= 0.97 / peak
    return Clip(
        samples=assembled.astype(np.float32),
        label=label,
        event_start_s=pre_roll + pad,
        event_end_s=pre_roll + pad + duration,
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
