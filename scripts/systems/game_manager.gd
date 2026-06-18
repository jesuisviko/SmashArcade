# AUTOLOAD À ENREGISTRER dans Project Settings → AutoLoad :
#   Nom : GameManager   Chemin : res://scripts/systems/game_manager.gd

extends Node

var stocks             : Dictionary = {1: 3, 2: 3}
var players            : Dictionary = {}
var game_state         : String     = "fighting"
var winner_id          : int        = 0
var selected_mode      : String     = "3_vies"
var p1_character       : int        = 0
var p2_character       : int        = 1
var debug_mode_global  : bool       = false
var round_started           : bool       = false
var match_ended             : bool       = false
var sudden_death_triggered  : bool       = false
var death_count             : Dictionary = {1: 0, 2: 0}

const SPAWN_POSITIONS := {
	1: Vector3(-3.0, 2.0, 0.0),
	2: Vector3( 3.0, 2.0, 0.0),
}
const RESPAWN_POSITIONS := {
	1: Vector3(-3.0, 4.0, 0.0),
	2: Vector3( 3.0, 4.0, 0.0),
}


# ─── Enregistrement ──────────────────────────────────────────────────────────

func register_player(player_id: int, node: CharacterBody3D) -> void:
	players[player_id] = node


# ─── Cycle de vie d'un joueur ────────────────────────────────────────────────

func player_died(player_id: int) -> void:
	if game_state != "fighting":
		return
	var hud = get_tree().get_first_node_in_group("hud")
	if hud:
		hud.lose_life(player_id, stocks[player_id] - 1)
	stocks[player_id] -= 1
	if hud:
		hud.show_kill_feed(player_id, stocks[player_id])
	death_count[player_id] += 1
	var death_sfx := "res://assets/sfx/death_%d.mp3" % min(death_count[player_id], 3)
	MusicManager.play_sfx(death_sfx)
	MusicManager.duck_volume(MusicManager.DUCK_DB)
	if not sudden_death_triggered and stocks[1] == 1 and stocks[2] == 1:
		sudden_death_triggered = true
		MusicManager.crossfade_to("res://assets/sfx/sudden_death_2.mp3", 1.0, 1.0)
	if stocks[player_id] > 0:
		respawn(player_id)
	else:
		game_over(player_id)


func respawn(player_id: int) -> void:
	if not players.has(player_id):
		return
	var player: CharacterBody3D = players[player_id]
	var cam   : Camera3D        = get_tree().get_first_node_in_group("camera")

	# Téléporte hors écran, désactive la physique, caméra vers position centrale
	player.global_position    = Vector3(0.0, -50.0, 0.0)
	player.set_physics_process(false)
	player.visible            = false
	if cam and cam.has_method("start_reset"):
		cam.start_reset()

	# Attendre 2 secondes réelles
	await get_tree().create_timer(2.0).timeout
	if not is_instance_valid(player) or game_state != "fighting":
		return

	# Pause avant réapparition
	await get_tree().create_timer(0.5).timeout
	if not is_instance_valid(player) or game_state != "fighting":
		return

	# Repositionne au point de respawn aérien
	player.global_position    = RESPAWN_POSITIONS[player_id]
	player.velocity           = Vector3.ZERO
	player.damage_percent     = 0.0
	player.is_dead            = false
	player.visible            = true
	player.set_physics_process(true)
	MusicManager.restore_volume(MusicManager.DUCK_DB)

	# Invincibilité de respawn + focus caméra sur le joueur
	if player.has_method("start_respawn_invincibility"):
		player.start_respawn_invincibility(4.0)
	if cam and cam.has_method("start_focus"):
		cam.start_focus(player)


func reset() -> void:
	Engine.time_scale       = 1.0
	game_state              = "fighting"
	stocks                  = {1: 3, 2: 3}
	players                 = {}
	round_started           = false
	match_ended             = false
	sudden_death_triggered  = false
	death_count             = {1: 0, 2: 0}


func game_over(loser_id: int) -> void:
	game_state = "game_over"
	winner_id  = 2 if loser_id == 1 else 1
	MusicManager.stop_music(3.0)

	var cam : Camera3D = get_tree().get_first_node_in_group("camera")
	if cam and cam.has_method("start_reset"):
		cam.start_reset()   # recentre la caméra pendant le ralenti

	Engine.time_scale = 0.2
	await get_tree().create_timer(4.0 * Engine.time_scale).timeout
	Engine.time_scale = 1.0

	var loser  : CharacterBody3D = players.get(loser_id)
	var winner : CharacterBody3D = players.get(winner_id)

	if is_instance_valid(loser):
		loser.visible = false
		loser.set_physics_process(false)
		loser.set_collision_layer(0)
		loser.set_collision_mask(0)

	var bg = get_tree().get_first_node_in_group("background")
	if is_instance_valid(bg) and bg is Sprite3D:
		bg.texture = load("res://assets/textures/maps/map_01_bg1.png")

	if is_instance_valid(winner):
		winner.global_position = Vector3(0.0, 3.0, 0.0)
		winner.velocity        = Vector3.ZERO
	MusicManager.play_music("res://assets/sfx/win_music.mp3", 1.0)

	match_ended = true   # après téléportation — déclenche rotation + emote dans _update_animation

	var hud = get_tree().get_first_node_in_group("hud")
	if is_instance_valid(hud):
		hud.visible = false
	var dbg = get_tree().get_first_node_in_group("debug_overlay")
	if is_instance_valid(dbg):
		dbg.visible = false

	if cam and cam.has_method("start_winner_focus"):
		cam.start_winner_focus(winner)

	var ui = get_tree().get_first_node_in_group("game_over_ui")
	if ui and ui.has_method("show_result"):
		ui.show_result(winner_id)
