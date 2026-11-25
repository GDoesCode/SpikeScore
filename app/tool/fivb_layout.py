#!/usr/bin/env python3
"""Measures the official FIVB scoresheet and writes the files the app needs.

Usage (from app/):
    python3 tool/fivb_layout.py path/to/FIVB_VB_OfficialScoresheet_2013.pdf

Needs poppler (pdftotext, pdftoppm), numpy and Pillow. Writes:
    assets/scoresheet/fivb_5set_blank.jpg   page 1 at 300 dpi
    assets/scoresheet/fivb_5set_layout.json box positions, in PDF points
                                            from the top-left of the page

Positions come from two places: the printed text (point numbers, colons,
S/R letters), read with pdftotext -bbox, and the ruled lines, found by
looking for long runs of dark pixels in the 300 dpi render.
"""
import json
import os
import re
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image

PDF = sys.argv[1]
OUT = 'assets/scoresheet'
DPI = 300
S = DPI / 72.0

tmp = tempfile.mkdtemp()
subprocess.run(['pdftoppm', '-gray', '-r', str(DPI), '-f', '1', '-l', '1',
                PDF, f'{tmp}/p'], check=True)
page_img = Image.open(f'{tmp}/p-1.pgm')
dark = np.array(page_img) < 140
subprocess.run(['pdftotext', '-f', '1', '-l', '1', '-bbox', PDF,
                f'{tmp}/b.html'], check=True)
WORDS = [
    (float(a), float(b), float(c), float(d), t)
    for a, b, c, d, t in re.findall(
        r'<word xMin="([\d.]+)" yMin="([\d.]+)" xMax="([\d.]+)" '
        r'yMax="([\d.]+)">([^<]*)</word>',
        open(f'{tmp}/b.html').read())
]


def r2(v):
    return round(float(v), 2)


def _runs(idx):
    out = []
    for i in idx:
        if out and i - out[-1][-1] <= 1:
            out[-1].append(i)
        else:
            out.append([i])
    return [((r[0] + r[-1]) / 2) / S for r in out]


def hlines(x0, x1, y0, y1, frac=0.85):
    """y of every horizontal line crossing the whole of [x0, x1]."""
    a = dark[int(y0 * S):int(y1 * S), int(x0 * S):int(x1 * S)]
    return [r2(v + int(y0 * S) / S)
            for v in _runs(np.where(a.mean(axis=1) > frac)[0])]


def vlines(x0, x1, y0, y1, frac=0.85):
    """x of every vertical line crossing the whole of [y0, y1]."""
    a = dark[int(y0 * S):int(y1 * S), int(x0 * S):int(x1 * S)]
    return [r2(v + int(x0 * S) / S)
            for v in _runs(np.where(a.mean(axis=0) > frac)[0])]


def words(x0, x1, y0, y1, text=None):
    """Words whose centre lies in the box."""
    out = []
    for w in WORDS:
        cx, cy = (w[0] + w[2]) / 2, (w[1] + w[3]) / 2
        if x0 <= cx <= x1 and y0 <= cy <= y1 and (text is None or w[4] == text):
            out.append(w)
    return out


def centre(w):
    return [r2((w[0] + w[2]) / 2), r2((w[1] + w[3]) / 2)]


def glyph_box(w):
    """pdftotext boxes run from ascent to descent; the digits sit lower."""
    return [r2(w[0]), r2(w[3] - 5.3), r2(w[2]), r2(w[3] - 1.3)]


def nearest(values, target, tol=3.0):
    best = min(values, key=lambda v: abs(v - target))
    assert abs(best - target) <= tol, (values, target)
    return best


def circle(cx, cy, r):
    return {'cx': r2(cx), 'cy': r2(cy), 'r': r2(r)}


# ---------------------------------------------------------------- set blocks
def block(name, set_no, side, x0, cols_right, pts_right, top, *, deciding,
          printed, letter, sr, name_box, change=None):
    """One team section. x0: left edge of column I; cols_right: right edge of
    column VI; pts_right: right edge of the POINTS column; top: the line under
    the header row (top of the I..VI row)."""
    bottom_guess = top + (145 if deciding else 160)
    rows = hlines(x0 + 3, cols_right - 3, top - 2, bottom_guess)
    # rows: top, under I..VI, starters, subNum, score1, score2, rounds...
    assert abs(rows[0] - top) < 1.5, rows
    rounds_n = 3 if deciding else 4
    rows = rows[:6 + rounds_n]
    col_x = vlines(x0 - 2, cols_right + 2, rows[2] + 2, rows[3] - 2)
    col_x = [nearest(col_x, x0)] + [
        v for v in col_x if x0 + 5 < v < cols_right - 5] + [
        nearest(col_x, cols_right)]
    assert len(col_x) == 7, col_x
    cols = [[col_x[k], col_x[k + 1]] for k in range(6)]

    # Service-round boxes: each column split in two, rounds 1-4 (1-3 in the
    # deciding set) down the left half, 5-8 (4-6) down the right half.
    rounds = []
    for c in cols:
        mid = nearest(vlines(c[0] + 3, c[1] - 3, rows[5] + 2, rows[6] - 2, 0.8),
                      (c[0] + c[1]) / 2)
        left, right = [], []
        for i in range(rounds_n):
            y0, y1 = rows[5 + i], rows[6 + i]
            left.append([c[0], y0, mid, y1])
            right.append([mid, y0, c[1], y1])
        rounds.append(left + right)

    # Substitution score colons.
    colons = [[], []]
    for k, c in enumerate(cols):
        for i, (y0, y1) in enumerate([(rows[3], rows[4]), (rows[4], rows[5])]):
            ws = words(c[0], c[1], y0, y1, ':')
            assert len(ws) == 1, (name, k, i, ws)
            colons[i].append(centre(ws[0]))

    # POINTS: the printed numbers.
    grid = {}
    # The POINTS column runs to the "T" box: one row lower on sets 1 to 4.
    grid_bottom = rows[5] if deciding else rows[6]
    for w in words(cols_right, pts_right, top, grid_bottom):
        if w[4].isdigit():
            n = int(w[4])
            assert n not in grid, (name, n)
            grid[n] = glyph_box(w)
    expected = 8 if side == 'L' and deciding else (30 if deciding else 48)
    assert sorted(grid) == list(range(1, expected + 1)), (name, sorted(grid))

    # Time-outs: the two colons under "T" below the POINTS column.
    t_row = rows.index(grid_bottom) + 1
    tos = sorted(words(cols_right, pts_right, rows[t_row], rows[-1], ':'),
                 key=lambda w: w[1])
    assert len(tos) == 2, (name, tos)
    timeouts = []
    for w in tos:
        cx, cy = centre(w)
        timeouts.append({'colonX': cx, 'cy': cy, 'x0': r2(cols_right),
                         'x1': r2(pts_right), 'y0': r2(cy - 6), 'y1': r2(cy + 6)})

    out = {
        'set': set_no,
        'side': side,
        'printedLetter': printed,
        'cols': cols,
        # rows[0] is the line under the header row; I..VI sit between
        # rows[0] and rows[1], the starting players below them, and so on.
        'rows': {
            'starters': [rows[1], rows[2]],
            'subNum': [rows[2], rows[3]],
            'score1': [rows[3], rows[4]],
            'score2': [rows[4], rows[5]],
        },
        'roundRows': rounds_n,
        'rounds': rounds,
        'scoreColons': colons,
        'grid': {str(n): grid[n] for n in sorted(grid)},
        'timeouts': timeouts,
        'nameBox': name_box,
        'letterCircle': letter,
        'sr': sr,
    }
    if change:
        out['changeBox'] = change
    return out, rows


def sr_pair(x0, x1, y0, y1):
    s = words(x0, x1, y0, y1, 'S')
    r = words(x0, x1, y0, y1, 'R')
    s = [w for w in s if w[2] - w[0] < 7]
    r = [w for w in r if w[2] - w[0] < 7]
    assert len(s) == 1 and len(r) == 1, (x0, y0, s, r)
    (sx, sy), (rx, ry) = centre(s[0]), centre(r[0])
    return {'S': circle(sx, sy + 0.4, 4.6), 'R': circle(rx, ry + 0.4, 4.6)}


blocks = {}
set_times = {}

# Sets 1 to 4: four identical panels. Left block columns start at the first
# line right of the "SET n" strip.
base_x = 186.36  # column I of set 1, left block
for n in (1, 2, 3, 4):
    dx = 0.0 if n % 2 else nearest(vlines(650, 700, 165, 172), 686.3) - base_x
    hdr_lines = hlines(200, 240, 100 if n < 3 else 262, 145 if n < 3 else 305, 0.6)
    top = [v for v in hdr_lines if v > (135 if n < 3 else 297)][0]
    dy = top - 137.4
    lx = base_x + dx
    v = vlines(lx - 2, lx + 480, top + 22, top + 34)
    lcols_r = nearest(v, lx + 188.3)
    lpts_r = nearest(v, lx + 234.4)
    rcols_r = nearest(v, lx + 422.4)
    rpts_r = nearest(v, lx + 469.0)
    hy0, hy1 = top - 21.4, top
    left_letter = 'A' if n % 2 else 'B'
    right_letter = 'B' if n % 2 else 'A'

    def letter_at(x0, x1, ch):
        ws = [w for w in words(x0, x1, hy0, hy1, ch) if w[2] - w[0] > 9]
        assert len(ws) == 1, (n, ch, ws)
        cx, cy = centre(ws[0])
        return circle(cx, cy, 10.5)

    b, rows = block(f'S{n}L', n, 'L', lx, lcols_r, lpts_r, top, deciding=False,
                    printed=left_letter,
                    letter=letter_at(lx + 150, lx + 175, left_letter),
                    sr=sr_pair(lx + 175, lx + 186, hy0, hy1),
                    name_box=[r2(lx + 98.64), r2(hy0 + 2.4), r2(lx + 146.76), r2(hy1 - 2.9)])
    blocks[f'S{n}L'] = b
    b, rows = block(f'S{n}R', n, 'R', lpts_r, rcols_r, rpts_r, top, deciding=False,
                    printed=right_letter,
                    letter=letter_at(lpts_r + 12, lpts_r + 36, right_letter),
                    sr=sr_pair(lpts_r + 1, lpts_r + 12, hy0, hy1),
                    name_box=[r2(lpts_r + 41.4), r2(hy0 + 2.4), r2(lpts_r + 89.5), r2(hy1 - 2.9)])
    blocks[f'S{n}R'] = b

    start = words(lx + 30, lx + 62, hy0, hy1, ':')
    end = words(rcols_r - 40, rcols_r - 10, hy0, hy1, ':')
    assert len(start) == 1 and len(end) == 1, (n, start, end)
    set_times[str(n)] = {'startColonX': centre(start[0])[0],
                         'endColonX': centre(end[0])[0],
                         'baselineY': r2(start[0][3] - 1.0)}

# Set 5: left team, right team, then the left team again after the change.
top5 = [v for v in hlines(205, 240, 430, 470, 0.6) if v > 455][0]
hy0, hy1 = top5 - 21.4, top5
v5 = vlines(190, 935, top5 + 22, top5 + 34)
L0 = nearest(v5, 199.56)
L1 = nearest(v5, 387.72)
L2 = nearest(v5, 420.36)
M1 = nearest(v5, 608.76)
M2 = nearest(v5, 655.32)
C0 = nearest(v5, 685.92)
C1 = nearest(v5, 874.2)
C2 = nearest(v5, 919.68)

b, rows = block('S5L', 5, 'L', L0, L1, L2, top5, deciding=True, printed=None,
                letter=circle(363.48, (hy0 + hy1) / 2, 10.0),
                sr=sr_pair(L1 - 12, L1, hy0, hy1),
                name_box=[r2(297.6), r2(hy0 + 3.0), r2(345.6), r2(hy1 - 2.3)])
blocks['S5L'] = b
b, rows = block('S5R', 5, 'R', L2, M1, M2, top5, deciding=True, printed=None,
                letter=circle(444.42, (hy0 + hy1) / 2, 10.0),
                sr=sr_pair(L2 + 1, L2 + 12, hy0, hy1),
                name_box=[r2(462.12), r2(hy0 + 3.0), r2(510.24), r2(hy1 - 2.3)])
blocks['S5R'] = b
b, rows = block('S5C', 5, 'C', C0, C1, C2, top5, deciding=True, printed=None,
                letter=circle(736.32, (hy0 + hy1) / 2, 10.0), sr=None,
                name_box=None,
                change={'colonX': r2((833.04 + 865.08) / 2),
                        'cy': r2((hy0 + hy1) / 2)})
blocks['S5C'] = b
start = words(L0 + 30, L0 + 62, hy0, hy1, ':')
end = words(M1 - 40, M1 - 10, hy0, hy1, ':')
set_times['5'] = {'startColonX': centre(start[0])[0],
                  'endColonX': centre(end[0])[0],
                  'baselineY': r2(start[0][3] - 1.0)}

# ------------------------------------------------------------------- teams
tr = hlines(945, 1020, 440, 830, 0.8)
# 0 top, 1 header, 2 column heads, 3..16 players (14), 16 LIBERO label ...
player_rows = [[tr[i], tr[i + 1]] for i in range(2, 16)]
libero_rows = [[tr[17], tr[18]], [tr[18], tr[19]]]
official_rows = [[tr[i], tr[i + 1]] for i in range(20, 25)]
sig_label, captain_row, coach_row = tr[25], [tr[26], tr[27]], [tr[27], tr[28]]
players = {
    'rows': player_rows,
    'liberoRows': libero_rows,
    'left': {'numX': [927.0, 940.32], 'nameX': [940.32, 1040.64]},
    'right': {'numX': [1040.64, 1054.92], 'nameX': [1054.92, 1155.0]},
    'leftCircle': circle(943.26, (tr[0] + tr[1]) / 2, 10.4),
    'rightCircle': circle(1138.2, (tr[0] + tr[1]) / 2, 10.4),
    'leftNameBox': [965.88, r2(tr[0] + 2.0), 1014.0, r2(tr[1] - 3.2)],
    'rightNameBox': [1062.24, r2(tr[0] + 2.0), 1110.36, r2(tr[1] - 3.2)],
}
officials = {
    'rows': official_rows,
    'left': {'roleX': [1029.24, 1052.52], 'nameX': [927.0, 1029.24]},
    'right': {'roleX': [1029.24, 1052.52], 'nameX': [1052.52, 1155.0]},
    # The roles are printed in the middle column, one row each.
    'roleRows': {'C': 0, 'AC1': 1, 'AC2': 2, 'T': 3, 'M': 4},
}

# ---------------------------------------------------------------- signatures
signatures = {
    'captainLeft': [929.0, r2(captain_row[0] + 10.5), 1039.0, r2(captain_row[1] - 1.0)],
    'captainRight': [1042.5, r2(captain_row[0] + 10.5), 1154.0, r2(captain_row[1] - 1.0)],
    'coachLeft': [929.0, r2(coach_row[0] + 10.5), 1039.0, r2(coach_row[1] - 1.0)],
    'coachRight': [1042.5, r2(coach_row[0] + 10.5), 1154.0, r2(coach_row[1] - 1.0)],
}
ar = hlines(480, 520, 670, 830, 0.8)  # approval rows
# ar: 0 top line (double), .., header row, then 1st, 2nd, scorer, assistant,
# line judges 1/2, 3/4, team captains.
ar = [v for v in ar if v > 690]
ref_rows = [[ar[i], ar[i + 1]] for i in range(0, 4)]
for key, (y0, y1) in zip(['ref1', 'ref2', 'scorer', 'assistantScorer'], ref_rows):
    signatures[key] = [531.0, r2(y0 + 1.0), 689.0, r2(y1 - 1.0)]
lj1, lj2, cap = [ar[4], ar[5]], [ar[5], ar[6]], [ar[6], ar[7]]
signatures['lineJudge1'] = [229.0, r2(lj1[0] + 1.0), 426.0, r2(lj1[1] - 1.0)]
signatures['lineJudge3'] = [229.0, r2(lj2[0] + 1.0), 426.0, r2(lj2[1] - 1.0)]
signatures['lineJudge2'] = [487.0, r2(lj1[0] + 1.0), 689.0, r2(lj1[1] - 1.0)]
signatures['lineJudge4'] = [487.0, r2(lj2[0] + 1.0), 689.0, r2(lj2[1] - 1.0)]
signatures['approvalCaptainA'] = [229.0, r2(cap[0] + 1.0), 419.0, r2(cap[1] - 1.0)]
signatures['approvalCaptainB'] = [493.0, r2(cap[0] + 1.0), 689.0, r2(cap[1] - 1.0)]

# ------------------------------------------------------------------- remarks
rem = [v for v in hlines(320, 680, 595, 672, 0.6) if 598 < v < 670]
# The first two lines run beside the REMARKS label.
remarks = [[309.0 if i < 2 else 229.0, 688.0, b] for i, b in enumerate(rem)]

# ------------------------------------------------------------------- results
rr = hlines(700, 760, 590, 830, 0.8)
set_rows = [[rr[i], rr[i + 1]] for i in range(3, 8)]
total_row = [rr[8], rr[9]]
time_base = r2(words(718, 727, 785, 801, 'h')[0][3] - 2.3)
three = words(870, 882, 800, 822, '3')[0]
win_base = r2(three[3] - 2.7)
results = {
    'teamANameBox': [731.04, 618.0, 779.16, 633.96],
    'teamBNameBox': [837.6, 618.0, 885.6, 633.96],
    'teamACols': {'T': [698.28, 715.92], 'S': [715.92, 734.64],
                  'W': [734.64, 753.12], 'P': [753.12, 776.28]},
    'teamBCols': {'P': [840.36, 863.4], 'W': [863.4, 882.12],
                  'S': [882.12, 900.72], 'T': [900.72, 919.56]},
    'setRows': set_rows,
    'totalRow': total_row,
    'winnerNameX': [786.0, 831.0],
    'winnerTextBaselineY': win_base,
    'printedWinnerSets': [r2(three[0]), r2(three[1]), 887.1, r2(three[3])],
    'setDurationX': [801.6, 835.4],
    'totalSetDurationX': [784.0, 817.0],
    'totalSetDurationBaselineY': r2(words(815, 834, 762, 778, 'mn')[0][3] - 2.3),
    'timeBaselineY': time_base,
    # Match times are written "16 h 02 mn" in front of the printed h and mn.
    'startHoursRightX': 718.8, 'startMinutesRightX': 743.6,
    'endHoursRightX': 794.8, 'endMinutesRightX': 819.4,
    'durationHoursRightX': 872.6, 'durationMinutesRightX': 897.2,
}

# ---------------------------------------------------------- header + details
header = {
    'leftCircle': circle(480.12, 97.08, 10.6),
    'rightCircle': circle(669.42, 96.6, 10.6),
    'leftNameX': [497.5, 543.0],
    'rightNameX': [605.5, 651.5],
    'nameBaselineY': 101.0,
}
match_info = {
    'competition': [183.0, 36.0, 690.0, 52.0],
    'venue': [75.36, 73.44, 236.4, 89.28],  # Hall
    'matchType': [300.48, 73.44, 348.6, 89.28],  # Pool/Phase
    'matchNumber': [412.68, 73.44, 444.72, 89.4],
    'day': [482.04, 56.88, 514.08, 70.0],
    'month': [514.08, 56.88, 546.12, 70.0],
    'year': [546.12, 56.88, 578.16, 70.0],
    'time': [623.88, 56.88, 687.96, 70.0],
    'men': [113.64, 95.04, 129.72, 111.12],
    'women': [176.4, 95.04, 192.36, 111.12],
    'juniors': [371.04, 95.04, 387.0, 111.12],
}

layout = {
    'page': {'w': 1190.55, 'h': 841.89},
    # The printed colons are wide: keep scores a little further from them.
    'colonGap': 2.4,
    'blocks': blocks,
    'header': header,
    'players': players,
    'results': results,
    'signatures': signatures,
    'matchInfo': match_info,
    'officials': officials,
    'setTimes': set_times,
    'remarks': {'rows': remarks},
}
with open(f'{OUT}/fivb_5set_layout.json', 'w') as f:
    json.dump(layout, f, separators=(',', ':'))

# The picture: a 300 dpi greyscale JPEG keeps the small print sharp.
page_img.convert('L').save(f'{OUT}/fivb_5set_blank.jpg', quality=80,
                           optimize=True)
print('wrote', f'{OUT}/fivb_5set_layout.json',
      os.path.getsize(f'{OUT}/fivb_5set_layout.json'), 'bytes and',
      f'{OUT}/fivb_5set_blank.jpg',
      os.path.getsize(f'{OUT}/fivb_5set_blank.jpg'), 'bytes')
