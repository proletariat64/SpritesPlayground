extends CharacterBody2D
class_name RuntimeActor

const RebuildData = preload("res://godot/scripts/rebuild_data.gd")

@export var definition_path = ""
@export var is_player = false

var definition = {}
var sprite_set = {}
var moves = {}
var blackboard: Node
var state_driver: Node
var input_system: Node
var move_runtime: Node
var combat_ports: Node
var life_runtime: Node
var visual_presenter: Node
var intent = Vector2.ZERO
var loaded_ok = false
var load_error = ""


func _ready() -> void:
	blackboard = $RuntimeBlackboard
	state_driver = $StateDriver
	input_system = $InputSystem
	move_runtime = $MoveRuntime
	combat_ports = $CombatPorts
	life_runtime = $LifeRuntime
	visual_presenter = $VisualPresenter
	load_from_definition_path(definition_path)


func _physics_process(delta: float) -> void:
	if not loaded_ok:
		return
	input_system.tick(delta)
	move_runtime.tick(delta)
	_apply_movement()
	move_and_slide()


func load_from_definition_path(path: String) -> void:
	definition_path = path
	var bundle = RebuildData.load_actor_bundle(path)
	if bundle.has("_error"):
		loaded_ok = false
		load_error = str(bundle["_error"])
		push_error(load_error)
		return

	definition = bundle["definition"]
	sprite_set = bundle["sprite_set"]
	moves = bundle["moves"]
	blackboard.reset_from_definition(definition)
	if is_player:
		blackboard.faction = "player"

	var spawn = definition.get("spawn", {})
	if spawn.has("x") and spawn.has("y"):
		global_position = Vector2(float(spawn["x"]), float(spawn["y"]))

	state_driver.setup(self, blackboard)
	input_system.setup(self, blackboard, is_player)
	move_runtime.setup(self, blackboard, moves)
	combat_ports.setup(self, blackboard, definition)
	life_runtime.setup(self, blackboard)
	visual_presenter.setup(self, sprite_set)
	_update_collision_shapes()
	loaded_ok = true


func set_intent(next_intent: Vector2) -> void:
	if blackboard.state == "attack" or blackboard.state == "hurt" or blackboard.state == "dead":
		intent = Vector2.ZERO
		blackboard.velocity = Vector2.ZERO
		return
	intent = next_intent
	if intent.length() > 0.01:
		blackboard.facing = "west" if intent.x < -0.01 else ("east" if intent.x > 0.01 else blackboard.facing)
		state_driver.request_event("ev_move")
	else:
		state_driver.request_event("ev_stop")


func request_light_attack() -> bool:
	if blackboard.state == "dead" or blackboard.state == "hurt":
		return false
	return move_runtime.request_light_attack()


func receive_hurt_result(result: Dictionary) -> void:
	life_runtime.apply_hurt_result(result)


func set_overlay_flags(hitboxes: bool, hurtboxes: bool, foot_anchor: bool) -> void:
	visual_presenter.set_overlay_flags(hitboxes, hurtboxes, foot_anchor)


func local_rect_to_global(rect_data: Variant) -> Rect2:
	if typeof(rect_data) != TYPE_DICTIONARY:
		return Rect2(global_position, Vector2.ZERO)
	var x = float(rect_data.get("x", 0))
	var y = float(rect_data.get("y", 0))
	var w = float(rect_data.get("w", 0))
	var h = float(rect_data.get("h", 0))
	if blackboard.facing == "west":
		x = -x - w
	return Rect2(global_position + Vector2(x, y), Vector2(w, h))


func get_foot_rect_global() -> Rect2:
	var template = definition.get("character_template", {})
	var foot = template.get("foot_collision", {})
	return local_rect_to_global(foot.get("rect", {}))


func _apply_movement() -> void:
	if blackboard.state != "walk":
		velocity = Vector2.ZERO
		return
	var template = definition.get("character_template", {})
	var speed = float(template.get("move_speed", 0))
	velocity = intent * speed
	blackboard.velocity = velocity


func _update_collision_shapes() -> void:
	var template = definition.get("character_template", {})
	_apply_shape($CollisionBody/FootCollisionShape, template.get("foot_collision", {}).get("rect", {}))
	_apply_shape($CollisionBody/BodyCollisionShape, template.get("body_collision", {}).get("rect", {}))


func _apply_shape(shape_node: CollisionShape2D, rect_data: Variant) -> void:
	if typeof(rect_data) != TYPE_DICTIONARY:
		return
	var rect = RectangleShape2D.new()
	rect.size = Vector2(float(rect_data.get("w", 1)), float(rect_data.get("h", 1)))
	shape_node.shape = rect
	shape_node.position = Vector2(
		float(rect_data.get("x", 0)) + rect.size.x * 0.5,
		float(rect_data.get("y", 0)) + rect.size.y * 0.5
	)
