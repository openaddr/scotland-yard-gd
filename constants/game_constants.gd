class_name GameConstants

enum TransportType { TAXI, BUS, UNDERGROUND, FERRY }
enum TicketType { TAXI, BUS, UNDERGROUND, BLACK, DOUBLE }
enum GamePhase { MENU, PLAYING, GAME_OVER }
enum TurnPhase { MRX_MOVE, DETECTIVE_MOVE, TURN_TRANSITION }
enum PlayerRole { MRX, DETECTIVE }

const TICKET_COLORS := {
	TicketType.TAXI: Color("#E8C840"),
	TicketType.BUS: Color("#4CAF50"),
	TicketType.UNDERGROUND: Color("#F44336"),
	TicketType.BLACK: Color("#333333"),
	TicketType.DOUBLE: Color("#9C27B0"),
}

const CONNECTION_COLORS := {
	TransportType.TAXI: Color(0.3, 0.3, 0.35, 0.6),
	TransportType.BUS: Color(0.35, 0.5, 0.35, 0.7),
	TransportType.UNDERGROUND: Color(0.5, 0.35, 0.35, 0.8),
	TransportType.FERRY: Color(0.4, 0.4, 0.5, 0.7),
}

const CONNECTION_WIDTHS := {
	TransportType.TAXI: 0.8,
	TransportType.BUS: 1.5,
	TransportType.UNDERGROUND: 2.0,
	TransportType.FERRY: 1.5,
}

const TICKET_NAMES := {
	TicketType.TAXI: "出租车",
	TicketType.BUS: "公交车",
	TicketType.UNDERGROUND: "地铁",
	TicketType.BLACK: "黑票",
	TicketType.DOUBLE: "双倍移动",
}

const TRANSPORT_NAMES := {
	TransportType.TAXI: "出租车",
	TransportType.BUS: "公交车",
	TransportType.UNDERGROUND: "地铁",
	TransportType.FERRY: "渡船",
}

const MRX_STARTING_TICKETS := {
	TicketType.TAXI: 4,
	TicketType.BUS: 3,
	TicketType.UNDERGROUND: 3,
	TicketType.BLACK: 5,
	TicketType.DOUBLE: 2,
}

const DETECTIVE_STARTING_TICKETS := {
	TicketType.TAXI: 10,
	TicketType.BUS: 8,
	TicketType.UNDERGROUND: 4,
}

const SURFACE_ROUNDS := [3, 8, 13, 18, 24]
const MAX_ROUNDS := 24

const PLAYER_COLORS := [
	Color("#E53935"),
	Color("#2196F3"),
	Color("#FF9800"),
	Color("#9C27B0"),
	Color("#00BCD4"),
	Color("#8BC34A"),
]

const PLAYER_NAMES := ["Mr. X", "侦探1", "侦探2", "侦探3", "侦探4"]
