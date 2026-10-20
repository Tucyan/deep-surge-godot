"""Cut a pure-white studio background out of a supplied square image.

Only background pixels connected to the image border are removed, so bright
cream highlights enclosed by the subject survive. Edge pixels get a
distance-driven alpha ramp plus a de-fringe pass, so downscaling leaves no
white halo on paper-toned card faces.

Usage (from the repository root):
    python tools/cutout_white_background.py <source> <destination> [--size 1024]

The original file is never modified. Output is RGBA PNG.
"""
import argparse
from collections import deque
from pathlib import Path

from PIL import Image

T0 = 8.0     # at or below this white distance a pixel is definitely background
T1 = 22.0    # at or above this it is definitely subject
PAD = 0.055  # square padding around the subject bounding box


def _white_distance(px, x: int, y: int) -> float:
    r, g, b = px[x, y]
    return max(255 - r, 255 - g, 255 - b)


def _background_mask(im: Image.Image):
    """Return (distance grid, mask) where mask marks border-connected white."""
    w, h = im.size
    px = im.load()
    dist = [[0.0] * w for _ in range(h)]
    for y in range(h):
        row = dist[y]
        for x in range(w):
            row[x] = _white_distance(px, x, y)
    seen = bytearray(w * h)
    queue = deque()
    seeds = [(x, 0) for x in range(w)] + [(x, h - 1) for x in range(w)]
    seeds += [(0, y) for y in range(h)] + [(w - 1, y) for y in range(h)]
    for x, y in seeds:
        if dist[y][x] <= T0 and not seen[y * w + x]:
            seen[y * w + x] = 1
            queue.append((x, y))
    while queue:
        x, y = queue.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h and not seen[ny * w + nx] and dist[ny][nx] <= T0:
                seen[ny * w + nx] = 1
                queue.append((nx, ny))
    return dist, seen


def cutout(src: Path, dst: Path, size: int = 1024) -> dict:
    im = Image.open(src).convert('RGB')
    w, h = im.size
    px = im.load()
    dist, background = _background_mask(im)

    alpha = Image.new('L', (w, h), 255)
    ap = alpha.load()
    for y in range(h):
        for x in range(w):
            if background[y * w + x]:
                ap[x, y] = 0
                continue
            d = dist[y][x]
            if d >= T1:
                ap[x, y] = 255
                continue
            ramp = ((d - T0) / (T1 - T0)) ** 0.85 if d > T0 else 0.0
            value = int(round(255.0 * ramp))
            ap[x, y] = value if value >= 26 else 0

    # De-fringe: recover the subject colour from the white-blended edge pixel.
    rgb = Image.new('RGB', (w, h))
    rp = rgb.load()
    for y in range(h):
        for x in range(w):
            r, g, b = px[x, y]
            a = ap[x, y] / 255.0
            if a <= 0.0 or a >= 1.0:
                rp[x, y] = (r, g, b)
            else:
                rp[x, y] = tuple(
                    max(0, min(255, int(round((c - (1.0 - a) * 255.0) / a)))) for c in (r, g, b)
                )

    rgba = Image.merge('RGBA', (*rgb.split(), alpha))
    bbox = rgba.getchannel('A').point(lambda v: 255 if v > 12 else 0).getbbox()
    if bbox is None:
        raise SystemExit(f'{src}: cutout is empty; check the background assumption')
    x0, y0, x1, y1 = bbox
    cx, cy = (x0 + x1) / 2.0, (y0 + y1) / 2.0
    side = max(x1 - x0, y1 - y0) * (1.0 + 2 * PAD)
    half = side / 2.0
    box = (int(round(cx - half)), int(round(cy - half)), int(round(cx + half)), int(round(cy + half)))
    canvas = Image.new('RGBA', (box[2] - box[0], box[3] - box[1]), (0, 0, 0, 0))
    canvas.paste(rgba, (-box[0], -box[1]))
    out = canvas.resize((size, size), Image.LANCZOS)
    dst.parent.mkdir(parents=True, exist_ok=True)
    out.save(dst, optimize=True)

    hist = out.getchannel('A').histogram()
    return {
        'source_dimensions': [w, h],
        'dimensions': [size, size],
        'bbox': list(bbox),
        'opaque_share': round(hist[255] / (size * size), 3),
        'transparent_share': round(hist[0] / (size * size), 3),
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('destination', type=Path)
    parser.add_argument('--size', type=int, default=1024)
    args = parser.parse_args()
    info = cutout(args.source, args.destination, args.size)
    print(f'{args.source} -> {args.destination}: {info}')


if __name__ == '__main__':
    main()
