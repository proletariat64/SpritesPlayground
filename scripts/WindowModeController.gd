extends Node

const FULLSCREEN_SIZE := Vector2i(1920, 1080)
const WINDOWED_SIZE := Vector2i(1280, 720)

func _ready() -> void:
	_set_fullscreen()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_set_windowed()
		get_viewport().set_input_as_handled()

func _set_fullscreen() -> void:
	DisplayServer.window_set_size(FULLSCREEN_SIZE)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func _set_windowed() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(WINDOWED_SIZE)
	var screen := DisplayServer.window_get_current_screen()
	var screen_position := DisplayServer.screen_get_position(screen)
	var screen_size := DisplayServer.screen_get_size(screen)
	DisplayServer.window_set_position(screen_position + (screen_size - WINDOWED_SIZE) / 2)
