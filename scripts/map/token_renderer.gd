extends Node2D
var _color: Color
var is_active: bool = false
var _pulse: float = 0.0

func setup(c: Color, _l: String) -> void:
	_color = c

func _process(delta: float) -> void:
	_pulse += delta * 4.0
	queue_redraw()

func _draw() -> void:
	var md = get_parent()
	var sp: float = md._sp if md else 1.0
	var r: float = 6.0 * sp
	var pulse: float = (sin(_pulse) + 1.0) / 2.0 if is_active else 0.0
	var extra_r: float = lerp(0.0, 5.0 * sp, pulse)
	var glow_alpha: float = lerp(0.0, 0.45, pulse) if is_active else 0.0
	# Active glow
	if is_active and extra_r > 0.1:
		draw_circle(Vector2.ZERO, r + 4.0 * sp + extra_r, Color(_color.r, _color.g, _color.b, glow_alpha))
	# Dark shadow for contrast
	var shadow_lw: float = max(3.5, 4.5 * sp)
	var d: float = r * 0.7
	draw_line(Vector2(-d, -d), Vector2(d, d), Color(0, 0, 0, 0.6), shadow_lw)
	draw_line(Vector2(-d, d), Vector2(d, -d), Color(0, 0, 0, 0.6), shadow_lw)
	# X mark (thicker, larger)
	var lw: float = max(3.0, 3.5 * sp)
	draw_line(Vector2(-d, -d), Vector2(d, d), _color, lw)
	draw_line(Vector2(-d, d), Vector2(d, -d), _color, lw)
