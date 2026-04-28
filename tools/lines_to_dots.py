"""Replace green <line> elements with dotted circles along each line path."""
import re
import math

with open('assets/Scotland_Yard_schematic.svg', 'r', encoding='utf-8') as f:
    svg = f.read()

DOT_RADIUS = 1.5
DOT_SPACING = 8.0
DOT_COLOR = "#4a9e50"

green_match = re.search(
    r'(<g\s+fill="none"\s+stroke="#4a9e50"[^>]*style="z-index:2">)(.*?)(</g>)',
    svg,
    re.DOTALL,
)

def fc(v):
    return f"{v:.2f}"

def lines_to_dots(group_text):
    line_pattern = re.compile(
        r'<line x1="([\d.]+)" y1="([\d.]+)" x2="([\d.]+)" y2="([\d.]+)"/>'
    )
    replacements = []
    for m in line_pattern.finditer(group_text):
        x1, y1, x2, y2 = float(m.group(1)), float(m.group(2)), float(m.group(3)), float(m.group(4))
        dx, dy = x2 - x1, y2 - y1
        length = math.sqrt(dx * dx + dy * dy)
        if length < 0.01:
            replacements.append((m.start(), m.end(), ''))
            continue
        nx, ny = dx / length, dy / length
        dots = []
        dist = DOT_SPACING / 2
        while dist < length:
            cx = x1 + nx * dist
            cy = y1 + ny * dist
            dots.append(f'<circle cx="{fc(cx)}" cy="{fc(cy)}" r="{DOT_RADIUS}" fill="{DOT_COLOR}"/>')
            dist += DOT_SPACING
        replacements.append((m.start(), m.end(), '\n'.join(dots)))

    result = group_text
    for start, end, replacement in sorted(replacements, key=lambda x: x[0], reverse=True):
        result = result[:start] + replacement + result[end:]
    return result

new_green_content = lines_to_dots(green_match.group(2))

# Update the <g> tag: remove stroke attrs since we use fill now
new_g_tag = '<g fill="none" style="z-index:2">'

svg = svg.replace(
    green_match.group(0),
    new_g_tag + new_green_content + green_match.group(3),
)

with open('assets/Scotland_Yard_schematic.svg', 'w', encoding='utf-8') as f:
    f.write(svg)
print("Done: replaced green lines with dot circles")
