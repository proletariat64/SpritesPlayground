extends Node
class_name RuntimeBlackboard

var actor_id = ""
var display_name = ""
var faction = ""
var state = "idle"
var current_move = ""
var current_segment = ""
var authored_frame = 0
var runtime_frame = 0
var facing = "east"
var velocity = Vector2.ZERO
var hp = 1
var hp_max = 1
var input_buffer: Array[String] = []
var last_hurt_result = {}
var limbo_status = "unchecked"


func reset_from_definition(definition: Dictionary) -> void:
	actor_id = str(definition.get("id", "actor"))
	display_name = str(definition.get("display_name", actor_id))
	faction = str(definition.get("faction", "neutral"))
	var spawn = definition.get("spawn", {})
	facing = str(spawn.get("facing", "east"))
	var template = definition.get("character_template", {})
	hp_max = int(template.get("hp_max", 1))
	hp = hp_max
	state = "idle"
	current_move = ""
	current_segment = ""
	authored_frame = 0
	runtime_frame = 0
	velocity = Vector2.ZERO
	input_buffer.clear()
	last_hurt_result = {}


func push_input(token: String) -> void:
	input_buffer.append(token)
	while input_buffer.size() > 8:
		input_buffer.pop_front()


func input_buffer_text() -> String:
	if input_buffer.is_empty():
		return "-"
	return " ".join(input_buffer)
