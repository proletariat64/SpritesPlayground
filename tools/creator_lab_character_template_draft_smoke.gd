extends SceneTree

const DataStore := preload("res://godot/scripts/prd_v0_3_data_store.gd")
const DraftScript := preload("res://godot/scripts/creator_lab_authoring_draft.gd")

const TEMPLATE_ID := "combat_gray_s64"
const ALTERNATE_TEMPLATE_ID := "skeleton_default_unarmed_s64"
const COPY_TEMPLATE_ID := "combat_gray_s64_issue_44_unsaved_copy"

var _errors: Array = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_run_character_template_draft_slice()
	if _errors.is_empty():
		print("creator_lab_character_template_draft_smoke=PASS")
		quit(0)
	else:
		for error in _errors:
			push_error(str(error))
		print("creator_lab_character_template_draft_smoke=FAIL")
		quit(1)


func _run_character_template_draft_slice() -> void:
	var draft := DraftScript.new()

	var source_bundle := DataStore.load_runtime_bundle(TEMPLATE_ID)
	var source_before := source_bundle.duplicate(true)
	draft.load_bundle(source_bundle)

	var valid_before_values: Dictionary = draft.snapshot().get("preview_bundle", {}).duplicate(true)
	_expect(
		draft.edit_character_values(0, 80.0, 220.0),
		"Draft accepts a temporarily invalid CharacterTemplate value edit"
	)
	var invalid_values: Dictionary = draft.snapshot()
	_expect(
		int(invalid_values.get("bundle", {}).get("template", {}).get("hp", -1)) == 0,
		"temporarily invalid HP remains editable in the current Draft"
	)
	_expect(not invalid_values.get("diagnostics", []).is_empty(), "invalid CharacterTemplate values expose diagnostics")
	_expect(not bool(invalid_values.get("can_save", true)), "invalid CharacterTemplate values block Save")
	_expect(not bool(invalid_values.get("can_apply", true)), "invalid CharacterTemplate values block Apply")
	_expect(
		invalid_values.get("preview_bundle", {}) == valid_before_values,
		"invalid CharacterTemplate values retain the most recent valid Preview bundle"
	)

	_expect(
		draft.edit_character_values(125, 80.0, 220.0),
		"Draft repairs CharacterTemplate values through the same public seam"
	)
	var repaired_values: Dictionary = draft.snapshot()
	_expect(repaired_values.get("diagnostics", []).is_empty(), "repaired CharacterTemplate values validate")
	_expect(bool(repaired_values.get("dirty", false)), "valid CharacterTemplate values mark the Draft dirty")
	_expect(bool(repaired_values.get("can_apply", false)), "repaired CharacterTemplate values enable Apply")
	_expect(
		int(repaired_values.get("preview_bundle", {}).get("template", {}).get("hp", -1)) == 125,
		"repaired CharacterTemplate values advance the valid Preview bundle"
	)

	var valid_before_hurtbox: Dictionary = repaired_values.get("preview_bundle", {}).duplicate(true)
	_expect(
		draft.edit_hurtbox_rect("hurt_head", {"x": -9, "y": -62, "w": 0, "h": 20}),
		"Draft accepts a temporarily invalid character hurtbox edit"
	)
	var invalid_hurtbox: Dictionary = draft.snapshot()
	_expect(not invalid_hurtbox.get("diagnostics", []).is_empty(), "invalid character hurtbox exposes diagnostics")
	_expect(not bool(invalid_hurtbox.get("can_apply", true)), "invalid character hurtbox blocks Apply")
	_expect(
		invalid_hurtbox.get("preview_bundle", {}) == valid_before_hurtbox,
		"invalid character hurtbox retains the most recent valid Preview bundle"
	)
	_expect(
		draft.edit_hurtbox_rect("hurt_head", {"x": -9, "y": -62, "w": 26, "h": 20}),
		"Draft repairs a character hurtbox through the same public seam"
	)
	var repaired_hurtbox: Dictionary = draft.snapshot()
	_expect(repaired_hurtbox.get("diagnostics", []).is_empty(), "repaired character hurtbox validates")
	_expect(
		float(repaired_hurtbox.get("preview_bundle", {}).get("template", {}).get("hurtboxes", {}).get("hurt_head", {}).get("w", -1.0)) == 26.0,
		"repaired character hurtbox advances the valid Preview bundle"
	)

	var valid_before_foot: Dictionary = repaired_hurtbox.get("preview_bundle", {}).duplicate(true)
	_expect(
		draft.edit_foot_collision({"x": 2, "y": -6}, {"x": 0, "y": 10}),
		"Draft accepts a temporarily invalid foot-collision edit"
	)
	var invalid_foot: Dictionary = draft.snapshot()
	_expect(not invalid_foot.get("diagnostics", []).is_empty(), "invalid foot collision exposes diagnostics")
	_expect(not bool(invalid_foot.get("can_apply", true)), "invalid foot collision blocks Apply")
	_expect(
		invalid_foot.get("preview_bundle", {}) == valid_before_foot,
		"invalid foot collision retains the most recent valid Preview bundle"
	)
	_expect(
		draft.edit_foot_collision({"x": 2, "y": -6}, {"x": 20, "y": 10}),
		"Draft repairs foot collision through the same public seam"
	)
	var repaired_foot: Dictionary = draft.snapshot()
	_expect(repaired_foot.get("diagnostics", []).is_empty(), "repaired foot collision validates")
	_expect(
		float(repaired_foot.get("preview_bundle", {}).get("template", {}).get("foot_collision", {}).get("radius", {}).get("x", -1.0)) == 20.0,
		"repaired foot collision advances the valid Preview bundle"
	)

	var malformed_sprite_set_before: Dictionary = draft.snapshot()
	_expect(not draft.change_sprite_set({}), "malformed SpriteSet intent is rejected")
	_expect(draft.snapshot() == malformed_sprite_set_before, "rejected malformed SpriteSet intent leaves the Draft unchanged")

	var missing_sprite_set := {
		"schema_version": "0.3",
		"sprite_set_id": "missing_sprite_set",
		"animation_clips": {},
		"frame_sequences": {},
		"required_moves_mapping": {},
	}
	var valid_before_missing_sprite_set: Dictionary = draft.snapshot().get("preview_bundle", {}).duplicate(true)
	_expect(draft.change_sprite_set(missing_sprite_set), "well-formed missing SpriteSet document state is accepted into the current Draft")
	var missing_sprite_set_snapshot: Dictionary = draft.snapshot()
	_expect(
		str(missing_sprite_set_snapshot.get("bundle", {}).get("template", {}).get("sprite_set_ref", "")) == "missing_sprite_set"
		and missing_sprite_set_snapshot.get("bundle", {}).get("sprite_set", {}) == missing_sprite_set,
		"missing SpriteSet reference and empty document remain coherent in the editable current Draft"
	)
	_expect(not missing_sprite_set_snapshot.get("diagnostics", []).is_empty(), "missing SpriteSet document exposes diagnostics")
	_expect(not bool(missing_sprite_set_snapshot.get("can_apply", true)), "missing SpriteSet document blocks Apply")
	_expect(
		missing_sprite_set_snapshot.get("preview_bundle", {}) == valid_before_missing_sprite_set,
		"missing SpriteSet document retains the most recent valid Preview bundle"
	)
	_expect(draft.change_sprite_set(source_bundle.get("sprite_set", {})), "valid SpriteSet document repairs the missing-document Draft")
	_expect(draft.snapshot().get("diagnostics", []).is_empty(), "repaired SpriteSet document validates")

	var malformed_moves_before: Dictionary = draft.snapshot()
	_expect(not draft.set_equipped_moves(["Bad Move"], {}), "malformed equipped Move intent is rejected")
	_expect(draft.snapshot() == malformed_moves_before, "rejected malformed Move intent leaves the Draft unchanged")

	var missing_move_ids: Array = source_bundle.get("template", {}).get("equipped_moves", []).duplicate(true)
	missing_move_ids.append("missing_move")
	var source_moves: Dictionary = source_bundle.get("moves", {}).duplicate(true)
	var valid_before_missing_move: Dictionary = draft.snapshot().get("preview_bundle", {}).duplicate(true)
	_expect(
		draft.set_equipped_moves(missing_move_ids, source_moves),
		"well-formed missing equipped Move document state is accepted into the current Draft"
	)
	var missing_move_snapshot: Dictionary = draft.snapshot()
	_expect(
		missing_move_snapshot.get("bundle", {}).get("template", {}).get("equipped_moves", []) == missing_move_ids
		and not missing_move_snapshot.get("bundle", {}).get("moves", {}).has("missing_move"),
		"missing equipped Move id remains visible with its absent document in the editable current Draft"
	)
	_expect(not missing_move_snapshot.get("diagnostics", []).is_empty(), "missing equipped Move document exposes diagnostics")
	_expect(not bool(missing_move_snapshot.get("can_apply", true)), "missing equipped Move document blocks Apply")
	_expect(
		missing_move_snapshot.get("preview_bundle", {}) == valid_before_missing_move,
		"missing equipped Move document retains the most recent valid Preview bundle"
	)
	_expect(
		draft.set_equipped_moves(source_bundle.get("template", {}).get("equipped_moves", []), source_moves),
		"valid equipped Move documents repair the missing-document Draft"
	)
	_expect(draft.snapshot().get("diagnostics", []).is_empty(), "repaired equipped Move documents validate")

	var alternate_bundle := DataStore.load_runtime_bundle(ALTERNATE_TEMPLATE_ID)
	var alternate_template: Dictionary = alternate_bundle.get("template", {})
	var alternate_moves: Dictionary = alternate_bundle.get("moves", {}).duplicate(true)
	# The alternate SpriteSet intentionally uses longer idle art and shorter hurt art.
	# Build coherent unsaved Move documents so the two-step relationship swap can
	# prove last-valid retention between its document edits.
	alternate_moves["idle"]["frame_count"] = 6
	alternate_moves["hurt"]["frame_count"] = 2
	alternate_moves["hurt"]["active_window"]["end_frame"] = 1
	alternate_moves["hurt"]["events"][0]["frame"] = 1
	var alternate_move_ids: Array = alternate_template.get("equipped_moves", []).duplicate(true)
	var valid_before_relationship_swap: Dictionary = draft.snapshot().get("preview_bundle", {}).duplicate(true)
	_expect(
		draft.set_equipped_moves(alternate_move_ids, alternate_moves),
		"Draft owns equipped Move ids and documents as one edit"
	)
	var equipped_snapshot: Dictionary = draft.snapshot()
	_expect(not equipped_snapshot.get("diagnostics", []).is_empty(), "first relationship document exposes temporary frame-count mismatches")
	_expect(not bool(equipped_snapshot.get("can_save", true)), "temporary relationship mismatch blocks Save")
	_expect(not bool(equipped_snapshot.get("can_apply", true)), "temporary relationship mismatch blocks Apply")
	_expect(
		equipped_snapshot.get("preview_bundle", {}) == valid_before_relationship_swap,
		"first relationship document retains the latest valid Preview"
	)
	_expect(
		equipped_snapshot.get("bundle", {}).get("template", {}).get("equipped_moves", []) == alternate_move_ids
		and equipped_snapshot.get("bundle", {}).get("moves", {}) == alternate_moves,
		"equipped Move ids and documents update together"
	)

	var alternate_sprite_set: Dictionary = alternate_bundle.get("sprite_set", {})
	_expect(
		draft.change_sprite_set(alternate_sprite_set),
		"Draft owns the SpriteSet reference and document as one edit"
	)
	var sprite_set_snapshot: Dictionary = draft.snapshot()
	var sprite_set_bundle: Dictionary = sprite_set_snapshot.get("bundle", {})
	var alternate_sprite_set_id := str(alternate_sprite_set.get("sprite_set_id", ""))
	_expect(sprite_set_snapshot.get("diagnostics", []).is_empty(), "coherent SpriteSet edit validates")
	_expect(
		str(sprite_set_bundle.get("template", {}).get("sprite_set_ref", "")) == alternate_sprite_set_id
		and str(sprite_set_bundle.get("sprite_set", {}).get("sprite_set_id", "")) == alternate_sprite_set_id,
		"SpriteSet reference and document update together"
	)
	_expect(
		sprite_set_snapshot.get("preview_bundle", {}) == sprite_set_bundle,
		"valid coherent document edits advance the Preview bundle"
	)

	var source_template_path := DataStore.template_path(TEMPLATE_ID)
	var copy_template_path := DataStore.template_path(COPY_TEMPLATE_ID)
	var source_template_text_before := FileAccess.get_file_as_string(source_template_path)
	_expect(not FileAccess.file_exists(copy_template_path), "#44 unsaved copy fixture starts without a destination file")
	_expect(draft.copy_template(COPY_TEMPLATE_ID), "Draft creates a new unsaved template identity")
	var copied: Dictionary = draft.snapshot()
	var copied_bundle: Dictionary = copied.get("bundle", {})
	_expect(
		str(copied_bundle.get("template", {}).get("template_id", "")) == COPY_TEMPLATE_ID,
		"template copy changes the active Draft identity"
	)
	_expect(
		str(copied_bundle.get("template", {}).get("sprite_set_ref", "")) == alternate_sprite_set_id
		and copied_bundle.get("template", {}).get("equipped_moves", []) == alternate_move_ids,
		"template copy preserves SpriteSet and equipped Move identity relationships"
	)
	_expect(bool(copied.get("dirty", false)), "unsaved template copy remains dirty")
	_expect(
		str(copied.get("preview_bundle", {}).get("template", {}).get("template_id", "")) == COPY_TEMPLATE_ID,
		"valid template copy advances Preview to the new Draft identity"
	)
	_expect(source_bundle == source_before, "CharacterTemplate edits never mutate the loaded source bundle")
	_expect(
		FileAccess.get_file_as_string(source_template_path) == source_template_text_before,
		"template copy does not mutate the persisted source template"
	)
	_expect(not FileAccess.file_exists(copy_template_path), "template copy does not persist before explicit Save")


func _expect(condition: bool, label: String) -> void:
	if not condition:
		_errors.append(label)
