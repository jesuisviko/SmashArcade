extends Camera3D

# l'avantage est que on peut modifier ces valeurs sans souci

const FOV_MIN          := 60.0
const FOV_MAX          := 80.0
const DIST_ZOOM_START  := 7.5   # distance minimale avant que le FOV commence à augmenter
const DIST_MAX         := 10.0   # distance de référence pour le zoom max
const CAM_THRESHOLD    := 2.0    # déplacement X minimal du point médian avant de bouger la cqaméra
const LERP_SPEED       := 0.005
const FIXED_Y          := 2.0
const FIXED_Z          := 8.0


func _process(_delta: float) -> void:
	var players := GameManager.players
	if not (players.has(1) and players.has(2)):
		return

	var p1: CharacterBody3D = players[1]
	var p2: CharacterBody3D = players[2]

	# Cible X : suit le point médian uniquement si celui-ci dépasse le seuil
	var mid_x: float    = (p1.global_position.x + p2.global_position.x) * 0.5
	var target_x: float = mid_x if abs(mid_x) > CAM_THRESHOLD else 0.0

	# FOV : ne commence à monter qu'au-delà de DIST_ZOOM_START
	var dist: float       = abs(p1.global_position.x - p2.global_position.x)
	var zoom_range: float = DIST_MAX - DIST_ZOOM_START
	var t: float          = clampf((dist - DIST_ZOOM_START) / zoom_range, 0.0, 1.0)
	var target_fov: float = lerp(FOV_MIN, FOV_MAX, t)

	position.x = lerp(position.x, target_x, LERP_SPEED)
	position.y = FIXED_Y
	position.z = FIXED_Z
	fov        = lerp(fov, target_fov, LERP_SPEED)
