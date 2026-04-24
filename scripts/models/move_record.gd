class_name MoveRecord
extends RefCounted

var round_number: int
var ticket_type: int
var station_id: int
var is_surface: bool = false

func _init(r: int, t: int, s: int, surface: bool = false) -> void:
	round_number = r
	ticket_type = t
	station_id = s
	is_surface = surface
