extends RefCounted
class_name SpriteFramesGenerator

const DEFAULT_ANIMATION_FPS := 12.0
const GENERATED_RESOURCE_ROOT := "res://godot/resources/sprite_frames"
const PLACEHOLDER_ROOT := "res://godot/assets/frame_placeholders"

const SLOT_STATE_TEXTURE := "texture"
const SLOT_STATE_EMPTY := "empty"
const SLOT_STATE_MISSING := "missing"
const SLOT_STATE_PLACEHOLDER := "placeholder"
const SLOT_STATE_INVALID := "invalid"

const WARNING_EMPTY_FRAME_SLOT := "EMPTY_FRAME_SLOT"
const WARNING_MISSING_FRAME_SLOT := "MISSING_FRAME_SLOT"
const WARNING_PLACEHOLDER_FRAME_SLOT := "PLACEHOLDER_FRAME_SLOT"
const WARNING_UNLOADABLE_FRAME_TEXTURE := "UNLOADABLE_FRAME_TEXTURE_WARNING"
const WARNING_LOCAL_ONLY_FRAME_TEXTURE := "LOCAL_ONLY_FRAME_TEXTURE"

const ERROR_INVALID_FRAME_SLOT_URI := "INVALID_FRAME_SLOT_URI"
const ERROR_INVALID_SPRITEFRAMES_RESOURCE := "INVALID_SPRITEFRAMES_RESOURCE"
const ERROR_SPRITEFRAMES_MISSING_ANIMATION := "SPRITEFRAMES_MISSING_ANIMATION"
const ERROR_SPRITEFRAMES_WRONG_FRAME_COUNT := "SPRITEFRAMES_WRONG_FRAME_COUNT"
const ERROR_SPRITEFRAMES_WRONG_LOOP_FLAG := "SPRITEFRAMES_WRONG_LOOP_FLAG"
const ERROR_RESOURCE_SAVE_FAILED := "SPRITEFRAMES_SAVE_FAILED"


static func sprite_frames_path(sprite_set_id: String) -> String:
	return GENERATED_RESOURCE_ROOT.path_join("%s.tres" % sprite_set_id)


static func frame_slot_state(slot: String) -> String:
	if slot.begins_with("res://") or slot.begins_with("user://"):
		return SLOT_STATE_TEXTURE
	if slot.begins_with("empty://"):
		return SLOT_STATE_EMPTY
	if slot.begins_with("missing://"):
		return SLOT_STATE_MISSING
	if slot.begins_with("placeholder://"):
		return SLOT_STATE_PLACEHOLDER
	return SLOT_STATE_INVALID


static func validate_frame_slot(slot: String) -> Array:
	var state := frame_slot_state(slot)
	if state == SLOT_STATE_INVALID:
		return [_warning(ERROR_INVALID_FRAME_SLOT_URI, slot)]
	if state == SLOT_STATE_EMPTY:
		return [_warning(WARNING_EMPTY_FRAME_SLOT, slot)]
	if state == SLOT_STATE_MISSING:
		return [_warning(WARNING_MISSING_FRAME_SLOT, slot)]
	if state == SLOT_STATE_PLACEHOLDER:
		return [_warning(WARNING_PLACEHOLDER_FRAME_SLOT, slot)]
	if slot.begins_with("user://"):
		return [_warning(WARNING_LOCAL_ONLY_FRAME_TEXTURE, slot)]
	return []


static func generate(sprite_set: Dictionary, options: Dictionary = {}) -> Dictionary:
	var warnings: Array = []
	var errors: Array = []
	var sprite_set_id := str(sprite_set.get("sprite_set_id", ""))
	var output_path := str(options.get("output_path", sprite_frames_path(sprite_set_id)))
	var frames := SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")

	var clips: Dictionary = sprite_set.get("animation_clips", {})
	var sequences: Dictionary = sprite_set.get("frame_sequences", {})
	var clip_keys := clips.keys()
	clip_keys.sort()
	for clip_key in clip_keys:
		var clip: Dictionary = clips[clip_key]
		var clip_id := str(clip.get("clip_id", clip_key))
		var sequence_ref := str(clip.get("frame_sequence_ref", ""))
		if not sequences.has(sequence_ref):
			errors.append(_error("MISSING_FRAME_SEQUENCE", "%s:%s" % [clip_id, sequence_ref]))
			continue
		frames.add_animation(clip_id)
		frames.set_animation_loop(clip_id, bool(clip.get("loop", false)))
		frames.set_animation_speed(clip_id, float(clip.get("fps", DEFAULT_ANIMATION_FPS)))
		var sequence: Array = sequences[sequence_ref]
		var target_frame_count := _target_frame_count(clip_id, sequence, options)
		for frame_index in target_frame_count:
			var slot := str(sequence[frame_index]) if frame_index < sequence.size() else _slot_uri(SLOT_STATE_EMPTY, sprite_set_id, clip_id, frame_index)
			var resolved := _texture_for_slot(slot, {
				"sprite_set_id": sprite_set_id,
				"clip_id": clip_id,
				"frame_index": frame_index,
			})
			warnings.append_array(resolved["warnings"])
			errors.append_array(resolved["errors"])
			var texture: Texture2D = resolved.get("texture", null)
			if texture == null:
				texture = _generated_placeholder_texture(SLOT_STATE_INVALID)
			frames.add_frame(clip_id, texture)

	if not errors.is_empty():
		return _result(false, output_path, warnings, errors, frames)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_path.get_base_dir()))
	var save_error := ResourceSaver.save(frames, output_path)
	if save_error != OK:
		errors.append(_error(ERROR_RESOURCE_SAVE_FAILED, "%s:%d" % [output_path, save_error]))
		return _result(false, output_path, warnings, errors, frames)

	var validation := validate_generated(sprite_set, output_path, options)
	warnings.append_array(validation["warnings"])
	errors.append_array(validation["errors"])
	return _result(errors.is_empty(), output_path, warnings, errors, frames)


static func load_generated(sprite_set_id: String) -> SpriteFrames:
	var resource := ResourceLoader.load(sprite_frames_path(sprite_set_id), "SpriteFrames", ResourceLoader.CACHE_MODE_IGNORE)
	if resource is SpriteFrames:
		return resource
	return null


static func validate_generated(sprite_set: Dictionary, path: String = "", options: Dictionary = {}) -> Dictionary:
	var warnings: Array = []
	var errors: Array = []
	var sprite_set_id := str(sprite_set.get("sprite_set_id", ""))
	var resource_path := path if not path.is_empty() else sprite_frames_path(sprite_set_id)
	var resource := ResourceLoader.load(resource_path, "SpriteFrames", ResourceLoader.CACHE_MODE_IGNORE)
	if not resource is SpriteFrames:
		errors.append(_error(ERROR_INVALID_SPRITEFRAMES_RESOURCE, resource_path))
		return {"warnings": warnings, "errors": errors}
	var frames: SpriteFrames = resource
	var clips: Dictionary = sprite_set.get("animation_clips", {})
	var sequences: Dictionary = sprite_set.get("frame_sequences", {})
	for clip_key in clips.keys():
		var clip: Dictionary = clips[clip_key]
		var clip_id := str(clip.get("clip_id", clip_key))
		var sequence_ref := str(clip.get("frame_sequence_ref", ""))
		if not frames.has_animation(clip_id):
			errors.append(_error(ERROR_SPRITEFRAMES_MISSING_ANIMATION, clip_id))
			continue
		var expected_count := 0
		if sequences.has(sequence_ref):
			expected_count = _target_frame_count(clip_id, sequences[sequence_ref], options)
		var actual_count := frames.get_frame_count(clip_id)
		if actual_count != expected_count:
			errors.append(_error(ERROR_SPRITEFRAMES_WRONG_FRAME_COUNT, "%s:%d!=%d" % [clip_id, actual_count, expected_count]))
		if frames.get_animation_loop(clip_id) != bool(clip.get("loop", false)):
			errors.append(_error(ERROR_SPRITEFRAMES_WRONG_LOOP_FLAG, clip_id))
	return {"warnings": warnings, "errors": errors}


static func _texture_for_slot(slot: String, context: Dictionary) -> Dictionary:
	var warnings: Array = []
	var errors: Array = []
	var state := frame_slot_state(slot)
	for warning in validate_frame_slot(slot):
		warnings.append(warning)

	match state:
		SLOT_STATE_TEXTURE:
			var texture := _load_texture(slot)
			if texture is Texture2D:
				return {"texture": texture, "warnings": warnings, "errors": errors}
			warnings.append(_warning(WARNING_UNLOADABLE_FRAME_TEXTURE, slot))
			return {"texture": _placeholder_texture(SLOT_STATE_MISSING), "warnings": warnings, "errors": errors}
		SLOT_STATE_EMPTY:
			return {"texture": _placeholder_texture(SLOT_STATE_EMPTY), "warnings": warnings, "errors": errors}
		SLOT_STATE_MISSING:
			return {"texture": _placeholder_texture(SLOT_STATE_MISSING), "warnings": warnings, "errors": errors}
		SLOT_STATE_PLACEHOLDER:
			return {"texture": _placeholder_texture(SLOT_STATE_PLACEHOLDER), "warnings": warnings, "errors": errors}

	errors.append(_error(ERROR_INVALID_FRAME_SLOT_URI, "%s:%s:%s" % [context.get("clip_id", ""), context.get("frame_index", 0), slot]))
	return {"texture": _placeholder_texture(SLOT_STATE_INVALID), "warnings": warnings, "errors": errors}


static func _placeholder_texture(state: String) -> Texture2D:
	var path := PLACEHOLDER_ROOT.path_join("%s_s64.png" % state)
	var texture := _load_texture(path)
	if texture is Texture2D:
		return texture
	return _generated_placeholder_texture(state)


static func _load_texture(path: String) -> Texture2D:
	if path.begins_with("res://") or path.begins_with("user://"):
		if not FileAccess.file_exists(path):
			return null
		if path.begins_with("res://"):
			var imported_resource := ResourceLoader.load(path, "Texture2D", ResourceLoader.CACHE_MODE_IGNORE)
			if imported_resource is Texture2D:
				return imported_resource
		var image := Image.new()
		if path.get_extension().to_lower() == "png" and image.load(ProjectSettings.globalize_path(path)) == OK:
			return ImageTexture.create_from_image(image)
	if not ResourceLoader.exists(path):
		return null
	var resource := ResourceLoader.load(path, "Texture2D", ResourceLoader.CACHE_MODE_IGNORE)
	if resource is Texture2D:
		return resource
	return null


static func _target_frame_count(clip_id: String, sequence: Array, options: Dictionary) -> int:
	var target := sequence.size()
	var moves: Dictionary = options.get("moves", {})
	if moves.has(clip_id):
		target = maxi(target, int(moves[clip_id].get("frame_count", target)))
	return target


static func _slot_uri(state: String, sprite_set_id: String, clip_id: String, frame_index: int) -> String:
	return "%s://%s/%s/frame_%03d.png" % [state, sprite_set_id, clip_id, frame_index]


static func _generated_placeholder_texture(state: String) -> Texture2D:
	var color := Color(0.18, 0.2, 0.24, 0.0)
	if state == SLOT_STATE_MISSING:
		color = Color(0.9, 0.1, 0.08, 1.0)
	elif state == SLOT_STATE_PLACEHOLDER:
		color = Color(0.95, 0.68, 0.18, 1.0)
	elif state == SLOT_STATE_INVALID:
		color = Color(0.8, 0.0, 0.8, 1.0)
	var image := Image.create_empty(64, 64, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)


static func _result(ok: bool, path: String, warnings: Array, errors: Array, frames: SpriteFrames) -> Dictionary:
	return {
		"ok": ok,
		"path": path,
		"warnings": warnings,
		"errors": errors,
		"animation_names": frames.get_animation_names() if frames != null else [],
	}


static func _warning(code: String, detail: String) -> Dictionary:
	return {"severity": "warning", "code": code, "detail": detail}


static func _error(code: String, detail: String) -> Dictionary:
	return {"severity": "error", "code": code, "detail": detail}
