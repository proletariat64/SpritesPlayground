extends RefCounted
class_name SpriteCatalog

const RESOURCE_ROOT := "res://resources/sprite_frames"
const DIRECTIONS := [
	"east",
	"southeast",
	"south",
	"southwest",
	"west",
	"northwest",
	"north",
	"northeast",
]

static func load_actor_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	var dir := DirAccess.open(RESOURCE_ROOT)
	if dir == null:
		return ids

	for file_name in dir.get_files():
		if file_name.ends_with(".tres"):
			ids.append(file_name.get_basename())
	ids.sort()
	return ids

static func load_sprite_frames(actor_id: String) -> SpriteFrames:
	var path := "%s/%s.tres" % [RESOURCE_ROOT, actor_id]
	var resource := load(path)
	if resource is SpriteFrames:
		return resource
	push_warning("Missing SpriteFrames resource: %s" % path)
	return null

static func animation_name(action: String, direction: String) -> StringName:
	return StringName("%s__%s" % [action, direction])

static func list_actions(sprite_frames: SpriteFrames) -> PackedStringArray:
	if sprite_frames == null:
		return PackedStringArray()
	if sprite_frames.has_meta("action_names"):
		return sprite_frames.get_meta("action_names")

	var actions := {}
	for animation in sprite_frames.get_animation_names():
		var pieces := String(animation).split("__")
		actions[pieces[0]] = true

	var result := PackedStringArray()
	for action in actions.keys():
		result.append(String(action))
	result.sort()
	return result

static func resolve_animation(sprite_frames: SpriteFrames, action: String, direction: String) -> Dictionary:
	if sprite_frames == null:
		return {}

	var requested := animation_name(action, direction)
	if sprite_frames.has_animation(requested):
		return {"animation": requested, "flip_h": false, "resolved_direction": direction}

	var west_like := direction in ["west", "northwest", "southwest"]
	if west_like:
		var west := animation_name(action, "west")
		if sprite_frames.has_animation(west):
			return {"animation": west, "flip_h": false, "resolved_direction": "west"}

		var east := animation_name(action, "east")
		if sprite_frames.has_animation(east):
			return {"animation": east, "flip_h": true, "resolved_direction": "east"}

	var east_fallback := animation_name(action, "east")
	if sprite_frames.has_animation(east_fallback):
		return {"animation": east_fallback, "flip_h": false, "resolved_direction": "east"}

	for animation in sprite_frames.get_animation_names():
		if String(animation).begins_with("%s__" % action):
			return {"animation": animation, "flip_h": false, "resolved_direction": String(animation).split("__")[1]}

	return {}
