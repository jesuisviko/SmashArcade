extends Node3D

# Connecte les zones de mort en _ready et gère les sorties de map.
# Chaque Area3D (BottomZone, LeftZone, RightZone, TopZone) est dans le
# nœud enfant "DeathZones". Elles ont collision_mask=1 pour détecter
# les joueurs (collision_layer=1).

func _ready() -> void:
	for zone: Area3D in $DeathZones.get_children():
		zone.body_entered.connect(_on_death_zone_entered)


func _on_death_zone_entered(body: Node3D) -> void:
	# Vérifie que c'est bien un personnage joueur
	var pid: Variant = body.get("player_id")
	if pid == null:
		return
	# Évite le double-appel si le joueur est déjà mort
	if body.get("is_dead"):
		return
	if body.has_method("die"):
		body.die()
	GameManager.player_died(pid)
