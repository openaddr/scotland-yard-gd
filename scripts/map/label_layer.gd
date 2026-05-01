extends Node2D
var _stations: Dictionary = {}
var _font: Font
var _md: Node

func setup(stations: Dictionary, md: Node) -> void:
	_stations = stations
	_md = md

func _ready() -> void:
	_font = ThemeDB.fallback_font

func _draw() -> void:
	var sp: float = _md.get_viewport_scale() if _md else 1.0
	var fs: int = int(clamp(7.0 * sp, 6.0, 12.0))
	var outline: float = max(0.8, fs / 8.0)
	var col: Color = Color.WHITE
	var bg: Color = Color(0, 0, 0, 0.7)
	var all_colors = {
		"taxi": Color(0.91, 0.78, 0.25, 1.0),
		"bus": Color(0.30, 0.69, 0.31, 1.0),
		"underground": Color(0.96, 0.26, 0.21, 1.0),
		"ferry": Color(0.2, 0.2, 0.2, 1.0),
	}
	var border_col = Color(0.2, 0.2, 0.2, 1.0)
	for sid_str in _stations:
		var pos: Vector2 = _md.get_station_position(int(sid_str))
		var r: float = 5.0 * sp
		# Draw vertical color bands inside station circle
		var types_raw: Array = _md.stations[sid_str].get("types", [])
		if types_raw.size() > 0:
			var band_w: float = (2.0 * r) / float(types_raw.size())
			for i in range(types_raw.size()):
				var c: Color = all_colors.get(types_raw[i], Color.WHITE)
				var x_left: float = pos.x - r + float(i) * band_w
				var x_right: float = x_left + band_w
				var pts: PackedVector2Array = _circle_band_points(pos, r, x_left, x_right)
				draw_colored_polygon(pts, c)
			# Restore circle border
			draw_arc(pos, r, 0, TAU, 24, border_col, max(1.2, 1.0 * sp), false)
		var text: String = sid_str
		var ts: Vector2 = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
		var cx: float = pos.x - ts.x / 2.0
		var cy: float = pos.y - ts.y / 2.0 + 1.0 * sp
		for dx in [-1, 0, 1]:
			for dy in [-1, 0, 1]:
				if dx == 0 and dy == 0:
					continue
				draw_string(_font, Vector2(cx + dx * outline, cy + dy * outline), text, HORIZONTAL_ALIGNMENT_CENTER, -1, fs, bg)
		draw_string(_font, Vector2(cx, cy), text, HORIZONTAL_ALIGNMENT_CENTER, -1, fs, col)

func _circle_band_points(center: Vector2, r: float, x_left: float, x_right: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var steps: int = 8
	# Top arc from x_left to x_right
	for i in range(steps + 1):
		var x: float = lerp(x_left, x_right, float(i) / float(steps))
		var dx: float = x - center.x
		if absf(dx) > r:
			dx = r * (1.0 if dx > 0 else -1.0)
		var dy: float = sqrt(maxf(0.0, r * r - dx * dx))
		pts.append(Vector2(x, center.y - dy))
	# Bottom arc from x_right to x_left
	for i in range(steps, -1, -1):
		var x: float = lerp(x_left, x_right, float(i) / float(steps))
		var dx: float = x - center.x
		if absf(dx) > r:
			dx = r * (1.0 if dx > 0 else -1.0)
		var dy: float = sqrt(maxf(0.0, r * r - dx * dx))
		pts.append(Vector2(x, center.y + dy))
	return pts
