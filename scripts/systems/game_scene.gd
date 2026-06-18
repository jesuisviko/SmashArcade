extends Node3D

const CHAR_SCENES : Dictionary = {
	1: "res://scenes/characters/char_01.tscn",
	2: "res://scenes/characters/base_character.tscn",
	3: "res://scenes/characters/base_character.tscn",
	4: "res://scenes/characters/base_character.tscn",
}

const P1_START       := Vector3(-5.0, 2.0, 0.0)
const P2_START       := Vector3( 5.0, 2.0, 0.0)
const PHASE_DURATION := 1.0

var _p1                : CharacterBody3D = null
var _p2                : CharacterBody3D = null
var _round_start_timer : float           = 0.0
var _last_phase        : int             = -1


func _ready() -> void:
	GameManager.reset()
	_p1 = _spawn_player(1, GameManager.p1_character, P1_START)
	_p2 = _spawn_player(2, GameManager.p2_character, P2_START)
	# Correction post-instanciation : certains persos hardcodent player_id dans leur _ready(),
	# ce qui peut fausser les registrations. On corrige ici après les deux instanciations.
	_p1.player_id = 1
	_p2.player_id = 2
	_p1.set_initial_facing(1.0)    # P1 regarde à droite
	_p2.set_initial_facing(-1.0)   # P2 regarde à gauche
	GameManager.register_player(1, _p1)
	GameManager.register_player(2, _p2)
	MusicManager.play_music("res://assets/sfx/Combat_music_1.mp3")


func _process(delta: float) -> void:
	if GameManager.round_started:
		return

	_round_start_timer += delta
	var phase : int = mini(int(_round_start_timer / PHASE_DURATION), 4)
	if phase == _last_phase:
		return
	_last_phase = phase

	var cam : Camera3D = get_tree().get_first_node_in_group("camera")
	var hud            = get_tree().get_first_node_in_group("hud")

	match phase:
		0:
			pass  # t=0–1s : joueurs spawnés, immobiles, rien à l'écran
		1:
			if hud: hud.show_countdown("3")
			if cam: cam.start_intro_focus(_p1, 16.0)
		2:
			if hud: hud.show_countdown("2")
			if cam: cam.start_intro_focus(_p2, 16.0)
		3:
			if hud: hud.show_countdown("1")
			if cam: cam._cam_state = cam.CamState.NORMAL
		4:
			if hud: hud.hide_countdown()
			GameManager.round_started = true


func _spawn_player(pid: int, char_id: int, start_pos: Vector3) -> CharacterBody3D:
	# Libère le placeholder de la scène (base_character.tscn statique dans game.tscn)
	var placeholder: Node = get_node_or_null("Player" + str(pid))
	if placeholder:
		placeholder.queue_free()

	var path   : String          = CHAR_SCENES.get(char_id, CHAR_SCENES[2])
	var scene  : PackedScene     = load(path)
	var player : CharacterBody3D = scene.instantiate()
	player.name       = "Player" + str(pid)
	player.player_id  = pid
	player.debug_mode = GameManager.debug_mode_global
	add_child(player)
	player.global_position = start_pos
	return player
