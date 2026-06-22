extends Resource
class_name CharacterTemplate

const MoveLibraryScript := preload("res://godot/scripts/move_library.gd")


static func combat_gray_s64() -> Dictionary:
	return {
		"template_id": "combat_gray_s64",
		"sprite_size_class": "s64",
		"frame_size": 80,
		"max_hp": 100,
		"hurtbox_profile": {
			"hurt_head": Rect2(-12, -64, 24, 18),
			"hurt_upper_body": Rect2(-16, -46, 32, 24),
			"hurt_lower_body": Rect2(-14, -22, 28, 22),
		},
		"foot_collision_profile": {
			"center": Vector2(0, -4),
			"radius": Vector2(18, 8),
		},
		"move_templates": MoveLibraryScript.combat_gray_s64_moves(),
	}
