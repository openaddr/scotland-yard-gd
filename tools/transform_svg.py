import re
import math
from collections import defaultdict

with open('assets/Scotland_Yard_schematic.svg', 'r', encoding='utf-8') as f:
    svg = f.read()

# 1. Station circles: r=6 -> r=5.0
svg = svg.replace('<circle r="6"', '<circle r="5.0"')

# 2. Red lines: stroke-width 3 -> 4.0 (do FIRST, since "3" also matches green)
svg = svg.replace(
    'stroke="#d44040" stroke-width="3" stroke-dasharray="6,4"',
    'stroke="#d44040" stroke-width="4.0" stroke-dasharray="8,8"'
)

# 3. Green lines: stroke-width 2.5 -> 3.0, add dasharray
svg = svg.replace(
    'stroke="#4a9e50" stroke-width="2.5"  stroke-linecap="round"',
    'stroke="#4a9e50" stroke-width="3.0"  stroke-dasharray="10,8" stroke-linecap="round"'
)


def parse_lines(group_text):
    lines = []
    for m in re.finditer(
        r'<line x1="([\d.]+)" y1="([\d.]+)" x2="([\d.]+)" y2="([\d.]+)"/>',
        group_text,
    ):
        lines.append(
            (float(m.group(1)), float(m.group(2)), float(m.group(3)), float(m.group(4)))
        )
    return lines


green_match = re.search(
    r'(<g\s+fill="none"\s+stroke="#4a9e50"[^>]*style="z-index:2">)(.*?)(</g>)',
    svg,
    re.DOTALL,
)
yellow_match = re.search(
    r'(<g\s+fill="none"\s+stroke="#c8b830"[^>]*style="z-index:3">)(.*?)(</g>)',
    svg,
    re.DOTALL,
)

green_lines = parse_lines(green_match.group(2))
yellow_lines = parse_lines(yellow_match.group(2))
green_set = set(green_lines)
yellow_set = set(yellow_lines)
overlap = green_set & yellow_set
reverse_overlap = set((x2, y2, x1, y1) for x1, y1, x2, y2 in overlap)
full_overlap = overlap | reverse_overlap
print(f"Parallel offset: {len(overlap)} overlapping lines")


def fc(v):
    return f"{v:.2f}"


def perp_offset(x1, y1, x2, y2, d):
    dx = x2 - x1
    dy = y2 - y1
    length = math.sqrt(dx * dx + dy * dy)
    if length < 0.01:
        return (x1, y1, x2, y2)
    nx = -dy / length * d
    ny = dx / length * d
    return (x1 + nx, y1 + ny, x2 + nx, y2 + ny)


def transform_group(group_text, overlap_set, para_dist):
    line_pattern = re.compile(
        r'<line x1="([\d.]+)" y1="([\d.]+)" x2="([\d.]+)" y2="([\d.]+)"/>'
    )
    line_matches = list(line_pattern.finditer(group_text))

    replacements = []
    for m in line_matches:
        x1, y1, x2, y2 = (
            float(m.group(1)),
            float(m.group(2)),
            float(m.group(3)),
            float(m.group(4)),
        )
        key = (x1, y1, x2, y2)
        if key in overlap_set:
            nx1, ny1, nx2, ny2 = perp_offset(x1, y1, x2, y2, para_dist)
            new_line = (
                f'<line x1="{fc(nx1)}" y1="{fc(ny1)}" x2="{fc(nx2)}" y2="{fc(ny2)}"/>'
            )
            replacements.append((m.start(), m.end(), new_line))

    result = group_text
    for start, end, replacement in sorted(replacements, key=lambda x: x[0], reverse=True):
        result = result[:start] + replacement + result[end:]

    return result


new_green = transform_group(green_match.group(2), full_overlap, -0.5)
new_yellow = transform_group(yellow_match.group(2), full_overlap, 1.5)

svg = svg.replace(
    green_match.group(0),
    green_match.group(1) + new_green + green_match.group(3),
)
svg = svg.replace(
    yellow_match.group(0),
    yellow_match.group(1) + new_yellow + yellow_match.group(3),
)

with open('assets/Scotland_Yard_schematic.svg', 'w', encoding='utf-8') as f:
    f.write(svg)
print("Done")
