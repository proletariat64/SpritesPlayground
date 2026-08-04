extends SceneTree

const PlaygroundScene := preload("res://godot/scenes/Playground.tscn")

var _errors: Array = []
var _skeleton_attack_count := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var playground: Node = PlaygroundScene.instantiate()
	root.add_child(playground)
	await process_frame
	playground.set_physics_process(false)
	var player: Node = playground.player
	var npc: Node = playground.dummy

	player.apply_template_id("combat_gray_s64")
	_expect(player.request_basic_attack("punch"), "gray resolves semantic punch")
	_expect(str(player.debug_summary()["move"]) == "basic_punch", "gray selects basic_punch")
	player.reset_runtime(player.position)
	_expect(player.request_basic_attack("kick"), "gray resolves semantic kick")
	_expect(str(player.debug_summary()["move"]) == "basic_kick", "gray selects basic_kick")
	player.apply_template_id("miduo")
	_expect(player.request_basic_attack("punch"), "Miduo resolves semantic punch")
	_expect(str(player.debug_summary()["move"]) == "miduo_jab", "Miduo selects scoped jab")
	player.apply_template_id("skeleton_default_unarmed_s64")
	_expect(not player.request_basic_attack("kick"), "Skeleton reports unavailable kick")
	_expect(player.request_basic_attack("punch"), "Skeleton resolves its punch")

	player.apply_template_id("combat_gray_s64")
	player.control_mode = "manual"
	player.is_test_dummy = true
	npc.apply_template_id("skeleton_default_unarmed_s64")
	npc.control_mode = "ai"
	npc.is_test_dummy = false
	npc.set_combat_target(player)
	npc.move_executor.move_started.connect(_on_skeleton_move_started)
	player.reset_runtime(Vector2(245, 245))
	npc.reset_runtime(Vector2(289, 245))
	for _frame in 240:
		playground.advance_gameplay(1.0 / 60.0)
	_expect(_skeleton_attack_count >= 2, "punch-only Skeleton AI attacks repeatedly")

	player.control_mode = "manual"
	player.is_test_dummy = true
	npc.control_mode = "manual"
	npc.is_test_dummy = true
	var trade_template := _trade_template()
	var trade_move := _trade_move()
	player.apply_v0_3_runtime_bundle(trade_template.duplicate(true), {}, {"trade_probe": trade_move.duplicate(true)})
	npc.apply_v0_3_runtime_bundle(trade_template.duplicate(true), {}, {"trade_probe": trade_move.duplicate(true)})
	player.reset_runtime(Vector2(245, 245))
	npc.reset_runtime(Vector2(275, 245))
	player.current_hp = 5
	var npc_hp_before: int = npc.current_hp
	_expect(player.request_attack("trade_probe"), "player starts trade probe")
	_expect(npc.request_attack("trade_probe"), "NPC starts reciprocal trade probe")
	playground.advance_gameplay(0.0)
	_expect(player.current_hp == 0, "lethal side of reciprocal trade lands")
	_expect(npc.current_hp == npc_hp_before - 10, "reciprocal attack lands after executor cancellation")
	var hit_summary: Dictionary = npc.debug_summary()
	_expect(str(hit_summary["last_hit_hurtbox"]) == "hurt_first", "first contact remains resolved hurtbox")
	_expect(hit_summary["contact_hurtboxes"] == ["hurt_first", "hurt_second"], "ordered contact debug list is preserved")
	playground.advance_gameplay(0.0)
	_expect(npc.current_hp == npc_hp_before - 10, "same window and target applies damage only once")

	var before := _live_snapshot(npc)
	npc.apply_template_id("missing_remediation_template")
	_expect(_live_snapshot(npc) == before, "missing authored template is rejected atomically")
	npc.apply_runtime_template({})
	_expect(_live_snapshot(npc) == before, "malformed runtime template is rejected atomically")
	npc.apply_v0_3_runtime_bundle({}, {}, {})
	_expect(_live_snapshot(npc) == before, "malformed v0.3 bundle is rejected atomically")

	playground.free()
	if _errors.is_empty():
		print("gdscript_remediation_smoke=PASS")
		quit(0)
	else:
		for error in _errors:
			push_error(str(error))
		print("gdscript_remediation_smoke=FAIL")
		quit(1)


func _on_skeleton_move_started(_move_id: String) -> void:
	_skeleton_attack_count += 1


func _trade_template() -> Dictionary:
	return {
		"template_id": "trade_character",
		"sprite_set_ref": "combat_gray_s64",
		"hp": 100,
		"walk_speed": 95.0,
		"run_speed": 150.0,
		"hurtboxes": {
			"hurt_first": {"x": -20, "y": -60, "w": 40, "h": 60},
			"hurt_second": {"x": -18, "y": -58, "w": 36, "h": 56},
		},
		"foot_collision": {
			"center": {"x": 0, "y": -4},
			"radius": {"x": 18, "y": 8},
		},
	}


func _trade_move() -> Dictionary:
	return {
		"move_id": "trade_probe",
		"move_type": "combat",
		"state_context_override": "idle",
		"frame_count": 30,
		"active_window": {"start_frame": 0, "end_frame": 29},
		"damage": 10,
		"hitstop_frames": 0,
		"hitboxes": [{
			"hitbox_id": "hit_trade",
			"active_window": {"start_frame": 0, "end_frame": 29},
			"rect": {"x": -80, "y": -80, "w": 160, "h": 100},
		}],
		"hurtboxes": [],
		"multi_hit": false,
		"events": [],
	}


func _live_snapshot(character: Node) -> Dictionary:
	return {
		"summary": character.debug_summary().duplicate(true),
		"template": character.template.duplicate(true),
		"hurtboxes": character.hurtbox_profile.duplicate(true),
		"foot": character.foot_collision_profile.duplicate(true),
		"moves": character.move_executor.move_templates.duplicate(true),
		"walk_speed": character.walk_speed,
		"run_speed": character.run_speed,
	}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
