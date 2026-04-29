class_name MoveRecord
extends RefCounted

var move_number: int
var ticket_type: int
var station_id: int
var is_surface: bool = false

func _init(m: int, t: int, s: int, surface: bool = false) -> void:
	move_number = m
	ticket_type = t
	station_id = s
	is_surface = surface
