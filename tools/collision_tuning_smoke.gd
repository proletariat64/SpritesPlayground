extends SceneTree

const PanelScript := preload("res://godot/scripts/creator_lab_v0_3_panel.gd")
const DataStore := preload("res://godot/scripts/prd_v0_3_data_store.gd")
const CombatCharacterScript := preload("res://godot/scripts/combat_character.gd")

const TEMPLATE_ID := "miduo"
const MOVE_ID := "miduo_jab"
const OTHER_MOVE_ID := "miduo_blue_jab"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var errors: Array = []
	var original_template := DataStore.load_template(TEMPLATE_ID)
	var backups := {}
	backups[DataStore.template_path(TEMPLATE_ID)] = _read_text(DataStore.template_path(TEMPLATE_ID))
	backups[DataStore.sprite_set_path(str(original_template["sprite_set_ref"]))] = _read_text(DataStore.sprite_set_path(str(original_template["sprite_set_ref"])))
	backups["res://godot/resources/sprite_frames/miduo.tres"] = _read_text("res://godot/resources/sprite_frames/miduo.tres")
	for move_id in original_template["equipped_moves"]:
		backups[DataStore.move_path(str(move_id))] = _read_text(DataStore.move_path(str(move_id)))
	var other_move_text := _read_text(DataStore.move_path(OTHER_MOVE_ID))
	var panel: PanelContainer = PanelScript.new()
	root.add_child(panel)
	panel.setup()
	await process_frame
	panel.load_template_id(TEMPLATE_ID)
	panel.select_move(MOVE_ID)

	# Fixed geometry: attacker at x=0 faces right; defender stands at x=50.
	panel.set_first_hitbox("hit_jab", 1, 2, {"x": 32, "y": -50, "w": 24, "h": 18})
	panel.set_first_attack_hurtbox("hurt_attack_body", 1, 2, {"x": -14, "y": -56, "w": 28, "h": 48})
	panel.save_all()
	var saved_move := DataStore.load_move(MOVE_ID)
	errors.append_array(_expect(saved_move.get("hurtboxes", []).size() == 1, "attack-frame hurtbox persists"))
	errors.append_array(_expect(float(saved_move["hitboxes"][0]["rect"]["x"]) == 32.0, "hitbox position persists"))
	errors.append_array(_expect(float(saved_move["hitboxes"][0]["rect"]["w"]) == 24.0, "hitbox size persists"))
	errors.append_array(_expect(float(saved_move["hurtboxes"][0]["rect"]["x"]) == -14.0, "attack hurtbox position persists"))
	errors.append_array(_expect(float(saved_move["hurtboxes"][0]["rect"]["h"]) == 48.0, "attack hurtbox size persists"))
	errors.append_array(_expect(_read_text(DataStore.move_path(OTHER_MOVE_ID)) == other_move_text, "character-scoped peer remains unchanged"))

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

	for path in backups.keys():
		_write_text(str(path), str(backups[path]))
	panel.queue_free()
	attacker.queue_free()
	defender.queue_free()

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
	var bundle := DataStore.load_runtime_bundle(TEMPLATE_ID)
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


func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	return file.get_as_text()


func _write_text(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(content)


func _expect(condition: bool, label: String) -> Array:
	return [] if condition else [label]
