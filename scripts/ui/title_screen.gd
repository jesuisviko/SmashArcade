extends Node2D

var _pulse_timer : float = 0.0

func _ready() -> void:
	$SubtitleLabel.pivot_offset = $SubtitleLabel.size / 2
	MusicManager.play_music("res://assets/sfx/main_menu_theme.mp3")

func _process(delta: float) -> void:
	_pulse_timer += delta
	var s : float = 1.0 + sin(_pulse_timer * PI / 2.0) * 0.08
	$SubtitleLabel.scale = Vector2(s, s)

	if _any_button_just_pressed():
		MusicManager.play_sfx("res://assets/sfx/buttonclickrelease.mp3")
		get_node("/root/SceneTransition").transition_to("res://scenes/ui/mode_select.tscn")

func _any_button_just_pressed() -> bool:
	for action in ["p1_attack_light", "p1_attack_strong", "p1_parry",
				   "p2_attack_light", "p2_attack_strong", "p2_parry"]:
		if Input.is_action_just_pressed(action):
			return true
	return false
