# AUTOLOAD À ENREGISTRER dans Project Settings → AutoLoad :
#   Nom : GameManager   Chemin : res://scripts/systems/game_manager.gd

extends Node

var stocks     : Dictionary = {1: 3, 2: 3}
var players    : Dictionary = {}
var game_state : String     = "fighting"

const SPAWN_POSITIONS := {
	1: Vector3(-2.0, 3.0, 0.0),
	2: Vector3( 2.0, 3.0, 0.0),
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
	player.global_position = SPAWN_POSITIONS[player_id]
	player.velocity        = Vector3.ZERO
	player.damage_percent  = 0.0
	player.is_dead         = false


func game_over(loser_id: int) -> void:
	game_state    = "game_over"
	var winner_id := 2 if loser_id == 1 else 1
	print("[GAME OVER] Joueur %d gagne !" % winner_id)
