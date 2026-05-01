class_name PlayerData
extends RefCounted

var player_index: int
var role: int  # GameConstants.PlayerRole
var player_name: String
var color: Color
var station_id: int
var tickets: TicketInventory
var is_stuck: bool = false

func _init(idx: int, r: int, n: String, c: Color, start_tickets: Dictionary) -> void:
	player_index = idx
	role = r
	player_name = n
	color = c
	tickets = TicketInventory.new(start_tickets)

func to_dict() -> Dictionary:
	return {
		"player_index": player_index,
		"role": role,
		"player_name": player_name,
		"color": color.to_html(false),
		"station_id": station_id,
		"tickets": tickets.to_dict(),
		"is_stuck": is_stuck,
	}

static func from_dict(d: Dictionary) -> PlayerData:
	var p := PlayerData.new(int(d["player_index"]), int(d["role"]), d["player_name"], Color(d["color"]), {})
	p.tickets = TicketInventory.from_dict(d["tickets"])
	p.station_id = int(d["station_id"])
	p.is_stuck = d.get("is_stuck", false)
	return p
