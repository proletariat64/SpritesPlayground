extends SceneTree

const PanelScript := preload("res://godot/scripts/creator_lab_v0_3_panel.gd")
const DataStore := preload("res://godot/scripts/prd_v0_3_data_store.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var panel: PanelContainer = PanelScript.new()
	root.add_child(panel)
	panel.setup()
	await process_frame

	var errors: Array = []
	errors.append_array(_expect(str(panel.template_json["template_id"]) == "combat_gray_s64", "panel loads combat_gray_s64"))
	errors.append_array(_expect(panel.navigation_list != null, "three-panel navigation exists"))
	errors.append_array(_expect(panel.values_panel != null, "three-panel values panel exists"))
	errors.append_array(_expect(panel.detail_panel != null, "three-panel detail panel exists"))
	errors.append_array(_expect(panel.navigation_list.item_count >= 10, "navigation exposes domains and objects"))
	errors.append_array(_expect(panel.validate_current().is_empty(), "initial panel data validates"))
	var valid_sprite_ref := str(panel.template_json["sprite_set_ref"])
	panel.template_json["sprite_set_ref"] = "missing_sprite_set"
	panel.sprite_set_json = {}
	panel._on_check_pressed()
	errors.append_array(_expect(str(panel.status_label.text).contains("validation FAIL"), "check button validates broken references"))
	panel.set_sprite_set_ref(valid_sprite_ref)

	var original := DataStore.load_template("combat_gray_s64")
	var copy_id := "combat_gray_s64_v03_smoke_copy"
	_remove_if_exists(DataStore.template_path(copy_id))
	panel.copy_template(copy_id)
	errors.append_array(_expect(str(panel.template_json["template_id"]) == copy_id, "copy template id"))
	errors.append_array(_expect(str(DataStore.load_template("combat_gray_s64")["template_id"]) == str(original["template_id"]), "copy does not mutate original"))

	panel.select_move("basic_punch")
	panel.current_move_section = "hitbox"
	panel._refresh_fields()
	var walk_nav_index: int = panel.nav_keys.find("move:walk")
	errors.append_array(_expect(walk_nav_index >= 0, "navigation exposes walk move"))
	panel._on_navigation_selected(walk_nav_index)
	errors.append_array(_expect(str(panel.selected_move) == "walk", "navigation switches selected move"))
	errors.append_array(_expect(str(panel.current_move_section) == "summary", "navigation resets move section"))
	panel.select_move("basic_punch")
	var original_events: Array = panel.selected_move_json()["events"].duplicate(true)
	panel.set_move_events([
		{"frame": 1, "event_type": "play_sound", "payload": {"sound_id": "bad"}},
	])
	errors.append_array(_expect(not panel.validate_current().is_empty(), "validation rejects unsupported event_type"))
	errors.append_array(_expect(not panel.save_reload_exact(), "save/reload refuses unsupported event_type"))
	panel.set_move_events([
		{"frame": 3, "event_type": "enable_hitbox", "payload": {"hitbox_id": "hit_fist_1", "extra": "bad"}},
	])
	errors.append_array(_expect(not panel.validate_current().is_empty(), "validation rejects extra payload keys"))
	panel.set_move_events([
		{"frame": 3, "event_type": "enable_hitbox", "payload": {"hitbox_id": "bad"}},
	])
	errors.append_array(_expect(not panel.validate_current().is_empty(), "validation rejects malformed hitbox_id"))
	panel.set_move_events([
		{"frame": 3, "event_type": "enable_hitbox", "payload": {"hitbox_id": "hit_BAD"}},
	])
	errors.append_array(_expect(not panel.validate_current().is_empty(), "validation rejects uppercase hitbox_id"))
	panel.set_move_events([
		{"frame": 3, "event_type": "apply_hitstop", "payload": {"frames": "bad"}},
	])
	errors.append_array(_expect(not panel.validate_current().is_empty(), "validation rejects non-integer hitstop frames"))
	panel.set_move_events([
		{"frame": 3, "event_type": "apply_hitstop", "payload": {"frames": 999}},
	])
	errors.append_array(_expect(not panel.validate_current().is_empty(), "validation rejects out-of-range hitstop frames"))
	panel.set_move_events([
		{"frame": 3, "event_type": "set_velocity", "payload": {"x": "bad", "y": 0}},
	])
	errors.append_array(_expect(not panel.validate_current().is_empty(), "validation rejects non-numeric velocity"))
	panel.set_move_events(original_events)

	var clips: Dictionary = panel.sprite_set_json["animation_clips"]
	var original_ref := str(clips["idle"]["frame_sequence_ref"])
	clips["idle"]["frame_sequence_ref"] = "missing_sequence"
	errors.append_array(_expect(not panel.validate_current().is_empty(), "validation rejects bad animation clip sequence"))
	clips["idle"]["frame_sequence_ref"] = original_ref

	panel.set_hp(111)
	panel.select_move("basic_punch")
	panel.set_move_scalar("move_type", "combat")
	panel.set_move_scalar("frame_count", 9)
	panel.set_move_active_window(2, 6)
	panel.set_move_scalar("damage", 9)
	panel.set_move_scalar("hitstop_frames", 4)
	panel.set_move_scalar("multi_hit", true)
	panel.current_nav = "character_hurtboxes"
	panel._refresh_fields()
	var original_hurt_x := float(panel.template_json["hurtboxes"][panel.current_hurtbox_id]["x"])
	panel.hurt_inputs["x"].text = "12a"
	panel._on_box_fields_submitted()
	errors.append_array(_expect(str(panel.status_label.text).contains("invalid numeric input"), "hurtbox rejects invalid numeric input"))
	errors.append_array(_expect(float(panel.template_json["hurtboxes"][panel.current_hurtbox_id]["x"]) == original_hurt_x, "invalid numeric input does not mutate hurtbox"))
	panel.hurt_inputs["x"].text = "-10"
	panel.hurt_inputs["y"].text = "-63"
	panel.hurt_inputs["w"].text = "25"
	panel.hurt_inputs["h"].text = "19"
	panel._on_box_fields_submitted()
	panel.current_nav = "character_foot"
	panel._refresh_fields()
	panel.foot_inputs["center_x"].text = "1"
	panel.foot_inputs["center_y"].text = "-5"
	panel.foot_inputs["radius_x"].text = "19"
	panel.foot_inputs["radius_y"].text = "9"
	panel._on_box_fields_submitted()
	panel.current_nav = "move:basic_punch"
	panel.current_move_section = "hitbox"
	panel._refresh_fields()
	panel.hitbox_id_input.text = "HIT_UPPER"
	panel._on_box_fields_submitted()
	errors.append_array(_expect(str(panel.status_label.text).contains("invalid hitbox_id"), "hitbox editor reports invalid hitbox id"))
	panel.hitbox_id_input.text = "hit_fist_1"
	panel.hitbox_inputs["start_frame"].text = "2"
	panel.hitbox_inputs["end_frame"].text = "6"
	panel.hitbox_inputs["x"].text = "13"
	panel.hitbox_inputs["y"].text = "-47"
	panel.hitbox_inputs["w"].text = "25"
	panel.hitbox_inputs["h"].text = "15"
	panel._on_box_fields_submitted()
	panel.current_move_section = "events"
	panel._refresh_fields()
	panel.events_text.text = JSON.stringify([
		{"frame": 1, "event_type": "play_sound", "payload": {"sound_id": "bad"}},
	], "\t", true)
	panel._on_events_apply_pressed()
	errors.append_array(_expect(str(panel.status_label.text).contains("validation FAIL"), "events Apply validates event content"))
	panel.events_text.text = JSON.stringify([
		{"frame": 2, "event_type": "enable_hitbox", "payload": {"hitbox_id": "hit_fist_1"}},
		{"frame": 6, "event_type": "disable_hitbox", "payload": {"hitbox_id": "hit_fist_1"}},
		{"frame": 6, "event_type": "apply_hitstop", "payload": {"frames": 4}},
	], "\t", true)
	panel._on_events_apply_pressed()

	var coverage: Dictionary = panel.wardrobe_coverage()
	errors.append_array(_expect(coverage["missing_mapping"].is_empty(), "wardrobe mapping coverage"))
	errors.append_array(_expect(coverage["missing_clips"].is_empty(), "wardrobe clip coverage"))
	errors.append_array(_expect(coverage["missing_sequences"].is_empty(), "wardrobe sequence coverage"))
	errors.append_array(_expect(panel.validate_current().is_empty(), "edited panel data validates"))

	panel.runtime_start_selected_move()
	panel.runtime_advance_frame(2)
	var summary: Dictionary = panel.runtime_summary()
	errors.append_array(_expect(str(summary["current_move"]) == "basic_punch", "runtime starts selected move"))
	errors.append_array(_expect(int(summary["current_frame"]) == 2, "runtime advances selected move"))
	errors.append_array(_expect(int(summary["active_hitbox_count"]) == 1, "runtime exposes active hitbox"))

	errors.append_array(_expect(panel.save_reload_exact(), "save reload exact"))
	var reloaded_template := DataStore.load_template(copy_id)
	var reloaded_move := DataStore.load_move("basic_punch")
	errors.append_array(_expect(int(reloaded_template["hp"]) == 111, "reloaded hp"))
	errors.append_array(_expect(float(reloaded_template["hurtboxes"]["hurt_head"]["x"]) == -10.0, "reloaded hurtbox"))
	errors.append_array(_expect(int(reloaded_move["damage"]) == 9, "reloaded move damage"))
	errors.append_array(_expect(bool(reloaded_move["multi_hit"]), "reloaded multi_hit"))

	_restore_basic_punch()
	_remove_if_exists(DataStore.template_path(copy_id))

	if errors.is_empty():
		print("creator_lab_v0_3_smoke=PASS")
		quit(0)
	else:
		for error in errors:
			push_error(str(error))
		print("creator_lab_v0_3_smoke=FAIL")
		quit(1)


func _restore_basic_punch() -> void:
	DataStore.save_move({
		"schema_version": "0.3",
		"move_id": "basic_punch",
		"move_type": "combat",
		"frame_count": 8,
		"active_window": {"start_frame": 3, "end_frame": 5},
		"damage": 8,
		"hitstop_frames": 3,
		"hitboxes": [
			{
				"hitbox_id": "hit_fist_1",
				"active_window": {"start_frame": 3, "end_frame": 5},
				"rect": {"x": 12, "y": -48, "w": 24, "h": 14}
			}
		],
		"multi_hit": false,
		"events": [
			{"frame": 3, "event_type": "enable_hitbox", "payload": {"hitbox_id": "hit_fist_1"}},
			{"frame": 5, "event_type": "disable_hitbox", "payload": {"hitbox_id": "hit_fist_1"}},
			{"frame": 5, "event_type": "apply_hitstop", "payload": {"frames": 3}}
		]
	})


func _remove_if_exists(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _expect(condition: bool, message: String) -> Array:
	if condition:
		return []
	return [message]
