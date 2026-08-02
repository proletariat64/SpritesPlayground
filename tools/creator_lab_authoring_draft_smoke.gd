extends SceneTree

const DataStore := preload("res://godot/scripts/prd_v0_3_data_store.gd")
const PanelScript := preload("res://godot/scripts/creator_lab_v0_3_panel.gd")
const PlaygroundScene := preload("res://godot/scenes/Playground.tscn")

const DRAFT_SCRIPT_PATH := "res://godot/scripts/creator_lab_authoring_draft.gd"
const TEMPLATE_ID := "combat_gray_s64"
const MOVE_ID := "basic_punch"
const ORIGINAL_DAMAGE := 8
const EDITED_DAMAGE := 13
const LEGACY_HITBOX_WIDTH := 29.0
const ACTIVE_FRAME := 3
const FRAME_DELTA := 1.0 / 60.0

var _errors: Array = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var move_path := DataStore.move_path(MOVE_ID)
	var persisted_move_before := FileAccess.get_file_as_string(move_path)
	_expect(not persisted_move_before.is_empty(), "fixture loads persisted basic_punch JSON")

	_run_headless_draft_slice(persisted_move_before)
	await _run_panel_tracer(persisted_move_before)

	if _errors.is_empty():
		print("creator_lab_authoring_draft_smoke=PASS")
		quit(0)
	else:
		for error in _errors:
			push_error(str(error))
		print("creator_lab_authoring_draft_smoke=FAIL")
		quit(1)


func _run_headless_draft_slice(persisted_move_before: String) -> void:
	if not ResourceLoader.exists(DRAFT_SCRIPT_PATH):
		_expect(false, "Authoring Draft module exists at %s" % DRAFT_SCRIPT_PATH)
		return

	var draft_script = load(DRAFT_SCRIPT_PATH)
	if draft_script == null:
		_expect(false, "Authoring Draft script loads")
		return
	var draft = draft_script.new()
	for method_name in ["load_bundle", "edit_move_scalar", "snapshot", "legacy_bundle_view"]:
		if not draft.has_method(method_name):
			_expect(false, "Authoring Draft exposes public %s" % method_name)
			return

	var source_bundle := DataStore.load_runtime_bundle(TEMPLATE_ID)
	var source_before := source_bundle.duplicate(true)
	draft.load_bundle(source_bundle)
	var initial: Dictionary = draft.snapshot()
	_expect(_snapshot_is_coherent(initial), "Authoring Draft loads one coherent Template, SpriteSet, and Moves bundle")
	_expect(not bool(initial.get("dirty", true)), "fresh Authoring Draft is clean")
	var legacy_view: Dictionary = draft.legacy_bundle_view()
	legacy_view["moves"][MOVE_ID]["damage"] = 91
	var after_legacy_alias_attempt: Dictionary = draft.snapshot()
	_expect(
		_bundle_move_damage(after_legacy_alias_attempt.get("bundle", {})) == ORIGINAL_DAMAGE
		and _bundle_move_damage(after_legacy_alias_attempt.get("preview_bundle", {})) == ORIGINAL_DAMAGE
		and not bool(after_legacy_alias_attempt.get("dirty", true)),
		"mutating legacy_bundle_view cannot bypass Draft ownership, dirty state, or valid Preview snapshot"
	)

	draft.edit_move_scalar(MOVE_ID, "damage", EDITED_DAMAGE)
	var edited: Dictionary = draft.snapshot()
	var current_bundle: Dictionary = edited.get("bundle", {})
	var preview_bundle: Dictionary = edited.get("preview_bundle", {})
	_expect(_bundle_move_damage(current_bundle) == EDITED_DAMAGE, "Draft owns the edited basic_punch damage")
	_expect(_bundle_move_damage(preview_bundle) == EDITED_DAMAGE, "valid edit advances the latest valid Preview snapshot")
	_expect(bool(edited.get("dirty", false)), "successful edit marks the Draft dirty")
	_expect(edited.get("diagnostics", []).is_empty(), "representative Draft edit remains valid")
	_expect(bool(edited.get("can_save", false)), "valid dirty Draft is save eligible")
	_expect(bool(edited.get("can_apply", false)), "valid dirty Draft is apply eligible")
	_expect(source_bundle == source_before, "Draft deep-copies its input instead of mutating the loaded bundle")
	_expect(_bundle_move_damage(source_bundle) == ORIGINAL_DAMAGE, "source bundle retains persisted damage 8")
	_expect(
		FileAccess.get_file_as_string(DataStore.move_path(MOVE_ID)) == persisted_move_before,
		"headless Draft edit does not persist basic_punch"
	)


func _run_panel_tracer(persisted_move_before: String) -> void:
	var playground: Node = PlaygroundScene.instantiate()
	root.add_child(playground)
	await process_frame
	playground.set_process(false)
	playground.set_physics_process(false)

	var panel: PanelContainer = PanelScript.new()
	root.add_child(panel)
	panel.setup()
	await process_frame

	var playable_sprite: Node = playground.player
	playable_sprite.apply_template_id(TEMPLATE_ID)
	panel.bind_instance(playable_sprite)
	panel.select_action(MOVE_ID)
	panel.set_preview_frame(ACTIVE_FRAME)

	var initial_preview: Dictionary = panel.preview_observation()
	_expect(_observation_hitbox_damage(initial_preview) == ORIGINAL_DAMAGE, "Preview starts from persisted damage 8")
	var initial_live_damage := _run_live_move_to_first_hitbox(playable_sprite, playground)
	_expect(initial_live_damage == ORIGINAL_DAMAGE, "Playground starts from persisted damage 8")

	var live_before_edit := {
		"hp": int(playable_sprite.current_hp),
		"position": playable_sprite.position,
		"template_id": str(playable_sprite.template_id),
		"damage": initial_live_damage,
	}
	var preview_sprite: Node = panel.preview_sprite()
	_expect(not playground.all_characters().has(preview_sprite), "Creator Lab Preview remains outside Playground membership")
	_expect(preview_sprite.combat_target == null, "Creator Lab Preview remains targetless")
	var live_template_before := {
		"max_hp": int(playable_sprite.max_hp),
		"walk_speed": float(playable_sprite.walk_speed),
		"run_speed": float(playable_sprite.run_speed),
		"hurt_head": playable_sprite.hurtbox_profile.get("hurt_head", Rect2()),
		"foot": playable_sprite.foot_collision_profile.duplicate(true),
	}
	var preview_before_invalid_template: Dictionary = panel.preview_observation().duplicate(true)
	var preview_hp_before_invalid := int(preview_sprite.max_hp)
	panel.set_hp(0)
	var invalid_template_status: Dictionary = panel.draft_status()
	_expect(not invalid_template_status.get("diagnostics", []).is_empty(), "Panel exposes invalid CharacterTemplate diagnostics")
	_expect(not bool(invalid_template_status.get("can_apply", true)), "Panel blocks Apply for an invalid CharacterTemplate Draft")
	_expect(
		panel.preview_observation() == preview_before_invalid_template,
		"Panel retains the last valid real Preview while CharacterTemplate Draft is invalid"
	)
	_expect(int(preview_sprite.max_hp) == preview_hp_before_invalid, "invalid HP retains the last valid real Preview sprite HP")
	_expect(not panel.apply_to_bound_instance(), "invalid CharacterTemplate Draft cannot Apply")
	_expect(
		int(playable_sprite.max_hp) == int(live_template_before["max_hp"]),
		"invalid CharacterTemplate Apply leaves the Playground sprite unchanged"
	)

	panel.set_hp(125)
	panel.set_movement_speeds(80.0, 220.0)
	panel.set_hurtbox_rect("hurt_head", {"x": -9, "y": -62, "w": 26, "h": 20})
	var valid_hurtbox_preview := _box_rect_by_id(panel.preview_observation().get("hurtboxes", []), "hurtbox_id", "hurt_head")
	panel.set_hurtbox_rect("hurt_head", {"x": -9, "y": -62, "w": 0, "h": 20})
	var invalid_hurtbox_status: Dictionary = panel.draft_status()
	_expect(not invalid_hurtbox_status.get("diagnostics", []).is_empty(), "Panel exposes invalid character hurtbox diagnostics")
	_expect(not bool(invalid_hurtbox_status.get("can_apply", true)), "Panel blocks Apply for an invalid character hurtbox")
	_expect(
		_box_rect_by_id(panel.preview_observation().get("hurtboxes", []), "hurtbox_id", "hurt_head") == valid_hurtbox_preview,
		"invalid character hurtbox retains the last valid real Preview hurtbox"
	)
	panel.set_hurtbox_rect("hurt_head", {"x": -9, "y": -62, "w": 26, "h": 20})
	panel.set_foot_collision({"x": 2, "y": -6}, {"x": 20, "y": 10})
	var valid_template_status: Dictionary = panel.draft_status()
	var refreshed_template_preview: Dictionary = panel.preview_observation()
	_expect(bool(valid_template_status.get("dirty", false)), "Panel CharacterTemplate edit intention marks the Draft dirty")
	_expect(valid_template_status.get("diagnostics", []).is_empty(), "repaired Panel CharacterTemplate Draft validates")
	_expect(
		int(preview_sprite.max_hp) == 125
		and is_equal_approx(float(preview_sprite.walk_speed), 80.0)
		and is_equal_approx(float(preview_sprite.run_speed), 220.0),
		"repaired character values automatically refresh Preview sprite HP and movement speeds"
	)
	_expect(
		_box_rect_by_id(refreshed_template_preview.get("hurtboxes", []), "hurtbox_id", "hurt_head").size == Vector2(26, 20),
		"valid character hurtbox edit automatically refreshes the real Preview"
	)
	_expect(
		preview_sprite.foot_contact_ellipse().get("radius", Vector2.ZERO) == Vector2(20, 10),
		"valid foot-collision edit automatically refreshes the real Preview"
	)
	_expect(
		int(playable_sprite.max_hp) == int(live_template_before["max_hp"])
		and is_equal_approx(float(playable_sprite.walk_speed), float(live_template_before["walk_speed"]))
		and is_equal_approx(float(playable_sprite.run_speed), float(live_template_before["run_speed"]))
		and playable_sprite.hurtbox_profile.get("hurt_head", Rect2()) == live_template_before["hurt_head"]
		and playable_sprite.foot_collision_profile == live_template_before["foot"],
		"valid CharacterTemplate Preview refresh leaves Playground unchanged before Apply"
	)

	var has_draft_status := panel.has_method("draft_status")
	_expect(has_draft_status, "Creator Lab Panel exposes read-only Authoring Draft status")
	panel.set_first_hitbox(
		"hit_fist_1",
		3,
		5,
		{"x": 12, "y": -48, "w": LEGACY_HITBOX_WIDTH, "h": 14}
	)
	if has_draft_status:
		_expect(
			bool(panel.draft_status().get("dirty", false)),
			"Panel hitbox edit is owned by the Authoring Draft and remains dirty"
		)
	panel.set_move_scalar("damage", EDITED_DAMAGE)
	if has_draft_status:
		var status_after_edit: Dictionary = panel.draft_status()
		_expect(bool(status_after_edit.get("dirty", false)), "Panel edit intention marks its Authoring Draft dirty")
		_expect(status_after_edit.get("diagnostics", []).is_empty(), "Panel reports the representative edit as valid")
		_expect(bool(status_after_edit.get("can_apply", false)), "Panel reports the valid Draft as apply eligible")

	var refreshed: Dictionary = panel.preview_observation()
	_expect(
		int(refreshed.get("frame", -1)) == ACTIVE_FRAME
		and _observation_hitbox_damage(refreshed) == EDITED_DAMAGE,
		"valid Draft edit automatically refreshes the real Preview at the inspected frame"
	)

	var live_after_preview_edit := {
		"hp": int(playable_sprite.current_hp),
		"position": playable_sprite.position,
		"template_id": str(playable_sprite.template_id),
		"damage": _active_hitbox_damage(playable_sprite),
	}
	_expect(live_after_preview_edit == live_before_edit, "Preview refresh leaves the selected Playground sprite unchanged before Apply")
	_expect(not playground.all_characters().has(preview_sprite), "edited Preview remains outside Playground membership")
	_expect(preview_sprite.combat_target == null, "edited Preview remains targetless")
	_expect(
		FileAccess.get_file_as_string(DataStore.move_path(MOVE_ID)) == persisted_move_before,
		"Panel edit does not save basic_punch"
	)

	panel.current_nav = "move:%s" % MOVE_ID
	panel.current_move_section = "timing"
	panel.select_move(MOVE_ID)
	panel.set_preview_frame(ACTIVE_FRAME)
	var trusted_move_preview: Dictionary = panel.preview_observation().duplicate(true)
	var trusted_preview_frame_count: int = panel.preview_frame_count()
	panel.set_move_scalar("frame_count", 5)
	var invalid_move_status: Dictionary = panel.draft_status()
	_expect(
		int(panel.selected_move_json().get("frame_count", -1)) == 5,
		"temporarily invalid Move remains visible and editable through the Panel public seam"
	)
	_expect(
		panel.frame_count_input != null and panel.frame_count_input.text == "5",
		"Panel renders the current invalid frame count instead of the Preview snapshot value"
	)
	_expect(not invalid_move_status.get("diagnostics", []).is_empty(), "Panel exposes invalid Move timing diagnostics")
	_expect(not bool(invalid_move_status.get("can_save", true)), "Panel blocks Save for an invalid Move Draft")
	_expect(not bool(invalid_move_status.get("can_apply", true)), "Panel blocks Apply for an invalid Move Draft")
	_expect(panel.preview_frame_count() == trusted_preview_frame_count, "invalid Move retains the last valid Preview frame count")
	_expect(panel.preview_observation() == trusted_move_preview, "invalid Move retains the last valid real Preview observation")

	panel.save_all()
	_expect(
		FileAccess.get_file_as_string(DataStore.move_path(MOVE_ID)) == persisted_move_before,
		"invalid Move Save leaves the persisted JSON bytes unchanged"
	)
	_expect(not panel.apply_to_bound_instance(), "invalid Move Draft cannot Apply")
	var invalid_apply_damage := _run_live_move_to_first_hitbox(playable_sprite, playground)
	_expect(invalid_apply_damage == ORIGINAL_DAMAGE, "invalid Move Apply leaves Playground damage unchanged")
	_expect(is_equal_approx(_active_hitbox_width(playable_sprite), 24.0), "invalid Move Apply leaves Playground hitbox geometry unchanged")

	panel.set_move_scalar("frame_count", 8)
	var repaired_move_status: Dictionary = panel.draft_status()
	refreshed = panel.preview_observation()
	_expect(repaired_move_status.get("diagnostics", []).is_empty(), "Panel can repair a temporarily invalid Move")
	_expect(bool(repaired_move_status.get("can_save", false)), "repaired Move Draft can Save")
	_expect(bool(repaired_move_status.get("can_apply", false)), "repaired Move Draft can Apply")
	_expect(
		int(refreshed.get("frame", -1)) == ACTIVE_FRAME
		and _observation_hitbox_damage(refreshed) == EDITED_DAMAGE,
		"repair advances the real Preview to the latest valid Move Draft"
	)

	_expect(panel.apply_to_bound_instance(), "explicit Apply succeeds for the valid Draft")
	var applied_damage := _run_live_move_to_first_hitbox(playable_sprite, playground)
	_expect(applied_damage == EDITED_DAMAGE, "explicit Apply reaches Playground through the real Move execution path")
	_expect(
		int(playable_sprite.max_hp) == 125
		and is_equal_approx(float(playable_sprite.walk_speed), 80.0)
		and is_equal_approx(float(playable_sprite.run_speed), 220.0)
		and playable_sprite.hurtbox_profile.get("hurt_head", Rect2()).size == Vector2(26, 20)
		and playable_sprite.foot_collision_profile.get("radius", Vector2.ZERO) == Vector2(20, 10),
		"explicit Apply sends valid CharacterTemplate values and collision profiles through the live bundle path"
	)
	_expect(
		is_equal_approx(_active_hitbox_width(playable_sprite), LEGACY_HITBOX_WIDTH),
		"Draft-owned hitbox edit survives explicit Apply through the real Move path"
	)
	if has_draft_status:
		_expect(bool(panel.draft_status().get("dirty", false)), "Apply does not clear the unsaved Draft dirty state")
	_expect(
		FileAccess.get_file_as_string(DataStore.move_path(MOVE_ID)) == persisted_move_before,
		"Apply is not Save and leaves basic_punch JSON unchanged"
	)

	var mapping: Dictionary = panel.sprite_set_json.get("required_moves_mapping", {})
	var clips: Dictionary = panel.sprite_set_json.get("animation_clips", {})
	var clip_id := str(mapping.get(MOVE_ID, ""))
	var sequence_ref := str(clips.get(clip_id, {}).get("frame_sequence_ref", ""))
	var sequence_size_before: int = panel.sprite_set_json.get("frame_sequences", {}).get(sequence_ref, []).size()
	var frame_count_before := int(panel.selected_move_json().get("frame_count", 0))
	_expect(not sequence_ref.is_empty() and sequence_size_before > 0, "legacy import rollback fixture exposes the selected Move frame sequence")
	var accepted_preview: Dictionary = panel.preview_observation().duplicate(true)
	var accepted_preview_frame_count: int = panel.preview_frame_count()
	panel.sprite_set_json.clear()
	var rejected_legacy_errors: Array = panel.validate_current()
	_expect(
		not rejected_legacy_errors.is_empty()
		and str(rejected_legacy_errors[0]).contains("Authoring Draft rejected legacy edit"),
		"public validation surfaces a structurally rejected legacy import"
	)
	_expect(
		panel.status_label != null and str(panel.status_label.text).contains("Authoring Draft rejected legacy edit"),
		"Panel renders the rejected legacy import failure"
	)
	_expect(
		str(panel.sprite_set_json.get("sprite_set_id", "")) == str(panel.template_json.get("sprite_set_ref", ""))
		and panel.sprite_set_json.get("frame_sequences", {}).get(sequence_ref, []).size() == sequence_size_before
		and int(panel.selected_move_json().get("frame_count", 0)) == frame_count_before,
		"rejected legacy import rolls Panel aliases back to the accepted Draft snapshot"
	)
	_expect(
		panel.preview_frame_count() == accepted_preview_frame_count
		and panel.preview_observation() == accepted_preview,
		"rejected legacy import does not advance the latest valid real Preview"
	)

	panel.queue_free()
	playground.queue_free()
	await process_frame


func _snapshot_is_coherent(snapshot: Dictionary) -> bool:
	var bundle: Dictionary = snapshot.get("bundle", {})
	var template: Dictionary = bundle.get("template", {})
	var sprite_set: Dictionary = bundle.get("sprite_set", {})
	var moves: Dictionary = bundle.get("moves", {})
	if str(template.get("template_id", "")) != TEMPLATE_ID:
		return false
	if str(template.get("sprite_set_ref", "")) != str(sprite_set.get("sprite_set_id", "")):
		return false
	var equipped_moves: Array = template.get("equipped_moves", [])
	if equipped_moves.size() != moves.size():
		return false
	for move_id in equipped_moves:
		if not moves.has(str(move_id)):
			return false
	return true


func _bundle_move_damage(bundle: Dictionary) -> int:
	var moves: Dictionary = bundle.get("moves", {})
	var move: Dictionary = moves.get(MOVE_ID, {})
	return int(move.get("damage", -1))


func _observation_hitbox_damage(observation: Dictionary) -> int:
	var hitboxes: Array = observation.get("hitboxes", [])
	return int(hitboxes[0].get("damage", -1)) if not hitboxes.is_empty() else -1


func _active_hitbox_damage(sprite: Node) -> int:
	var hitboxes: Array = sprite.active_hitboxes_world()
	return int(hitboxes[0].get("damage", -1)) if not hitboxes.is_empty() else -1


func _active_hitbox_width(sprite: Node) -> float:
	var hitboxes: Array = sprite.active_hitboxes_world()
	if hitboxes.is_empty():
		return -1.0
	var rect: Rect2 = hitboxes[0].get("rect", Rect2())
	return rect.size.x


func _box_rect_by_id(boxes: Array, id_key: String, box_id: String) -> Rect2:
	for box in boxes:
		if str(box.get(id_key, "")) == box_id:
			return box.get("rect", Rect2())
	return Rect2()


func _run_live_move_to_first_hitbox(sprite: Node, playground: Node) -> int:
	sprite.is_test_dummy = true
	sprite.reset_runtime(sprite.position)
	sprite.set_combat_target(null)
	_expect(sprite.request_attack(MOVE_ID), "real Playground sprite starts basic_punch")
	sprite.tick_character(0.0, playground.arena_center, playground.arena_radius)
	var guard := 0
	while sprite.active_hitboxes_world().is_empty() and guard < 16:
		sprite.tick_character(FRAME_DELTA, playground.arena_center, playground.arena_radius)
		guard += 1
	_expect(guard < 16, "real Playground Move reaches its active hitbox")
	return _active_hitbox_damage(sprite)


func _expect(condition: bool, label: String) -> void:
	if not condition:
		_errors.append(label)
