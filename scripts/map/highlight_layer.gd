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
	var fill_col: Color = Color(0.2, 0.95, 0.3, alpha * 0.25)
	var border_col: Color = Color(0.2, 0.95, 0.3, alpha)
	for sid in _stations:
		var pos: Vector2 = _md.get_station_position(sid)
		draw_circle(pos, radius, fill_col)
		draw_circle(pos, radius, border_col, false, 3.0)
