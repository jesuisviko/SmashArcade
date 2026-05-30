extends Camera3D

const FOV_MIN         := 60.0
const FOV_MAX         := 85.0
const DIST_ZOOM_START := 5.0    # distance minimale avant que le FOV commence à augmenter
const DIST_MAX        := 10.0   # distance de référence pour le zoom max
const CAM_THRESHOLD   := 2.0    # déplacement X minimal du point médian avant de bouger la caméra
const X_CLAMP         := 4.0    # limite absolue du déplacement horizontal de la caméra
const LERP_SPEED      := 0.005
const FIXED_Y         := 4.0
const FIXED_Z         := 8.0


func _process(_delta: float) -> void:
	var players := GameManager.players
	if not (players.has(1) and players.has(2)):
		return

	var p1: CharacterBody3D = players[1]
	var p2: CharacterBody3D = players[2]

	var p1x := p1.global_position.x
	var p2x := p2.global_position.x

	# Cible X : suit le point médian si > seuil, clampée aux limites de la map
	var mid_x    := (p1x + p2x) * 0.5
	var target_x := clampf(mid_x if abs(mid_x) > CAM_THRESHOLD else 0.0, -X_CLAMP, X_CLAMP)

	# Spread : distance entre les joueurs OU éloignement du joueur le plus excentré
	# → le FOV réagit aussi quand un joueur sort de la zone de la caméra
	var dist_between   : float = abs(p1x - p2x)
	var dist_from_edge : float = max(abs(p1x), abs(p2x)) * 1.5
	var spread         : float = max(dist_between, dist_from_edge)

	var zoom_range: float = DIST_MAX - DIST_ZOOM_START
	var t: float          = clampf((spread - DIST_ZOOM_START) / zoom_range, 0.0, 1.0)
	var target_fov: float = lerp(FOV_MIN, FOV_MAX, t)

	position.x = lerp(position.x, target_x, LERP_SPEED)
	position.y = FIXED_Y
	position.z = FIXED_Z
	fov        = lerp(fov, target_fov, LERP_SPEED)
