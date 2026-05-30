extends Node2D

const SCENE_NEXT  := "res://scenes/ui/how_to_play.tscn"
const CHAR_NAMES  := ["PERSO 1", "PERSO 2", "PERSO 3", "PERSO 4"]
const CHAR_COLORS := [
	Color(0.85, 0.2,  0.2,  1.0),
	Color(0.2,  0.2,  0.85, 1.0),
	Color(0.2,  0.75, 0.2,  1.0),
	Color(0.85, 0.75, 0.1,  1.0),
]

@onready var _slot0    : Node2D = $Slot0
@onready var _slot1    : Node2D = $Slot1
@onready var _slot2    : Node2D = $Slot2
@onready var _slot3    : Node2D = $Slot3
@onready var _p1_label : Label  = $P1Cursor
@onready var _p2_label : Label  = $P2Cursor
@onready var _status   : Label  = $StatusLabel

var _slots  : Array[Node2D]
var _p1_idx : int  = 0
var _p2_idx : int  = 1
var _p1_ok  : bool = false
var _p2_ok  : bool = false

func _ready() -> void:
	_slots = [_slot0, _slot1, _slot2, _slot3]
	_refresh()

func _process(_delta: float) -> void:
	if not _p1_ok:
		if Input.is_action_just_pressed("p1_left"):
			_p1_idx = (_p1_idx - 1 + 4) % 4
			_refresh()
		elif Input.is_action_just_pressed("p1_right"):
			_p1_idx = (_p1_idx + 1) % 4
			_refresh()
		elif Input.is_action_just_pressed("p1_attack_light"):
			_p1_ok = true
			_refresh()
	if not _p2_ok:
		if Input.is_action_just_pressed("p2_left"):
			_p2_idx = (_p2_idx - 1 + 4) % 4
			_refresh()
		elif Input.is_action_just_pressed("p2_right"):
			_p2_idx = (_p2_idx + 1) % 4
			_refresh()
		elif Input.is_action_just_pressed("p2_attack_light"):
			_p2_ok = true
			_refresh()
	if _p1_ok and _p2_ok:
		GameManager.p1_character = _p1_idx
		GameManager.p2_character = _p2_idx
		get_tree().change_scene_to_file(SCENE_NEXT)

func _refresh() -> void:
	for i in _slots.size():
		var box   := _slots[i].get_node("Box") as ColorRect
		var lbl   := _slots[i].get_node("NameLabel") as Label
		box.color = CHAR_COLORS[i]
		lbl.text  = CHAR_NAMES[i]
		var hovered   : bool = (i == _p1_idx and not _p1_ok) or (i == _p2_idx and not _p2_ok)
		var confirmed : bool = (_p1_ok and _p1_idx == i) or (_p2_ok and _p2_idx == i)
		_slots[i].modulate = Color.WHITE if (hovered or confirmed) else Color(0.4, 0.4, 0.4, 1.0)
	_p1_label.text = "P1  →  " + CHAR_NAMES[_p1_idx] + ("  ✓" if _p1_ok else "")
	_p2_label.text = "P2  →  " + CHAR_NAMES[_p2_idx] + ("  ✓" if _p2_ok else "")
	_p1_label.add_theme_color_override("font_color",
		Color(0.5, 1.0, 0.5) if _p1_ok else Color(1.0, 0.7, 0.7))
	_p2_label.add_theme_color_override("font_color",
		Color(0.5, 1.0, 0.5) if _p2_ok else Color(0.7, 0.7, 1.0))
	if _p1_ok and _p2_ok:
		_status.text = "Les deux joueurs prêts..."
	elif _p1_ok:
		_status.text = "P1 prêt — P2 : confirme !"
	elif _p2_ok:
		_status.text = "P2 prêt — P1 : confirme !"
	else:
		_status.text = "Naviguez avec ←→     Confirmez : Bouton 1"
