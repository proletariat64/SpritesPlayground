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
