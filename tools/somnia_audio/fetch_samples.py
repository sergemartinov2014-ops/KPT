"""Download small external sample packs into a gitignored directory.

Only ESC-50 categories are fetched automatically.  The audio stays in
``tools/somnia_audio/data/external/`` and must never be committed.

    python -m tools.somnia_audio.fetch_samples
    python -m tools.somnia_audio.fetch_samples --target snoring --target breathing

ESC-50 is licensed CC BY-NC 3.0: evaluation and research only, no commercial
use.  The script writes the attribution next to the clips.
"""

from __future__ import annotations

import argparse
import csv
import io
import time
import urllib.error
import urllib.request
from pathlib import Path

ESC50_META_URL = "https://raw.githubusercontent.com/karolpiczak/ESC-50/master/meta/esc50.csv"
ESC50_AUDIO_URL = "https://raw.githubusercontent.com/karolpiczak/ESC-50/master/audio/"
DEFAULT_OUT = Path("tools/somnia_audio/data/external/esc50")
USER_AGENT = "somnia-research/1.0 (dataset sanity check)"

# ESC-50 category -> local label directory.
TARGETS = {
    "snoring": "snore",
    "breathing": "breathing",
}

ATTRIBUTION = """\
ESC-50 clips fetched from https://github.com/karolpiczak/ESC-50
Piczak, K. J. (2015). ESC: Dataset for Environmental Sound Classification.
Proceedings of the 23rd ACM International Conference on Multimedia, 1015-1018.
DOI: 10.1145/2733373.2806390

License: Creative Commons Attribution-NonCommercial 3.0 (CC BY-NC 3.0).
Research and evaluation only. Do not use these clips in a commercial product
or in a model that is shipped commercially without a separate license.

These are 5-second web clips, not labelled sleep recordings. Do not treat
results on them as real-world accuracy.
"""


def _download(url: str, destination: Path, retries: int = 3) -> bytes:
    if destination.exists() and destination.stat().st_size > 0:
        return destination.read_bytes()
    last_error: Exception | None = None
    for attempt in range(retries):
        try:
            request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
            with urllib.request.urlopen(request, timeout=60) as response:
                data = response.read()
            if not data:
                raise ValueError("empty response")
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(data)
            return data
        except (urllib.error.URLError, TimeoutError, ValueError) as error:
            last_error = error
            time.sleep(1.0 + attempt)
    raise SystemExit(f"failed to download {url}: {last_error}")


def _looks_like_wav(data: bytes) -> bool:
    return len(data) > 44 and data[:4] == b"RIFF" and data[8:12] == b"WAVE"


def fetch_esc50(out: Path, targets: list[str]) -> None:
    unknown = [name for name in targets if name not in TARGETS]
    if unknown:
        raise SystemExit(f"unknown ESC-50 targets {unknown}; choose from {sorted(TARGETS)}")
    meta_data = _download(ESC50_META_URL, out / "meta" / "esc50.csv")
    reader = csv.DictReader(io.StringIO(meta_data.decode("utf-8")))
    rows = [row for row in reader if row["category"] in targets]
    if not rows:
        raise SystemExit(f"no ESC-50 rows for {targets}")

    for row in rows:
        category = row["category"]
        destination = out / TARGETS[category] / row["filename"]
        data = _download(ESC50_AUDIO_URL + row["filename"], destination)
        if not _looks_like_wav(data):
            destination.unlink(missing_ok=True)
            raise SystemExit(f"not a WAV file: {row['filename']}")
        print(f"{category:>10s} -> {destination} ({len(data) / 1024:.0f} KiB)")
        time.sleep(0.2)

    (out / "LICENSE.txt").write_text(ATTRIBUTION, encoding="utf-8")
    print(f"\nfetched {len(rows)} clips into {out}")
    print("license: CC BY-NC 3.0 (research/evaluation only, no commercial use)")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    parser.add_argument(
        "--target",
        action="append",
        choices=sorted(TARGETS),
        help="ESC-50 category to fetch; repeatable (default: snoring)",
    )
    args = parser.parse_args()
    fetch_esc50(args.out, args.target or ["snoring"])


if __name__ == "__main__":
    main()
