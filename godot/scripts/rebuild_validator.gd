extends Node
class_name RebuildValidator

const RebuildData = preload("res://godot/scripts/rebuild_data.gd")


static func validate_character(definition: Dictionary) -> Dictionary:
	var blocking: Array[String] = []
	var warnings: Array[String] = []

	_require_string(definition, "kind", "SpriteDefinition", blocking)
	_require_string(definition, "id", "", blocking)
	_require_string(definition, "display_name", "", blocking)
	_require_string(definition, "faction", "", blocking)

	var template = definition.get("character_template")
	if typeof(template) != TYPE_DICTIONARY:
		blocking.append("character_template must be an object")
		return _report(blocking, warnings)

	_require_number(template, "hp_max", blocking, 1)
	_require_string(template, "sprite_set_id", "", blocking)
	_require_string(template, "sprite_set_path", "", blocking)
	_require_rect(template.get("foot_collision", {}), "foot_collision", blocking)
	_require_rect(template.get("body_collision", {}), "body_collision", blocking)

	var hurtboxes = template.get("hurtboxes")
	if typeof(hurtboxes) != TYPE_ARRAY or hurtboxes.is_empty():
		blocking.append("character_template.hurtboxes must be a non-empty array")
	else:
		for i in range(hurtboxes.size()):
			var hurtbox = hurtboxes[i]
			if typeof(hurtbox) != TYPE_DICTIONARY:
				blocking.append("hurtboxes[%s] must be an object" % i)
				continue
			_require_string(hurtbox, "id", "", blocking, "hurtboxes[%s]" % i)
			_require_number(hurtbox, "priority", blocking, 0, "hurtboxes[%s]" % i)
			if not hurtbox.has("def"):
				warnings.append("hurtboxes[%s].def missing; runtime default is 0" % i)
			_require_rect(hurtbox, "hurtboxes[%s]" % i, blocking)

	var sprite_set_path = str(template.get("sprite_set_path", ""))
	if sprite_set_path != "" and not FileAccess.file_exists(sprite_set_path):
		blocking.append("sprite_set_path does not exist: %s" % sprite_set_path)

	for move_id in template.get("equipped_moves", []):
		var path = RebuildData.move_path(str(move_id))
		if not FileAccess.file_exists(path):
			blocking.append("equipped move is missing: %s" % path)

	return _report(blocking, warnings)


static func validate_move(move: Dictionary) -> Dictionary:
	var blocking: Array[String] = []
	var warnings: Array[String] = []

	_require_string(move, "kind", "MoveData", blocking)
	_require_string(move, "id", "", blocking)
	_require_string(move, "category", "combat", blocking)
	_require_string(move, "state_event", "ev_attack", blocking)
	_require_string(move, "finish_event", "ev_finished", blocking)

	var segments = move.get("segments")
	if typeof(segments) != TYPE_ARRAY or segments.is_empty():
		blocking.append("segments must be a non-empty array")
	else:
		for i in range(segments.size()):
			var segment = segments[i]
			if typeof(segment) != TYPE_DICTIONARY:
				blocking.append("segments[%s] must be an object" % i)
				continue
			_require_string(segment, "segment_id", "", blocking, "segments[%s]" % i)
			_require_number(segment, "startup_frames", blocking, 0, "segments[%s]" % i)
			_require_number(segment, "active_frames", blocking, 0, "segments[%s]" % i)
			_require_number(segment, "recovery_frames", blocking, 0, "segments[%s]" % i)
			var hitboxes = segment.get("hitbox_profiles", [])
			if typeof(hitboxes) != TYPE_ARRAY:
				blocking.append("segments[%s].hitbox_profiles must be an array" % i)
			else:
				for j in range(hitboxes.size()):
					var hitbox = hitboxes[j]
					if typeof(hitbox) != TYPE_DICTIONARY:
						blocking.append("segments[%s].hitbox_profiles[%s] must be an object" % [i, j])
						continue
					_require_string(hitbox, "id", "", blocking, "segments[%s].hitbox_profiles[%s]" % [i, j])
					_require_number(hitbox, "atk", blocking, 0, "segments[%s].hitbox_profiles[%s]" % [i, j])
					_require_rect(hitbox, "segments[%s].hitbox_profiles[%s]" % [i, j], blocking)

	if move.get("id", "") == "basic_punch_3hit" and move.get("segment_policy", "") != "linear_continue":
		blocking.append("basic_punch_3hit must use segment_policy linear_continue")

	return _report(blocking, warnings)


static func validate_sprite_set(sprite_set: Dictionary) -> Dictionary:
	var blocking: Array[String] = []
	var warnings: Array[String] = []

	_require_string(sprite_set, "kind", "SpriteSet", blocking)
	_require_string(sprite_set, "id", "", blocking)
	var clips = sprite_set.get("clips")
	if typeof(clips) != TYPE_DICTIONARY:
		blocking.append("clips must be an object")
	else:
		for clip_id in ["idle", "walk", "hurt", "dead"]:
			if not clips.has(clip_id):
				blocking.append("clips.%s is required for M1 coverage" % clip_id)
		for attack_clip in ["basic_punch", "basic_punch_3hit"]:
			if not clips.has(attack_clip):
				warnings.append("clips.%s missing; attack visual fallback will be used" % attack_clip)

	return _report(blocking, warnings)


static func validate_all_sources() -> Dictionary:
	var blocking: Array[String] = []
	var warnings: Array[String] = []

	for character_id in RebuildData.CHARACTER_IDS:
		var character = RebuildData.load_character(character_id)
		if character.has("_error"):
			blocking.append(character["_error"])
		else:
			var report = validate_character(character)
			_append_prefixed(blocking, report.blocking, "character:%s" % character_id)
			_append_prefixed(warnings, report.warnings, "character:%s" % character_id)

	for move_id in RebuildData.MOVE_IDS:
		var move = RebuildData.load_move(move_id)
		if move.has("_error"):
			blocking.append(move["_error"])
		else:
			var report = validate_move(move)
			_append_prefixed(blocking, report.blocking, "move:%s" % move_id)
			_append_prefixed(warnings, report.warnings, "move:%s" % move_id)

	for sprite_set_id in RebuildData.CHARACTER_IDS:
		var sprite_set = RebuildData.load_sprite_set(sprite_set_id)
		if sprite_set.has("_error"):
			blocking.append(sprite_set["_error"])
		else:
			var report = validate_sprite_set(sprite_set)
			_append_prefixed(blocking, report.blocking, "sprite_set:%s" % sprite_set_id)
			_append_prefixed(warnings, report.warnings, "sprite_set:%s" % sprite_set_id)

	return _report(blocking, warnings)


static func report_to_text(report: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append("blocking: %s" % report.get("blocking", []).size())
	for item in report.get("blocking", []):
		lines.append("- %s" % item)
	lines.append("warnings: %s" % report.get("warnings", []).size())
	for item in report.get("warnings", []):
		lines.append("- %s" % item)
	if report.get("blocking", []).is_empty():
		lines.append("PASS")
	else:
		lines.append("FAIL")
	return "\n".join(lines)


static func _report(blocking: Array[String], warnings: Array[String]) -> Dictionary:
	return {
		"ok": blocking.is_empty(),
		"blocking": blocking,
		"warnings": warnings
	}


static func _append_prefixed(target: Array[String], source: Array, prefix: String) -> void:
	for item in source:
		target.append("%s: %s" % [prefix, item])


static func _require_string(data: Dictionary, key: String, expected: String, blocking: Array[String], prefix = "") -> void:
	var label = _path(prefix, key)
	if not data.has(key) or typeof(data[key]) != TYPE_STRING or str(data[key]).strip_edges() == "":
		blocking.append("%s must be a non-empty string" % label)
		return
	if expected != "" and data[key] != expected:
		blocking.append("%s must be %s" % [label, expected])


static func _require_number(data: Dictionary, key: String, blocking: Array[String], minimum: float, prefix = "") -> void:
	var label = _path(prefix, key)
	if not data.has(key) or not (typeof(data[key]) == TYPE_INT or typeof(data[key]) == TYPE_FLOAT):
		blocking.append("%s must be a number" % label)
		return
	if float(data[key]) < minimum:
		blocking.append("%s must be >= %s" % [label, minimum])


static func _require_rect(data: Variant, prefix: String, blocking: Array[String]) -> void:
	if typeof(data) != TYPE_DICTIONARY:
		blocking.append("%s must be an object with rect" % prefix)
		return
	var rect = data.get("rect")
	if typeof(rect) != TYPE_DICTIONARY:
		blocking.append("%s.rect must be an object" % prefix)
		return
	for key in ["x", "y", "w", "h"]:
		if not rect.has(key) or not (typeof(rect[key]) == TYPE_INT or typeof(rect[key]) == TYPE_FLOAT):
			blocking.append("%s.rect.%s must be a number" % [prefix, key])
	if rect.has("w") and float(rect["w"]) <= 0:
		blocking.append("%s.rect.w must be > 0" % prefix)
	if rect.has("h") and float(rect["h"]) <= 0:
		blocking.append("%s.rect.h must be > 0" % prefix)


static func _path(prefix: String, key: String) -> String:
	if prefix == "":
		return key
	return "%s.%s" % [prefix, key]
