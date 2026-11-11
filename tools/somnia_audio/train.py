"""Train the Phase-1 Somnia classifier on synthetic clips.

The report this script prints is the only source of the numbers in the v2
documentation.  It never claims real-night accuracy: the dataset is synthetic.
"""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path

import numpy as np
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import confusion_matrix, f1_score, precision_recall_fscore_support
from sklearn.preprocessing import StandardScaler

from .features import FEATURE_NAMES, extract
from .synth import CLASSES, Clip, generate_dataset

WINDOW_SECONDS = 1.0
WINDOW_HOP_SECONDS = 1.0
MAX_WINDOWS_PER_CLIP = 6


def _features_for(samples: np.ndarray) -> list[float]:
    values = extract(samples)
    return [values[name] for name in FEATURE_NAMES]


def _label_for_window(clip: Clip, start: float, length: float) -> str:
    overlap = max(
        0.0,
        min(start + length, clip.event_end_s) - max(start, clip.event_start_s),
    )
    return clip.label if overlap >= 0.5 * length else "ambient"


def build_rows(clips: list[Clip], include_windows: bool) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    rows: list[list[float]] = []
    labels: list[str] = []
    weights: list[float] = []
    for clip in clips:
        rows.append(_features_for(clip.samples))
        labels.append(clip.label)
        weights.append(5.0)
        if not include_windows:
            continue
        total = clip.samples.size / 16000.0
        starts = []
        cursor = 0.0
        while cursor + WINDOW_SECONDS <= total + 1e-6:
            starts.append(cursor)
            cursor += WINDOW_HOP_SECONDS
        if len(starts) > MAX_WINDOWS_PER_CLIP:
            index = np.linspace(0, len(starts) - 1, MAX_WINDOWS_PER_CLIP)
            starts = [starts[int(round(value))] for value in index]
        for start in starts:
            begin = int(round(start * 16000))
            end = min(clip.samples.size, begin + int(WINDOW_SECONDS * 16000))
            if end - begin < int(0.5 * 16000):
                continue
            window = _features_for(clip.samples[begin:end])
            window_label = _label_for_window(clip, start, WINDOW_SECONDS)
            # A silent gap inside a snore event is background, not snore.
            if window_label != "ambient" and window[FEATURE_NAMES.index("active_frame_ratio")] < 0.20:
                window_label = "ambient"
            rows.append(window)
            labels.append(window_label)
            weights.append(1.0)
    return (
        np.asarray(rows, dtype=np.float64),
        np.asarray(labels),
        np.asarray(weights, dtype=np.float64),
    )


def _load_or_build(
    cache: Path,
    per_class: int,
    seed: int,
    include_windows: bool,
    force: bool,
) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    if cache.exists() and not force:
        data = np.load(cache, allow_pickle=True)
        return data["x"], data["y"], data["w"]
    clips = generate_dataset(per_class=per_class, seed=seed)
    x, y, w = build_rows(clips, include_windows)
    cache.parent.mkdir(parents=True, exist_ok=True)
    np.savez_compressed(cache, x=x, y=y, w=w)
    return x, y, w


def _softmax(logits: np.ndarray) -> np.ndarray:
    logits = logits - np.max(logits, axis=1, keepdims=True)
    exp = np.exp(logits)
    return exp / np.sum(exp, axis=1, keepdims=True)


def _temperature_scale(probabilities: np.ndarray, temperature: float) -> np.ndarray:
    clipped = np.clip(probabilities, 1e-9, 1.0)
    logits = np.log(clipped) / temperature
    return _softmax(logits)


def _ece(probabilities: np.ndarray, predictions: np.ndarray, truth: np.ndarray, bins: int = 15) -> float:
    confidence = probabilities[np.arange(probabilities.shape[0]), predictions]
    correct = (predictions == truth).astype(np.float64)
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


def _choose_temperature(probabilities: np.ndarray, truth: np.ndarray) -> float:
    best_temperature = 1.0
    best_loss = float("inf")
    for temperature in np.arange(0.30, 4.01, 0.01):
        calibrated = _temperature_scale(probabilities, float(temperature))
        loss = -float(
            np.mean(np.log(calibrated[np.arange(truth.size), truth] + 1e-12))
        )
        if loss < best_loss:
            best_loss = loss
            best_temperature = float(temperature)
    return best_temperature


def _choose_unknown_threshold(
    probabilities: np.ndarray, predictions: np.ndarray, truth: np.ndarray, classes: list[str]
) -> float:
    best_threshold = 0.0
    best_score = -1.0
    snore_index = classes.index("snore")
    talk_index = classes.index("talk")
    for threshold in np.arange(0.30, 0.86, 0.01):
        confidence = probabilities[np.arange(probabilities.shape[0]), predictions]
        accepted = confidence >= threshold
        if np.mean(accepted) < 0.85:
            continue
        y_true = truth[accepted]
        y_pred = predictions[accepted]
        score = f1_score(y_true, y_pred, average="macro")
        talk_to_snore = float(
            np.mean((truth == talk_index)[accepted] & (predictions[accepted] == snore_index))
        )
        if talk_to_snore > 0.05:
            continue
        if score > best_score:
            best_score = score
            best_threshold = float(threshold)
    return best_threshold


def evaluate(
    probabilities: np.ndarray,
    truth: np.ndarray,
    classes: list[str],
    threshold: float,
    label: str,
) -> dict:
    predictions = np.argmax(probabilities, axis=1)
    confidence = probabilities[np.arange(probabilities.shape[0]), predictions]
    known = confidence >= threshold
    effective = np.where(known, predictions, len(classes))
    names = classes + ["unknown"]
    matrix = confusion_matrix(truth, effective, labels=list(range(len(classes) + 1)))
    macro_f1 = f1_score(truth, effective, labels=list(range(len(classes))), average="macro")
    precision, recall, f1, support = precision_recall_fscore_support(
        truth, effective, labels=list(range(len(classes))), zero_division=0
    )
    snore_index = classes.index("snore")
    talk_index = classes.index("talk")
    talk_to_snore = float(
        np.mean((truth == talk_index) & (effective == snore_index))
    )
    snore_precision = float(precision[snore_index])
    snore_recall = float(recall[snore_index])
    report = {
        "split": label,
        "rows": int(truth.size),
        "coverage": float(np.mean(known)),
        "unknown_rate": float(np.mean(~known)),
        "accuracy_known": float(np.mean(effective[known] == truth[known]))
        if np.any(known)
        else 0.0,
        "macro_f1": float(macro_f1),
        "snore_precision": snore_precision,
        "snore_recall": snore_recall,
        "talk_to_snore_rate": talk_to_snore,
        "ece": float(_ece(probabilities, predictions, truth)),
        "per_class": {
            name: {
                "precision": float(precision[index]),
                "recall": float(recall[index]),
                "f1": float(f1[index]),
                "support": int(support[index]),
            }
            for index, name in enumerate(classes)
        },
        "confusion": {
            "labels": names,
            "matrix": matrix.astype(int).tolist(),
        },
    }
    print(f"\n[{label}] rows={report['rows']} coverage={report['coverage']:.3f} "
          f"macro-F1={report['macro_f1']:.3f} snore P/R={snore_precision:.3f}/"
          f"{snore_recall:.3f} talk->snore={talk_to_snore:.3f} ECE={report['ece']:.3f}")
    print("confusion (rows=true, cols=pred):")
    print("       " + " ".join(f"{name:>9s}" for name in names))
    for index, name in enumerate(names):
        print(f"{name:>6s} " + " ".join(f"{value:9d}" for value in matrix[index]))
    return report


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--per-class", type=int, default=120)
    parser.add_argument("--force", action="store_true", help="rebuild feature caches")
    parser.add_argument("--out", type=Path, default=Path("tools/somnia_audio/data/model_v2.json"))
    parser.add_argument("--report", type=Path, default=Path("tools/somnia_audio/data/report_v2.json"))
    args = parser.parse_args()

    data_dir = Path("tools/somnia_audio/data")
    classes = list(CLASSES)
    train_x, train_y, train_w = _load_or_build(
        data_dir / "features_train.npz", args.per_class, 1000, True, args.force
    )
    val_x, val_y, val_w = _load_or_build(
        data_dir / "features_val.npz", max(20, args.per_class // 3), 500_000, True, args.force
    )
    test_x, test_y, test_w = _load_or_build(
        data_dir / "features_test.npz", max(20, args.per_class // 3), 900_000, True, args.force
    )

    scaler = StandardScaler().fit(train_x, sample_weight=train_w)
    model = LogisticRegression(
        C=1.0,
        max_iter=3000,
        class_weight="balanced",
        solver="lbfgs",
    )
    model.fit(scaler.transform(train_x), train_y, sample_weight=train_w)

    def probabilities_for(x: np.ndarray) -> np.ndarray:
        return model.predict_proba(scaler.transform(x))

    row = {name: index for index, name in enumerate(model.classes_)}
    order = np.array([row[name] for name in classes])
    train_probabilities = probabilities_for(train_x)[:, order]
    val_probabilities = probabilities_for(val_x)[:, order]
    test_probabilities = probabilities_for(test_x)[:, order]

    truth_train = np.array([classes.index(value) for value in train_y])
    truth_val = np.array([classes.index(value) for value in val_y])
    truth_test = np.array([classes.index(value) for value in test_y])

    temperature = _choose_temperature(val_probabilities, truth_val)
    val_calibrated = _temperature_scale(val_probabilities, temperature)
    test_calibrated = _temperature_scale(test_probabilities, temperature)
    train_calibrated = _temperature_scale(train_probabilities, temperature)
    threshold = _choose_unknown_threshold(
        val_calibrated, np.argmax(val_calibrated, axis=1), truth_val, classes
    )

    report = {
        "dataset": "synthetic (synth.py)",
        "warning": "No real labelled nights were available. These numbers do not estimate real-world accuracy.",
        "train_rows": int(train_x.shape[0]),
        "val_rows": int(val_x.shape[0]),
        "test_rows": int(test_x.shape[0]),
        "temperature": temperature,
        "unknown_threshold": threshold,
        "train": evaluate(train_calibrated, truth_train, classes, threshold, "train"),
        "val": evaluate(val_calibrated, truth_val, classes, threshold, "val"),
        "test": evaluate(test_calibrated, truth_test, classes, threshold, "test"),
    }

    model_payload = {
        "version": 2,
        "model_type": "multinomial_logistic_regression",
        "sample_rate": 16000,
        "frame_size": 400,
        "hop_size": 160,
        "fft_size": 512,
        "feature_names": list(FEATURE_NAMES),
        "classes": classes,
        "mean": scaler.mean_.astype(float).tolist(),
        "scale": scaler.scale_.astype(float).tolist(),
        "coefficients": getattr(model, "coef_")[order, :].astype(float).tolist(),
        "intercept": getattr(model, "intercept_")[order].astype(float).tolist(),
        "temperature": temperature,
        "unknown_threshold": threshold,
        "training": {
            "source": "synthetic",
            "rows": int(train_x.shape[0]),
            "per_class": args.per_class,
            "seed": 1000,
            "warning": report["warning"],
            "test_macro_f1": report["test"]["macro_f1"],
            "test_snore_precision": report["test"]["snore_precision"],
            "test_snore_recall": report["test"]["snore_recall"],
            "test_ece": report["test"]["ece"],
        },
    }

    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(model_payload, ensure_ascii=False, indent=2), encoding="utf-8")
    args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"\nwrote {args.out}")
    print(f"wrote {args.report}")
    print(f"temperature={temperature:.2f} unknown_threshold={threshold:.2f}")


if __name__ == "__main__":
    main()
