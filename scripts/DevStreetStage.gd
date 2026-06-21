extends Node2D

const SCREEN_WIDTH := 640
const SCREEN_HEIGHT := 360
const DEFAULT_ROUTE_WIDTH := SCREEN_WIDTH * 4
const WALKTHROUGH_SECONDS := 28.0
const HOLD_SECONDS := 1.25
const RESET_SECONDS := 2.0

@export var route_width: int = DEFAULT_ROUTE_WIDTH
@export var route_height: int = SCREEN_HEIGHT

@onready var camera: Camera2D = %WalkthroughCamera

var _elapsed := 0.0

func _ready() -> void:
	set_meta("route_width", route_width)
	set_meta("route_height", route_height)
	_build_stage_art()
	_configure_camera()

func _process(delta: float) -> void:
	_elapsed += delta
	var loop_seconds := HOLD_SECONDS + WALKTHROUGH_SECONDS + HOLD_SECONDS + RESET_SECONDS
	var phase := fmod(_elapsed, loop_seconds)
	var start_x := SCREEN_WIDTH * 0.5
	var end_x := float(route_width) - SCREEN_WIDTH * 0.5

	if phase < HOLD_SECONDS:
		camera.position.x = start_x
	elif phase < HOLD_SECONDS + WALKTHROUGH_SECONDS:
		var t := (phase - HOLD_SECONDS) / WALKTHROUGH_SECONDS
		camera.position.x = lerpf(start_x, end_x, smoothstep(0.0, 1.0, t))
	elif phase < HOLD_SECONDS + WALKTHROUGH_SECONDS + HOLD_SECONDS:
		camera.position.x = end_x
	else:
		var reset_t := (phase - HOLD_SECONDS - WALKTHROUGH_SECONDS - HOLD_SECONDS) / RESET_SECONDS
		camera.position.x = lerpf(end_x, start_x, smoothstep(0.0, 1.0, reset_t))

func _configure_camera() -> void:
	camera.position = Vector2(SCREEN_WIDTH * 0.5, SCREEN_HEIGHT * 0.5)
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = route_width
	camera.limit_bottom = route_height
	camera.enabled = true
	camera.make_current()

func _build_stage_art() -> void:
	if has_node("StageArt"):
		get_node("StageArt").queue_free()

	var art := Node2D.new()
	art.name = "StageArt"
	add_child(art)

	var sky := Node2D.new()
	sky.name = "SkyLayer"
	sky.z_index = -40
	art.add_child(sky)
	_add_rect(sky, Rect2(0, 0, route_width, route_height), Color("#8aa3b5"))
	_add_rect(sky, Rect2(0, 208, route_width, 152), Color("#4a6b64"))
	_add_rect(sky, Rect2(0, 0, route_width, 96), Color("#f2b880"))
	for x in range(48, route_width, 210):
		_add_rect(sky, Rect2(x, 42 + (x / 210) % 3 * 10, 88, 16), Color("#f7d6a4"))
		_add_rect(sky, Rect2(x + 16, 30 + (x / 210) % 2 * 8, 56, 14), Color("#ffd99a"))

	var far := Node2D.new()
	far.name = "FarBuildingsLayer"
	far.z_index = -30
	art.add_child(far)
	for x in range(-40, route_width + 120, 120):
		var h := 72 + (x / 120) % 4 * 16
		var y := 176 - h
		_add_rect(far, Rect2(x, y, 96, h), Color("#5d6975"))
		_add_rect(far, Rect2(x + 6, y + 8, 84, 8), Color("#72808a"))
		for wx in range(14, 82, 24):
			for wy in range(26, int(h) - 8, 22):
				_add_rect(far, Rect2(x + wx, y + wy, 8, 8), Color("#ffd07a"))

	var near := Node2D.new()
	near.name = "NearLandmarksLayer"
	near.z_index = -10
	art.add_child(near)
	_add_school_gate(near, 54)
	_add_shop(near, 505)
	_add_kindergarten_gate(near, 910)
	_add_market(near, 1338)
	_add_crossroad(near, 1740)
	_add_home(near, 2180)

	var street := Node2D.new()
	street.name = "StreetGroundLayer"
	street.z_index = 10
	art.add_child(street)
	_add_rect(street, Rect2(0, 244, route_width, 116), Color("#33424d"))
	_add_rect(street, Rect2(0, 238, route_width, 16), Color("#53695f"))
	_add_rect(street, Rect2(0, 280, route_width, 54), Color("#465560"))
	for x in range(20, route_width, 96):
		_add_rect(street, Rect2(x, 306, 48, 4), Color("#e7c77d"))
	for x in range(0, route_width, 128):
		_add_rect(street, Rect2(x, 235, 72, 3), Color("#89a077"))

func _add_school_gate(parent: Node2D, x: float) -> void:
	_add_rect(parent, Rect2(x, 126, 300, 96), Color("#724e4a"))
	_add_rect(parent, Rect2(x + 18, 100, 84, 126), Color("#b56a54"))
	_add_rect(parent, Rect2(x + 198, 100, 84, 126), Color("#b56a54"))
	_add_rect(parent, Rect2(x + 42, 144, 216, 16), Color("#38454f"))
	_add_rect(parent, Rect2(x + 118, 86, 64, 18), Color("#d6a65f"))
	for bar_x in range(60, 244, 24):
		_add_rect(parent, Rect2(x + bar_x, 160, 8, 68), Color("#2c353f"))
	_add_label(parent, Vector2(x + 100, 72), "School Gate")

func _add_shop(parent: Node2D, x: float) -> void:
	_add_rect(parent, Rect2(x, 134, 250, 96), Color("#536b76"))
	_add_rect(parent, Rect2(x + 16, 116, 220, 28), Color("#b85f4d"))
	_add_rect(parent, Rect2(x + 32, 152, 72, 70), Color("#27323a"))
	_add_rect(parent, Rect2(x + 124, 156, 86, 52), Color("#f0c879"))
	for sx in range(28, 224, 34):
		_add_rect(parent, Rect2(x + sx, 122, 18, 18), Color("#ffd07a"))
		_add_rect(parent, Rect2(x + sx + 7, 130, 10, 10), Color("#79a878"))
	_add_label(parent, Vector2(x + 78, 94), "Small Shop")

func _add_kindergarten_gate(parent: Node2D, x: float) -> void:
	_add_rect(parent, Rect2(x, 142, 280, 84), Color("#75985f"))
	_add_rect(parent, Rect2(x + 22, 112, 54, 112), Color("#e6a654"))
	_add_rect(parent, Rect2(x + 204, 112, 54, 112), Color("#e6a654"))
	_add_rect(parent, Rect2(x + 52, 120, 176, 22), Color("#f0cc65"))
	_add_rect(parent, Rect2(x + 92, 150, 96, 74), Color("#6d8cc4"))
	for star_x in range(88, 206, 30):
		_add_rect(parent, Rect2(x + star_x, 126, 12, 12), Color("#f7f0a3"))
	_add_label(parent, Vector2(x + 66, 88), "Kindergarten Gate")

func _add_market(parent: Node2D, x: float) -> void:
	_add_rect(parent, Rect2(x, 122, 310, 110), Color("#6a4f5f"))
	_add_rect(parent, Rect2(x + 12, 104, 286, 22), Color("#cf7a4f"))
	for stall_x in range(24, 274, 62):
		_add_rect(parent, Rect2(x + stall_x, 144, 44, 62), Color("#26343e"))
		_add_rect(parent, Rect2(x + stall_x + 6, 154, 32, 16), Color("#83b86f"))
		_add_rect(parent, Rect2(x + stall_x + 10, 180, 24, 12), Color("#d95f52"))
	_add_label(parent, Vector2(x + 100, 82), "Market Entrance")

func _add_crossroad(parent: Node2D, x: float) -> void:
	_add_rect(parent, Rect2(x, 112, 250, 122), Color("#59646f"))
	_add_rect(parent, Rect2(x + 100, 72, 20, 170), Color("#35434f"))
	_add_rect(parent, Rect2(x + 74, 72, 72, 18), Color("#c65f4f"))
	_add_rect(parent, Rect2(x + 82, 98, 12, 12), Color("#d85a4f"))
	_add_rect(parent, Rect2(x + 106, 98, 12, 12), Color("#e6b34f"))
	_add_rect(parent, Rect2(x + 130, 98, 12, 12), Color("#7fb66c"))
	for stripe_y in range(260, 336, 18):
		_add_rect(parent, Rect2(x + 150, stripe_y, 118, 6), Color("#e9dec0"))
	_add_label(parent, Vector2(x + 82, 48), "Crossroad")

func _add_home(parent: Node2D, x: float) -> void:
	_add_rect(parent, Rect2(x, 110, 270, 122), Color("#715b67"))
	_add_rect(parent, Rect2(x + 24, 88, 222, 28), Color("#bd6653"))
	_add_rect(parent, Rect2(x + 38, 142, 58, 82), Color("#2b3540"))
	_add_rect(parent, Rect2(x + 132, 138, 78, 62), Color("#f0cf8b"))
	_add_rect(parent, Rect2(x + 158, 200, 24, 26), Color("#30424d"))
	_add_rect(parent, Rect2(x + 216, 162, 34, 64), Color("#4d7869"))
	_add_label(parent, Vector2(x + 86, 66), "Home Entrance")

func _add_rect(parent: Node2D, rect: Rect2, color: Color) -> Polygon2D:
	var polygon := Polygon2D.new()
	polygon.polygon = PackedVector2Array([
		rect.position,
		rect.position + Vector2(rect.size.x, 0),
		rect.position + rect.size,
		rect.position + Vector2(0, rect.size.y),
	])
	polygon.color = color
	parent.add_child(polygon)
	return polygon

func _add_label(parent: Node2D, position: Vector2, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.position = position
	label.custom_minimum_size = Vector2(160, 18)
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", Color("#f8f1d2"))
	label.add_theme_color_override("font_shadow_color", Color("#1f2730"))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	parent.add_child(label)
	return label
