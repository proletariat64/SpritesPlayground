extends RefCounted
class_name CreatorLabAuthoringDraft

const DocumentRules := preload("res://godot/scripts/prd_v0_3_document_rules.gd")

signal valid_snapshot_changed

var _bundle: Dictionary = {}
var _clean_bundle: Dictionary = {}
var _preview_bundle: Dictionary = {}
var _diagnostics: Array = []
var _dirty: bool = false
var _loaded: bool = false


func load_bundle(source: Dictionary) -> Array:
	var candidate := source.duplicate(true)
	var candidate_diagnostics := DocumentRules.validate_runtime_bundle(candidate)
	_bundle = candidate
	_clean_bundle = candidate.duplicate(true)
	_diagnostics = candidate_diagnostics.duplicate(true)
	_dirty = false
	_loaded = not candidate.is_empty()
	if _diagnostics.is_empty():
		var preview_changed := _preview_bundle != candidate
		_preview_bundle = candidate.duplicate(true)
		if preview_changed:
			valid_snapshot_changed.emit()
	return _diagnostics.duplicate(true)


func edit_move_scalar(move_id: String, field: String, value) -> bool:
	if not _loaded or field != "damage" or typeof(value) != TYPE_INT:
		return false
	var moves: Dictionary = _bundle.get("moves", {})
	if not moves.has(move_id) or typeof(moves[move_id]) != TYPE_DICTIONARY:
		return false

	var candidate := _bundle.duplicate(true)
	candidate["moves"][move_id]["damage"] = value
	return _commit_candidate(candidate)


func edit_character_values(hp, walk_speed, run_speed) -> bool:
	if (
		not _loaded
		or typeof(hp) != TYPE_INT
		or not _is_finite_number(walk_speed)
		or not _is_finite_number(run_speed)
		or typeof(_bundle.get("template", null)) != TYPE_DICTIONARY
	):
		return false
	var candidate := _bundle.duplicate(true)
	candidate["template"]["hp"] = hp
	candidate["template"]["walk_speed"] = walk_speed
	candidate["template"]["run_speed"] = run_speed
	return _commit_candidate(candidate)


func edit_hurtbox_rect(hurtbox_id, rect) -> bool:
	if (
		not _loaded
		or typeof(hurtbox_id) != TYPE_STRING
		or not str(hurtbox_id).begins_with("hurt_")
		or not _has_exact_numeric_fields(rect, ["x", "y", "w", "h"])
	):
		return false
	var template: Dictionary = _bundle.get("template", {})
	var hurtboxes = template.get("hurtboxes", null)
	if typeof(hurtboxes) != TYPE_DICTIONARY or not hurtboxes.has(hurtbox_id):
		return false
	var candidate := _bundle.duplicate(true)
	candidate["template"]["hurtboxes"][hurtbox_id] = rect.duplicate(true)
	return _commit_candidate(candidate)


func edit_foot_collision(center, radius) -> bool:
	if (
		not _loaded
		or not _has_exact_numeric_fields(center, ["x", "y"])
		or not _has_exact_numeric_fields(radius, ["x", "y"])
		or typeof(_bundle.get("template", null)) != TYPE_DICTIONARY
	):
		return false
	var candidate := _bundle.duplicate(true)
	candidate["template"]["foot_collision"] = {
		"center": center.duplicate(true),
		"radius": radius.duplicate(true),
	}
	return _commit_candidate(candidate)


func change_sprite_set(sprite_set_document) -> bool:
	if (
		not _loaded
		or not _is_sprite_set_document(sprite_set_document)
		or typeof(_bundle.get("template", null)) != TYPE_DICTIONARY
	):
		return false
	var sprite_set_id := str(sprite_set_document["sprite_set_id"])
	if not _is_snake_id(sprite_set_id):
		return false
	var candidate := _bundle.duplicate(true)
	candidate["template"]["sprite_set_ref"] = sprite_set_id
	candidate["sprite_set"] = sprite_set_document.duplicate(true)
	return _commit_candidate(candidate)


func set_equipped_moves(move_ids, move_documents) -> bool:
	if (
		not _loaded
		or typeof(move_ids) != TYPE_ARRAY
		or typeof(move_documents) != TYPE_DICTIONARY
		or typeof(_bundle.get("template", null)) != TYPE_DICTIONARY
	):
		return false
	var unique_ids := {}
	for move_id in move_ids:
		if typeof(move_id) != TYPE_STRING or not _is_snake_id(str(move_id)) or unique_ids.has(move_id):
			return false
		unique_ids[move_id] = true
	for document_id in move_documents.keys():
		if (
			typeof(document_id) != TYPE_STRING
			or not unique_ids.has(document_id)
			or not _is_move_document(move_documents[document_id])
		):
			return false
	var candidate := _bundle.duplicate(true)
	candidate["template"]["equipped_moves"] = move_ids.duplicate(true)
	candidate["moves"] = move_documents.duplicate(true)
	return _commit_candidate(candidate)


func copy_template(next_template_id) -> bool:
	if (
		not _loaded
		or typeof(next_template_id) != TYPE_STRING
		or not _is_snake_id(str(next_template_id))
		or typeof(_bundle.get("template", null)) != TYPE_DICTIONARY
		or str(_bundle["template"].get("template_id", "")) == str(next_template_id)
	):
		return false
	var candidate := _bundle.duplicate(true)
	candidate["template"]["template_id"] = str(next_template_id)
	return _commit_candidate(candidate)


func import_legacy_bundle(source) -> bool:
	if not _loaded or not _has_bundle_documents(source):
		return false
	# Import current legacy edits without resetting the original clean baseline.
	return _commit_candidate(source.duplicate(true))


func snapshot() -> Dictionary:
	var valid := _loaded and _diagnostics.is_empty()
	return {
		"bundle": _bundle.duplicate(true),
		"preview_bundle": _preview_bundle.duplicate(true),
		"dirty": _dirty,
		"diagnostics": _diagnostics.duplicate(true),
		"can_save": _dirty and valid,
		"can_apply": valid,
	}


func legacy_bundle_view() -> Dictionary:
	# Temporary detached bridge while Panel edits migrate behind Draft in #44-#46.
	return _bundle.duplicate(true)


func _commit_candidate(candidate: Dictionary) -> bool:
	var candidate_diagnostics := DocumentRules.validate_runtime_bundle(candidate)
	var preview_changed := candidate_diagnostics.is_empty() and _preview_bundle != candidate
	_bundle = candidate
	_diagnostics = candidate_diagnostics.duplicate(true)
	_dirty = _bundle != _clean_bundle
	if _diagnostics.is_empty():
		_preview_bundle = candidate.duplicate(true)
		if preview_changed:
			valid_snapshot_changed.emit()
	return true


func _has_bundle_documents(value) -> bool:
	return (
		typeof(value) == TYPE_DICTIONARY
		and typeof(value.get("template", null)) == TYPE_DICTIONARY
		and not value["template"].is_empty()
		and typeof(value.get("sprite_set", null)) == TYPE_DICTIONARY
		and not value["sprite_set"].is_empty()
		and typeof(value.get("moves", null)) == TYPE_DICTIONARY
		and not value["moves"].is_empty()
	)


func _is_sprite_set_document(value) -> bool:
	return (
		typeof(value) == TYPE_DICTIONARY
		and typeof(value.get("sprite_set_id", null)) == TYPE_STRING
	)


func _is_move_document(value) -> bool:
	return typeof(value) == TYPE_DICTIONARY


func _has_exact_numeric_fields(value, fields: Array) -> bool:
	if typeof(value) != TYPE_DICTIONARY or value.size() != fields.size():
		return false
	for field in fields:
		if not value.has(field) or not _is_finite_number(value[field]):
			return false
	return true


func _is_finite_number(value) -> bool:
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
		return false
	return not is_nan(float(value)) and not is_inf(float(value))


func _is_snake_id(value: String) -> bool:
	if value.is_empty():
		return false
	var expression := RegEx.new()
	expression.compile("^[a-z][a-z0-9_]*$")
	return expression.search(value) != null
