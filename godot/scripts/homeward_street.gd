extends Node2D
## Three generated panoramas, pre-sized with NEAREST; original PNGs stay untouched.
const BACKGROUNDS := [
	preload("res://godot/assets/homeward/backgrounds/school_gate.png"),
	preload("res://godot/assets/homeward/backgrounds/shopping_street.png"),
	preload("res://godot/assets/homeward/backgrounds/homeward_alley.png"),
]
const LOCATIONS := ["SchoolGate", "ShoppingStreet", "HomewardAlley"]
var font: Font

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for index in BACKGROUNDS.size():
		var panorama := Sprite2D.new()
		panorama.name = LOCATIONS[index]
		panorama.texture = BACKGROUNDS[index]
		panorama.centered = false
		panorama.position = Vector2(index * 768, -72)
		# Children render behind this node's location annotations, not over them.
		panorama.z_index = -1
		add_child(panorama)

func sign_text(at: Vector2, title: String, size := 15) -> void:
	draw_string(font, at + Vector2.ONE, title, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color("382c42"))
	draw_string(font, at, title, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color("ffe4a0"))

func _draw() -> void:
	if font == null:
		return
	sign_text(Vector2(215, 185), "米多的学校")
	sign_text(Vector2(852, 104), "面包屋", 13)
	sign_text(Vector2(1060, 104), "放学便利店", 13)
	sign_text(Vector2(1380, 112), "自行车修理", 13)
	sign_text(Vector2(1983, 170), "米多的家", 16)
	# Home's doorway is just right of the unchanged x=2010 arrival threshold.
	sign_text(Vector2(1970, 254), "HOME →", 19)
