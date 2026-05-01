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

func to_dict() -> Dictionary:
	return {"move_number": move_number, "ticket_type": ticket_type, "station_id": station_id, "is_surface": is_surface}

static func from_dict(d: Dictionary) -> MoveRecord:
	return MoveRecord.new(int(d["move_number"]), int(d["ticket_type"]), int(d["station_id"]), d.get("is_surface", false))
