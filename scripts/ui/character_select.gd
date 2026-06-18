extends Node2D

const SCENE_NEXT := "res://scenes/ui/how_to_play.tscn"

const CHAR_POSES := [
	preload("res://assets/textures/characters/char_01_pose.png"),
	preload("res://assets/textures/ui/unknown_character.png"),
	preload("res://assets/textures/ui/unknown_character.png"),
	preload("res://assets/textures/ui/unknown_character.png"),
]
const CHAR_POSES_MIRROR := [
	preload("res://assets/textures/characters/char_01_pose_mirror.png"),
	preload("res://assets/textures/ui/unknown_character.png"),
	preload("res://assets/textures/ui/unknown_character.png"),
	preload("res://assets/textures/ui/unknown_character.png"),
]

@onready var _p1_splash : TextureRect    = $P1Splash
@onready var _p2_splash : TextureRect    = $P2Splash
@onready var _p1_cursor : Control        = $P1Cursor
@onready var _p2_cursor : Control        = $P2Cursor
@onready var _slots     : Array[Control] = [
	$CharacterGrid/Slot1,
	$CharacterGrid/Slot2,
	$CharacterGrid/Slot3,
	$CharacterGrid/Slot4,
]

var p1_idx         : int   = 0
var p2_idx         : int   = 0
var _p1_confirmed  : bool  = false
var _p2_confirmed  : bool  = false
var _blink_timer   : float = 0.4
var _blink_visible : bool  = true
var _transitioning : bool  = false


func _ready() -> void:
	_update_cursors()
	_update_splashes()


func _process(delta: float) -> void:
	# P1 navigation — annule la confirmation si on bouge
	if Input.is_action_just_pressed("p1_left"):
		p1_idx        = max(0, p1_idx - 1)
		_p1_confirmed = false
		_update_splashes()
		MusicManager.play_sfx("res://assets/sfx/buttonrollover.mp3")
	elif Input.is_action_just_pressed("p1_right"):
		p1_idx        = min(3, p1_idx + 1)
		_p1_confirmed = false
		_update_splashes()
		MusicManager.play_sfx("res://assets/sfx/buttonrollover.mp3")
	if Input.is_action_just_pressed("p1_attack_light"):
		var was_confirmed := _p1_confirmed
		_p1_confirmed = not _p1_confirmed
		if _p1_confirmed:
			MusicManager.play_sfx("res://assets/sfx/buttonclickrelease.mp3")
		else:
			MusicManager.play_sfx("res://assets/sfx/buttonrollover.mp3")

	# P2 navigation
	if Input.is_action_just_pressed("p2_left"):
		p2_idx        = max(0, p2_idx - 1)
		_p2_confirmed = false
		_update_splashes()
		MusicManager.play_sfx("res://assets/sfx/buttonrollover.mp3")
	elif Input.is_action_just_pressed("p2_right"):
		p2_idx        = min(3, p2_idx + 1)
		_p2_confirmed = false
		_update_splashes()
		MusicManager.play_sfx("res://assets/sfx/buttonrollover.mp3")
	if Input.is_action_just_pressed("p2_attack_light"):
		var was_confirmed := _p2_confirmed
		_p2_confirmed = not _p2_confirmed
		if _p2_confirmed:
			MusicManager.play_sfx("res://assets/sfx/buttonclickrelease.mp3")
		else:
			MusicManager.play_sfx("res://assets/sfx/buttonrollover.mp3")

	# Blink timer
	_blink_timer -= delta
	if _blink_timer <= 0.0:
		_blink_visible = not _blink_visible
		_blink_timer   = 0.4

	# Visibilité des curseurs
	_p1_cursor.visible = _blink_visible if _p1_confirmed else true
	_p2_cursor.visible = _blink_visible if _p2_confirmed else true

	_update_cursors()

	if _p1_confirmed and _p2_confirmed and not _transitioning:
		_transitioning = true
		GameManager.p1_character = p1_idx + 1
		GameManager.p2_character = p2_idx + 1
		get_node("/root/SceneTransition").transition_to(SCENE_NEXT)


func _get_slot(idx: int) -> Control:
	return _slots[idx]


func _update_cursors() -> void:
	var s1 := _get_slot(p1_idx)
	_p1_cursor.global_position = s1.global_position

	var s2 := _get_slot(p2_idx)
	_p2_cursor.global_position = s2.global_position + Vector2(s2.size.x - 40, 0)


func _update_splashes() -> void:
	_p1_splash.texture = CHAR_POSES[p1_idx]
	_p2_splash.texture = CHAR_POSES_MIRROR[p2_idx]
