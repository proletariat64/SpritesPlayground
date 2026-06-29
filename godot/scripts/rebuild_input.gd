extends Node
class_name RebuildInput


static func ensure_actions() -> void:
	_add_key_action("move_up", KEY_W)
	_add_key_action("move_down", KEY_S)
	_add_key_action("move_left", KEY_A)
	_add_key_action("move_right", KEY_D)
	_add_key_action("attack_light", KEY_J)
	_add_key_action("toggle_hitboxes", KEY_F1)
	_add_key_action("toggle_hurtboxes", KEY_F2)
	_add_key_action("toggle_foot_anchor", KEY_F3)


static func _add_key_action(action_name: String, keycode: Key) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	var exists = false
	for event in InputMap.action_get_events(action_name):
		if event is InputEventKey and event.keycode == keycode:
			exists = true
			break
	if exists:
		return
	var event = InputEventKey.new()
	event.keycode = keycode
	InputMap.action_add_event(action_name, event)
