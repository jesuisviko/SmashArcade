extends Node2D

const SCENE_NEXT := "res://scenes/ui/character_select.tscn"
const MODES      := ["3_vies", "temps", "custom"]

@onready var _opt0 : Label = $Option0
@onready var _opt1 : Label = $Option1
@onready var _opt2 : Label = $Option2

const COLOR_SELECTED := Color(1.0, 1.0, 0.0, 1.0)
const COLOR_ENABLED  := Color(1.0, 1.0, 1.0, 1.0)
const COLOR_DISABLED := Color(0.35, 0.35, 0.35, 1.0)

var _enabled  := [true, false, false]
var _selected : int = 0
var _labels   : Array[Label]

func _ready() -> void:
	_labels = [_opt0, _opt1, _opt2]
	_refresh()

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("p1_up") or Input.is_action_just_pressed("p2_up"):
		_move(-1)
	if Input.is_action_just_pressed("p1_down") or Input.is_action_just_pressed("p2_down"):
		_move(1)
	if Input.is_action_just_pressed("p1_attack_light") or Input.is_action_just_pressed("p2_attack_light"):
		if _enabled[_selected]:
			GameManager.selected_mode = MODES[_selected]
			get_tree().change_scene_to_file(SCENE_NEXT)

func _move(dir: int) -> void:
	_selected = (_selected + dir + _labels.size()) % _labels.size()
	_refresh()

func _refresh() -> void:
	for i in _labels.size():
		var col: Color
		if   i == _selected: col = COLOR_SELECTED
		elif _enabled[i]:    col = COLOR_ENABLED
		else:                col = COLOR_DISABLED
		_labels[i].add_theme_color_override("font_color", col)
