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
