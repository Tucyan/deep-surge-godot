"""Rebuild the seamless sea ambience loop from the CC0 OpenGameArt sources.

The runtime asset is committed, so this only needs to run when the sources or
the mix change. It needs numpy, soundfile and an ffmpeg binary; none of them
are required to build or run the game.

    python tools/build_waves_ambience.py --fetch --cache <dir>
    python tools/build_waves_ambience.py --cache <dir>

Without --fetch the script expects the eight CC0 FLAC files to be present in
the cache directory already. See asset-sources/ocean-waves-20261020/README.md
for the source list, the licence and the exact processing steps.
"""
import argparse
import hashlib
import os
import shutil
import subprocess
import sys
import urllib.request

import numpy as np
import soundfile as sf

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_FILE = "assets/audio/ambience/waves-loop-v1.ogg"
BASE_URL = "https://opengameart.org/sites/default/files/"

SOURCES = [
    "wave_01_cc0-18363__jasinski__alkaibeach.flac",
    "wave_02_cc0-18363__jasinski__alkaibeach.flac",
    "wave_03_cc0-18363__jasinski__alkaibeach.flac",
    "wave_04_cc0-18363__jasinski__alkaibeach.flac",
    "wave_01_cc0-11505__transitking__wavesound.flac",
    "wave_02_cc0-11505__transitking__wavesound.flac",
    "wave_03_cc0-11505__transitking__wavesound.flac",
    "wave_04_cc0-11505__transitking__wavesound.flac",
]

SR = 44100
LENGTH = 48.0
SEED = 20261020
XFADE = 3.0
WASH_CUTOFF = 700.0
TARGET_PEAK_DB = -3.0


def fetch(cache: str) -> None:
    os.makedirs(cache, exist_ok=True)
    for name in SOURCES:
        target = os.path.join(cache, name)
        if os.path.isfile(target) and os.path.getsize(target) > 200000:
            print(f"cached {name}")
            continue
        print(f"download {name}")
        urllib.request.urlretrieve(BASE_URL + name, target)


def load(path):
    data, sr = sf.read(path, always_2d=True, dtype="float32")
    if data.shape[1] == 1:
        data = np.repeat(data, 2, axis=1)
    if sr != SR:
        count = int(round(data.shape[0] * SR / sr))
        idx = np.linspace(0, data.shape[0] - 1, count)
        data = np.stack(
            [np.interp(idx, np.arange(data.shape[0]), data[:, c]) for c in range(2)], axis=1
        ).astype("float32")
    return data


def trim(data, thresh_db=-55.0, fade=0.06):
    above = np.nonzero(np.abs(data).max(axis=1) > 10 ** (thresh_db / 20.0))[0]
    if above.size == 0:
        return None
    out = data[above[0]:above[-1] + 1].copy()
    length = min(int(fade * SR), out.shape[0] // 2)
    if length > 1:
        ramp = np.linspace(0.0, 1.0, length, dtype="float32")[:, None]
        out[:length] *= ramp
        out[-length:] *= ramp[::-1]
    return out


def lowpass(data, cutoff):
    """Zero-phase FFT low-pass with a 4th-order Butterworth magnitude."""
    count = data.shape[0]
    spec = np.fft.rfft(data, axis=0)
    freqs = np.fft.rfftfreq(count, 1.0 / SR)[:, None]
    gain = 1.0 / np.sqrt(1.0 + (freqs / cutoff) ** 8)
    return np.fft.irfft(spec * gain, n=count, axis=0).astype("float32")


def loop_tile(seed, total, xfade_n):
    """Tile the seed into a strictly seamless loop: the tail folds back onto the head."""
    seed_len = seed.shape[0]
    xfade_n = max(1, min(xfade_n, seed_len // 3))
    step = max(1, seed_len - xfade_n)
    buf_len = total + seed_len
    n_tiles = int(np.ceil(buf_len / step))
    offsets = (np.arange(n_tiles) * step)[:, None]
    grid = offsets + np.arange(seed_len)[None, :]
    valid = grid < buf_len
    mask = np.broadcast_to(valid[:, :, None], (n_tiles, seed_len, 2)).reshape(-1)
    sample_idx = np.where(valid, grid, 0).ravel()
    flat_idx = np.repeat(sample_idx, 2) * 2 + np.tile(np.array([0, 1]), sample_idx.size)
    vals = np.broadcast_to(seed, (n_tiles, seed_len, 2)).reshape(-1)[mask]
    buf = np.bincount(flat_idx[mask], weights=vals, minlength=buf_len * 2).reshape(buf_len, 2).astype("float32")
    fade = np.linspace(0.0, np.pi / 2.0, xfade_n, dtype="float32")[:, None]
    out = buf[:total].copy()
    spill = buf[total:total + xfade_n]
    used = min(xfade_n, spill.shape[0])
    out[:used] = out[:used] * np.sin(fade[:used]) + spill[:used] * np.cos(fade[:used])
    return out


def find_ffmpeg():
    found = os.environ.get("FFMPEG_EXE")
    if found and os.path.isfile(found):
        return found
    found = shutil.which("ffmpeg")
    if found:
        return found
    try:
        import imageio_ffmpeg
        return imageio_ffmpeg.get_ffmpeg_exe()
    except Exception:
        return None


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cache", default=os.path.join(ROOT, ".cache", "ocean-waves"))
    parser.add_argument("--fetch", action="store_true")
    args = parser.parse_args()
    cache = os.path.abspath(args.cache)
    if args.fetch:
        fetch(cache)

    rng = np.random.default_rng(SEED)
    total = int(LENGTH * SR)
    xfade_n = int(XFADE * SR)

    clips = []
    for name in SOURCES:
        path = os.path.join(cache, name)
        if not os.path.isfile(path):
            print(f"missing source: {name} (run with --fetch)")
            return 1
        trimmed = trim(load(path))
        if trimmed is None:
            print(f"skip {name}: silent")
            continue
        clips.append((name, trimmed))
        print(f"loaded {name:46s} {trimmed.shape[0] / SR:6.2f}s")
    if not clips:
        return 1

    wash = np.zeros((total, 2), dtype="float32")
    for _, clip in clips:
        rolled = np.roll(lowpass(clip, WASH_CUTOFF), int(rng.integers(0, clip.shape[0])), axis=0)
        wash += loop_tile(rolled, total, xfade_n) * float(rng.uniform(0.55, 1.0))
    wash *= 0.5 / (float(np.abs(wash).max()) + 1e-9)

    bed = wash.copy()
    events = 0
    moment = float(rng.uniform(0.4, 2.0))
    while moment < LENGTH:
        _, clip = clips[int(rng.integers(0, len(clips)))]
        gain = float(10 ** (rng.uniform(-17.0, -6.0) / 20.0))
        pan = float(rng.uniform(-0.6, 0.6))
        panned = clip * np.array(
            [[np.sqrt((1 - pan) / 2) * np.sqrt(2), np.sqrt((1 + pan) / 2) * np.sqrt(2)]], dtype="float32"
        )
        start = int(moment * SR)
        end = start + panned.shape[0]
        if end <= total:
            bed[start:end] += panned * gain
        else:
            head = total - start
            bed[start:] += panned[:head] * gain
            bed[:panned.shape[0] - head] += panned[head:] * gain
        events += 1
        moment += float(rng.uniform(2.4, 6.0))

    bed *= 10 ** (TARGET_PEAK_DB / 20.0) / (float(np.abs(bed).max()) + 1e-9)

    out_path = os.path.join(ROOT, OUT_FILE)
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    wav_path = out_path + ".wav"
    sf.write(wav_path, bed, SR, subtype="PCM_16")

    ffmpeg = find_ffmpeg()
    if not ffmpeg:
        print("ffmpeg not found; kept the WAV next to the OGG target")
        print(f"wav={wav_path}")
        return 2
    result = subprocess.run(
        [ffmpeg, "-y", "-loglevel", "error", "-i", wav_path, "-c:a", "libvorbis", "-qscale:a", "4", out_path],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        print("ffmpeg failed:", result.stderr.strip()[:300])
        return 3
    os.remove(wav_path)

    digest = hashlib.sha256(open(out_path, "rb").read()).hexdigest()
    rms_db = 20 * np.log10(np.sqrt((bed ** 2).mean()) + 1e-9)
    print(f"events={events} len={LENGTH:.1f}s peak={TARGET_PEAK_DB:.1f}dB rms={rms_db:+.1f}dB")
    print(f"wrote {OUT_FILE} ({os.path.getsize(out_path)} bytes) sha256={digest}")
    print("now run: python tools/register_ambience.py")
    return 0


if __name__ == "__main__":
    sys.exit(main())
