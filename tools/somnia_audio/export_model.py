"""Export the trained JSON model into Dart constants and the Flutter asset.

Legacy (v2).  The runtime classifier is the DSP score fusion in
``lib/services/audio_event_classifier.dart`` and no longer imports the
generated constants.  This script is kept so a future labelled-night dataset
can be exported and compared against the rules.

A JSON asset alone is awkward inside ``Isolate.run`` (no rootBundle in a
background isolate), so the same numbers are generated as Dart constants.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path


def _dart_double(value: float) -> str:
    text = repr(float(value))
    if text in ("inf", "-inf", "nan"):
        raise ValueError(f"non-finite value in model: {value}")
    return text if ("." in text or "e" in text or "E" in text) else text + ".0"


def _dart_list(values, indent: str = "  ") -> str:
    return "[\n" + "".join(
        f"{indent}{_dart_double(value)},\n" for value in values
    ) + "]"


def render(model: dict) -> str:
    feature_names = model["feature_names"]
    classes = model["classes"]
    mean = model["mean"]
    scale = model["scale"]
    coefficients = model["coefficients"]
    intercept = model["intercept"]
    lines = [
        "// GENERATED FILE — do not edit by hand.",
        "// Source: assets/models/sleep_audio_v2.json",
        "// Regenerate: python -m tools.somnia_audio.export_model",
        "",
        "/// Version of the on-device model format.",
        f"const int kSleepAudioModelVersion = {int(model.get('version', 2))};",
        "",
        "/// Feature order used by the Dart extractor and the Python reference.",
        "const List<String> kSleepAudioFeatureNames = [",
        *[f"  '{name}'," for name in feature_names],
        "];",
        "",
        "const List<String> kSleepAudioModelClasses = [",
        *[f"  '{name}'," for name in classes],
        "];",
        "",
        "const List<double> kSleepAudioModelMean = " + _dart_list(mean) + ";",
        "",
        "const List<double> kSleepAudioModelScale = " + _dart_list(scale) + ";",
        "",
        "const List<List<double>> kSleepAudioModelCoefficients = [",
        *["  " + _dart_list(row) + "," for row in coefficients],
        "];",
        "",
        "const List<double> kSleepAudioModelIntercept = " + _dart_list(intercept) + ";",
        "",
        f"const double kSleepAudioModelTemperature = {_dart_double(model['temperature'])};",
        f"const double kSleepAudioUnknownThreshold = {_dart_double(model['unknown_threshold'])};",
        "",
    ]
    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--model", type=Path, default=Path("tools/somnia_audio/data/model_v2.json")
    )
    parser.add_argument(
        "--asset", type=Path, default=Path("assets/models/sleep_audio_v2.json")
    )
    parser.add_argument(
        "--dart", type=Path, default=Path("lib/services/sleep_audio_model.dart")
    )
    args = parser.parse_args()

    model = json.loads(args.model.read_text(encoding="utf-8"))
    args.asset.parent.mkdir(parents=True, exist_ok=True)
    args.asset.write_text(
        json.dumps(model, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    args.dart.write_text(render(model), encoding="utf-8")
    print(f"wrote {args.asset}")
    print(f"wrote {args.dart}")


if __name__ == "__main__":
    main()
