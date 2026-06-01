# AUTOLOAD À ENREGISTRER dans Project Settings → AutoLoad :
#   Nom : GameManager   Chemin : res://scripts/systems/game_manager.gd

extends Node

var stocks        : Dictionary = {1: 3, 2: 3}
var players       : Dictionary = {}
var game_state    : String     = "fighting"
var winner_id     : int        = 0
var selected_mode : String     = "3_vies"
var p1_character  : int        = 0
var p2_character  : int        = 1

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
	stocks[player_id] -= 1
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

	# Invincibilité de respawn + focus caméra sur le joueur
	if player.has_method("start_respawn_invincibility"):
		player.start_respawn_invincibility(4.0)
	if cam and cam.has_method("start_focus"):
		cam.start_focus(player)


func reset() -> void:
	Engine.time_scale = 1.0
	game_state = "fighting"
	stocks     = {1: 3, 2: 3}
	players    = {}


func game_over(loser_id: int) -> void:
	game_state = "game_over"
	winner_id  = 2 if loser_id == 1 else 1
	var cam: Camera3D = get_tree().get_first_node_in_group("camera")
	if cam and cam.has_method("reset_to_origin"):
		cam.reset_to_origin()
	Engine.time_scale = 0.2
	await get_tree().create_timer(4.0 * Engine.time_scale).timeout
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file("res://scenes/ui/game_over.tscn")
