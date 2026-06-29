extends Node
class_name InputSystem

var actor: Node = null
var blackboard: Node = null
var enabled_for_player = false


func setup(owner_actor: Node, owner_blackboard: Node, is_player: bool) -> void:
	actor = owner_actor
	blackboard = owner_blackboard
	enabled_for_player = is_player


func tick(_delta: float) -> void:
	if not enabled_for_player or actor == null or blackboard == null:
		return
	if blackboard.state == "dead" or blackboard.state == "hurt":
		actor.set_intent(Vector2.ZERO)
		return
	if not InputMap.has_action("move_left"):
		return

	var intent = Vector2.ZERO
	if Input.is_action_pressed("move_left"):
		intent.x -= 1.0
	if Input.is_action_pressed("move_right"):
		intent.x += 1.0
	if Input.is_action_pressed("move_up"):
		intent.y -= 1.0
	if Input.is_action_pressed("move_down"):
		intent.y += 1.0
	if intent.length() > 1.0:
		intent = intent.normalized()
	actor.set_intent(intent)

	if Input.is_action_just_pressed("attack_light"):
		press_attack_light()


func press_attack_light() -> void:
	if actor == null or blackboard == null:
		return
	blackboard.push_input("J")
	actor.request_light_attack()
