extends Node2D

const SCENE_NEXT := "res://scenes/game.tscn"

@onready var _p1_ready_label : Label = $P1Ready
@onready var _p2_ready_label : Label = $P2Ready

var _p1_ready  : bool  = false
var _p2_ready  : bool  = false
var _dot_timer : float = 0.0
var _dot_count : int   = 0

var _p1_parry_time  : float = -1.0
var _p2_parry_time  : float = -1.0
var _time_elapsed   : float = 0.0
var _debug_label    : Label = null

const DOUBLE_PARRY_WINDOW := 1.0


func _ready() -> void:
	MusicManager.stop_music(2.0)
	_p1_ready_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.6))
	_p2_ready_label.add_theme_color_override("font_color", Color(0.6, 0.6, 1.0))
	_debug_label            = Label.new()
	_debug_label.position   = Vector2(10, 10)
	_debug_label.z_index    = 100
	_debug_label.text       = ""
	add_child(_debug_label)


func _process(delta: float) -> void:
	_time_elapsed += delta

	# Confirmation "prêt" — attack_light uniquement
	if not _p1_ready and Input.is_action_just_pressed("p1_attack_light"):
		_p1_ready = true
		_p1_ready_label.text = "P1 : PRÊT  ✓"
		_p1_ready_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
		MusicManager.play_sfx("res://assets/sfx/buttonclickrelease.mp3")
	if not _p2_ready and Input.is_action_just_pressed("p2_attack_light"):
		_p2_ready = true
		_p2_ready_label.text = "P2 : PRÊT  ✓"
		_p2_ready_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
		MusicManager.play_sfx("res://assets/sfx/buttonclickrelease.mp3")
	if _p1_ready and _p2_ready:
		get_node("/root/SceneTransition").transition_to(SCENE_NEXT)

	# Double parry → toggle debug global
	if Input.is_action_just_pressed("p1_parry"):
		_p1_parry_time = _time_elapsed
	if Input.is_action_just_pressed("p2_parry"):
		_p2_parry_time = _time_elapsed
	if _p1_parry_time >= 0.0 and _p2_parry_time >= 0.0:
		if abs(_p1_parry_time - _p2_parry_time) <= DOUBLE_PARRY_WINDOW:
			GameManager.debug_mode_global = not GameManager.debug_mode_global
			_p1_parry_time = -1.0
			_p2_parry_time = -1.0
			_debug_label.text = "DEBUG : ACTIVÉ" if GameManager.debug_mode_global else "DEBUG : DÉSACTIVÉ"
			print("[DEBUG TOGGLE] debug_mode_global =", GameManager.debug_mode_global)

	# Réinitialise les temps de parry expirés
	if _p1_parry_time >= 0.0 and _time_elapsed - _p1_parry_time > DOUBLE_PARRY_WINDOW:
		_p1_parry_time = -1.0
	if _p2_parry_time >= 0.0 and _time_elapsed - _p2_parry_time > DOUBLE_PARRY_WINDOW:
		_p2_parry_time = -1.0

	# Indicateur d'attente animé
	_dot_timer += delta
	if _dot_timer >= 0.5:
		_dot_timer = 0.0
		_dot_count = (_dot_count + 1) % 4
		var dots   := ".".repeat(_dot_count)
		if not _p1_ready:
			_p1_ready_label.text = "P1 : en attente" + dots
		if not _p2_ready:
			_p2_ready_label.text = "P2 : en attente" + dots
