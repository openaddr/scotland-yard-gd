class_name TicketInventory
extends RefCounted

var counts: Dictionary = {}

func _init(starting: Dictionary = {}) -> void:
	for key in starting:
		counts[key] = starting[key]
	if not counts.has(GameConstants.TicketType.TAXI):
		counts[GameConstants.TicketType.TAXI] = 0
	if not counts.has(GameConstants.TicketType.BUS):
		counts[GameConstants.TicketType.BUS] = 0
	if not counts.has(GameConstants.TicketType.UNDERGROUND):
		counts[GameConstants.TicketType.UNDERGROUND] = 0
	if not counts.has(GameConstants.TicketType.BLACK):
		counts[GameConstants.TicketType.BLACK] = 0
	if not counts.has(GameConstants.TicketType.DOUBLE):
		counts[GameConstants.TicketType.DOUBLE] = 0

func can_use(ticket_type: int) -> bool:
	return counts.get(ticket_type, 0) > 0

func use_ticket(ticket_type: int) -> void:
	if counts.has(ticket_type):
		counts[ticket_type] = max(0, counts[ticket_type] - 1)

func add_ticket(ticket_type: int, amount: int = 1) -> void:
	if counts.has(ticket_type):
		counts[ticket_type] += amount
