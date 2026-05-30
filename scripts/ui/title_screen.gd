extends Node2D

func _process(_delta: float) -> void:
	if _any_button_just_pressed():
		get_tree().change_scene_to_file("res://scenes/ui/mode_select.tscn")

func _any_button_just_pressed() -> bool:
	for action in ["p1_attack_light", "p1_attack_strong", "p1_parry",
				   "p2_attack_light", "p2_attack_strong", "p2_parry"]:
		if Input.is_action_just_pressed(action):
			return true
	return false
