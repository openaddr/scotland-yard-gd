extends Node2D
var _stations: Array = []
var _pulse_time: float = 0.0
var _md: Node

func setup(md: Node) -> void:
	_md = md

func _process(delta: float) -> void:
	if _stations.size() > 0:
		_pulse_time += delta * 3.0
		queue_redraw()

func _draw() -> void:
	if _stations.is_empty():
		return
	var pulse: float = (sin(_pulse_time) + 1.0) / 2.0
	var radius: float = lerp(14.0, 20.0, pulse)
	var alpha: float = lerp(0.5, 1.0, pulse)
	var gs = get_node_or_null("/root/GameSettings")
	var hl_color: Color = gs.highlight_color if gs else Color(0.2, 0.95, 0.3)
	var fill_col: Color = Color(hl_color.r, hl_color.g, hl_color.b, alpha * 0.25)
	var border_col: Color = Color(hl_color.r, hl_color.g, hl_color.b, alpha)
	for sid in _stations:
		var pos: Vector2 = _md.get_station_position(sid)
		draw_circle(pos, radius, fill_col)
		draw_circle(pos, radius, border_col, false, 3.0)
