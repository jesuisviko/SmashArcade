extends Node2D

const SCENE_NEXT := "res://scenes/game.tscn"

@onready var _p1_ready_label : Label = $P1Ready
@onready var _p2_ready_label : Label = $P2Ready

var _p1_ready  : bool  = false
var _p2_ready  : bool  = false
var _dot_timer : float = 0.0
var _dot_count : int   = 0

func _ready() -> void:
	_p1_ready_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.6))
	_p2_ready_label.add_theme_color_override("font_color", Color(0.6, 0.6, 1.0))

func _process(delta: float) -> void:
	if not _p1_ready and _any_just_pressed(1):
		_p1_ready = true
		_p1_ready_label.text = "P1 : PRÊT  ✓"
		_p1_ready_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
	if not _p2_ready and _any_just_pressed(2):
		_p2_ready = true
		_p2_ready_label.text = "P2 : PRÊT  ✓"
		_p2_ready_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
	if _p1_ready and _p2_ready:
		get_node("/root/SceneTransition").transition_to(SCENE_NEXT)

	_dot_timer += delta
	if _dot_timer >= 0.5:
		_dot_timer = 0.0
		_dot_count = (_dot_count + 1) % 4
		var dots   := ".".repeat(_dot_count)
		if not _p1_ready:
			_p1_ready_label.text = "P1 : en attente" + dots
		if not _p2_ready:
			_p2_ready_label.text = "P2 : en attente" + dots

func _any_just_pressed(player_id: int) -> bool:
	var prefix := "p%d_" % player_id
	for suffix in ["attack_light", "attack_strong", "parry"]:
		if Input.is_action_just_pressed(prefix + suffix):
			return true
	return false
