extends Node

var highlight_color: Color = Color(0.2, 0.95, 0.3)
const SETTINGS_FILE := "user://settings.json"

func _ready() -> void:
	load_settings()

func load_settings() -> void:
	var file := FileAccess.open(SETTINGS_FILE, FileAccess.READ)
	if file == null:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return
	var data = json.data
	if data is Dictionary and data.has("highlight_color"):
		highlight_color = Color(data["highlight_color"])

func save_settings() -> void:
	var data := {"highlight_color": highlight_color.to_html(false)}
	var file := FileAccess.open(SETTINGS_FILE, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(data, "\t"))
