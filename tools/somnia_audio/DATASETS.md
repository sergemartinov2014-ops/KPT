# Audio datasets and sample packs

Checked on 2026-11-10. Licences and access rules can change; verify the
current terms on the source page before you download or train on anything.

## Rules for this repository

- External audio is stored under `tools/somnia_audio/data/external/` and is
  gitignored. Never commit downloaded clips, model checkpoints trained on
  them, or derived audio.
- The Phase 1 model is trained only on `synth.py` output. No external clip is
  used for training.
- `CC0` is the safest choice for a commercial product. `CC BY` needs
  attribution. `CC BY-NC` and `CC BY-NC-SA` are research/evaluation only.
  `CC Sampling+` has its own sampling conditions.
- Freesound licences are per sound, not per search result. Check the licence
  on the sound page, not the pack page.
- AudioSet annotations are CC BY 4.0, but the audio comes from YouTube. The
  YouTube terms still apply, and the clips are not distributed as a clean
  audio pack.
- Record the source URL, author, licence, and download date for every clip you
  keep.

## Used in this branch

### Synthetic clips

`tools/somnia_audio/synth.py` generates all training, validation, test, demo,
and fixture audio with NumPy. No external recording is involved. The synthetic
signals are an idealisation of snoring, speech, movement, and room tone. They
are not a substitute for real night recordings.

### ESC-50 (evaluation only)

- Source: <https://github.com/karolpiczak/ESC-50>
- Paper: Piczak, K. J. (2015), DOI
  <https://doi.org/10.1145/2733373.2806390>
- Licence: CC BY-NC 3.0. The smaller ESC-10 subset is CC BY.
- Contents used here: 40 clips from `snoring`, 40 from `breathing`.
- Size: 5 s, 44.1 kHz, mono, 2000 clips in the full dataset.
- Access: direct download from GitHub.
- Restriction: non-commercial research and evaluation only. Do not use these
  clips to train a model that ships in a commercial product without a separate
  licence.

Download the two categories used by the sanity check:

```bash
python -m tools.somnia_audio.fetch_samples \
    --target snoring --target breathing
```

The script writes the clips and the attribution file under
`tools/somnia_audio/data/external/esc50/`.

### FSD50K (metadata only here)

- Source: <https://zenodo.org/records/4060432>
- Paper: Fonseca et al. (2022), DOI
  <https://doi.org/10.5281/zenodo.4060432>
- Licence of the dataset as a whole: CC BY 4.0. Each clip keeps its own
  Freesound licence: CC0, CC BY, CC BY-NC, or CC Sampling+.
- Contents: 51,197 clips, 200 classes, 108.3 h.
- Relevant vocabulary: no `Snoring` and no `Rustle` class. `Speech` and
  `Respiratory sounds` exist, but they are broad.
- Restriction: check each clip licence. Commercial use requires contacting the
  dataset authors.

Only `FSD50K.ground_truth.zip` was downloaded in this branch to inspect the
vocabulary. The audio is multi-GB and was not fetched.

## Real night recordings for a future phase

These are candidate sources for calibration and a real-world benchmark. None
of them were used for the reported Phase 1 metrics.

| Dataset | Contents | Access | Licence | Notes |
| --- | --- | --- | --- | --- |
| ICSD | Real strongly labelled, weakly labelled, and synthetic snoring; also infant cry. 26.7 GB. | Hugging Face gate and manual approval. | CC BY-NC-SA 4.0 plus additional terms: non-commercial research/education only, no redistribution. | Best match for real snoring research. The dataset does not own the audio copyright. Do not use for a commercial shipped model. |
| PSG-Audio | 212 full-night polysomnograms with synchronized tracheal and ambient microphone audio. EDF, 1 h chunks. | Science Data Bank, open download. | Reported as CC BY 4.0; verify the current ScienceDB record. | Real sleep audio, but labels are apnea/hypopnea events, not snore events. Useful for ambient/background and for future snore annotation. |
| SimuSOE | 4,428 simulated snores from 82 adults, 0.55-9.84 s each, awake, supine and lateral. | Request from the authors. | Not stated in the paper. | Simulated, close-microphone recordings. Useful for snore timbre, not for night-time false-positive rates. |
| Munich-Passau Snore Sound Corpus (MPSSC) | Real snore recordings with video and audio, labelled by excitation location. | Research access; check the current distribution page. | Verify with the authors. | Real snore, but the task is snore type classification, not night event detection. |

Links:

- ICSD: <https://huggingface.co/datasets/QingyuLiu1/ICSD>
- ICSD code: <https://github.com/QingyuLiu0521/ICSD>
- PSG-Audio paper: <https://www.nature.com/articles/s41597-021-00977-w>
- PSG-Audio data: <https://doi.org/10.11922/sciencedb.00345>
- SimuSOE paper: <https://arxiv.org/abs/2407.07397>
- MPSSC paper: <https://doi.org/10.1016/j.compbiomed.2018.01.007>

## Speech and background corpora

| Corpus | Contents | Licence | Use |
| --- | --- | --- | --- |
| Mozilla Common Voice | Crowd-sourced speech, many languages, clip-level audio and sentences. | CC0 for the audio and sentences, plus dataset terms. | `talk` and `unknown` negatives. Check the current dataset terms and speaker consent. |
| LibriSpeech | About 1000 h of read English speech. | CC BY 4.0. | `talk` negatives. Read speech is cleaner than sleep talk. |
| MUSAN | Speech, music, and noise, about 109 h. | CC BY 4.0. | Ambient and unknown negatives. |
| Freesound CC0 speech | Per-sound CC0 speech and room tone. | CC0 per sound. | Small ad-hoc negatives, after checking each sound page. |

Links:

- Common Voice: <https://commonvoice.mozilla.org/datasets>
- LibriSpeech: <https://www.openslr.org/12/>
- MUSAN: <https://www.openslr.org/17/>

## Freesound sample packs

These are small, directly useful clips for listening and for a quick sanity
check. They are not a training set and they are not a benchmark.

### Snoring

| Sound | Author | Length | Format | Licence | Link |
| --- | --- | --- | --- | --- | --- |
| `snoring` | Daxter31 | 46.8 s | WAV, 96 kHz, 24-bit, stereo | CC0 | <https://freesound.org/s/114609/> |
| `Male Snore 2.wav` | mattyharm | 27.4 s | WAV, 48 kHz, 24-bit, stereo | CC0 | <https://freesound.org/s/432996/> |
| `Snoring Heavy guttural, rasping, and rhythmic sound` | fudgealtoid | 4:44 | M4A, 44.1 kHz | CC BY 4.0 | <https://freesound.org/s/769054/> |
| `snore_okm2_t3.flac` | ermine | 1:37.9 | FLAC, 44.1 kHz, 16-bit, stereo | CC BY-NC 3.0 | <https://freesound.org/s/27405/> |

The ermine recording contains long silence gaps. It is useful for timing and
for false-trigger checks, but the licence forbids commercial use.

### Rustling

| Sound | Author | Length | Format | Licence | Link |
| --- | --- | --- | --- | --- | --- |
| `Leaves Rustling` | ericnorcross81 | 1:02.5 | AIFF, 48 kHz, 16-bit, stereo | CC0 | <https://freesound.org/s/570759/> |
| `Leaves Rustling Slow Rustling.wav` | miaopolus | 9.6 s | WAV, 48 kHz, 24-bit, stereo | CC BY-NC 4.0 | <https://freesound.org/s/656296/> |

Freesound search filters change. As of 2026-11-10 a CC0-filtered search
returned about 284 results for `snore` and about 336 for `rustling`. Treat the
counts as a starting point and verify the licence on each sound page.

Search pages:

- <https://freesound.org/search/?q=snore>
- <https://freesound.org/search/?q=rustling>
- <https://freesound.org/search/?q=speech>

## Excluded sources

- BBC sound effects: the BBC terms require permission for computer analysis
  and AI training. Excluded.
- Kaggle `tareqkhanemu/snoring`: the licence is listed as `Unknown`. Do not
  train on it and do not redistribute it.
- Kaggle `tariqkhan1940/snoring-10s` and `tariqkhan1940/new-snoring-dataset`:
  the pages claim Apache 2.0, but the provenance of the audio is unclear.
  Do not use them without written confirmation from the uploader.
- ESC-50 and any CC BY-NC clip: research and evaluation only.

## Attribution template

Keep this next to each downloaded clip:

```text
Title:
Author:
Source URL:
Licence:
Downloaded:
Changes made:
```
