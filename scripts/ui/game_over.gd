extends Node2D

const DESTINATIONS := [
	"res://scenes/ui/character_select.tscn",
	"res://scenes/ui/title_screen.tscn",
]
const COLOR_SELECTED := Color(1.0, 1.0, 0.0, 1.0)
const COLOR_NORMAL   := Color(1.0, 1.0, 1.0, 1.0)

@onready var _winner_label : Label = $WinnerLabel
@onready var _opt0         : Label = $Option0
@onready var _opt1         : Label = $Option1

var _selected : int = 0
var _options  : Array[Label]

func _ready() -> void:
	_options = [_opt0, _opt1]
	_winner_label.text = "JOUEUR %d GAGNE !" % GameManager.winner_id
	_refresh()

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("p1_up") or Input.is_action_just_pressed("p2_up"):
		_selected = max(0, _selected - 1)
		_refresh()
	if Input.is_action_just_pressed("p1_down") or Input.is_action_just_pressed("p2_down"):
		_selected = min(1, _selected + 1)
		_refresh()
	if Input.is_action_just_pressed("p1_attack_light") or Input.is_action_just_pressed("p2_attack_light"):
		get_tree().change_scene_to_file(DESTINATIONS[_selected])

func _refresh() -> void:
	for i in _options.size():
		_options[i].add_theme_color_override("font_color",
			COLOR_SELECTED if i == _selected else COLOR_NORMAL)
