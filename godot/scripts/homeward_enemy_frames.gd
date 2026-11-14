extends RefCounted
## In-memory, Homeward-only art. Never saves/replaces shared SpriteFrames or move data.
const IDENTITIES := {"brawler": "red_jacket_brawler", "rusher": "track_sprinter", "kicker": "violet_kicker", "mini": "iron_leg", "boss": "crossroads_captain"}
static var _cache: Dictionary = {}

static func for_role(role: String) -> SpriteFrames:
	if _cache.has(role):
		return _cache[role]
	if not IDENTITIES.has(role):
		return null
	var texture := load("res://godot/assets/homeward/enemies/%s.png" % IDENTITIES[role]) as Texture2D
	if texture == null:
		return null
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	_add(frames, texture, "guard", 1, 0, 1, true)
	_add(frames, texture, "fight_idle", 1, 0, 1, true)
	_add(frames, texture, "walk", 0, 0, 6, true)
	# Authored jab/cross active on clock 1..2, source contacts on cells 2..3.
	# Compress anticipation, never move the existing hitbox/event window.
	_add(frames, texture, "punch", 1, 0, 6, false, [0, 2, 3, 4, 5, 5])
	_add(frames, texture, "kick", 2, 0, 6, false)
	_add(frames, texture, "hurt", 3, 0, 3, false)
	_add(frames, texture, "fall", 3, 3, 3, false)
	_add(frames, texture, "down", 3, 5, 1, false)
	_add(frames, texture, "get_up", 7, 3, 3, false)
	_add(frames, texture, "run", 4, 0, 6, true)
	_add(frames, texture, "dash", 5, 0, 6, false)
	_cache[role] = frames
	return frames

static func _add(frames: SpriteFrames, texture: Texture2D, clip: String, row: int, first: int, count: int, loops: bool, columns: Array = []) -> void:
	frames.add_animation(clip)
	frames.set_animation_speed(clip, 12)
	frames.set_animation_loop(clip, loops)
	for index in count:
		var col: int = first + index if columns.is_empty() else int(columns[index])
		var region := AtlasTexture.new()
		region.atlas = texture
		region.region = Rect2(col * 80, row * 80, 80, 80)
		frames.add_frame(clip, region)
