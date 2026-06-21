extends AnimatedSprite2D
class_name SpritesPlaygroundActor

const SpriteCatalogRef := preload("res://scripts/SpriteCatalog.gd")

var actor_id := ""
var action := ""
var direction := "east"
var resolved_direction := "east"
var visual_sprite_intent := Vector2i(64, 64)
var godot_frame_size := Vector2i(80, 80)
var source_png_size := Vector2i.ZERO

func _ready() -> void:
	animation_finished.connect(_restart_finished_animation)

func setup(new_actor_id: String, frames: SpriteFrames) -> void:
	actor_id = new_actor_id
	sprite_frames = frames
	centered = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if frames != null:
		visual_sprite_intent = frames.get_meta("visual_sprite_intent", Vector2i(64, 64))
		godot_frame_size = frames.get_meta("godot_frame_size", Vector2i(80, 80))
		source_png_size = frames.get_meta("source_png_size", Vector2i.ZERO)
		var actions := SpriteCatalogRef.list_actions(frames)
		action = "idle_breath" if actions.has("idle_breath") else (actions[0] if not actions.is_empty() else "")
		play_state(action, "east")

func play_state(new_action: String, new_direction: String) -> void:
	action = new_action
	direction = new_direction
	var resolved := SpriteCatalogRef.resolve_animation(sprite_frames, action, direction)
	if resolved.is_empty():
		stop()
		return

	animation = resolved["animation"]
	flip_h = bool(resolved["flip_h"])
	resolved_direction = String(resolved["resolved_direction"])
	play()

func _restart_finished_animation() -> void:
	if sprite_frames == null or animation == &"":
		return
	if not sprite_frames.get_animation_loop(animation):
		play()

func frame_count() -> int:
	if sprite_frames == null or animation == &"":
		return 0
	return sprite_frames.get_frame_count(animation)

func debug_text() -> String:
	return "actor: %s\naction: %s\ndir: %s -> %s\nframe: %d / %d\nplaying: %s\nsource png: %s\ngodot frame: %s\nvisual intent: %s" % [
		actor_id,
		action,
		direction,
		resolved_direction,
		frame + 1,
		frame_count(),
		str(is_playing()),
		str(source_png_size),
		str(godot_frame_size),
		str(visual_sprite_intent),
	]
