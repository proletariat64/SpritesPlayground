extends SceneTree

const CombatCharacterScript := preload("res://godot/scripts/combat_character.gd")

var arena_center := Vector2(320, 205)
var arena_radius := Vector2(280, 125)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var punch_ok: bool = await _run_move_hit_smoke("basic_punch", 8)
	var kick_ok: bool = await _run_move_hit_smoke("basic_kick", 10)
	if punch_ok and kick_ok:
		print("runtime_smoke=PASS")
		quit(0)
	else:
		push_error("runtime_smoke=FAIL")
		quit(1)


func _run_move_hit_smoke(move_id: String, expected_damage: int) -> bool:
	var attacker: Node2D = CombatCharacterScript.new()
	var target: Node2D = CombatCharacterScript.new()
	root.add_child(attacker)
	root.add_child(target)
	await process_frame

	attacker.instance_id = "smoke_attacker"
	target.instance_id = "smoke_target"
	attacker.position = Vector2(245, 245)
	target.position = Vector2(282, 245)
	attacker.is_test_dummy = true
	target.is_test_dummy = true

	attacker.state_machine.request_action(move_id)
	for i in 45:
		attacker.tick_character(1.0 / 60.0, arena_center, arena_radius)
		target.tick_character(1.0 / 60.0, arena_center, arena_radius)
		_process_hits(attacker, target)

	var expected_hp: int = target.max_hp - expected_damage
	var did_hit_once: bool = target.current_hp == expected_hp
	attacker.queue_free()
	target.queue_free()
	return did_hit_once


func _process_hits(attacker: Node2D, target: Node2D) -> void:
	for hitbox in attacker.active_hitboxes_world():
		var window_index := int(hitbox["window_index"])
		if not attacker.move_executor.can_hit_target(target.instance_id, window_index):
			continue
		for hurtbox in target.hurtboxes_world():
			if Rect2(hitbox["rect"]).intersects(Rect2(hurtbox["rect"])):
				target.take_hit(int(hitbox["damage"]), str(hitbox["hitbox_id"]), attacker.instance_id)
				attacker.move_executor.mark_target_hit(target.instance_id, window_index)
				break
