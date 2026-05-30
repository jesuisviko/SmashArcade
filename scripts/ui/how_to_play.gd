extends Node2D

const SCENE_NEXT := "res://scenes/game.tscn"

@onready var _p1_ready_label : Label = $P1Ready
@onready var _p2_ready_label : Label = $P2Ready

var _p1_ready : bool = false
var _p2_ready : bool = false

func _ready() -> void:
	_p1_ready_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.6))
	_p2_ready_label.add_theme_color_override("font_color", Color(0.6, 0.6, 1.0))

func _process(_delta: float) -> void:
	if not _p1_ready and _any_just_pressed(1):
		_p1_ready = true
		_p1_ready_label.text = "P1 : PRÊT  ✓"
		_p1_ready_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
	if not _p2_ready and _any_just_pressed(2):
		_p2_ready = true
		_p2_ready_label.text = "P2 : PRÊT  ✓"
		_p2_ready_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
	if _p1_ready and _p2_ready:
		get_tree().change_scene_to_file(SCENE_NEXT)

func _any_just_pressed(player_id: int) -> bool:
	var prefix := "p%d_" % player_id
	for suffix in ["attack_light", "attack_strong", "parry"]:
		if Input.is_action_just_pressed(prefix + suffix):
			return true
	return false
