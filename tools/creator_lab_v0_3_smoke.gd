extends SceneTree

const PanelScript := preload("res://godot/scripts/creator_lab_v0_3_panel.gd")
const DataStore := preload("res://godot/scripts/prd_v0_3_data_store.gd")
const Catalog := preload("res://godot/scripts/creator_lab_action_catalog.gd")
const Coverage := preload("res://godot/scripts/creator_lab_action_coverage.gd")


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
	errors.append_array(_expect(panel.action_preview_control != null, "persistent preview control exists"))
	errors.append_array(_expect(panel.floating_preview_window != null, "floating selected-sprite preview window exists"))
	errors.append_array(_expect(panel.floating_preview_control != null, "floating selected-sprite preview control exists"))
	errors.append_array(_expect(panel.floating_preview_window.position.x <= 16.0, "floating preview defaults to left screen side"))
	errors.append_array(_expect(not panel.is_preview_window_visible(), "floating preview starts hidden"))
	panel.toggle_preview_window()
	errors.append_array(_expect(panel.is_preview_window_visible(), "floating preview toggles on"))
	panel.toggle_preview_window()
	errors.append_array(_expect(not panel.is_preview_window_visible(), "floating preview toggles off"))
	errors.append_array(_expect(panel.navigation_list.item_count >= 10, "navigation exposes domains and objects"))
	errors.append_array(_expect(panel.validate_current().is_empty(), "initial panel data validates"))
	errors.append_array(_run_catalog_and_coverage_smoke(panel))
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
	panel.set_move_scalar("state_context_override", "idle")
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
	errors.append_array(_run_preview_smoke(panel))
	panel.current_nav = "move:basic_punch"
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
	errors.append_array(_expect(str(reloaded_move["move_type"]) == "combat", "reloaded move_type"))
	errors.append_array(_expect(str(reloaded_move["state_context_override"]) == "idle", "reloaded state_context_override"))

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


func _run_catalog_and_coverage_smoke(panel: PanelContainer) -> Array:
	var errors: Array = []
	errors.append_array(_expect(Catalog.validate().is_empty(), "catalog validates frozen states and roles"))
	errors.append_array(_expect(Catalog.required_actions().size() == 22, "catalog has 22 required actions"))
	for add_back_id in ["run", "turn", "heavy_punch", "round_kick", "guard", "stun", "win_pose"]:
		errors.append_array(_expect(Catalog.action_ids().has(add_back_id), "add-back %s is required" % add_back_id))
	var coverage: Dictionary = panel.refresh_action_coverage()
	errors.append_array(_expect(coverage["rows"].size() == 22, "coverage returns required rows"))
	errors.append_array(_expect(int(coverage["summary"]["fail"]) == 0, "default coverage has no fail rows"))
	errors.append_array(_expect(int(coverage["summary"]["warning"]) == 22, "default placeholder coverage warns"))
	errors.append_array(_expect(_row_warnings(coverage, "idle").has(Coverage.PLACEHOLDER_ANIMATION), "placeholder warning"))

	var missing_animation := _coverage_with(panel, func(template: Dictionary, sprite_set: Dictionary, moves: Dictionary) -> void:
		sprite_set["required_moves_mapping"].erase("basic_punch")
	)
	errors.append_array(_expect(_row_warnings(missing_animation, "basic_punch").has(Coverage.MISSING_ANIMATION), "missing animation warning"))
	errors.append_array(_expect(_row_warnings(missing_animation, "basic_punch").has(Coverage.INVALID_SPRITE_MAPPING), "invalid missing mapping warning"))

	var invalid_mapping := _coverage_with(panel, func(template: Dictionary, sprite_set: Dictionary, moves: Dictionary) -> void:
		sprite_set["required_moves_mapping"]["basic_punch"] = "missing_clip"
	)
	errors.append_array(_expect(_row_warnings(invalid_mapping, "basic_punch").has(Coverage.INVALID_SPRITE_MAPPING), "invalid unknown clip mapping warning"))

	var missing_sequence := _coverage_with(panel, func(template: Dictionary, sprite_set: Dictionary, moves: Dictionary) -> void:
		sprite_set["animation_clips"]["basic_punch"]["frame_sequence_ref"] = "missing_sequence"
	)
	errors.append_array(_expect(_row_warnings(missing_sequence, "basic_punch").has(Coverage.MISSING_FRAME_SEQUENCE), "missing frame sequence warning"))

	var wrong_count := _coverage_with(panel, func(template: Dictionary, sprite_set: Dictionary, moves: Dictionary) -> void:
		sprite_set["frame_sequences"]["basic_punch"].pop_back()
	)
	errors.append_array(_expect(_row_warnings(wrong_count, "basic_punch").has(Coverage.WRONG_FRAME_COUNT), "wrong frame count warning"))

	var duplicate_hurt := _coverage_with(panel, func(template: Dictionary, sprite_set: Dictionary, moves: Dictionary) -> void:
		sprite_set["required_moves_mapping"]["hurt_light"] = "idle"
		sprite_set["required_moves_mapping"]["hurt_heavy"] = "idle"
	)
	errors.append_array(_expect(_row_warnings(duplicate_hurt, "hurt_light").has(Coverage.DUPLICATE_IDLE_FOR_DAMAGE_STATE), "duplicate idle damage warning light"))
	errors.append_array(_expect(_row_warnings(duplicate_hurt, "hurt_heavy").has(Coverage.DUPLICATE_IDLE_FOR_DAMAGE_STATE), "duplicate idle damage warning heavy"))

	var duplicate_dead := _coverage_with(panel, func(template: Dictionary, sprite_set: Dictionary, moves: Dictionary) -> void:
		sprite_set["required_moves_mapping"]["dead"] = "idle"
	)
	errors.append_array(_expect(_row_warnings(duplicate_dead, "dead").has(Coverage.DUPLICATE_IDLE_FOR_DEAD_STATE), "duplicate idle dead warning"))

	var duplicate_knockdown := _coverage_with(panel, func(template: Dictionary, sprite_set: Dictionary, moves: Dictionary) -> void:
		sprite_set["required_moves_mapping"]["knockdown"] = "idle"
	)
	errors.append_array(_expect(_row_warnings(duplicate_knockdown, "knockdown").has(Coverage.DUPLICATE_IDLE_FOR_KNOCKDOWN_STATE), "duplicate idle knockdown warning"))

	var missing_role := Coverage.analyze_entries([
		{
			"action_id": "role_probe",
			"category": "utility",
			"state_context": "idle",
			"visual_role": "",
			"backing": "move:idle",
			"required_this_wave": true,
		}
	], panel.template_json, panel.sprite_set_json, panel.moves_json)
	errors.append_array(_expect(_row_warnings(missing_role, "role_probe").has(Coverage.MISSING_VISUAL_ROLE), "missing visual role warning"))
	return errors


func _run_preview_smoke(panel: PanelContainer) -> Array:
	var errors: Array = []
	panel.current_nav = "character_foot"
	panel.select_action("basic_punch")
	panel._refresh_fields()
	errors.append_array(_expect(panel.action_preview_control != null, "preview control exists on foot editor"))
	errors.append_array(_expect(str(panel.action_preview_control.current_render_state()) == "PLACEHOLDER", "persistent preview renders placeholder frame"))
	panel.set_preview_window_visible(true)
	errors.append_array(_expect(str(panel.floating_preview_control.current_render_state()) == "PLACEHOLDER", "floating preview renders selected sprite placeholder"))
	panel.current_nav = "action_preview"
	panel._refresh_fields()
	errors.append_array(_expect(panel.action_preview_control != null, "preview control exists"))
	errors.append_array(_expect(panel.preview_frame == 0, "preview starts at frame zero"))
	errors.append_array(_expect(str(panel.action_preview_control.current_render_state()) == "PLACEHOLDER", "preview renders placeholder frame"))
	errors.append_array(_expect(not bool(panel.action_preview_control.current_frame_active()), "preview inactive frame state"))
	panel.preview_step_forward()
	errors.append_array(_expect(panel.preview_frame == 1, "preview step forward"))
	panel.preview_step_forward()
	errors.append_array(_expect(bool(panel.action_preview_control.current_frame_active()), "preview active frame state"))
	panel.preview_reset()
	errors.append_array(_expect(panel.preview_frame == 0, "preview reset"))
	panel.set_preview_speed(0.5)
	errors.append_array(_expect(is_equal_approx(panel.preview_speed, 0.5), "preview 0.5x speed"))
	panel.set_preview_speed(1.0)
	errors.append_array(_expect(is_equal_approx(panel.preview_speed, 1.0), "preview 1x speed"))
	panel._on_preview_hurt_toggled(false)
	panel._on_preview_hit_toggled(false)
	panel._on_preview_foot_toggled(false)
	errors.append_array(_expect(not panel.preview_show_hurtboxes and not panel.preview_show_hitboxes and not panel.preview_show_foot, "preview overlay toggles off"))
	panel._on_preview_hurt_toggled(true)
	panel._on_preview_hit_toggled(true)
	panel._on_preview_foot_toggled(true)
	panel.set_first_hitbox("hit_fist_1", 2, 6, {"x": 14, "y": -46, "w": 26, "h": 16})
	var preview_moves: Dictionary = panel.action_preview_control.get("moves")
	var floating_preview_moves: Dictionary = panel.floating_preview_control.get("moves")
	errors.append_array(_expect(int(preview_moves["basic_punch"]["hitboxes"][0]["rect"]["w"]) == 26, "preview updates hitbox edit"))
	errors.append_array(_expect(int(floating_preview_moves["basic_punch"]["hitboxes"][0]["rect"]["w"]) == 26, "floating preview updates hitbox edit"))
	errors.append_array(_expect(str(panel.current_nav) == "action_preview", "hitbox edit keeps preview surface visible"))
	panel.set_hurtbox_rect("hurt_head", {"x": -9, "y": -62, "w": 26, "h": 20})
	var preview_template: Dictionary = panel.action_preview_control.get("template")
	errors.append_array(_expect(float(preview_template["hurtboxes"]["hurt_head"]["w"]) == 26.0, "preview updates hurtbox edit"))
	panel.set_foot_collision({"x": 2, "y": -6}, {"x": 20, "y": 10})
	preview_template = panel.action_preview_control.get("template")
	errors.append_array(_expect(float(preview_template["foot_collision"]["radius"]["x"]) == 20.0, "preview updates foot edit"))
	panel.set_move_scalar("frame_count", 8)
	errors.append_array(_expect(panel._preview_frame_count() == 8, "preview updates timing edit"))
	panel.set_sprite_set_ref(str(panel.template_json["sprite_set_ref"]))
	errors.append_array(_expect(panel._coverage_row_for("basic_punch")["warnings"].has(Coverage.PLACEHOLDER_ANIMATION), "preview refreshes mapping coverage"))
	var preview_row: Dictionary = panel._coverage_row_for("basic_punch")
	var sequence_ref := str(preview_row.get("frame_sequence_ref", ""))
	var original_sequence: Array = panel.sprite_set_json["frame_sequences"][sequence_ref].duplicate(true)
	var texture_path := "user://creator_lab_preview_smoke.png"
	var image := Image.create_empty(4, 4, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.2, 0.8, 0.4, 1.0))
	errors.append_array(_expect(image.save_png(texture_path) == OK, "preview smoke writes user texture"))
	panel.sprite_set_json["frame_sequences"][sequence_ref][0] = texture_path
	panel.preview_reset()
	panel._refresh_fields()
	errors.append_array(_expect(str(panel.action_preview_control.current_render_state()) == "TEXTURE", "preview renders real texture frame"))
	panel.sprite_set_json["frame_sequences"][sequence_ref][0] = "res://missing/creator_lab_preview_smoke.png"
	panel.preview_reset()
	panel._refresh_fields()
	errors.append_array(_expect(str(panel.action_preview_control.current_render_state()) == "MISSING", "preview renders missing frame"))
	panel.sprite_set_json["frame_sequences"][sequence_ref] = original_sequence
	DirAccess.remove_absolute(ProjectSettings.globalize_path(texture_path))
	panel._refresh_fields()
	panel._on_preview_edit_hitbox_pressed()
	errors.append_array(_expect(str(panel.current_nav) == "move:basic_punch" and str(panel.current_move_section) == "hitbox", "preview navigates to hitbox editor"))
	panel.current_nav = "wardrobe_mapping"
	panel._refresh_fields()
	panel._on_wardrobe_generate_stub_pressed()
	errors.append_array(_expect(str(panel.status_label.text).contains("wardrobe generation stub"), "wardrobe generation stub is visible"))
	panel.set_hurtbox_rect("hurt_head", {"x": -10, "y": -63, "w": 25, "h": 19})
	panel.set_foot_collision({"x": 1, "y": -5}, {"x": 19, "y": 9})
	panel.set_move_scalar("frame_count", 9)
	panel.set_first_hitbox("hit_fist_1", 2, 6, {"x": 13, "y": -47, "w": 25, "h": 15})
	panel.set_preview_window_visible(false)
	return errors


func _coverage_with(panel: PanelContainer, mutate: Callable) -> Dictionary:
	var template: Dictionary = panel.template_json.duplicate(true)
	var sprite_set: Dictionary = panel.sprite_set_json.duplicate(true)
	var moves: Dictionary = panel.moves_json.duplicate(true)
	mutate.call(template, sprite_set, moves)
	return Coverage.analyze(template, sprite_set, moves)


func _row_warnings(coverage: Dictionary, action_id: String) -> Array:
	for row in coverage.get("rows", []):
		if str(row.get("action_id", "")) == action_id:
			return row.get("warnings", [])
	return []


func _remove_if_exists(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _expect(condition: bool, message: String) -> Array:
	if condition:
		return []
	return [message]
