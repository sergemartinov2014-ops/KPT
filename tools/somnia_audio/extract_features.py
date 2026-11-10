"""Extract v2 features from WAV files into JSONL or CSV.

Every record carries the file path, an optional label, and all 34 features.
The label is taken from ``--label`` or from the parent directory name, which
makes a directory tree such as ``external/esc50/snore/*.wav`` directly usable
by ``eval.py``.

    python -m tools.somnia_audio.extract_features data/external/esc50/snore/*.wav
    python -m tools.somnia_audio.extract_features data/external/esc50 --out features.jsonl
"""

from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path

from .features import FEATURE_NAMES, extract, read_wav

WAV_SUFFIXES = {".wav", ".wave"}


def _iter_wavs(paths: list[Path], recursive: bool) -> list[Path]:
    files: list[Path] = []
    for path in paths:
        if path.is_dir():
            pattern = "**/*" if recursive else "*"
            files.extend(
                sorted(
                    child
                    for child in path.glob(pattern)
                    if child.is_file() and child.suffix.lower() in WAV_SUFFIXES
                )
            )
        elif path.is_file():
            files.append(path)
        else:
            raise SystemExit(f"not a file or directory: {path}")
    # Preserve the caller's order but drop duplicates.
    seen: set[Path] = set()
    unique: list[Path] = []
    for path in files:
        resolved = path.resolve()
        if resolved in seen:
            continue
        seen.add(resolved)
        unique.append(path)
    return unique


def _record(path: Path, label: str | None) -> dict[str, object]:
    samples, rate = read_wav(path)
    values = extract(samples, rate)
    return {
        "file": str(path).replace("\\", "/"),
        "label": label,
        "sample_rate": rate,
        "samples": int(samples.size),
        "features": {name: float(values[name]) for name in FEATURE_NAMES},
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("paths", nargs="+", type=Path, help="WAV files or directories")
    parser.add_argument("--recursive", action="store_true", help="walk directories recursively")
    parser.add_argument("--label", help="label for every file (default: parent directory name)")
    parser.add_argument("--no-label", action="store_true", help="omit labels entirely")
    parser.add_argument("--out", type=Path, help="output .jsonl or .csv (default: print JSONL)")
    parser.add_argument("--csv", action="store_true", help="write CSV instead of JSONL")
    args = parser.parse_args()

    files = _iter_wavs(args.paths, args.recursive)
    if not files:
        raise SystemExit("no WAV files found")

    records = []
    for path in files:
        if args.no_label:
            label = None
        elif args.label is not None:
            label = args.label
        else:
            label = path.parent.name
        records.append(_record(path, label))
        print(f"{path} -> {label or '-'} ({records[-1]['features']['duration_s']:.2f} s)")

    if args.out is None:
        for record in records:
            print(json.dumps(record, ensure_ascii=False))
        return

    args.out.parent.mkdir(parents=True, exist_ok=True)
    if args.csv:
        with args.out.open("w", encoding="utf-8", newline="") as handle:
            writer = csv.writer(handle)
            writer.writerow(["file", "label", *FEATURE_NAMES])
            for record in records:
                features = record["features"]
                writer.writerow(
                    [record["file"], record["label"] or ""]
                    + [features[name] for name in FEATURE_NAMES]
                )
    else:
        with args.out.open("w", encoding="utf-8") as handle:
            for record in records:
                handle.write(json.dumps(record, ensure_ascii=False) + "\n")
    print(f"wrote {args.out} ({len(records)} files)")


if __name__ == "__main__":
    main()
