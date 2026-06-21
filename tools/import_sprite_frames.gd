extends SceneTree

const MANIFEST_ROOT := "res://sprites/chibi_64"
const OUTPUT_ROOT := "res://resources/sprite_frames"
const ANIMATION_SEPARATOR := "__"
const VISUAL_SPRITE_INTENT := Vector2i(64, 64)
const GODOT_FRAME_SIZE := Vector2i(80, 80)
const DEBUG_CELL_SIZE := Vector2i(80, 80)

func _initialize() -> void:
	var result := _run()
	quit(result)

func _run() -> int:
	var output_dir := DirAccess.open("res://")
	if output_dir == null:
		push_error("Cannot open project root.")
		return 1
	output_dir.make_dir_recursive("resources/sprite_frames")

	var root := DirAccess.open(MANIFEST_ROOT)
	if root == null:
		push_error("Cannot open %s" % MANIFEST_ROOT)
		return 1

	var actor_ids := root.get_directories()
	actor_ids.sort()
	var imported_count := 0

	for actor_id in actor_ids:
		var manifest_path := "%s/%s/manifest.json" % [MANIFEST_ROOT, actor_id]
		if not FileAccess.file_exists(manifest_path):
			push_warning("Skipping %s: missing manifest.json" % actor_id)
			continue

		var manifest := _read_json(manifest_path)
		if manifest.is_empty() or not manifest.has("actions"):
			push_warning("Skipping %s: manifest has no actions" % actor_id)
			continue

		var sprite_frames := SpriteFrames.new()
		sprite_frames.remove_animation(&"default")

		var action_names := {}
		var source_size := Vector2i.ZERO

		for entry in manifest["actions"]:
			var action := String(entry.get("action", ""))
			var direction := _normalize_direction(String(entry.get("direction", "")))
			var frames: Array = entry.get("frames", [])
			if action.is_empty() or direction.is_empty() or frames.is_empty():
				push_warning("Skipping incomplete action entry in %s" % actor_id)
				continue

			var animation_name := "%s%s%s" % [action, ANIMATION_SEPARATOR, direction]
			sprite_frames.add_animation(animation_name)
			sprite_frames.set_animation_speed(animation_name, _fps_for_entry(entry))
			sprite_frames.set_animation_loop(animation_name, _should_loop_action(action))

			for frame_path in frames:
				var texture := load("res://%s" % String(frame_path))
				if texture == null:
					push_warning("Missing texture: %s" % frame_path)
					continue
				var atlas := _centered_atlas_texture(texture)
				sprite_frames.add_frame(animation_name, atlas)

			action_names[action] = true
			if source_size == Vector2i.ZERO and entry.has("dimensions") and entry["dimensions"].size() > 0:
				var first_dimension: Dictionary = entry["dimensions"][0]
				source_size = Vector2i(int(first_dimension.get("width", 0)), int(first_dimension.get("height", 0)))

		sprite_frames.set_meta("actor_id", actor_id)
		sprite_frames.set_meta("visual_sprite_intent", VISUAL_SPRITE_INTENT)
		sprite_frames.set_meta("godot_frame_size", GODOT_FRAME_SIZE)
		sprite_frames.set_meta("debug_cell_size", DEBUG_CELL_SIZE)
		sprite_frames.set_meta("source_png_size", source_size)
		sprite_frames.set_meta("animation_separator", ANIMATION_SEPARATOR)
		sprite_frames.set_meta("action_names", _sorted_keys(action_names))

		var save_path := "%s/%s.tres" % [OUTPUT_ROOT, actor_id]
		var error := ResourceSaver.save(sprite_frames, save_path)
		if error != OK:
			push_error("Failed saving %s: %s" % [save_path, error])
			return 1

		imported_count += 1
		print("Imported %s -> %s (%d animations)" % [actor_id, save_path, sprite_frames.get_animation_names().size()])

	if imported_count == 0:
		push_error("No sprite actors imported.")
		return 1

	print("Imported %d sprite actors." % imported_count)
	return 0

func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Invalid JSON: %s" % path)
		return {}
	return parsed

func _fps_for_entry(entry: Dictionary) -> float:
	var duration_ms := float(entry.get("duration_ms", 167))
	if duration_ms <= 0.0:
		return 12.0
	return 1000.0 / duration_ms

func _should_loop_action(action: String) -> bool:
	if action.ends_with("_loop") or action == "idle_breath" or action == "fight_idle":
		return true
	return false

func _normalize_direction(direction: String) -> String:
	return direction.replace("_", "")

func _centered_atlas_texture(texture: Texture2D) -> AtlasTexture:
	var source_size := texture.get_size()
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = Rect2(
		floor((source_size.x - GODOT_FRAME_SIZE.x) * 0.5),
		floor((source_size.y - GODOT_FRAME_SIZE.y) * 0.5),
		GODOT_FRAME_SIZE.x,
		GODOT_FRAME_SIZE.y
	)
	return atlas

func _sorted_keys(values: Dictionary) -> PackedStringArray:
	var keys := PackedStringArray()
	for key in values.keys():
		keys.append(String(key))
	keys.sort()
	return keys
