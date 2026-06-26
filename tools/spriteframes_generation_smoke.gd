extends SceneTree

const DataStore := preload("res://godot/scripts/prd_v0_3_data_store.gd")
const Generator := preload("res://godot/scripts/spriteframes_generator.gd")

const SKELETON_ID := "skeleton_default_unarmed_s64"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var errors: Array = []
	var sprite_set := DataStore.load_sprite_set(SKELETON_ID)
	var moves := {"basic_punch": DataStore.load_move("basic_punch")}
	errors.append_array(_expect(not sprite_set.is_empty(), "loads skeleton sprite set"))

	var result: Dictionary = Generator.generate(sprite_set, {"moves": moves})
	errors.append_array(_expect(bool(result.get("ok", false)), "generates skeleton SpriteFrames"))
	errors.append_array(_expect(str(result.get("path", "")) == Generator.sprite_frames_path(SKELETON_ID), "uses skeleton generated path"))
	errors.append_array(_expect(FileAccess.file_exists(Generator.sprite_frames_path(SKELETON_ID)), "writes skeleton .tres"))

	var frames := Generator.load_generated(SKELETON_ID)
	errors.append_array(_expect(frames != null, "loads generated skeleton SpriteFrames"))
	if frames != null:
		errors.append_array(_expect(_has_animation(frames, "idle"), "skeleton has idle animation"))
		errors.append_array(_expect(_has_animation(frames, "walk"), "skeleton has walk animation"))
		errors.append_array(_expect(_has_animation(frames, "run"), "skeleton has run animation"))
		errors.append_array(_expect(_has_animation(frames, "basic_punch"), "skeleton has basic_punch animation"))
		errors.append_array(_expect(_has_animation(frames, "hurt"), "skeleton has hurt animation"))
		errors.append_array(_expect(frames.get_frame_count("idle") == 6, "skeleton idle frame count"))
		errors.append_array(_expect(frames.get_frame_count("walk") == 6, "skeleton walk frame count"))
		errors.append_array(_expect(frames.get_frame_count("run") == 6, "skeleton run frame count"))
		errors.append_array(_expect(frames.get_frame_count("basic_punch") == 8, "skeleton basic_punch timing frame count"))
		errors.append_array(_expect(frames.get_frame_count("hurt") == 2, "skeleton hurt frame count"))
		errors.append_array(_expect(frames.get_animation_loop("idle"), "skeleton idle loops"))
		errors.append_array(_expect(frames.get_animation_loop("walk"), "skeleton walk loops"))
		errors.append_array(_expect(frames.get_animation_loop("run"), "skeleton run loops"))
		errors.append_array(_expect(not frames.get_animation_loop("basic_punch"), "skeleton basic_punch does not loop"))
		errors.append_array(_expect(not frames.get_animation_loop("hurt"), "skeleton hurt does not loop"))
		errors.append_array(_expect(frames.get_frame_texture("idle", 0) != null, "skeleton idle texture exists"))

	errors.append_array(_run_missing_real_frame_smoke(sprite_set))
	errors.append_array(_run_user_frame_smoke(sprite_set))
	errors.append_array(_run_sparse_timeline_smoke(sprite_set))
	errors.append_array(_run_invalid_slot_smoke(sprite_set))

	_remove_if_exists("res://godot/resources/sprite_frames/__smoke_missing.tres")
	_remove_if_exists("res://godot/resources/sprite_frames/__smoke_user.tres")
	_remove_if_exists("res://godot/resources/sprite_frames/__smoke_sparse.tres")
	_remove_if_exists("res://godot/resources/sprite_frames/__smoke_invalid.tres")
	_remove_if_exists("user://spriteframes_user_slot.png")

	if errors.is_empty():
		print("spriteframes_generation_smoke=PASS")
		quit(0)
	else:
		for error in errors:
			push_error(str(error))
		print("spriteframes_generation_smoke=FAIL")
		quit(1)


func _run_missing_real_frame_smoke(source_sprite_set: Dictionary) -> Array:
	var errors: Array = []
	var sprite_set := _one_clip_sprite_set(source_sprite_set, "idle", "__smoke_missing")
	sprite_set["frame_sequences"]["idle"][0] = "res://missing/spriteframes_generation_smoke.png"
	var result: Dictionary = Generator.generate(sprite_set, {"output_path": "res://godot/resources/sprite_frames/__smoke_missing.tres"})
	errors.append_array(_expect(bool(result.get("ok", false)), "missing real frame still generates"))
	errors.append_array(_expect(_has_warning(result, Generator.WARNING_UNLOADABLE_FRAME_TEXTURE), "missing real frame warns"))
	var frames := ResourceLoader.load("res://godot/resources/sprite_frames/__smoke_missing.tres")
	errors.append_array(_expect(frames is SpriteFrames, "missing smoke resource loads"))
	if frames is SpriteFrames:
		errors.append_array(_expect(frames.get_frame_count("idle") == 6, "missing smoke preserves frame count"))
		errors.append_array(_expect(frames.get_frame_texture("idle", 0) != null, "missing smoke uses placeholder texture"))
	return errors


func _run_user_frame_smoke(source_sprite_set: Dictionary) -> Array:
	var errors: Array = []
	var image := Image.create_empty(4, 4, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.2, 0.8, 0.4, 1.0))
	errors.append_array(_expect(image.save_png("user://spriteframes_user_slot.png") == OK, "writes user frame texture"))
	var sprite_set := _one_clip_sprite_set(source_sprite_set, "idle", "__smoke_user")
	sprite_set["frame_sequences"]["idle"][0] = "user://spriteframes_user_slot.png"
	var result: Dictionary = Generator.generate(sprite_set, {"output_path": "res://godot/resources/sprite_frames/__smoke_user.tres"})
	errors.append_array(_expect(bool(result.get("ok", false)), "user frame generates"))
	errors.append_array(_expect(_has_warning(result, Generator.WARNING_LOCAL_ONLY_FRAME_TEXTURE), "user frame warns local-only"))
	return errors


func _run_sparse_timeline_smoke(source_sprite_set: Dictionary) -> Array:
	var errors: Array = []
	var sprite_set := _one_clip_sprite_set(source_sprite_set, "basic_punch", "__smoke_sparse")
	var sequence: Array = source_sprite_set["frame_sequences"]["basic_punch"]
	sprite_set["frame_sequences"]["basic_punch"] = [
		sequence[0],
		"empty://__smoke_sparse/basic_punch/frame_001.png",
		"missing://__smoke_sparse/basic_punch/frame_002.png",
		sequence[3],
		"placeholder://__smoke_sparse/basic_punch/frame_004.png",
		"empty://__smoke_sparse/basic_punch/frame_005.png",
		"missing://__smoke_sparse/basic_punch/frame_006.png",
		sequence[5],
	]
	var result: Dictionary = Generator.generate(sprite_set, {"output_path": "res://godot/resources/sprite_frames/__smoke_sparse.tres"})
	errors.append_array(_expect(bool(result.get("ok", false)), "sparse timeline generates"))
	errors.append_array(_expect(_has_warning(result, Generator.WARNING_EMPTY_FRAME_SLOT), "sparse timeline warns empty"))
	errors.append_array(_expect(_has_warning(result, Generator.WARNING_MISSING_FRAME_SLOT), "sparse timeline warns missing"))
	errors.append_array(_expect(_has_warning(result, Generator.WARNING_PLACEHOLDER_FRAME_SLOT), "sparse timeline warns placeholder"))
	var frames := ResourceLoader.load("res://godot/resources/sprite_frames/__smoke_sparse.tres")
	errors.append_array(_expect(frames is SpriteFrames, "sparse resource loads"))
	if frames is SpriteFrames:
		errors.append_array(_expect(frames.get_frame_count("basic_punch") == 8, "sparse timeline preserves eight timing frames"))
	return errors


func _run_invalid_slot_smoke(source_sprite_set: Dictionary) -> Array:
	var errors: Array = []
	var sprite_set := _one_clip_sprite_set(source_sprite_set, "idle", "__smoke_invalid")
	sprite_set["frame_sequences"]["idle"][0] = "bogus://bad"
	var result: Dictionary = Generator.generate(sprite_set, {"output_path": "res://godot/resources/sprite_frames/__smoke_invalid.tres"})
	errors.append_array(_expect(not bool(result.get("ok", true)), "invalid slot fails generation"))
	errors.append_array(_expect(_has_error(result, Generator.ERROR_INVALID_FRAME_SLOT_URI), "invalid slot reports error"))
	return errors


func _one_clip_sprite_set(source_sprite_set: Dictionary, clip_id: String, next_id: String) -> Dictionary:
	var clip: Dictionary = source_sprite_set["animation_clips"][clip_id].duplicate(true)
	var sequence_ref := str(clip["frame_sequence_ref"])
	return {
		"schema_version": "0.3",
		"sprite_set_id": next_id,
		"animation_clips": {clip_id: clip},
		"frame_sequences": {sequence_ref: source_sprite_set["frame_sequences"][sequence_ref].duplicate(true)},
		"required_moves_mapping": {clip_id: clip_id},
	}


func _has_animation(frames: SpriteFrames, animation_name: String) -> bool:
	for name in frames.get_animation_names():
		if str(name) == animation_name:
			return true
	return false


func _has_warning(result: Dictionary, code: String) -> bool:
	return _has_diagnostic(result.get("warnings", []), code)


func _has_error(result: Dictionary, code: String) -> bool:
	return _has_diagnostic(result.get("errors", []), code)


func _has_diagnostic(diagnostics: Array, code: String) -> bool:
	for diagnostic in diagnostics:
		if typeof(diagnostic) == TYPE_DICTIONARY and str(diagnostic.get("code", "")) == code:
			return true
	return false


func _remove_if_exists(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _expect(condition: bool, message: String) -> Array:
	if condition:
		return []
	return [message]
