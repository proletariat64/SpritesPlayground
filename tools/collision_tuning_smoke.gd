extends SceneTree

const PanelScript := preload("res://godot/scripts/creator_lab_v0_3_panel.gd")
const DataStore := preload("res://godot/scripts/prd_v0_3_data_store.gd")
const CombatCharacterScript := preload("res://godot/scripts/combat_character.gd")

const TEMPLATE_ID := "miduo"
const MOVE_ID := "miduo_jab"
const OTHER_MOVE_ID := "miduo_blue_jab"
const DATA_ROOT := "user://collision_tuning_smoke"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var errors: Array = []
	_remove_tree(DATA_ROOT)
	errors.append_array(_expect(
		DataStore.save_runtime_bundle(DataStore.load_runtime_bundle("combat_gray_s64"), DATA_ROOT).is_empty(),
		"isolated Creator Lab bootstrap fixture persists"
	))
	errors.append_array(_expect(
		DataStore.save_runtime_bundle(DataStore.load_runtime_bundle(TEMPLATE_ID), DATA_ROOT).is_empty(),
		"isolated collision fixture persists"
	))
	var other_move := DataStore.load_move(OTHER_MOVE_ID)
	errors.append_array(_expect(DataStore.save_move(other_move, DATA_ROOT) == OK, "isolated peer move persists"))
	var panel: PanelContainer = PanelScript.new()
	root.add_child(panel)
	panel.setup(DATA_ROOT)
	await process_frame
	panel.load_template_id(TEMPLATE_ID)
	panel.select_move(MOVE_ID)

	# Fixed geometry: attacker at x=0 faces right; defender stands at x=50.
	panel.set_first_hitbox("hit_jab", 1, 2, {"x": 32, "y": -50, "w": 24, "h": 18})
	panel.set_first_attack_hurtbox("hurt_attack_body", 1, 2, {"x": -14, "y": -56, "w": 28, "h": 48})
	panel.save_all()
	var saved_move := DataStore.load_move(MOVE_ID, DATA_ROOT)
	errors.append_array(_expect(saved_move.get("hurtboxes", []).size() == 1, "attack-frame hurtbox persists"))
	errors.append_array(_expect(float(saved_move["hitboxes"][0]["rect"]["x"]) == 32.0, "hitbox position persists"))
	errors.append_array(_expect(float(saved_move["hitboxes"][0]["rect"]["w"]) == 24.0, "hitbox size persists"))
	errors.append_array(_expect(float(saved_move["hurtboxes"][0]["rect"]["x"]) == -14.0, "attack hurtbox position persists"))
	errors.append_array(_expect(float(saved_move["hurtboxes"][0]["rect"]["h"]) == 48.0, "attack hurtbox size persists"))
	errors.append_array(_expect(DataStore.load_move(OTHER_MOVE_ID, DATA_ROOT) == other_move, "character-scoped peer remains unchanged"))

	panel.current_move_section = "summary"
	panel.select_move(MOVE_ID)
	var summary_text := _descendant_text(panel)
	errors.append_array(_expect("multi_hit (preview-only; not live)" in summary_text, "unsupported multi-hit is honestly labeled"))
	panel.current_move_section = "damage"
	panel.select_move(MOVE_ID)
	var damage_text := _descendant_text(panel)
	errors.append_array(_expect("Preview-only: Playground does not currently apply hitstop." in damage_text, "unsupported hitstop is honestly labeled"))
	panel.current_move_section = "events"
	panel.select_move(MOVE_ID)
	var events_text := _descendant_text(panel)
	errors.append_array(_expect("Frame events JSON (preview-only; not live)" in events_text, "unsupported events are honestly labeled"))

	var attacker = await _spawn("attacker", Vector2.ZERO)
	var defender = await _spawn("defender", Vector2(50, 0))
	_apply_saved_bundle(attacker)
	_apply_saved_bundle(defender)
	_start_active_jab(attacker)
	errors.append_array(_expect(_live_overlap(attacker, defender), "saved reachable hitbox produces hit at fixed distance"))

	panel.set_first_hitbox("hit_jab", 1, 2, {"x": 10, "y": -50, "w": 12, "h": 18})
	panel.save_all()
	_apply_saved_bundle(attacker)
	_start_active_jab(attacker)
	errors.append_array(_expect(not _live_overlap(attacker, defender), "saved short hitbox produces miss at same distance"))

	# Keep attacker reach fixed and change only defender's saved attack hurtbox.
	panel.set_first_hitbox("hit_jab", 1, 2, {"x": 32, "y": -50, "w": 24, "h": 18})
	panel.set_first_attack_hurtbox("hurt_attack_body", 1, 2, {"x": 40, "y": -56, "w": 12, "h": 48})
	panel.save_all()
	_apply_saved_bundle(attacker)
	_apply_saved_bundle(defender)
	_start_active_jab(attacker)
	_start_active_jab(defender)
	errors.append_array(_expect(not _live_overlap(attacker, defender), "moved attack hurtbox is safe at fixed distance"))

	panel.set_first_attack_hurtbox("hurt_attack_body", 1, 2, {"x": -14, "y": -56, "w": 28, "h": 48})
	panel.save_all()
	_apply_saved_bundle(attacker)
	_apply_saved_bundle(defender)
	_start_active_jab(attacker)
	_start_active_jab(defender)
	errors.append_array(_expect(_live_overlap(attacker, defender), "restored attack hurtbox is vulnerable at same distance"))

	panel.queue_free()
	attacker.queue_free()
	defender.queue_free()
	_remove_tree(DATA_ROOT)

	if errors.is_empty():
		print("collision_tuning_smoke=PASS")
		quit(0)
	else:
		for error in errors:
			push_error(str(error))
		print("collision_tuning_smoke=FAIL")
		quit(1)


func _spawn(id: String, spawn_position: Vector2):
	var character = CombatCharacterScript.new()
	character.instance_id = id
	character.template_id = TEMPLATE_ID
	root.add_child(character)
	await process_frame
	character.reset_runtime(spawn_position)
	return character


func _apply_saved_bundle(character) -> void:
	var bundle := DataStore.load_runtime_bundle(TEMPLATE_ID, DATA_ROOT)
	character.apply_v0_3_runtime_bundle(bundle["template"], bundle["sprite_set"], bundle["moves"])
	character.reset_runtime(character.position)


func _start_active_jab(character) -> void:
	character.state_machine.reset_to_idle()
	character.move_executor.start_attack_intent(MOVE_ID)
	character.move_executor.tick()


func _live_overlap(attacker, defender) -> bool:
	for hitbox in attacker.active_hitboxes_world():
		for hurtbox in defender.hurtboxes_world():
			if hitbox["rect"].intersects(hurtbox["rect"]):
				return true
	return false


func _descendant_text(node: Node) -> String:
	var result := ""
	if node is Label or node is Button or node is CheckBox:
		result += str(node.get("text")) + "\n"
	for child in node.get_children():
		result += _descendant_text(child)
	return result


func _remove_tree(path: String) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		if entry != "." and entry != "..":
			var child := path.path_join(entry)
			if directory.current_is_dir():
				_remove_tree(child)
			else:
				DirAccess.remove_absolute(ProjectSettings.globalize_path(child))
		entry = directory.get_next()
	directory.list_dir_end()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _expect(condition: bool, label: String) -> Array:
	return [] if condition else [label]
