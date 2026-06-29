extends Node2D
class_name Playground

@onready var adam = $Actors/Adam
@onready var cain = $Actors/Cain
@onready var combat_resolver = $CombatResolver

var show_hitboxes = true
var show_hurtboxes = true
var show_foot_anchor = true
var hud_labels = {}


func _ready() -> void:
	combat_resolver.set_actors([adam, cain])
	_build_hud()
	_apply_overlay_flags()


func _process(_delta: float) -> void:
	_handle_debug_toggles()
	combat_resolver.tick()
	_update_hud()


func smoke_attack_sequence() -> Dictionary:
	adam.global_position = Vector2(360, 258)
	cain.global_position = Vector2(396, 258)
	adam.blackboard.facing = "east"
	adam.input_system.press_attack_light()
	for i in range(7):
		adam.move_runtime.tick(1.0 / 12.0)
		combat_resolver.tick()
	adam.input_system.press_attack_light()
	for i in range(6):
		adam.move_runtime.tick(1.0 / 12.0)
		combat_resolver.tick()
	adam.input_system.press_attack_light()
	for i in range(18):
		adam.move_runtime.tick(1.0 / 12.0)
		combat_resolver.tick()
	while adam.blackboard.state == "attack":
		adam.move_runtime.tick(1.0 / 12.0)
		combat_resolver.tick()
	return {
		"adam_state": adam.blackboard.state,
		"cain_state": cain.blackboard.state,
		"cain_hp": cain.blackboard.hp,
		"hit_log": combat_resolver.hit_log.duplicate()
	}


func _handle_debug_toggles() -> void:
	if not InputMap.has_action("toggle_hitboxes"):
		return
	if Input.is_action_just_pressed("toggle_hitboxes"):
		show_hitboxes = not show_hitboxes
		_apply_overlay_flags()
	if Input.is_action_just_pressed("toggle_hurtboxes"):
		show_hurtboxes = not show_hurtboxes
		_apply_overlay_flags()
	if Input.is_action_just_pressed("toggle_foot_anchor"):
		show_foot_anchor = not show_foot_anchor
		_apply_overlay_flags()


func _apply_overlay_flags() -> void:
	for actor in [adam, cain]:
		actor.set_overlay_flags(show_hitboxes, show_hurtboxes, show_foot_anchor)


func _build_hud() -> void:
	var layer = CanvasLayer.new()
	layer.name = "HUD"
	add_child(layer)
	var root = Control.new()
	root.name = "HUDRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)

	var panel = PanelContainer.new()
	panel.name = "DebugPanel"
	panel.position = Vector2(8, 8)
	panel.size = Vector2(360, 116)
	root.add_child(panel)

	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)
	for key in ["adam", "cain", "move", "buffer", "limbo", "overlay", "last_hit"]:
		var label = Label.new()
		label.name = key
		label.add_theme_font_size_override("font_size", 11)
		box.add_child(label)
		hud_labels[key] = label


func _update_hud() -> void:
	hud_labels["adam"].text = "Adam HP %s/%s state=%s vel=%s" % [adam.blackboard.hp, adam.blackboard.hp_max, adam.blackboard.state, adam.blackboard.velocity.round()]
	hud_labels["cain"].text = "Cain HP %s/%s state=%s" % [cain.blackboard.hp, cain.blackboard.hp_max, cain.blackboard.state]
	hud_labels["move"].text = "move=%s segment=%s authored_frame=%s runtime_frame=%s" % [adam.blackboard.current_move, adam.blackboard.current_segment, adam.blackboard.authored_frame, adam.blackboard.runtime_frame]
	hud_labels["buffer"].text = "input_buffer=%s" % adam.blackboard.input_buffer_text()
	hud_labels["limbo"].text = "StateDriver=%s" % adam.blackboard.limbo_status
	hud_labels["overlay"].text = "F1 hitbox=%s  F2 hurtbox=%s  F3 foot=%s" % [show_hitboxes, show_hurtboxes, show_foot_anchor]
	if combat_resolver.last_results.is_empty():
		hud_labels["last_hit"].text = "last_hit=-"
	else:
		var hit = combat_resolver.last_results[-1]
		hud_labels["last_hit"].text = "last_hit %s/%s dmg=%s via %s" % [hit.get("hitbox_id", ""), hit.get("hurtbox_id", ""), hit.get("damage", 0), hit.get("formula", "")]
