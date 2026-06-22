extends Resource
class_name MoveLibrary


static func combat_gray_s64_moves() -> Dictionary:
	return {
		"basic_punch": {
			"move_id": "basic_punch",
			"fps": 60,
			"total_frames": 27,
			"hitbox_windows": [
				{
					"from_frame": 7,
					"to_frame": 12,
					"hitbox_id": "hit_fist_1",
					"damage": 8,
					"rect": Rect2(12, -48, 24, 14),
				},
			],
		},
		"basic_kick": {
			"move_id": "basic_kick",
			"fps": 60,
			"total_frames": 33,
			"hitbox_windows": [
				{
					"from_frame": 12,
					"to_frame": 19,
					"hitbox_id": "hit_leg_1",
					"damage": 10,
					"rect": Rect2(10, -26, 34, 14),
				},
			],
		},
	}
