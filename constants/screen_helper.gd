extends Node

var is_mobile: bool = false

func _ready() -> void:
	var vp := get_viewport()
	vp.size_changed.connect(_check_mobile)
	_check_mobile()

func _check_mobile() -> void:
	var size := get_viewport().get_visible_rect().size
	is_mobile = minf(size.x, size.y) < 500.0

func get_side_panel_width() -> float:
	if not is_mobile:
		return 280.0
	var size := get_viewport().get_visible_rect().size
	return clampf(size.x * 0.28, 170.0, 240.0)

func tap_tolerance() -> float:
	return 40.0 if is_mobile else 25.0

func content_margin() -> float:
	return 6.0 if is_mobile else 10.0
