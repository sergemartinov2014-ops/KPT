# Somnia audio tooling

Offline tools for the night-sound classifier.

## Current state (v3, 2026-11-14)

The shipping classifier is **not** a trained model any more. It is the DSP score
fusion in `lib/services/audio_event_classifier.dart`, and the event detector is
`lib/services/night_sound_detector.dart`. The reasons and the measured results
are in `docs/SLEEP_AUDIO_DSP.md`.

| Piece | Status |
| --- | --- |
| `features.py` | Active. Reference extractor; the Dart port is checked against it by `test/audio_feature_parity_test.dart`. |
| `synth.py` | Active, rewritten for v3: physically grounded snore spectrum, iPhone path, bedroom floor. Generates test data. |
| `make_fixtures.py` | Active. Writes the committed WAV fixtures and Python reference features. |
| `classifier_eval.dart` | Active. Runs the **shipping Dart classifier** on labelled WAVs (directory tree or `--manifest labels.csv`). |
| `session_eval.dart` | Active. Runs the **whole chain** (detector + classifier) over one long recording at several target levels, simulating distance. |
| `eval.py` | Legacy. Evaluates the retired v2 model JSON only. |
| `train.py`, `export_model.py`, `model_v2.json`, `assets/models/sleep_audio_v2.json` | Legacy, kept for a future labelled-night dataset. The runtime no longer imports the exported model. |

### Evaluate the current classifier

```bash
# Real external sanity check (ESC-50 snore/breathing, not a benchmark)
dart run tools/somnia_audio/classifier_eval.dart \
    tools/somnia_audio/data/external/esc50 --recursive \
    --window 1.0 --hop 0.5 --min-active 0.3 \
    --out tools/somnia_audio/data/classifier_real_windows.json

# Synthetic held-out set
python -m tools.somnia_audio.synth --out tools/somnia_audio/data/v3_test --per-class 40 --seed 900000
dart run tools/somnia_audio/classifier_eval.dart \
    --manifest tools/somnia_audio/data/v3_test/labels.csv \
    --out tools/somnia_audio/data/classifier_synthetic.json
```

Measured with those commands:

| Dataset | Metric | v2 model | v3 rules |
| --- | --- | ---: | ---: |
| ESC-50 snore, whole clips (40) | snore recall | 0.025 | **0.950** |
| ESC-50 snore, 1 s windows with ≥0.3 s active | snore recall | 0.033 | **0.867** |
| ESC-50 breathing (false-positive probe) | → snore | 0.028 | **0.475** |
| Synthetic held-out (160 clips) | macro-F1 | 0.938 | **0.932** |

The synthetic number dropped slightly; the real-recording recall rose by a
factor of ~30. That is the intended trade.

---

The rest of this file describes the retired v2 model pipeline. It is kept for a
future dataset of labelled nights; do not use its numbers in product claims.

> **Warning.** The Phase 1 model is trained on synthetic audio only. The
> numbers below describe synthetic clips and a small external sanity check.
> They do not estimate real-world accuracy on a sleeping person. Do not use
> them in a product claim.

## Contents

| File | Purpose |
| --- | --- |
| `features.py` | Reference feature extractor and WAV reader. The Dart implementation must match it. |
| `synth.py` | Deterministic synthetic snore, talk, movement, and ambient clips (v3: physically grounded snore spectrum + iPhone path). |
| `make_fixtures.py` | Writes the committed test fixtures and Python reference values. |
| `train.py` | Legacy v2. Trains, calibrates, tunes the `unknown` threshold, and writes `data/model_v2.json` plus `data/report_v2.json`. |
| `export_model.py` | Legacy v2. Copies the JSON model to `assets/models/` and generates `lib/services/sleep_audio_model.dart`; the runtime does not import it. |
| `classifier_eval.dart` | Runs the shipping Dart classifier on labelled WAVs (directory tree or `--manifest labels.csv`). |
| `extract_features.py` | Extracts the 34 features from WAV files to JSONL or CSV. |
| `eval.py` | Legacy v2. Evaluates the exported model JSON, not the runtime classifier. |
| `fetch_samples.py` | Downloads the ESC-50 snoring and breathing clips used for the external sanity check. |
| `baseline_eval.dart` | Runs the v1 classifier snapshot on a synthetic test directory. |
| `benchmark.dart` | Measures the Dart classifier on 15 s and 45 s clips. |
| `DATASETS.md` | Verified sources, licences, and access restrictions. |

## Requirements

- Python 3.10 or newer.
- NumPy and scikit-learn for training and evaluation.
- Flutter/Dart for the app, fixtures, and parity tests.

```bash
python -m venv .venv
# Windows: .venv\Scripts\activate
# POSIX:   source .venv/bin/activate
pip install -r tools/somnia_audio/requirements.txt
```

`fetch_samples.py` uses only the Python standard library.

## Reproduce the model

Run from the repository root:

```bash
python -m tools.somnia_audio.train --per-class 120 --force
python -m tools.somnia_audio.export_model
python -m tools.somnia_audio.make_fixtures
flutter test
```

`train.py` generates its own synthetic dataset and caches the feature matrices
under `tools/somnia_audio/data/`. The cache files are generated and gitignored.
`train.py` writes `model_v2.json` and `report_v2.json`. `export_model.py` copies
the model to `assets/models/sleep_audio_v2.json` and generates the Dart
constants. `make_fixtures.py` writes the committed WAV fixtures and the Python
reference values used by the parity test.

The final run used 120 clips per class:

| Split | Rows |
| --- | ---: |
| train | 3360 |
| validation | 1120 |
| test | 1120 |

Rows are clip-level samples plus 1 s windows from the same clips. Clip rows
have weight 5.0; window rows have weight 1.0. A window with an active-frame
ratio below 0.20 and only partial event overlap is relabelled `ambient`.

## Measured results

### Synthetic test split

Source: `data/report_v2.json`.

| Metric | Value |
| --- | ---: |
| Macro-F1 (4 known classes) | 0.938 |
| Snore precision | 0.957 |
| Snore recall | 0.928 |
| Talk to snore rate | 0.000 |
| Coverage at the `unknown` threshold | 0.945 |
| Accuracy on covered rows | 0.990 |
| Expected calibration error | 0.010 |
| Temperature | 1.08 |
| `unknown` threshold | 0.81 |

The test split comes from the same synthetic generator as training and
validation. It measures that the pipeline is consistent, not that the model
generalises to real bedrooms.

### Baseline v1 comparison

Source: `data/baseline_v1_report.json`.

The v1 snapshot was run on 160 synthetic clips, 40 per class, generated with
seeds outside the training range.

| Metric | v1 | v2 |
| --- | ---: | ---: |
| Accuracy | 0.3375 | 0.990 on covered rows |
| Macro-F1 | 0.365 | 0.938 |
| Snore recall | 0.000 | 0.928 |
| Talk to snore rate | 0.000 | 0.000 |

v2 can return `unknown`, so its accuracy is reported only for rows above the
threshold. It is not an exact apples-to-apples comparison with v1. The useful
comparison is that v1 missed every snore and labelled 38 of 40 ambient clips
as snore.

### External ESC-50 sanity check

Source: `data/external_esc50_whole_report.json` and
`data/external_esc50_windows_report.json`.

This is **not a benchmark**. ESC-50 clips are 5 s web recordings, not labelled
sleep recordings. The clips are CC BY-NC 3.0 and were used for evaluation
only. The model was not trained or tuned on them.

Whole clips, 40 snoring clips:

| Prediction | Count |
| --- | ---: |
| snore | 1 |
| talk | 7 |
| movement | 19 |
| ambient | 5 |
| unknown | 8 |

Snore recall is 0.025; coverage is 0.800.

Fixed 1 s windows with a 0.5 s hop, all 720 windows from 40 snoring and 40
breathing clips:

| True label | snore | talk | movement | ambient | unknown |
| --- | ---: | ---: | ---: | ---: | ---: |
| snore (360) | 12 | 14 | 98 | 138 | 98 |
| breathing (360, not a model class) | 10 | 133 | 26 | 104 | 87 |

Snore recall is 0.033; coverage is 0.728. The breathing rows are shown for
inspection only and are excluded from the supervised metrics because
`breathing` is not one of the model classes.

The gap is large and expected: the model has never seen a real snore, a real
room, or a real phone microphone. A real labelled night dataset is required
before any claim about field performance.


### End-to-end check on a real night recording

`session_eval.dart` feeds a continuous stream through the same detector and
classifier the app uses, mixing the recording into a fixed room-noise floor at
several target peak levels.  Source used for the checked-in report: a 47 s real
snoring recording with a long apnoea pause (BMC Medicine, CC BY, via Wikimedia
Commons), with the apnoea gap silenced so the synthetic room floor is what sits
between the two snoring bouts.  The file is not committed
(`data/external/` is gitignored).

```bash
dart run tools/somnia_audio/session_eval.dart \
    --source tools/somnia_audio/data/external/snoring_apnoea/snoring_apnoea_gated_16k.wav \
    --room-db -75 --levels -22,-32,-42,-52,-62 \
    --snore-ranges 0-7.2,39.8-46.9 \
    --out tools/somnia_audio/data/session_real_snore_quiet_room.json
```

Measured with a quiet-bedroom floor of −75 dBFS: both snoring bouts are
detected and labelled `snore` at −22, −32 and −42 dBFS peak; at −52 the events
are still detected but labelled `ambient`; at −62 one bout is missed.  With a
noisy floor of −65 dBFS the reliable range is −12…−32 dBFS.  See
`data/session_real_snore*.json` and `docs/SLEEP_AUDIO_DSP.md`.

### Dart runtime

Source: `data/benchmark_report.json` (v3 classifier). Measured on the development machine with
the Dart JIT, not on a phone.

| Clip | Median | Min | Max |
| --- | ---: | ---: | ---: |
| 15 s | 27.19 ms | 27.14 ms | 27.45 ms |
| 45 s | 81.63 ms | 80.08 ms | 114.73 ms |

The recorder runs classification in `Isolate.run`, so this work stays off the
UI isolate. Re-measure an AOT build on a target phone before making UI
promises.

## Evaluate your own WAV files

Directory names are labels:

```text
my_data/
  snore/*.wav
  talk/*.wav
  movement/*.wav
  ambient/*.wav
```

```bash
python -m tools.somnia_audio.eval my_data \
    --recursive \
    --out my_report.json \
    --predictions my_predictions.csv
```

Fixed-window evaluation:

```bash
python -m tools.somnia_audio.eval my_data \
    --recursive --window 1.0 --hop 0.5 \
    --out my_window_report.json
```

Map a directory label that is not a model class:

```bash
python -m tools.somnia_audio.eval my_data \
    --recursive --map breathing=ambient
```

A manifest with `file` and `label` columns is also accepted:

```bash
python -m tools.somnia_audio.eval --manifest my_manifest.csv
```

`extract_features.py` writes features without evaluating them:

```bash
python -m tools.somnia_audio.extract_features my_data --recursive --out features.jsonl
python -m tools.somnia_audio.extract_features my_data --recursive --csv --out features.csv
```

## Calibration notes

- The model outputs a temperature-scaled probability for each known class.
  If the top probability is below the exported `unknown` threshold, the result
  is `unknown`. The threshold is tuned on validation data with a coverage
  floor and a talk-to-snore ceiling.
- A raw synthetic fixture with an unusual envelope can score below the
  threshold and become `unknown`. A recorder-style synthetic clip scores above
  0.99. This is deliberate conservative behaviour, not a test failure.
- The recorder labels an event `unknown` when confidence is low. The service
  also requires enough active duration before it treats an event as a real
  candidate.
- Do not lower the threshold to make the external ESC-50 numbers look better.
  That would trade a real false-positive risk for a cosmetic metric.

## Data and licences

Read `DATASETS.md` before downloading anything. External audio belongs under
`tools/somnia_audio/data/external/` and is gitignored. ESC-50 is CC BY-NC 3.0:
research and evaluation only. ICSD is gated, non-commercial, and forbids
redistribution. Do not commit external clips or derived audio.


