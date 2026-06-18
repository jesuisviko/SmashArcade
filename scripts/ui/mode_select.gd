extends Node2D

const SCENE_NEXT := "res://scenes/ui/character_select.tscn"
const MODES      := ["3_vies", "temps", "custom"]

@onready var _icon3v : TextureRect = $Icon3Vies
@onready var _icon5m : TextureRect = $Icon5Min
@onready var _iconcu : TextureRect = $IconCustom

var _selected    : int   = 0
var _pulse_timer : float = 0.0
var _icons       : Array

func _ready() -> void:
	_icons = [_icon3v, _icon5m, _iconcu]
	_icon5m.modulate = Color(0.5, 0.5, 0.5, 1.0)
	_iconcu.modulate = Color(0.5, 0.5, 0.5, 1.0)

func _process(delta: float) -> void:
	_pulse_timer += delta

	for i in range(_icons.size()):
		if i == _selected:
			var s := 1.0 + sin(_pulse_timer * PI / 2.0 * 1.5) * 0.048
			_icons[i].scale        = Vector2(s, s)
			_icons[i].pivot_offset = _icons[i].size / 2
		else:
			_icons[i].scale = Vector2(1.0, 1.0)

	if Input.is_action_just_pressed("p1_left") or Input.is_action_just_pressed("p2_left"):
		_selected    = max(0, _selected - 1)
		_pulse_timer = 0.0
		MusicManager.play_sfx("res://assets/sfx/buttonrollover.mp3")
	if Input.is_action_just_pressed("p1_right") or Input.is_action_just_pressed("p2_right"):
		_selected    = min(2, _selected + 1)
		_pulse_timer = 0.0
		MusicManager.play_sfx("res://assets/sfx/buttonrollover.mp3")
	if Input.is_action_just_pressed("p1_attack_light") or Input.is_action_just_pressed("p2_attack_light"):
		if _selected == 0:
			MusicManager.play_sfx("res://assets/sfx/buttonclickrelease.mp3")
			GameManager.selected_mode = MODES[0]
			get_node("/root/SceneTransition").transition_to(SCENE_NEXT)
