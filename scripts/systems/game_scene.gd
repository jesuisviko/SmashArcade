extends Node3D


func _ready() -> void:
	GameManager.register_player(1, $Player1)
	GameManager.register_player(2, $Player2)
