extends Resource
class_name CharacterTemplate

const CreatorDataStoreScript := preload("res://godot/scripts/creator_data_store.gd")
const PrdV03DataStoreScript := preload("res://godot/scripts/prd_v0_3_data_store.gd")


static func combat_gray_s64() -> Dictionary:
	return load_template("combat_gray_s64")


static func load_template(template_id: String) -> Dictionary:
	if FileAccess.file_exists(CreatorDataStoreScript.template_path(template_id)):
		var template_json := CreatorDataStoreScript.load_template_json(template_id)
		if not template_json.is_empty():
			return CreatorDataStoreScript.template_json_to_runtime(template_json)
	# Imported characters (e.g. Eden imports) persist only as v0.3 bundles.
	return _load_v0_3_template(template_id)


static func _load_v0_3_template(template_id: String) -> Dictionary:
	var bundle := PrdV03DataStoreScript.load_runtime_bundle(template_id)
	var template: Dictionary = bundle.get("template", {})
	if template.is_empty():
		push_error("Missing template in legacy and v0.3 stores: %s" % template_id)
		return {}
	var move_templates := {}
	for move_id in template.get("equipped_moves", []):
		var move: Dictionary = bundle.get("moves", {}).get(str(move_id), {})
		if move.is_empty():
			push_error("Missing v0.3 move %s for template %s" % [move_id, template_id])
			continue
		move_templates[str(move_id)] = v0_3_move_to_runtime(str(move_id), move, template_id)
	return {
		"template_id": template_id,
		"sprite_size_class": "s64",
		"frame_size": 80,
		"sprite_set_id": str(template.get("sprite_set_ref", "")),
		"max_hp": int(template.get("hp", 100)),
		"hurtbox_profile": _v0_3_hurtboxes_to_runtime(template.get("hurtboxes", {})),
		"foot_collision_profile": _v0_3_foot_to_runtime(template.get("foot_collision", {})),
		"move_templates": move_templates,
	}


static func v0_3_move_to_runtime(move_id: String, move: Dictionary, template_id: String = "") -> Dictionary:
	var windows: Array = []
	for hitbox in move.get("hitboxes", []):
		var window: Dictionary = hitbox.get("active_window", {})
		var rect: Dictionary = hitbox.get("rect", {})
		windows.append({
			"from_frame": int(window.get("start_frame", 0)),
			"to_frame": int(window.get("end_frame", 0)),
			"hitbox_id": str(hitbox.get("hitbox_id", "")),
			"damage": int(move.get("damage", 0)),
			"rect": Rect2(
				float(rect.get("x", 0.0)),
				float(rect.get("y", 0.0)),
				maxf(1.0, float(rect.get("w", 1.0))),
				maxf(1.0, float(rect.get("h", 1.0)))
			),
		})
	return {
		"move_id": move_id,
		"animation_id": animation_id_for_move(move_id, template_id),
		"fps": 60,
		"total_frames": maxi(1, int(move.get("frame_count", 1))),
		"hitbox_windows": windows,
	}


# Explicit runtime-facing alias: character-scoped move ids (miduo_jab) map back to
# their imported animation clip (jab) without renaming Eden identity.
static func animation_id_for_move(move_id: String, template_id: String = "") -> String:
	var prefix := "%s_" % template_id
	if not template_id.is_empty() and move_id.begins_with(prefix):
		return move_id.substr(prefix.length())
	return move_id


static func _v0_3_hurtboxes_to_runtime(hurtboxes: Dictionary) -> Dictionary:
	var profile := {}
	for hurtbox_id in hurtboxes.keys():
		var rect: Dictionary = hurtboxes[hurtbox_id]
		profile[str(hurtbox_id)] = Rect2(
			float(rect.get("x", 0.0)),
			float(rect.get("y", 0.0)),
			maxf(1.0, float(rect.get("w", 1.0))),
			maxf(1.0, float(rect.get("h", 1.0)))
		)
	return profile


static func _v0_3_foot_to_runtime(foot: Dictionary) -> Dictionary:
	var center: Dictionary = foot.get("center", {})
	var radius: Dictionary = foot.get("radius", {})
	return {
		"center": Vector2(float(center.get("x", 0.0)), float(center.get("y", 0.0))),
		"radius": Vector2(maxf(1.0, float(radius.get("x", 1.0))), maxf(1.0, float(radius.get("y", 1.0)))),
	}
