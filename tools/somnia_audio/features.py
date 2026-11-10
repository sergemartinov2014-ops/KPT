"""Reference implementation of the Somnia night-sound features.

The Dart port in ``lib/services/audio_event_classifier.dart`` must produce the
same values (relative error <= 1e-3).  Keep the constants and the order of the
operations in sync with the Dart code.

Run as a CLI to dump features for WAV files::

    python -m tools.somnia_audio.features file.wav [...]
"""

from __future__ import annotations

import argparse
import json
import math
import wave
from pathlib import Path
from typing import Iterable

import numpy as np

SAMPLE_RATE = 16000
FRAME_SIZE = 400          # 25 ms
HOP_SIZE = 160            # 10 ms
FFT_SIZE = 512
EPS = 1e-12

BAND_EDGES_HZ = (50.0, 150.0, 400.0, 1000.0, 2500.0, 5000.0, 8000.0)
BAND_NAMES = (
    "band_50_150",
    "band_150_400",
    "band_400_1000",
    "band_1000_2500",
    "band_2500_5000",
    "band_5000_8000",
)

FEATURE_NAMES = (
    "duration_s",
    "active_duration_s",
    "snr_db",
    "duty_cycle",
    "active_frame_ratio",
    "onset_rate",
    "segment_duration_median_ms",
    "segment_duration_iqr_ms",
    "gap_cv",
    "crest_factor",
    "envelope_kurtosis",
    "short_broadband_ratio",
    "zcr_median",
    "centroid_median_hz",
    "centroid_iqr_hz",
    "rolloff_median_hz",
    "spectral_slope_db_per_khz",
    "flatness_median",
    "flatness_iqr",
    "flux_median",
    *BAND_NAMES,
    "voicing_median",
    "voiced_frame_ratio",
    "f0_median_hz",
    "f0_std_semitones",
    "modulation_syllable_ratio",
    "modulation_breath_ratio",
    "modulation_breath_valid",
    "modulation_peak_hz",
)

# ---------------------------------------------------------------- utilities


def _f32(value: float) -> float:
    return float(np.float32(value))


def _db(value: float) -> float:
    if value <= 1e-7:
        return -100.0
    return max(-100.0, min(0.0, 20.0 * math.log10(value)))


def _percentile(values: Iterable[float], q: float) -> float:
    """Nearest-rank percentile, identical to the Dart helper.

    ``q`` is 0..1.  The index is rounded half up: for a 4-element list
    ``q=0.5`` returns the third element.
    """
    data = np.sort(np.asarray(list(values), dtype=np.float64))
    if data.size == 0:
        return 0.0
    if data.size == 1:
        return float(data[0])
    index = int(math.floor(q * (data.size - 1) + 0.5))
    index = max(0, min(data.size - 1, index))
    return float(data[index])


def _median(values: Iterable[float]) -> float:
    return _percentile(values, 0.5)


def _hann(size: int) -> np.ndarray:
    n = np.arange(size, dtype=np.float64)
    return 0.5 * (1.0 - np.cos(2.0 * np.pi * n / max(1, size - 1)))


_HANN_400 = _hann(FRAME_SIZE)


def read_wav(path: str | Path) -> tuple[np.ndarray, int]:
    """Read a mono/stereo 16-bit PCM WAV, return float32 mono and sample rate."""
    with wave.open(str(path), "rb") as handle:
        channels = handle.getnchannels()
        width = handle.getsampwidth()
        rate = handle.getframerate()
        raw = handle.readframes(handle.getnframes())
    if width != 2:
        raise ValueError(f"only 16-bit PCM is supported, got {width * 8}-bit")
    data = np.frombuffer(raw, dtype="<i2").astype(np.float32) / 32768.0
    if channels > 1:
        data = data.reshape(-1, channels).mean(axis=1)
    if rate != SAMPLE_RATE and data.size:
        duration = data.size / rate
        target = int(round(duration * SAMPLE_RATE))
        data = np.interp(
            np.linspace(0.0, duration, target, endpoint=False),
            np.linspace(0.0, duration, data.size, endpoint=False),
            data,
        ).astype(np.float32)
        rate = SAMPLE_RATE
    return data, rate


def write_wav(path: str | Path, samples: np.ndarray, sample_rate: int = SAMPLE_RATE) -> None:
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    clipped = np.clip(samples, -1.0, 1.0)
    pcm = np.round(clipped * 32767.0).astype("<i2")
    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(sample_rate)
        handle.writeframes(pcm.tobytes())


# ---------------------------------------------------------------- framing


def _frame_count(sample_count: int) -> int:
    if sample_count <= FRAME_SIZE:
        return 1
    return 1 + (sample_count - FRAME_SIZE) // HOP_SIZE


def _rms_db(frame: np.ndarray) -> float:
    if frame.size == 0:
        return -100.0
    return _db(float(np.sqrt(np.mean(frame.astype(np.float64) ** 2) + EPS)))


def _zero_crossing_rate(frame: np.ndarray) -> float:
    if frame.size <= 1:
        return 0.0
    signs = frame >= 0
    return float(np.count_nonzero(signs[1:] != signs[:-1])) / float(frame.size - 1)


def _spectrum(frame: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    windowed = frame.astype(np.float64) * _HANN_400
    if windowed.size < FFT_SIZE:
        windowed = np.pad(windowed, (0, FFT_SIZE - windowed.size))
    spectrum = np.fft.rfft(windowed)
    power = (spectrum.real**2 + spectrum.imag**2).astype(np.float64)
    return power, np.abs(spectrum)


def _band_indices(freqs: np.ndarray) -> list[np.ndarray]:
    return [
        (freqs >= BAND_EDGES_HZ[i]) & (freqs < BAND_EDGES_HZ[i + 1])
        for i in range(len(BAND_EDGES_HZ) - 1)
    ]


# ---------------------------------------------------------------- voicing

_ACF_DECIMATION = 4
_ACF_WINDOW = 640  # 40 ms
_ACF_MIN_LAG = 10  # 400 Hz at 4 kHz
_ACF_MAX_LAG = 57  # ~70 Hz at 4 kHz


def _voicing(frame_start: int, samples: np.ndarray) -> tuple[float, float]:
    """Return (strength, f0) using a downsampled, bias-corrected ACF."""
    chunk = np.zeros(_ACF_WINDOW, dtype=np.float64)
    available = min(_ACF_WINDOW, max(0, samples.size - frame_start))
    if available <= 0:
        return 0.0, 0.0
    chunk[:available] = samples[frame_start : frame_start + available]
    usable = (chunk.size // _ACF_DECIMATION) * _ACF_DECIMATION
    down = chunk[:usable].reshape(-1, _ACF_DECIMATION).mean(axis=1)
    down = down - float(np.mean(down))
    energy = float(np.dot(down, down))
    if energy <= 1e-10:
        return 0.0, 0.0

    best = 0.0
    best_lag = 0
    crossed_zero = False
    n = down.size
    for lag in range(_ACF_MIN_LAG, min(_ACF_MAX_LAG, n - 1) + 1):
        a = down[: n - lag]
        b = down[lag:]
        denominator = math.sqrt(float(np.dot(a, a) * np.dot(b, b)) + EPS)
        if denominator <= 0.0:
            continue
        correlation = float(np.dot(a, b)) / denominator
        # Unbiased correction: shorter overlaps get lower weight.
        correlation /= max(EPS, (n - lag) / n)
        if not crossed_zero:
            if correlation < 0.0:
                crossed_zero = True
            continue
        if correlation > best:
            best = correlation
            best_lag = lag
    if best_lag == 0 or best <= 0.0:
        return 0.0, 0.0
    sample_rate_down = SAMPLE_RATE / _ACF_DECIMATION
    return min(1.0, best), sample_rate_down / best_lag


# ---------------------------------------------------------------- modulation


def _next_power_of_two(value: int) -> int:
    result = 1
    while result < value:
        result <<= 1
    return result


def _band_energy(freqs: np.ndarray, power: np.ndarray, low: float, high: float) -> float:
    mask = (freqs >= low) & (freqs < high)
    return float(np.sum(power[mask]))


def _modulation(envelope: np.ndarray, frame_rate: float) -> dict[str, float]:
    """Modulation spectrum of the active-region envelope (frame rate 100 Hz)."""
    result = {
        "syllable": 0.0,
        "breath": 0.0,
        "breath_valid": 0.0,
        "peak_hz": 0.0,
        "span_s": envelope.size / frame_rate if frame_rate > 0 else 0.0,
    }
    if envelope.size < 8:
        return result
    signal = envelope.astype(np.float64)
    signal = signal - float(np.mean(signal))
    if float(np.dot(signal, signal)) <= 1e-12:
        return result

    windowed = signal * _hann(signal.size)
    nfft = _next_power_of_two(max(64, windowed.size))
    spectrum = np.fft.rfft(windowed, nfft)
    power = (spectrum.real**2 + spectrum.imag**2).astype(np.float64)
    freqs = np.fft.rfftfreq(nfft, d=1.0 / frame_rate)
    total = _band_energy(freqs, power, 0.05, 20.0)
    if total <= EPS:
        return result

    result["syllable"] = _band_energy(freqs, power, 2.0, 8.0) / total
    if result["span_s"] >= 8.0:
        result["breath_valid"] = 1.0
        result["breath"] = _band_energy(freqs, power, 0.15, 0.7) / total

    mask = (freqs >= 0.15) & (freqs <= 8.0)
    if np.any(mask):
        local = np.where(mask, power, 0.0)
        result["peak_hz"] = float(freqs[int(np.argmax(local))])
    return result


# ---------------------------------------------------------------- main


def extract(samples: np.ndarray, sample_rate: int = SAMPLE_RATE) -> dict[str, float]:
    """Compute the v2 feature dictionary for mono float samples."""
    samples = np.asarray(samples, dtype=np.float32)
    sample_count = int(samples.size)
    if sample_count < 32 or sample_rate <= 0:
        return {name: 0.0 for name in FEATURE_NAMES}

    duration_s = sample_count / float(sample_rate)
    frame_count = _frame_count(sample_count)

    rms_db = np.empty(frame_count, dtype=np.float64)
    zcr = np.empty(frame_count, dtype=np.float64)
    centroid = np.empty(frame_count, dtype=np.float64)
    rolloff = np.empty(frame_count, dtype=np.float64)
    slope = np.empty(frame_count, dtype=np.float64)
    flatness = np.empty(frame_count, dtype=np.float64)
    flux = np.empty(frame_count, dtype=np.float64)
    band_power = np.zeros((frame_count, len(BAND_NAMES)), dtype=np.float64)
    voicing = np.zeros(frame_count, dtype=np.float64)
    f0 = np.zeros(frame_count, dtype=np.float64)

    bin_hz = sample_rate / float(FFT_SIZE)
    freqs = np.arange(FFT_SIZE // 2 + 1, dtype=np.float64) * bin_hz
    bands = _band_indices(freqs)
    audible = (freqs >= 50.0) & (freqs < 8000.0)
    flat_range = (freqs >= 100.0) & (freqs < 4000.0)
    slope_range = (freqs >= 50.0) & (freqs < 4000.0)
    centroid_weights = np.where(audible, freqs, 0.0)

    previous_magnitude = np.zeros(FFT_SIZE // 2 + 1, dtype=np.float64)
    for index in range(frame_count):
        start = index * HOP_SIZE
        frame = np.zeros(FRAME_SIZE, dtype=np.float32)
        available = min(FRAME_SIZE, sample_count - start)
        if available > 0:
            frame[:available] = samples[start : start + available]
        rms_db[index] = _rms_db(frame)
        zcr[index] = _zero_crossing_rate(frame)

        power, magnitude = _spectrum(frame)
        total = float(np.sum(power[audible]))
        centroid[index] = (
            float(np.dot(centroid_weights, power)) / total if total > EPS else 0.0
        )

        cumulative = np.cumsum(np.where(audible, power, 0.0))
        if total > EPS:
            target = 0.85 * total
            idx = int(np.searchsorted(cumulative, target, side="left"))
            idx = min(idx, freqs.size - 1)
            rolloff[index] = float(freqs[idx])
        else:
            rolloff[index] = 0.0

        if np.count_nonzero(slope_range) >= 2:
            p = power[slope_range]
            f = freqs[slope_range] / 1000.0
            db = 10.0 * np.log10(p + EPS)
            denominator = float(np.dot(f - np.mean(f), f - np.mean(f)))
            slope[index] = (
                float(np.dot(f - np.mean(f), db - np.mean(db))) / denominator
                if denominator > EPS
                else 0.0
            )
        else:
            slope[index] = 0.0

        p = power[flat_range]
        if p.size:
            arithmetic = float(np.mean(p))
            geometric = float(np.exp(np.mean(np.log(p + EPS))))
            flatness[index] = (
                max(0.0, min(1.0, geometric / arithmetic)) if arithmetic > EPS else 0.0
            )
        else:
            flatness[index] = 0.0

        normalized = magnitude / (float(np.sum(magnitude[audible])) + EPS)
        if index == 0:
            flux[index] = 0.0
        else:
            diff = float(np.sum(np.abs(normalized - previous_magnitude)))
            flux[index] = max(0.0, min(1.0, diff))
        previous_magnitude = normalized

        for band_index, mask in enumerate(bands):
            band_power[index, band_index] = float(np.sum(power[mask]))

        if index % 2 == 0:
            strength, pitch = _voicing(start, samples)
            voicing[index] = strength
            f0[index] = pitch
        elif index > 0:
            voicing[index] = voicing[index - 1]
            f0[index] = f0[index - 1]

    # Adaptive event detection: 10th percentile floor, +10 dB start, +6 dB hold.
    noise_floor_db = _percentile(rms_db, 0.10)
    start_threshold = noise_floor_db + 10.0
    hold_threshold = noise_floor_db + 6.0
    mask = rms_db > hold_threshold
    # A frame above the start threshold always starts an event.
    starts = rms_db > start_threshold
    for index in range(frame_count):
        if starts[index] and not mask[index]:
            mask[index] = True
    # Bridge gaps up to 40 ms (4 frames).
    index = 0
    while index < frame_count:
        if mask[index]:
            index += 1
            continue
        gap_start = index
        while index < frame_count and not mask[index]:
            index += 1
        gap = index - gap_start
        if 0 < gap <= 4 and gap_start > 0 and index < frame_count:
            mask[gap_start:index] = True

    active_indices = np.flatnonzero(mask)
    active_frame_count = int(active_indices.size)

    if active_frame_count == 0:
        result = {name: 0.0 for name in FEATURE_NAMES}
        result["duration_s"] = duration_s
        result["snr_db"] = 0.0
        result["active_frame_ratio"] = 0.0
        return result

    def active_median(values: np.ndarray) -> float:
        return _median(values[active_indices])

    def active_iqr(values: np.ndarray) -> float:
        picked = values[active_indices]
        return _percentile(picked, 0.75) - _percentile(picked, 0.25)

    first_active = int(active_indices[0])
    last_active = int(active_indices[-1])
    active_duration_s = active_frame_count * HOP_SIZE / float(sample_rate)
    event_span_s = (last_active - first_active + 1) * HOP_SIZE / float(sample_rate)

    # Event segments and gaps.
    segments: list[tuple[int, int]] = []
    index = first_active
    while index <= last_active:
        if not mask[index]:
            index += 1
            continue
        start = index
        while index <= last_active and mask[index]:
            index += 1
        segments.append((start, index - 1))
    segment_durations = np.array(
        [(end - start + 1) * HOP_SIZE / sample_rate for start, end in segments],
        dtype=np.float64,
    )
    gaps = []
    for previous, current in zip(segments, segments[1:]):
        gaps.append((current[0] - previous[1] - 1) * HOP_SIZE / sample_rate)
    gap_cv = 0.0
    if len(gaps) >= 2:
        gap_mean = float(np.mean(gaps))
        if gap_mean > EPS:
            gap_cv = float(np.std(gaps)) / gap_mean

    onset_rate = len(segments) / max(EPS, active_duration_s)
    duty_cycle = active_duration_s / max(EPS, duration_s)
    active_frame_ratio = active_frame_count / float(frame_count)

    # Level features.
    floor_db = noise_floor_db
    active_median_db = _median(rms_db[active_indices])
    snr_db = active_median_db - floor_db
    active_rms = np.power(10.0, rms_db[active_indices] / 20.0)
    crest = float(np.max(active_rms) / (np.mean(active_rms) + EPS))
    envelope = active_rms
    envelope_mean = float(np.mean(envelope))
    envelope_std = float(np.std(envelope))
    kurtosis = 0.0
    if envelope_std > EPS:
        kurtosis = float(
            np.mean(((envelope - envelope_mean) / envelope_std) ** 4)
        )

    # Short broadband bursts: <150 ms, bright and flat.
    short_total = 0.0
    for start, end in segments:
        duration = (end - start + 1) * HOP_SIZE / sample_rate
        if duration >= 0.150:
            continue
        frames = np.arange(start, end + 1)
        if (
            np.mean(centroid[frames]) > 2000.0
            and np.mean(flatness[frames]) > 0.30
        ):
            short_total += duration
    short_ratio = short_total / max(EPS, active_duration_s)

    # Spectral medians.
    zcr_median = active_median(zcr)
    centroid_median = active_median(centroid)
    centroid_iqr = active_iqr(centroid)
    rolloff_median = active_median(rolloff)
    slope_median = active_median(slope)
    flatness_median = active_median(flatness)
    flatness_iqr = active_iqr(flatness)
    flux_median = active_median(flux)

    mean_bands = np.mean(band_power[active_indices], axis=0)
    band_sum = float(np.sum(mean_bands) + EPS)
    band_ratios = [float(value / band_sum) for value in mean_bands]

    # Voicing on active frames.
    voiced_frames = active_indices[
        (voicing[active_indices] > 0.30) & (f0[active_indices] > 0.0)
    ]
    voiced_ratio = float(voiced_frames.size) / float(active_frame_count)
    voicing_median = active_median(voicing)
    f0_median = _median(f0[voiced_frames]) if voiced_frames.size else 0.0
    f0_std = 0.0
    if voiced_frames.size >= 2 and f0_median > 0.0:
        semitones = 12.0 * np.log2(f0[voiced_frames] / f0_median)
        f0_std = float(np.std(semitones))

    # Modulation on the envelope of the active span (including gaps).
    envelope_span = np.power(10.0, rms_db[first_active : last_active + 1] / 20.0)
    modulation = _modulation(envelope_span, sample_rate / HOP_SIZE)

    result = {
        "duration_s": duration_s,
        "active_duration_s": active_duration_s,
        "snr_db": snr_db,
        "duty_cycle": duty_cycle,
        "active_frame_ratio": active_frame_ratio,
        "onset_rate": onset_rate,
        "segment_duration_median_ms": _median(segment_durations) * 1000.0,
        "segment_duration_iqr_ms": (
            _percentile(segment_durations, 0.75)
            - _percentile(segment_durations, 0.25)
        )
        * 1000.0,
        "gap_cv": gap_cv,
        "crest_factor": crest,
        "envelope_kurtosis": kurtosis,
        "short_broadband_ratio": short_ratio,
        "zcr_median": zcr_median,
        "centroid_median_hz": centroid_median,
        "centroid_iqr_hz": centroid_iqr,
        "rolloff_median_hz": rolloff_median,
        "spectral_slope_db_per_khz": slope_median,
        "flatness_median": flatness_median,
        "flatness_iqr": flatness_iqr,
        "flux_median": flux_median,
        "voicing_median": voicing_median,
        "voiced_frame_ratio": voiced_ratio,
        "f0_median_hz": f0_median,
        "f0_std_semitones": f0_std,
        "modulation_syllable_ratio": modulation["syllable"],
        "modulation_breath_ratio": modulation["breath"],
        "modulation_breath_valid": modulation["breath_valid"],
        "modulation_peak_hz": modulation["peak_hz"],
        "event_span_s": event_span_s,
    }
    for name, value in zip(BAND_NAMES, band_ratios):
        result[name] = value
    return {name: float(result.get(name, 0.0)) for name in FEATURE_NAMES}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("wav", nargs="+", type=Path)
    parser.add_argument("--json", action="store_true", help="print JSON lines")
    args = parser.parse_args()
    for path in args.wav:
        samples, rate = read_wav(path)
        values = extract(samples, rate)
        if args.json:
            print(json.dumps({"file": str(path), "features": values}, ensure_ascii=False))
        else:
            print(path)
            for name in FEATURE_NAMES:
                print(f"  {name:32s} {values[name]:12.6f}")


if __name__ == "__main__":
    main()
