extends SceneTree

const MANIFEST_ROOT := "res://sprites/chibi_64"
const GODOT_FRAME_SIZE := Vector2i(80, 80)
const SpriteCatalogRef := preload("res://scripts/SpriteCatalog.gd")
const SpritesPlaygroundActorRef := preload("res://scripts/SpritesPlaygroundActor.gd")
const ChibiCharacterScript := preload("res://scripts/ChibiCharacter2D.gd")
const DevStreetStageScript := preload("res://scripts/DevStreetStage.gd")
const CHARACTER_SCENES := {
	"dad_chibi_64": "res://scenes/characters/dad_chibi_64.tscn",
	"mama_chibi_64": "res://scenes/characters/mama_chibi_64.tscn",
	"miduo_chibi_64": "res://scenes/characters/miduo_chibi_64.tscn",
}

func _initialize() -> void:
	var result: int = await _run()
	quit(result)

func _run() -> int:
	if not _verify_project_settings():
		return 1

	var expected := {
		"dad_chibi_64": 119,
		"mama_chibi_64": 119,
		"miduo_chibi_64": 119,
	}

	for actor_id in expected.keys():
		var path := "res://resources/sprite_frames/%s.tres" % actor_id
		var frames := load(path)
		if not frames is SpriteFrames:
			push_error("Expected SpriteFrames at %s" % path)
			return 1
		var animation_count: int = frames.get_animation_names().size()
		if animation_count != int(expected[actor_id]):
			push_error("%s has %d animations, expected %d" % [actor_id, animation_count, expected[actor_id]])
			return 1
		if not frames.has_animation(&"idle_breath__east"):
			push_error("%s is missing idle_breath__east" % actor_id)
			return 1
		if frames.get_meta("actor_id", "") != actor_id:
			push_error("%s has wrong actor_id metadata" % actor_id)
			return 1
		if frames.get_meta("godot_frame_size", Vector2i.ZERO) != GODOT_FRAME_SIZE:
			push_error("%s has wrong Godot frame size metadata" % actor_id)
			return 1
		if frames.get_meta("debug_cell_size", Vector2i.ZERO) != GODOT_FRAME_SIZE:
			push_error("%s has wrong debug cell size metadata" % actor_id)
			return 1
		var manifest := _read_json("%s/%s/manifest.json" % [MANIFEST_ROOT, actor_id])
		for entry in manifest.get("actions", []):
			var animation_name := "%s__%s" % [entry["action"], _normalize_direction(String(entry["direction"]))]
			if not frames.has_animation(animation_name):
				push_error("%s is missing %s" % [actor_id, animation_name])
				return 1
			if frames.get_frame_count(animation_name) != int(entry["frame_count"]):
				push_error("%s has wrong frame count for %s" % [actor_id, animation_name])
				return 1
			for frame_index in frames.get_frame_count(animation_name):
				var texture: Texture2D = frames.get_frame_texture(animation_name, frame_index)
				if not texture is AtlasTexture:
					push_error("%s frame %s[%d] is not an AtlasTexture" % [actor_id, animation_name, frame_index])
					return 1
				if Vector2i(texture.region.size) != GODOT_FRAME_SIZE:
					push_error("%s frame %s[%d] has region %s" % [actor_id, animation_name, frame_index, str(texture.region)])
					return 1

	for scene_path in [
		"res://scenes/MainMenu.tscn",
		"res://scenes/SpritesPlayground.tscn",
		"res://scenes/stages/dev_street_stage.tscn",
	]:
		var packed := load(scene_path)
		if not packed is PackedScene:
			push_error("Cannot load scene %s" % scene_path)
			return 1
		var node: Node = packed.instantiate()
		if node == null:
			push_error("Cannot instantiate scene %s" % scene_path)
			return 1
		node.queue_free()

	if not _verify_main_menu():
		return 1

	var street_result := await _verify_street_stage()
	if street_result != OK:
		return 1

	for actor_id in CHARACTER_SCENES.keys():
		var result := await _verify_character_scene(actor_id, CHARACTER_SCENES[actor_id])
		if result != OK:
			return 1

	var playground_scene := load("res://scenes/SpritesPlayground.tscn") as PackedScene
	var playground := playground_scene.instantiate()
	get_root().add_child(playground)
	await process_frame
	await process_frame

	if playground.current_actor_id != "dad_chibi_64":
		push_error("Expected first actor to be dad_chibi_64, got %s" % playground.current_actor_id)
		return 1
	if playground.current_action != "idle_breath" or playground.current_direction != "east":
		push_error("Unexpected default state: %s %s" % [playground.current_action, playground.current_direction])
		return 1

	var exact := SpriteCatalogRef.resolve_animation(playground.current_frames, "walk_loop", "southwest")
	if exact.get("animation") != &"walk_loop__southwest" or bool(exact.get("flip_h", false)):
		push_error("Exact southwest resolution failed: %s" % str(exact))
		return 1

	var fallback := SpriteCatalogRef.resolve_animation(playground.current_frames, "jab", "northwest")
	if fallback.get("animation") != &"jab__west" or bool(fallback.get("flip_h", true)):
		push_error("West-like fallback resolution failed: %s" % str(fallback))
		return 1

	playground.preview_actor.play_state("jab", "east")
	if playground.preview_actor.sprite_frames.get_animation_loop(&"jab__east"):
		push_error("jab__east should remain a non-loop SpriteFrames animation")
		return 1
	playground.preview_actor.stop()
	playground.preview_actor._restart_finished_animation()
	if not playground.preview_actor.is_playing():
		push_error("SpritesPlayground preview did not restart a finished one-shot animation")
		return 1

	playground.queue_free()
	print("SpritesPlayground smoke test passed.")
	return 0

func _verify_main_menu() -> bool:
	var packed := load("res://scenes/MainMenu.tscn") as PackedScene
	var menu := packed.instantiate()
	var open_button := menu.get_node_or_null("%OpenButton")
	var street_button := menu.get_node_or_null("%OpenStreetStageButton")
	menu.queue_free()

	if not open_button is Button:
		push_error("MainMenu is missing OpenButton")
		return false
	if not street_button is Button:
		push_error("MainMenu is missing OpenStreetStageButton")
		return false
	return true

func _verify_street_stage() -> Error:
	var packed := load("res://scenes/stages/dev_street_stage.tscn")
	if not packed is PackedScene:
		push_error("Cannot load street stage")
		return FAILED

	var stage: Node = packed.instantiate()
	if not stage is Node2D:
		push_error("Street stage root is not Node2D")
		return FAILED
	if stage.get_script() != DevStreetStageScript:
		push_error("Street stage root does not use DevStreetStage")
		return FAILED
	if int(stage.route_width) != 2560 or int(stage.route_height) != 360:
		push_error("Street stage route is %sx%s, expected 2560x360" % [stage.route_width, stage.route_height])
		return FAILED

	var camera := stage.get_node_or_null("%WalkthroughCamera")
	if not camera is Camera2D:
		push_error("Street stage is missing WalkthroughCamera")
		return FAILED
	if not camera.enabled:
		push_error("Street stage camera is not enabled")
		return FAILED

	get_root().add_child(stage)
	await process_frame
	await process_frame

	if not stage.has_node("StageArt"):
		push_error("Street stage did not build StageArt")
		return FAILED
	if int(stage.get_meta("route_width", 0)) != 2560 or int(stage.get_meta("route_height", 0)) != 360:
		push_error("Street stage route metadata is incorrect")
		return FAILED
	if camera.position != Vector2(320, 180):
		push_error("Street stage camera did not start at the school gate: %s" % str(camera.position))
		return FAILED
	if not camera.is_current():
		push_error("Street stage camera is not current")
		return FAILED
	if camera.limit_right != 2560 or camera.limit_bottom != 360:
		push_error("Street stage camera limits are incorrect")
		return FAILED
	if _has_actor_nodes(stage):
		push_error("Street stage should not instantiate actor or character nodes")
		return FAILED

	stage.queue_free()
	return OK

func _has_actor_nodes(node: Node) -> bool:
	if node is CharacterBody2D or node is AnimatedSprite2D:
		return true
	if node.scene_file_path.begins_with("res://scenes/characters/"):
		return true
	if node.get_script() == SpritesPlaygroundActorRef or node.get_script() == ChibiCharacterScript:
		return true
	for child in node.get_children():
		if _has_actor_nodes(child):
			return true
	return false

func _verify_project_settings() -> bool:
	var expected := {
		"display/window/size/viewport_width": 640,
		"display/window/size/viewport_height": 360,
		"display/window/size/window_width_override": 1280,
		"display/window/size/window_height_override": 720,
		"display/window/size/mode": 3,
		"display/window/stretch/mode": "viewport",
		"display/window/stretch/aspect": "keep",
		"rendering/textures/canvas_textures/default_texture_filter": 0,
	}
	for key in expected.keys():
		var actual = ProjectSettings.get_setting(key)
		if actual != expected[key]:
			push_error("Project setting %s is %s, expected %s" % [key, str(actual), str(expected[key])])
			return false
	if not ProjectSettings.has_setting("autoload/WindowModeController"):
		push_error("Missing WindowModeController autoload")
		return false
	return true

func _verify_character_scene(actor_id: String, scene_path: String) -> Error:
	var packed := load(scene_path)
	if not packed is PackedScene:
		push_error("Cannot load character scene %s" % scene_path)
		return FAILED

	var node: Node = packed.instantiate()
	if not node is CharacterBody2D:
		push_error("%s root is not CharacterBody2D" % scene_path)
		return FAILED

	var character: Variant = node
	if node.get_script() != ChibiCharacterScript:
		push_error("%s root does not use ChibiCharacter2D" % scene_path)
		return FAILED

	var animated_sprite: Node = node.get_node_or_null("AnimatedSprite2D")
	if not animated_sprite is AnimatedSprite2D:
		push_error("%s is missing AnimatedSprite2D" % scene_path)
		return FAILED
	if animated_sprite.sprite_frames == null:
		push_error("%s AnimatedSprite2D has no SpriteFrames" % scene_path)
		return FAILED
	if animated_sprite.sprite_frames.get_meta("actor_id", "") != actor_id:
		push_error("%s SpriteFrames actor mismatch" % scene_path)
		return FAILED

	var collision_shape: Node = node.get_node_or_null("CollisionShape2D")
	if not collision_shape is CollisionShape2D:
		push_error("%s is missing CollisionShape2D" % scene_path)
		return FAILED
	if not collision_shape.shape is RectangleShape2D:
		push_error("%s collision is not RectangleShape2D" % scene_path)
		return FAILED
	if Vector2i(collision_shape.shape.size) != GODOT_FRAME_SIZE:
		push_error("%s collision shape is not %s" % [scene_path, str(GODOT_FRAME_SIZE)])
		return FAILED

	get_root().add_child(node)
	await process_frame

	if character.actor_id != actor_id:
		push_error("%s actor_id is %s" % [scene_path, character.actor_id])
		return FAILED
	if character.action != "idle_breath" or character.direction != "east":
		push_error("%s default state is %s %s" % [scene_path, character.action, character.direction])
		return FAILED
	if character.resolved_animation != &"idle_breath__east":
		push_error("%s default animation is %s" % [scene_path, character.resolved_animation])
		return FAILED

	var actions: PackedStringArray = character.get_available_actions()
	var frames_actions: PackedStringArray = SpriteCatalogRef.list_actions(animated_sprite.sprite_frames)
	if actions.size() != 34:
		push_error("%s has %d actions, expected 34" % [scene_path, actions.size()])
		return FAILED
	for action in frames_actions:
		if not actions.has(action):
			push_error("%s is missing action %s from character API" % [scene_path, action])
			return FAILED
		character.play_state(action, "east")
		if character.action != action:
			push_error("%s did not accept action %s" % [scene_path, action])
			return FAILED

	character.play_state("walk_loop", "southwest")
	if character.resolved_animation != &"walk_loop__southwest":
		push_error("%s exact direction resolution failed" % scene_path)
		return FAILED

	character.play_state("jab", "northwest")
	if character.resolved_animation != &"jab__west":
		push_error("%s fallback direction resolution failed" % scene_path)
		return FAILED

	node.queue_free()
	return OK

func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Cannot open JSON: %s" % path)
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Invalid JSON: %s" % path)
		return {}
	return parsed

func _normalize_direction(direction: String) -> String:
	return direction.replace("_", "")
