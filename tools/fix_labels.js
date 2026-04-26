const fs = require('fs');
const content = fs.readFileSync('scripts/map/map_renderer.gd', 'utf8');
const lines = content.split('\n');

const newCode = [
  "\tlabel_script.source_code = (",
  "\t\t'extends Node2D\\n' +",
  "\t\t'var _stations: Dictionary = {}\\n' +",
  "\t\t'var _font: Font\\n' +",
  "\t\t'func setup(stations: Dictionary):\\n' +",
  "\t\t'\\t_stations = stations\\n' +",
  "\t\t'func _ready():\\n' +",
  "\t\t'\\t_font = ThemeDB.fallback_font\\n' +",
  "\t\t'func _draw():\\n' +",
  "\t\t'\\tvar md = get_node(\"/root/MapData\")\\n' +",
  "\t\t'\\tvar sp: float = md.get_viewport_scale() if md else 1.0\\n' +",
  "\t\t'\\tvar fs: float = clamp(9.0 * sp, 9.0, 18.0)\\n' +",
  "\t\t'\\tvar outline: float = max(1.0, fs / 8.0)\\n' +",
  "\t\t'\\tvar col: Color = Color.WHITE\\n' +",
  "\t\t'\\tvar bg: Color = Color(0, 0, 0, 0.7)\\n' +",
  "\t\t'\\tfor sid_str in _stations:\\n' +",
  "\t\t'\\t\\tvar pos: Vector2 = md.get_station_position(int(sid_str))\\n' +",
  "\t\t'\\t\\tvar text: String = sid_str\\n' +",
  "\t\t'\\t\\tvar ts: Vector2 = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)\\n' +",
  "\t\t'\\t\\tvar cx: float = pos.x - ts.x / 2.0\\n' +",
  "\t\t'\\t\\tvar cy: float = pos.y - ts.y / 2.0 - 3.0 * sp\\n' +",
  "\t\t'\\t\\tfor dx in [-1, 0, 1]:\\n' +",
  "\t\t'\\t\\t\\tfor dy in [-1, 0, 1]:\\n' +",
  "\t\t'\\t\\t\\t\\tif dx == 0 and dy == 0: continue\\n' +",
  "\t\t'\\t\\t\\t\\tdraw_string(_font, Vector2(cx + dx * outline, cy + dy * outline), text, HORIZONTAL_ALIGNMENT_CENTER, -1, fs, bg)\\n' +",
  "\t\t'\\t\\tdraw_string(_font, Vector2(cx, cy), text, HORIZONTAL_ALIGNMENT_CENTER, -1, fs, col)\\n'",
  "\t)",
];

// Find and replace the label_script.source_code block
const result = [];
let i = 0;
let replaced = false;
while (i < lines.length) {
  if (!replaced && lines[i].includes('label_script.source_code = (')) {
    result.push(...newCode);
    // Skip until the closing )
    i++;
    while (i < lines.length && !lines[i].trim() === ')') {
      i++;
    }
    i++; // skip the ) line
    replaced = true;
    continue;
  }
  result.push(lines[i]);
  i++;
}

if (replaced) {
  fs.writeFileSync('scripts/map/map_renderer.gd', result.join('\n'));
  console.log('OK: replaced label script, lines:', result.length);
} else {
  console.log('NOT FOUND');
}
