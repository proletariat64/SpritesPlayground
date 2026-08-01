extends SceneTree

const PlaygroundScene := preload("res://godot/scenes/Playground.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var errors: Array = []
	var playground: Node = PlaygroundScene.instantiate()
	root.add_child(playground)
	await process_frame
	await physics_frame
	var npc: Node2D = playground.dummy

	errors.append_array(_expect(npc.template_id == "miduo_blue", "default npc uses independent recolor"))
	errors.append_array(_expect(npc.control_mode == "ai", "default npc is AI controlled"))
	errors.append_array(_expect(npc.combat_target == playground.player, "npc targets player"))
	errors.append_array(_expect(ClassDB.class_exists("LimboHSM") and ClassDB.class_exists("LimboState"), "required LimboAI classes are installed"))
	errors.append_array(_expect(npc.ai_backend() == "limboai", "NPC uses the required LimboAI backend"))

	var ai_source := FileAccess.get_file_as_string("res://godot/scripts/combat_ai_controller.gd")
	errors.append_array(_expect(ai_source.contains('ClassDB.instantiate("LimboState")'), "LimboAI path creates real states"))
	errors.append_array(_expect(ai_source.contains('call("call_on_update"'), "LimboAI states own update callbacks"))
	errors.append_array(_expect(ai_source.contains('call("add_transition"'), "LimboAI path wires transitions"))
	errors.append_array(_expect(ai_source.contains('call("initialize", agent)') and ai_source.contains('call("set_active", true)'), "LimboAI HSM is initialized and activated"))
	var hsm: Node = npc.ai_controller.get_node_or_null("limbo_ai_intent_hsm")
	errors.append_array(_expect(hsm != null and hsm.get_child_count() == 2, "LimboAI backend owns two behavior states"))
	errors.append_array(_expect(not ai_source.contains("_fallback_movement_intent"), "required LimboAI backend has no silent gameplay fallback"))

	var replacement_npc: Node2D = playground.add_npc("miduo_blue")
	playground.player.control_mode = "ai"
	playground.player.set_combat_target(npc)
	errors.append_array(_expect(playground.remove_npc(npc), "NPC removal succeeds when a replacement exists"))
	npc = replacement_npc
	errors.append_array(_expect(playground.dummy == npc and playground.player.combat_target == npc, "player target refreshes after NPC removal"))
	playground.player.control_mode = "manual"
	playground.player.set_combat_target(null)

	playground.player.reset_runtime(Vector2(205, 245))
	npc.reset_runtime(Vector2(435, 245))
	var initial_distance := npc.position.distance_to(playground.player.position)
	var saw_attack := false
	for _frame in 240:
		playground._tick_combat(1.0 / 60.0)
		saw_attack = saw_attack or npc.state_machine.current_state == "attack"
	var useful_distance := npc.position.distance_to(playground.player.position)
	errors.append_array(_expect(useful_distance < initial_distance, "AI approaches player"))
	errors.append_array(_expect(useful_distance >= 34.0 and useful_distance <= 82.0, "AI maintains useful distance"))
	errors.append_array(_expect(saw_attack, "AI selects a basic attack"))
	errors.append_array(_expect(playground.player.current_hp < playground.player.max_hp, "AI attack uses shared combat damage"))

	# Freeze control sources so lifecycle checks exercise shared hit/reaction rules only.
	npc.control_mode = "manual"
	npc.is_test_dummy = true
	playground.player.control_mode = "manual"
	playground.player.is_test_dummy = true
	playground.player.reset_runtime(Vector2(245, 245))
	npc.reset_runtime(Vector2(282, 245))
	var npc_hp_before: int = int(npc.current_hp)
	playground.player.request_attack("roundhouse_kick")
	var saw_knockdown := false
	var saw_recovery := false
	for _frame in 120:
		playground._tick_combat(1.0 / 60.0)
		saw_knockdown = saw_knockdown or npc.state_machine.current_state == "hurt" and npc.state_machine.reaction_mode == "knockdown"
		saw_recovery = saw_knockdown and npc.state_machine.current_state == "idle"
	errors.append_array(_expect(npc.current_hp < npc_hp_before, "NPC receives player hit"))
	errors.append_array(_expect(saw_knockdown, "nonlethal heavy hit knocks NPC down"))
	errors.append_array(_expect(saw_recovery, "nonlethal NPC recovers"))

	npc.current_hp = 1
	npc.take_hit(99, "hit_test", playground.player.instance_id, "hurt_upper_body", ["hurt_upper_body"])
	for _frame in 180:
		npc.tick_character(1.0 / 60.0, playground.arena_center, playground.arena_radius)
	errors.append_array(_expect(npc.current_hp == 0, "lethal hit reaches zero HP"))
	errors.append_array(_expect(npc.state_machine.current_state == "dead", "dead NPC remains down"))

	var player_hp: int = int(playground.player.max_hp)
	npc.max_hp = 135
	npc.move_executor.move_templates["miduo_blue_jab"]["hitbox_windows"][0]["damage"] = 7
	errors.append_array(_expect(playground.player.max_hp == player_hp, "NPC HP edit is independent"))
	errors.append_array(_expect(playground.player.move_executor.move_templates["miduo_jab"]["hitbox_windows"][0]["damage"] == 6, "NPC move edit is independent"))
	playground.reset_playground()
	errors.append_array(_expect(npc.current_hp == 135, "reset restores independently edited NPC HP"))
	errors.append_array(_expect(npc.state_machine.current_state == "idle", "reset revives NPC"))
	errors.append_array(_expect(npc.control_mode == "ai", "reset restores NPC AI source"))

	if errors.is_empty():
		print("ai_combat_smoke=PASS backend=%s distance=%.2f" % [npc.ai_backend(), useful_distance])
		quit(0)
	else:
		for error in errors:
			push_error(str(error))
		print("ai_combat_smoke=FAIL")
		quit(1)


func _expect(condition: bool, message: String) -> Array:
	return [] if condition else [message]
