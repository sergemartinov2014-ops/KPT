"""Evaluate the exported v2 model on labelled WAV directories.

This is an end-to-end check of ``features.py`` + the exported JSON model.  It
does not run the Dart code; use ``tools/somnia_audio/baseline_eval.dart`` for
the committed Dart baseline and ``flutter test`` for parity.

Input layout::

    external/esc50/snore/*.wav
    external/esc50/breathing/*.wav

The directory name is the label.  Labels outside the model classes are kept
for inspection but excluded from supervised metrics unless mapped with
``--map breathing=ambient``.

    python -m tools.somnia_audio.eval tools/somnia_audio/data/external/esc50 \\
        --map snore=snore --map breathing=ambient

External clips are not a benchmark: they are short web samples, not labelled
sleep recordings.  The report says so explicitly.
"""

from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path

import numpy as np

from .features import extract, read_wav

DEFAULT_MODEL = Path("assets/models/sleep_audio_v2.json")
DEFAULT_WARNING = (
    "External clips only. Not labelled sleep recordings and not a benchmark. "
    "Numbers do not estimate real-world accuracy."
)


def _softmax(logits: np.ndarray) -> np.ndarray:
    logits = logits - np.max(logits)
    exp = np.exp(logits)
    return exp / np.sum(exp)


def _probabilities(features: dict[str, float], model: dict) -> np.ndarray:
    names = model["feature_names"]
    x = np.asarray([features[name] for name in names], dtype=np.float64)
    mean = np.asarray(model["mean"], dtype=np.float64)
    scale = np.asarray(model["scale"], dtype=np.float64)
    coefficients = np.asarray(model["coefficients"], dtype=np.float64)
    intercept = np.asarray(model["intercept"], dtype=np.float64)
    logits = coefficients @ ((x - mean) / scale) + intercept
    return _softmax(logits / float(model["temperature"]))


def _split_windows(samples: np.ndarray, rate: int, window: float, hop: float):
    size = int(round(window * rate))
    step = int(round(hop * rate))
    if size <= 0 or step <= 0:
        raise SystemExit("window and hop must be positive")
    if samples.size < size:
        return []
    starts = range(0, samples.size - size + 1, step)
    return [(start / rate, samples[start : start + size]) for start in starts]


def _ece(confidence: np.ndarray, correct: np.ndarray, bins: int = 15) -> float:
    edges = np.linspace(0.0, 1.0, bins + 1)
    error = 0.0
    for index in range(bins):
        lower, upper = edges[index], edges[index + 1]
        mask = (confidence >= lower) & (
            confidence < upper if index < bins - 1 else confidence <= upper
        )
        if not np.any(mask):
            continue
        error += float(np.mean(mask)) * abs(
            float(np.mean(confidence[mask]) - np.mean(correct[mask]))
        )
    return error


def _metrics(
    truth: np.ndarray,
    predictions: np.ndarray,
    confidence: np.ndarray,
    classes: list[str],
    threshold: float,
) -> dict:
    known = confidence >= threshold
    effective = np.where(known, predictions, len(classes))
    names = classes + ["unknown"]
    matrix = np.zeros((len(classes) + 1, len(classes) + 1), dtype=int)
    for actual, predicted in zip(truth, effective):
        matrix[int(actual), int(predicted)] += 1

    per_class = {}
    f1_values = []
    for index, name in enumerate(classes):
        true_positive = int(matrix[index, index])
        predicted_positive = int(matrix[:, index].sum())
        support = int(matrix[index, :].sum())
        precision = true_positive / predicted_positive if predicted_positive else 0.0
        recall = true_positive / support if support else 0.0
        f1 = (
            2.0 * precision * recall / (precision + recall)
            if precision + recall
            else 0.0
        )
        f1_values.append(f1)
        per_class[name] = {
            "precision": precision,
            "recall": recall,
            "f1": f1,
            "support": support,
        }

    snore_index = classes.index("snore")
    talk_index = classes.index("talk")
    talk_to_snore = float(
        np.mean((truth == talk_index) & (effective == snore_index))
    ) if np.any(truth == talk_index) else 0.0
    correct = (effective == truth).astype(np.float64)
    return {
        "rows": int(truth.size),
        "coverage": float(np.mean(known)),
        "unknown_rate": float(np.mean(~known)),
        "accuracy_known": float(np.mean(correct[known])) if np.any(known) else 0.0,
        "macro_f1": float(np.mean(f1_values)),
        "snore_precision": per_class["snore"]["precision"],
        "snore_recall": per_class["snore"]["recall"],
        "talk_to_snore_rate": talk_to_snore,
        "ece": _ece(confidence, correct),
        "per_class": per_class,
        "confusion": {"labels": names, "matrix": matrix.tolist()},
    }


def _read_manifest(path: Path) -> list[dict[str, str]]:
    if path.suffix.lower() == ".csv":
        with path.open("r", encoding="utf-8", newline="") as handle:
            return list(csv.DictReader(handle))
    records = []
    with path.open("r", encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if line:
                records.append(json.loads(line))
    return records


def _collect(paths: list[Path], recursive: bool) -> list[tuple[Path, str]]:
    found: list[tuple[Path, str]] = []
    for path in paths:
        if path.is_dir():
            pattern = "**/*.wav" if recursive else "*.wav"
            found.extend((child, child.parent.name) for child in sorted(path.glob(pattern)))
        elif path.is_file() and path.suffix.lower() == ".wav":
            found.append((path, path.parent.name))
        else:
            raise SystemExit(f"not a WAV file or directory: {path}")
    return found


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("paths", nargs="*", type=Path, help="labelled WAV files or directories")
    parser.add_argument("--manifest", type=Path, help="JSONL/CSV with file and label columns")
    parser.add_argument("--recursive", action="store_true")
    parser.add_argument("--model", type=Path, default=DEFAULT_MODEL)
    parser.add_argument("--map", action="append", default=[], metavar="LABEL=CLASS",
                        help="map a directory label to a model class; repeatable")
    parser.add_argument("--window", type=float, help="evaluate fixed windows, e.g. 1.0 seconds")
    parser.add_argument("--hop", type=float, help="window hop in seconds (default: --window)")
    parser.add_argument("--min-active", type=float, default=0.0,
                        help="skip windows with less active audio (seconds)")
    parser.add_argument("--out", type=Path, help="write the JSON report here")
    parser.add_argument("--predictions", type=Path, help="write per-file predictions as CSV")
    parser.add_argument("--warning", default=DEFAULT_WARNING)
    args = parser.parse_args()

    model = json.loads(args.model.read_text(encoding="utf-8"))
    classes = list(model["classes"])
    threshold = float(model["unknown_threshold"])
    mapping: dict[str, str] = {}
    for item in args.map:
        if "=" not in item:
            raise SystemExit(f"--map expects LABEL=CLASS, got {item!r}")
        label, target = item.split("=", 1)
        if target not in classes:
            raise SystemExit(f"unknown model class {target!r}; choose from {classes}")
        mapping[label] = target

    if args.manifest:
        entries = [(Path(row["file"]), str(row.get("label") or Path(row["file"]).parent.name))
                   for row in _read_manifest(args.manifest)]
    elif args.paths:
        entries = _collect(args.paths, args.recursive)
    else:
        raise SystemExit("pass WAV paths or --manifest")

    if args.window and not args.hop:
        args.hop = args.window

    rows = []
    for path, label in entries:
        samples, rate = read_wav(path)
        chunks = (
            _split_windows(samples, rate, args.window, args.hop)
            if args.window
            else [(0.0, samples)]
        )
        for offset, chunk in chunks:
            features = extract(chunk, rate)
            if features["active_duration_s"] < args.min_active:
                continue
            probabilities = _probabilities(features, model)
            best = int(np.argmax(probabilities))
            confidence = float(probabilities[best])
            predicted = classes[best] if confidence >= threshold else "unknown"
            rows.append(
                {
                    "file": str(path).replace("\\", "/"),
                    "label": label,
                    "offset_s": round(offset, 3),
                    "predicted": predicted,
                    "confidence": confidence,
                    "probabilities": dict(zip(classes, probabilities.tolist())),
                    "active_duration_s": features["active_duration_s"],
                }
            )

    if not rows:
        raise SystemExit("no rows evaluated (check --min-active)")

    known_rows = [row for row in rows if row["label"] in classes]
    report: dict[str, object] = {
        "model": str(args.model).replace("\\", "/"),
        "dataset": "external WAV files",
        "warning": args.warning,
        "unknown_threshold": threshold,
        "temperature": model["temperature"],
        "window_s": args.window,
        "hop_s": args.hop if args.window else None,
        "rows": len(rows),
        "supervised_rows": len(known_rows),
        "unmapped_labels": sorted({row["label"] for row in rows if row["label"] not in classes}),
    }

    if known_rows:
        truth = np.asarray([classes.index(row["label"]) for row in known_rows])
        predictions = np.asarray(
            [classes.index(row["predicted"]) if row["predicted"] in classes else -1
             for row in known_rows]
        )
        confidence = np.asarray([row["confidence"] for row in known_rows])
        report["metrics"] = _metrics(truth, predictions, confidence, classes, threshold)
        metrics = report["metrics"]
        print(
            f"rows={metrics['rows']} coverage={metrics['coverage']:.3f} "
            f"macro-F1={metrics['macro_f1']:.3f} "
            f"snore P/R={metrics['snore_precision']:.3f}/{metrics['snore_recall']:.3f} "
            f"talk->snore={metrics['talk_to_snore_rate']:.3f} ECE={metrics['ece']:.3f}"
        )
        print("confusion (rows=true, cols=pred):")
        names = metrics["confusion"]["labels"]
        print("       " + " ".join(f"{name:>9s}" for name in names))
        for index, name in enumerate(names):
            print(f"{name:>6s} " + " ".join(f"{value:9d}" for value in metrics["confusion"]["matrix"][index]))
    else:
        report["metrics"] = None
        print("no rows with a model-class label; only predictions are reported")

    counts: dict[str, dict[str, int]] = {}
    for row in rows:
        counts.setdefault(row["label"], {}).setdefault(row["predicted"], 0)
        counts[row["label"]][row["predicted"]] += 1
    report["prediction_counts"] = counts
    print("\npredictions by label:")
    for label in sorted(counts):
        summary = ", ".join(f"{name}={count}" for name, count in sorted(counts[label].items()))
        print(f"  {label:>12s}: {summary}")

    if args.out:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(
            json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
        )
        print(f"wrote {args.out}")

    if args.predictions:
        args.predictions.parent.mkdir(parents=True, exist_ok=True)
        with args.predictions.open("w", encoding="utf-8", newline="") as handle:
            writer = csv.writer(handle)
            writer.writerow(["file", "label", "offset_s", "predicted", "confidence",
                             *classes, "active_duration_s"])
            for row in rows:
                writer.writerow(
                    [row["file"], row["label"], row["offset_s"], row["predicted"],
                     row["confidence"], *[row["probabilities"][name] for name in classes],
                     row["active_duration_s"]]
                )
        print(f"wrote {args.predictions}")


if __name__ == "__main__":
    main()
