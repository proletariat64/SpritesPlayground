extends Node2D
class_name PixelStage


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(640, 360)), Color("#1f2937"))
	draw_rect(Rect2(Vector2(0, 210), Vector2(640, 150)), Color("#334155"))
	draw_rect(Rect2(Vector2(0, 258), Vector2(640, 4)), Color("#64748b"))
	for i in range(0, 640, 32):
		var shade = Color("#475569") if (i / 32) % 2 == 0 else Color("#3f4b5f")
		draw_rect(Rect2(Vector2(i, 262), Vector2(32, 98)), shade)
	for y in [228, 246, 282, 318]:
		draw_line(Vector2(0, y), Vector2(640, y), Color("#56657a"), 1.0)
	draw_rect(Rect2(Vector2(38, 58), Vector2(136, 92)), Color("#263445"))
	draw_rect(Rect2(Vector2(48, 68), Vector2(116, 72)), Color("#2f80a8"))
	draw_rect(Rect2(Vector2(438, 48), Vector2(136, 106)), Color("#263445"))
	draw_rect(Rect2(Vector2(450, 60), Vector2(112, 82)), Color("#4f9d69"))
	draw_line(Vector2(0, 210), Vector2(640, 210), Color("#8aa0b8"), 2.0)
