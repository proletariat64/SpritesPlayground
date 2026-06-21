extends CharacterBody2D
class_name ChibiCharacter2D

const SpriteCatalogRef := preload("res://scripts/SpriteCatalog.gd")

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var actor_id := ""
var action := "idle_breath"
var direction := "east"
var resolved_direction := "east"
var resolved_animation := &""
var resolved_flip_h := false

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	animated_sprite.centered = true
	animated_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if animated_sprite.sprite_frames != null:
		actor_id = String(animated_sprite.sprite_frames.get_meta("actor_id", actor_id))
	play_state(action, direction)

func setup(new_actor_id: String) -> void:
	actor_id = new_actor_id
	animated_sprite.sprite_frames = SpriteCatalogRef.load_sprite_frames(actor_id)
	play_state(action, direction)

func set_action(new_action: String) -> void:
	play_state(new_action, direction)

func set_direction(new_direction: String) -> void:
	play_state(action, new_direction)

func play_state(new_action: String, new_direction: String) -> void:
	action = new_action
	direction = new_direction
	if animated_sprite == null or animated_sprite.sprite_frames == null:
		return

	var resolved := SpriteCatalogRef.resolve_animation(animated_sprite.sprite_frames, action, direction)
	if resolved.is_empty():
		resolved_animation = &""
		resolved_direction = ""
		resolved_flip_h = false
		animated_sprite.stop()
		push_warning("%s cannot resolve %s__%s" % [actor_id, action, direction])
		return

	resolved_animation = resolved["animation"]
	resolved_direction = String(resolved["resolved_direction"])
	resolved_flip_h = bool(resolved["flip_h"])
	animated_sprite.animation = resolved_animation
	animated_sprite.flip_h = resolved_flip_h
	animated_sprite.play()

func get_available_actions() -> PackedStringArray:
	if animated_sprite == null:
		return PackedStringArray()
	return SpriteCatalogRef.list_actions(animated_sprite.sprite_frames)

func get_available_directions() -> PackedStringArray:
	return PackedStringArray(SpriteCatalogRef.DIRECTIONS)

func get_frame_count() -> int:
	if animated_sprite == null or animated_sprite.sprite_frames == null or resolved_animation == &"":
		return 0
	return animated_sprite.sprite_frames.get_frame_count(resolved_animation)

func debug_text() -> String:
	return "actor: %s\naction: %s\ndir: %s -> %s\nanimation: %s\nframe: %d / %d\nflip_h: %s" % [
		actor_id,
		action,
		direction,
		resolved_direction,
		String(resolved_animation),
		animated_sprite.frame + 1 if animated_sprite != null else 0,
		get_frame_count(),
		str(resolved_flip_h),
	]
