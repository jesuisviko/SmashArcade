extends Control

const INTRO_SFX  := "res://assets/sfx/intro_sound.mp3"
const NEXT_SCENE := "res://scenes/ui/title_screen.tscn"

@onready var _logo : TextureRect = $Logo


func _ready() -> void:
	var tween := create_tween()
	tween.tween_interval(0.5)
	tween.tween_callback(func() -> void:
		MusicManager.play_sfx(INTRO_SFX)
	)
	tween.tween_property(_logo, "modulate:a", 1.0, 0.35)
	tween.tween_interval(1.0)
	tween.tween_property(_logo, "modulate:a", 0.0, 0.35)
	tween.tween_callback(func() -> void:
		get_node("/root/SceneTransition").transition_to(NEXT_SCENE)
	)
