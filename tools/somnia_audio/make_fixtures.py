"""Generate deterministic WAV fixtures and Python reference values.

Dart and Python feature extractors must agree within 1e-3 relative error.
The fixtures are committed so ``flutter test`` can check parity without a
Python installation.

    python -m tools.somnia_audio.make_fixtures
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np

from .features import FEATURE_NAMES, SAMPLE_RATE, extract, write_wav
from .synth import generate_clip

DEFAULT_OUT = Path("test/fixtures/sleep_audio")
DEFAULT_MODEL = Path("assets/models/sleep_audio_v2.json")

# Seeds deliberately outside the training ranges (training starts at 1000).
SYNTH_SEEDS = {
    "snore": 777001,
    "talk": 777014,
    "movement": 777027,
    "ambient": 777040,
}


def _pcm(values: np.ndarray) -> np.ndarray:
    return np.clip(values, -1.0, 1.0).astype(np.float32)


def snore_signal(seconds: float = 8.0, amplitude: float = 0.15) -> np.ndarray:
    rng = np.random.default_rng(7)
    count = int(SAMPLE_RATE * seconds)
    t = np.arange(count, dtype=np.float64) / SAMPLE_RATE
    envelope = 0.35 + 0.65 * (0.5 + 0.5 * np.sin(2 * np.pi * 0.8 * t))
    body = (
        np.sin(2 * np.pi * 80 * t)
        + 0.6 * np.sin(2 * np.pi * 160 * t)
        + 0.35 * np.sin(2 * np.pi * 240 * t)
    )
    noise = (rng.random(count) - 0.5) * 0.004
    return _pcm(amplitude * envelope * body * 0.5 + noise)


def talk_signal(seconds: float = 6.0, amplitude: float = 0.2) -> np.ndarray:
    rng = np.random.default_rng(11)
    count = int(SAMPLE_RATE * seconds)
    t = np.arange(count, dtype=np.float64) / SAMPLE_RATE
    formants = (700.0, 1200.0, 2600.0)
    syllable = 0.5 + 0.5 * np.sin(2 * np.pi * 4 * t)
    gate = (syllable > 0.25).astype(np.float64)
    value = np.zeros(count, dtype=np.float64)
    for harmonic in range(1, 31):
        frequency = 130.0 * harmonic
        if frequency > 7000:
            break
        weight = 0.02
        for formant in formants:
            weight += np.exp(-(((frequency - formant) / 350.0) ** 2))
        value += (weight / harmonic) * np.sin(2 * np.pi * frequency * t)
    noise = (rng.random(count) - 0.5) * 0.006
    return _pcm(amplitude * gate * value / 3.0 + noise)


def movement_signal(seconds: float = 4.0, amplitude: float = 0.3) -> np.ndarray:
    rng = np.random.default_rng(19)
    count = int(SAMPLE_RATE * seconds)
    t = np.arange(count, dtype=np.float64) / SAMPLE_RATE
    burst = ((t * 2) % 1.0 < 0.5).astype(np.float64)
    white = rng.random(count) - 0.5
    high = np.empty(count, dtype=np.float64)
    high[0] = white[0]
    for index in range(1, count):
        high[index] = white[index] - white[index - 1] * 0.9
    return _pcm(amplitude * burst * high)


def ambient_signal(seconds: float = 10.0, amplitude: float = 0.012) -> np.ndarray:
    rng = np.random.default_rng(23)
    count = int(SAMPLE_RATE * seconds)
    t = np.arange(count, dtype=np.float64) / SAMPLE_RATE
    white = (rng.random(count) - 0.5) * amplitude
    hum = 0.01 * np.sin(2 * np.pi * 100 * t)
    return _pcm(white + hum)


SIGNALS = {
    "snore": snore_signal,
    "talk": talk_signal,
    "movement": movement_signal,
    "ambient": ambient_signal,
}


def probabilities(features: dict[str, float], model: dict) -> list[float]:
    names = model["feature_names"]
    x = np.asarray([features[name] for name in names], dtype=np.float64)
    mean = np.asarray(model["mean"], dtype=np.float64)
    scale = np.asarray(model["scale"], dtype=np.float64)
    coefficients = np.asarray(model["coefficients"], dtype=np.float64)
    intercept = np.asarray(model["intercept"], dtype=np.float64)
    logits = coefficients @ ((x - mean) / scale) + intercept
    logits = logits / float(model["temperature"])
    logits -= logits.max()
    exp = np.exp(logits)
    return (exp / exp.sum()).tolist()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--model", type=Path, default=DEFAULT_MODEL)
    args = parser.parse_args()

    model = json.loads(args.model.read_text(encoding="utf-8"))
    classes = model["classes"]
    threshold = float(model["unknown_threshold"])
    args.out.mkdir(parents=True, exist_ok=True)

    manifest: dict[str, object] = {
        "sample_rate": SAMPLE_RATE,
        "source": "synthetic deterministic fixtures (tools/somnia_audio/make_fixtures.py)",
        "feature_names": list(FEATURE_NAMES),
        "model": str(args.model).replace("\\", "/"),
        "temperature": model["temperature"],
        "unknown_threshold": threshold,
        "clips": [],
    }

    for label, generator in SIGNALS.items():
        samples = generator()
        path = args.out / f"{label}.wav"
        write_wav(path, samples)
        values = extract(samples)
        if values["active_duration_s"] <= 0:
            # No active frames: the on-device classifier reports ambient with
            # zero confidence instead of running the model on an all-zero
            # vector.
            probs = [0.0, 0.0, 0.0, 1.0]
        else:
            probs = probabilities(values, model)
        best = max(range(len(probs)), key=lambda index: probs[index])
        predicted = classes[best] if probs[best] >= threshold else "unknown"
        if values["active_duration_s"] <= 0:
            predicted = "ambient"
        manifest["clips"].append(
            {
                "file": path.name,
                "expected_type": predicted,
                "probabilities": dict(zip(classes, probs)),
                "features": {name: values[name] for name in FEATURE_NAMES},
            }
        )
        print(f"{path} -> {predicted} ({probs[best]:.3f})")

    manifest["synth_clips"] = []
    for label, seed in SYNTH_SEEDS.items():
        clip = generate_clip(label, seed)
        path = args.out / "synth" / f"{label}.wav"
        write_wav(path, clip.samples)
        values = extract(clip.samples)
        probs = probabilities(values, model)
        best = max(range(len(probs)), key=lambda index: probs[index])
        predicted = classes[best] if probs[best] >= threshold else "unknown"
        manifest["synth_clips"].append(
            {
                "file": f"synth/{path.name}",
                "expected_type": predicted,
                "true_label": label,
                "probabilities": dict(zip(classes, probs)),
                "event_start_s": clip.event_start_s,
                "event_end_s": clip.event_end_s,
            }
        )
        print(f"{path} -> {predicted} ({probs[best]:.3f}), true={label}")

    manifest_path = args.out / "features.json"
    manifest_path.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"wrote {manifest_path}")


if __name__ == "__main__":
    main()
