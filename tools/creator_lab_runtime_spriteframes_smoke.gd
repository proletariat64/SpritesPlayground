extends SceneTree

const PreviewScript := preload("res://godot/scripts/creator_lab_action_preview.gd")
const Coverage := preload("res://godot/scripts/creator_lab_action_coverage.gd")
const DataStore := preload("res://godot/scripts/prd_v0_3_data_store.gd")
const Generator := preload("res://godot/scripts/spriteframes_generator.gd")

const TEMPLATE_ID := "skeleton_default_unarmed_s64"
const MOVE_ID := "basic_punch"
const USER_FRAME_PATH := "user://creator_lab_runtime_spriteframes_smoke.png"
const EXPECTED_SIZE := Vector2i(7, 5)
const EXPECTED_COLOR := Color8(31, 199, 79, 255)

var _errors: Array = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var bundle: Dictionary = DataStore.load_runtime_bundle(TEMPLATE_ID)
	var sprite_set: Dictionary = bundle.get("sprite_set", {}).duplicate(true)
	var clip: Dictionary = sprite_set.get("animation_clips", {}).get(MOVE_ID, {})
	var sequence_ref := str(clip.get("frame_sequence_ref", ""))
	_expect(not sequence_ref.is_empty(), "fixture exposes the basic_punch frame sequence")
	if sequence_ref.is_empty():
		_finish(null)
		return

	var image := Image.create_empty(EXPECTED_SIZE.x, EXPECTED_SIZE.y, false, Image.FORMAT_RGBA8)
	image.fill(EXPECTED_COLOR)
	_expect(image.save_png(USER_FRAME_PATH) == OK, "writes the unsaved Creator Lab frame to user://")
	sprite_set["frame_sequences"][sequence_ref][0] = USER_FRAME_PATH

	var generated_path := Generator.sprite_frames_path(str(sprite_set.get("sprite_set_id", "")))
	var generated_before := FileAccess.get_file_as_bytes(generated_path)
	var row := _coverage_row_for(MOVE_ID, bundle.get("template", {}), sprite_set, bundle.get("moves", {}))

	var preview: Control = PreviewScript.new()
	root.add_child(preview)
	await process_frame
	preview.set_preview_data(row, bundle.get("template", {}), sprite_set, bundle.get("moves", {}))
	await process_frame

	var real_sprite: Node = preview.real_sprite()
	_expect(real_sprite != null, "Preview exposes its real CombatCharacter")
	var animated_sprite: AnimatedSprite2D = real_sprite.animated_sprite if real_sprite != null else null
	_expect(animated_sprite != null, "real Preview owns an AnimatedSprite2D")
	if animated_sprite != null:
		_expect(str(animated_sprite.animation) == MOVE_ID, "real Preview starts the selected basic_punch animation")
		var frames: SpriteFrames = animated_sprite.sprite_frames
		_expect(frames != null, "real Preview has runtime SpriteFrames")
		if frames != null and frames.has_animation(MOVE_ID):
			var texture := frames.get_frame_texture(MOVE_ID, int(animated_sprite.frame))
			_expect(texture != null, "real Preview exposes its current runtime texture")
			if texture != null:
				var runtime_image: Image = texture.get_image()
				_expect(runtime_image.get_size() == EXPECTED_SIZE, "current real Preview texture uses the unsaved user:// frame dimensions")
				_expect(runtime_image.get_pixel(0, 0).is_equal_approx(EXPECTED_COLOR), "current real Preview texture uses the unsaved user:// frame color")
		else:
			_expect(false, "real Preview SpriteFrames contains basic_punch")

	_expect(
		FileAccess.get_file_as_bytes(generated_path) == generated_before,
		"Preview applies runtime SpriteFrames without writing the generated res:// resource"
	)
	_finish(preview)


func _coverage_row_for(action_id: String, template: Dictionary, sprite_set: Dictionary, moves: Dictionary) -> Dictionary:
	var result: Dictionary = Coverage.analyze(template, sprite_set, moves)
	for row in result.get("rows", []):
		if str(row.get("action_id", "")) == action_id:
			return row
	return {}


func _finish(preview: Control) -> void:
	if preview != null:
		preview.free()
	if FileAccess.file_exists(USER_FRAME_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(USER_FRAME_PATH))
	if _errors.is_empty():
		print("creator_lab_runtime_spriteframes_smoke=PASS")
		quit(0)
	else:
		for error in _errors:
			push_error(str(error))
		print("creator_lab_runtime_spriteframes_smoke=FAIL")
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
