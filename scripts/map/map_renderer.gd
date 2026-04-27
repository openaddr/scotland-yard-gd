extends Node2D

var _md: Node
var _highlight_stations: Array = []
var _highlight_color: Color = Color.GREEN
var _pulse_time: float = 0.0
var _token_nodes: Dictionary = {}
var _token_stations: Dictionary = {}
var _station_font: Font
var _connections: Array = []
var _stations: Dictionary = {}
var _bg_sprite: Sprite2D
var _highlight_layer: Node2D
var _label_layer: Node2D
var _sp: float = 1.0
var _current_player_idx: int = -1

func _ready() -> void:
	_md = get_node("/root/MapData")
	_connections = _md._connections_raw
	_stations = _md.stations
	_station_font = ThemeDB.fallback_font

	# SVG background: z_index=-1 so it draws below everything
	_bg_sprite = Sprite2D.new()
	_bg_sprite.name = "BoardBackground"
	_bg_sprite.z_index = -1
	var svg_tex := _load_svg_texture("res://assets/Scotland_Yard_schematic.svg")
	if svg_tex:
		_bg_sprite.texture = svg_tex
	add_child(_bg_sprite)

	# Station label layer: z_index=3 draws above highlights and tokens
	_label_layer = Node2D.new()
	_label_layer.name = "StationLabelLayer"
	_label_layer.z_index = 3
	var label_script := GDScript.new()
	label_script.source_code = (
		'extends Node2D\n' +
		'var _stations: Dictionary = {}\n' +
		'var _font: Font\n' +
		'func setup(stations: Dictionary):\n' +
		'\t_stations = stations\n' +
		'func _ready():\n' +
		'\t_font = ThemeDB.fallback_font\n' +
		'func _draw():\n' +
		'\tvar md = get_node("/root/MapData")\n' +
		'\tvar sp: float = md.get_viewport_scale() if md else 1.0\n' +
		'\tvar fs: int = int(clamp(9.0 * sp, 9.0, 18.0))\n' +
		'\tvar outline: float = max(1.0, fs / 8.0)\n' +
		'\tvar col: Color = Color.WHITE\n' +
		'\tvar bg: Color = Color(0, 0, 0, 0.7)\n' +
		'\tfor sid_str in _stations:\n' +
		'\t\tvar pos: Vector2 = md.get_station_position(int(sid_str))\n' +
		'\t\tvar text: String = sid_str\n' +
		'\t\tvar ts: Vector2 = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)\n' +
		'\t\tvar cx: float = pos.x - ts.x / 2.0\n' +
		'\t\tvar cy: float = pos.y - ts.y / 2.0 - 3.0 * sp\n' +
		'\t\tfor dx in [-1, 0, 1]:\n' +
		'\t\t\tfor dy in [-1, 0, 1]:\n' +
		'\t\t\t\tif dx == 0 and dy == 0: continue\n' +
		'\t\t\t\tdraw_string(_font, Vector2(cx + dx * outline, cy + dy * outline), text, HORIZONTAL_ALIGNMENT_CENTER, -1, fs, bg)\n' +
		'\t\tdraw_string(_font, Vector2(cx, cy), text, HORIZONTAL_ALIGNMENT_CENTER, -1, fs, col)\n'
	)
	label_script.reload()
	_label_layer.set_script(label_script)
	_label_layer.call("setup", _stations)
	add_child(_label_layer)

	# Highlight layer: z_index=0, above SVG but below labels
	_highlight_layer = Node2D.new()
	_highlight_layer.name = "HighlightLayer"
	_highlight_layer.z_index = 0
	var hl_script := GDScript.new()
	hl_script.source_code = (
		'extends Node2D\n' +
		'var _stations: Array = []\n' +
		'var _pulse_time: float = 0.0\n' +
		'func _process(delta: float) -> void:\n' +
		'\tif _stations.size() > 0:\n' +
		'\t\t_pulse_time += delta * 3.0\n' +
		'\t\tqueue_redraw()\n' +
		'func _draw() -> void:\n' +
		'\tif _stations.is_empty():\n' +
		'\t\treturn\n' +
		'\tvar pulse: float = (sin(_pulse_time) + 1.0) / 2.0\n' +
		'\tvar radius: float = lerp(14.0, 20.0, pulse)\n' +
		'\tvar alpha: float = lerp(0.5, 1.0, pulse)\n' +
		'\tvar fill_col: Color = Color(0.2, 0.95, 0.3, alpha * 0.25)\n' +
		'\tvar border_col: Color = Color(0.2, 0.95, 0.3, alpha)\n' +
		'\tfor sid in _stations:\n' +
		'\t\tvar md = get_node("/root/MapData")\n' +
		'\t\tvar pos: Vector2 = md.get_station_position(sid)\n' +
		'\t\tdraw_circle(pos, radius, fill_col)\n' +
		'\t\tdraw_circle(pos, radius, border_col, false, 3.0)\n'
	)
	hl_script.reload()
	_highlight_layer.set_script(hl_script)
	add_child(_highlight_layer)

	refresh()

func refresh() -> void:
	var parent = get_parent()
	var vp_size: Vector2
	if parent is Control and parent.size.x > 10 and parent.size.y > 10:
		vp_size = parent.size
	else:
		vp_size = get_viewport_rect().size
	if vp_size.x > 10 and vp_size.y > 10:
		_md.calculate_viewport_transform(vp_size)
	_update_bg_sprite()
	_update_token_positions()
	queue_redraw()
	if _label_layer:
		_label_layer.queue_redraw()

func _load_svg_texture(path: String) -> ImageTexture:
	var svg_file := FileAccess.open(path, FileAccess.READ)
	if not svg_file:
		push_warning("Could not open SVG: " + path)
		return null
	var svg_data := svg_file.get_buffer(svg_file.get_length())
	svg_file.close()
	print("SVG data size: ", svg_data.size(), " bytes for ", path)
	var img := Image.new()
	var err := img.load_svg_from_buffer(svg_data, 2.0)
	if err != OK or img.is_empty():
		push_warning("Failed to create image from SVG: %s (error: %d)" % [path, err])
		return null
	print("SVG image created: ", img.get_size())
	var tex := ImageTexture.create_from_image(img)
	print("SVG texture created for: ", path)
	return tex

func _update_bg_sprite() -> void:
	if not _bg_sprite or not _bg_sprite.texture:
		return
	_sp = _md.get_viewport_scale()
	var off: Vector2 = _md.get_viewport_offset()
	var s: float = _sp / 2.0
	_bg_sprite.scale = Vector2(s, s)
	_bg_sprite.position = Vector2(
		off.x + 600.0 * s,
		off.y + 450.0 * s
	)

func _update_token_positions() -> void:
	for idx in _token_nodes:
		if _token_stations.has(idx):
			var station_id: int = _token_stations[idx]
			var pos: Vector2 = _md.get_station_position(station_id)
			_token_nodes[idx].position = pos

func highlight_stations(station_ids: Array, color: Color = Color.GREEN) -> void:
	_highlight_stations = station_ids
	_highlight_color = color
	_pulse_time = 0.0
	if _highlight_layer:
		_highlight_layer._stations = station_ids.duplicate()
		_highlight_layer._pulse_time = 0.0
		_highlight_layer.queue_redraw()

func clear_highlights() -> void:
	_highlight_stations = []
	if _highlight_layer:
		_highlight_layer._stations = []

func set_active_player(player_index: int) -> void:
	_current_player_idx = player_index
	for idx in _token_nodes:
		var token: Node2D = _token_nodes[idx]
		token.set("is_active", idx == player_index)

func get_station_pos(station_id: int) -> Vector2:
	return _md.get_station_position(station_id)

func create_token(player_index: int, station_id: int, color: Color, label: String) -> void:
	var token := Node2D.new()
	token.name = "Token%d" % player_index
	var pos: Vector2 = _md.get_station_position(station_id)
	token.position = pos
	token.z_index = 2
	var dyn_script = GDScript.new()
	dyn_script.source_code = (
		'extends Node2D\n' +
		'var _color: Color\n' +
		'var _label: String\n' +
		'var _font: Font\n' +
		'var is_active: bool = false\n' +
		'var _pulse: float = 0.0\n' +
		'func setup(c: Color, l: String):\n' +
		'\t_color = c\n' +
		'\t_label = l\n' +
		'func _ready():\n' +
		'\t_font = ThemeDB.fallback_font\n' +
		'func _process(delta):\n' +
		'\t_pulse += delta * 4.0\n' +
		'\tqueue_redraw()\n' +
		'func _draw():\n' +
		'\tvar md = get_parent()\n' +
		'\tvar sp: float = md._sp if md else 1.0\n' +
		'\tvar r: float = 7.0 * sp\n' +
		'\tvar token_r: float = 9.0 * sp\n' +
		'\tvar gr: float = 11.0 * sp\n' +
		'\tvar fs: int = int(8.0 * sp)\n' +
		'\tvar bw: float = 1.5 * sp\n' +
		'\tvar pulse: float = (sin(_pulse) + 1.0) / 2.0 if is_active else 0.0\n' +
		'\tvar extra_r: float = lerp(0.0, 5.0 * sp, pulse)\n' +
		'\tvar glow_alpha: float = lerp(0.0, 0.35, pulse) if is_active else 0.0\n' +
		'\tif is_active and extra_r > 0.1:\n' +
		'\t\tdraw_circle(Vector2.ZERO, gr + extra_r, Color(_color.r, _color.g, _color.b, glow_alpha))\n' +
		'\tdraw_circle(Vector2.ZERO, token_r, Color(0, 0, 0, 0.5))\n' +
		'\tdraw_circle(Vector2.ZERO, r, _color)\n' +
		'\tdraw_circle(Vector2.ZERO, r, Color.WHITE, false, bw)\n' +
		'\tvar ts: Vector2 = _font.get_string_size(_label, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)\n' +
		'\tdraw_string(_font, Vector2(-ts.x/2.0, -ts.y/2.0 - 4.0*sp), _label, HORIZONTAL_ALIGNMENT_CENTER, -1, fs, Color.WHITE)\n'
	)
	dyn_script.reload()
	token.set_script(dyn_script)
	token.call("setup", color, label)
	add_child(token)
	_token_nodes[player_index] = token
	_token_stations[player_index] = station_id

func move_token(player_index: int, station_id: int) -> void:
	if not _token_nodes.has(player_index):
		return
	_token_stations[player_index] = station_id
	var token: Node2D = _token_nodes[player_index]
	var target_pos: Vector2 = _md.get_station_position(station_id)
	var tween = create_tween()
	tween.tween_property(token, "position", target_pos, 0.3)

func remove_token(player_index: int) -> void:
	if _token_nodes.has(player_index):
		_token_nodes[player_index].queue_free()
		_token_nodes.erase(player_index)

func show_token(player_index: int) -> void:
	if _token_nodes.has(player_index):
		_token_nodes[player_index].visible = true

func hide_token(player_index: int) -> void:
	if _token_nodes.has(player_index):
		_token_nodes[player_index].visible = false
