extends Node3D

const CHAR_SCENES : Dictionary = {
	1: "res://scenes/characters/char_01.tscn",
	2: "res://scenes/characters/base_character.tscn",
	3: "res://scenes/characters/base_character.tscn",
	4: "res://scenes/characters/base_character.tscn",
}

const P1_START := Vector3(-2.0, 2.0, 0.0)
const P2_START := Vector3( 2.0, 2.0, 0.0)


func _ready() -> void:
	GameManager.reset()
	var p1 := _spawn_player(1, GameManager.p1_character, P1_START)
	var p2 := _spawn_player(2, GameManager.p2_character, P2_START)
	# Correction post-instanciation : certains persos hardcodent player_id dans leur _ready(),
	# ce qui peut fausser les registrations. On corrige ici après les deux instanciations.
	p1.player_id = 1
	p2.player_id = 2
	p1.set_initial_facing(1.0)    # P1 regarde à droite
	p2.set_initial_facing(-1.0)   # P2 regarde à gauche
	GameManager.register_player(1, p1)
	GameManager.register_player(2, p2)


func _spawn_player(pid: int, char_id: int, start_pos: Vector3) -> CharacterBody3D:
	# Libère le placeholder de la scène (base_character.tscn statique dans game.tscn)
	var placeholder: Node = get_node_or_null("Player" + str(pid))
	if placeholder:
		placeholder.queue_free()

	var path   : String       = CHAR_SCENES.get(char_id, CHAR_SCENES[2])
	var scene  : PackedScene  = load(path)
	var player : CharacterBody3D = scene.instantiate()
	player.name       = "Player" + str(pid)
	player.debug_mode = true
	add_child(player)
	player.global_position = start_pos
	return player
