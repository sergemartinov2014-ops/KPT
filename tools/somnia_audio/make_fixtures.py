"""Generate deterministic WAV fixtures and Python reference feature values.

Dart and Python feature extractors must agree within 1e-3 relative error.
The fixtures are committed so ``flutter test`` can check parity without a
Python installation.

The fixtures are recordings, not isolated tones: each one is an event from
`synth.py` mixed with a room noise floor through the phone microphone path, so
the classifier tests exercise the same conditions as a real overnight clip.

    python -m tools.somnia_audio.make_fixtures
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np

from .features import FEATURE_NAMES, SAMPLE_RATE, extract, write_wav
from .synth import _normalize, _room_noise, generate_clip, generate_event, phone_path

DEFAULT_OUT = Path("test/fixtures/sleep_audio")

# Seeds deliberately outside the training ranges (training starts at 1000).
FIXTURE_SEEDS = {
    "snore": 777001,
    "talk": 777014,
    "movement": 777027,
    "ambient": 777040,
}


def recording_signal(label: str, seed: int) -> np.ndarray:
    """One event, 1 s of quiet room on each side, phone path applied."""
    rng = np.random.default_rng(seed)
    event, duration = generate_event(label, rng)
    event = _normalize(event) * 0.04
    event = phone_path(event, rng)
    pre = 1.0
    post = 1.0
    total = pre + duration + post
    room = _room_noise(total, rng, -58.0)
    samples = room.copy()
    start = int(pre * SAMPLE_RATE)
    end = min(samples.size, start + event.size)
    samples[start:end] += event[: end - start]
    samples = phone_path(samples, rng)
    peak = np.max(np.abs(samples))
    if peak > 0.97:
        samples *= 0.97 / peak
    return samples.astype(np.float32)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)

    manifest: dict[str, object] = {
        "sample_rate": SAMPLE_RATE,
        "source": "synthetic deterministic fixtures (tools/somnia_audio/make_fixtures.py)",
        "feature_names": list(FEATURE_NAMES),
        "clips": [],
        "synth_clips": [],
    }

    for label, seed in FIXTURE_SEEDS.items():
        samples = recording_signal(label, seed)
        path = args.out / f"{label}.wav"
        write_wav(path, samples)
        values = extract(samples)
        manifest["clips"].append(
            {
                "file": path.name,
                "label": label,
                "expected_type": label,
                "features": {name: values[name] for name in FEATURE_NAMES},
            }
        )
        print(f"{path} -> {label}")

    for label, seed in FIXTURE_SEEDS.items():
        clip = generate_clip(label, seed)
        path = args.out / "synth" / f"{label}.wav"
        write_wav(path, clip.samples)
        manifest["synth_clips"].append(
            {
                "file": f"synth/{path.name}",
                "true_label": label,
                "expected_type": label,
                "event_start_s": clip.event_start_s,
                "event_end_s": clip.event_end_s,
            }
        )
        print(f"{path} -> {label}")

    manifest_path = args.out / "features.json"
    manifest_path.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"wrote {manifest_path}")


if __name__ == "__main__":
    main()
