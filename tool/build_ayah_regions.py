"""Builds assets/ayah_regions.json: where each ayah sits on each mushaf page.

Run from the repository root:
    pip install numpy pillow opencv-python-headless
    python tool/build_ayah_regions.py

The round ayah-end markers are found in the bundled page images by template
matching and numbered in reading order through the whole Quran, using the
ayah order in assets/quran_text.txt. The numbering is checked against the
surah header frames: every header must be followed by ayah 1 of a surah and
no unmarked text may precede it, and all 6236 ayahs must be used. The
script fails instead of writing anything if a check does not hold.

Output: {"lines": [...], "halfHeight": h, "pages": [[[surah, ayah,
[line, left, right, ...]], ...], ...]} with each page's line centres as a
fraction of the page height (pages 1 and 2 carry their own "lines"), and
left/right in thousandths of the page width.
"""
import json
import sys

import cv2
import numpy as np
from PIL import Image

W, H = 512, 828
# Line centres (px at 512x828) of the fifteen-line pages, from clustering
# the markers of pages 3 to 604.
CENTERS = [36.6, 90.1, 143.5, 196.6, 249.6, 302.7, 355.9, 408.8, 461.8,
           514.7, 567.9, 620.9, 674.2, 727.0, 780.0]
# The two opening pages are laid out differently.
SPECIAL = {
    1: [47, 116, 178.5, 242, 302.5, 361, 429, 486.5],
    2: [47, 115.5, 173, 234, 294, 352, 411, 472],
}
HALF = 26.5


def load(page):
    img = Image.open(f'assets/quran-images/page{page:03d}.png').convert('RGBA')
    if img.size[0] != W:
        img = img.resize((W, round(img.size[1] * W / img.size[0])), Image.LANCZOS)
    return (np.array(img)[:, :, 3] > 100).astype(np.float32)


def marker_template():
    """The average of the clean, isolated markers on page 3."""
    ink = load(3)
    n, _, stats, _ = cv2.connectedComponentsWithStats(ink.astype(np.uint8), 8)
    crops = []
    for i in range(1, n):
        x, y, w, h, area = stats[i]
        if 22 <= w <= 30 and 22 <= h <= 30 and area / (w * h) > 0.6:
            cx, cy = x + w // 2, y + h // 2
            crops.append(ink[cy - 15:cy + 15, cx - 15:cx + 15])
    return np.mean(crops, axis=0).astype(np.float32)


def find_markers(ink, template, threshold):
    half = template.shape[0] // 2
    score = cv2.matchTemplate(ink, template, cv2.TM_CCOEFF_NORMED)
    ys, xs = np.where(score >= threshold)
    found = []
    for k in np.argsort(-score[ys, xs]):
        y, x = ys[k], xs[k]
        if all(abs(y - fy) > half or abs(x - fx) > half for fy, fx in found):
            found.append((y, x))
    return [(x + half, y + half, half) for y, x in found]


def main():
    order = []
    for line in open('assets/quran_text.txt', encoding='utf-8'):
        s, a, _ = line.split('|', 2)
        order.append((int(s), int(a)))
    assert len(order) == 6236

    template = marker_template()
    big = cv2.resize(template, None, fx=1.4, fy=1.4)
    pages, errors, ptr = {}, [], 0

    for p in range(1, 605):
        centers = SPECIAL.get(p, CENTERS)
        ink = load(p)
        ink8 = ink.astype(np.uint8)
        markers = (find_markers(ink, big, 0.9) if p in SPECIAL
                   else find_markers(ink, template, 0.55))

        def line_of(y):
            return min(range(len(centers)), key=lambda i: abs(centers[i] - y))

        def band(i):
            return max(0, centers[i] - HALF), min(H, centers[i] + HALF)

        def extent(i):
            y0, y1 = band(i)
            cols = np.where(ink8[int(y0):int(y1)].any(axis=0))[0]
            return (int(cols.min()), int(cols.max())) if len(cols) else None

        def has_ink(i, x0, x1):
            y0, y1 = band(i)
            return ink8[int(y0) + 8:int(y1) - 8, max(0, x0):x1].sum() > 30

        n, _, stats, _ = cv2.connectedComponentsWithStats(ink8, 8)
        headers = sorted(line_of(stats[i][1] + stats[i][3] / 2)
                         for i in range(1, n) if stats[i][2] > 400)
        skip = set()
        events = [(l, 10 ** 6, None) for l in headers]
        events += [(line_of(y), x, r) for x, y, r in markers]
        events.sort(key=lambda e: (e[0], -e[1]))

        items = {}
        cur_line, cur_x = 0, None

        def region(key, to_line, to_x):
            for l in range(cur_line, to_line + 1):
                e = extent(l)
                if l in skip or e is None:
                    continue
                right = e[1] if (l != cur_line or cur_x is None) else cur_x
                left = to_x if l == to_line else e[0]
                if right > left:
                    items.setdefault(key, []).extend(
                        [l, round(left / W * 1000),
                         round(min(W, right + 2) / W * 1000)])

        for line, x, radius in events:
            if radius is None:  # a surah header
                for l in range(cur_line, line):
                    e = extent(l)
                    if l in skip or e is None:
                        continue
                    right = e[1] if (l != cur_line or cur_x is None) else cur_x
                    if right - e[0] > 12 and has_ink(l, e[0], right):
                        errors.append((p, 'text before header', l))
                s, a = order[ptr]
                if a != 1:
                    errors.append((p, 'header followed by', (s, a)))
                skip.add(line)
                basmala = s not in (1, 9)
                if basmala:
                    skip.add(line + 1)
                cur_line, cur_x = line + (2 if basmala else 1), None
            else:
                key = order[ptr]
                region(key, line, x - radius)
                ptr += 1
                cur_line, cur_x = line, x - radius
        # Pages of this mushaf end on a complete ayah.
        last = max((l for l in range(len(centers))
                    if extent(l) and l not in skip), default=-1)
        if last > cur_line or (last == cur_line and cur_x is not None
                               and cur_x - extent(last)[0] > 12):
            errors.append((p, 'text after the last marker'))
        pages[p] = [[s, a, spans] for (s, a), spans in items.items()]

    print(f'assigned {ptr} of {len(order)} ayahs, {len(errors)} errors')
    for e in errors[:30]:
        print(e)
    if errors or ptr != len(order):
        sys.exit(1)
    out = {
        'lines': [round(c / H, 4) for c in CENTERS],
        'special': {str(p): [round(c / H, 4) for c in c_] for p, c_ in SPECIAL.items()},
        'halfHeight': round(HALF / H, 4),
        'pages': [pages[p] for p in range(1, 605)],
    }
    with open('assets/ayah_regions.json', 'w') as f:
        json.dump(out, f, separators=(',', ':'))


if __name__ == '__main__':
    main()
