# ACTIONS À CRÉER dans Project Settings → Input Map :
#
#   P1 : p1_left  p1_right  p1_up  p1_down
#         p1_jump  p1_attack_light  p1_attack_strong  p1_parry
#
#   P2 : p2_left  p2_right  p2_up  p2_down
#         p2_jump  p2_attack_light  p2_attack_strong  p2_parry
#
# Mapping clavier suggéré (à saisir dans l'éditeur, pas hardcodé ici) :
#   P1 — gauche/droite : Q / D     haut/bas : Z / S
#        jump : E     attack_light : R     attack_strong : T     parry : F
#   P2 — gauche/droite : ← / →    haut/bas : ↑ / ↓
#        jump : KP_0  attack_light : KP_1  attack_strong : KP_2  parry : KP_3

extends Node


func get_input(player_id: int) -> Dictionary:
	var p := "p%d_" % player_id
	return {
		"left":          Input.is_action_pressed(p + "left"),
		"right":         Input.is_action_pressed(p + "right"),
		"up":            Input.is_action_pressed(p + "up"),
		"down":          Input.is_action_pressed(p + "down"),
		"attack_light":  Input.is_action_just_pressed(p + "attack_light"),
		"attack_strong": Input.is_action_just_pressed(p + "attack_strong"),
		"parry":         Input.is_action_just_pressed(p + "parry"),
	}


func get_input_p1() -> Dictionary:
	return get_input(1)


func get_input_p2() -> Dictionary:
	return get_input(2)
