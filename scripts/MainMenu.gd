extends Control

func _ready() -> void:
	%OpenButton.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/SpritesPlayground.tscn")
	)
	%OpenStreetStageButton.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/stages/dev_street_stage.tscn")
	)
