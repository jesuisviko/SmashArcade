extends Camera3D

const FOV_MIN         := 32.0
const FOV_MAX         := 72.0
const DIST_ZOOM_START := 5.0    # distance minimale avant que le FOV commence à augmenter
const DIST_MAX        := 10.0   # distance de référence pour le zoom max
const X_CLAMP         := 8.0    # limite absolue du déplacement horizontal de la caméra
const LERP_SPEED      := 0.08
const FOV_LERP_SPEED  := 0.008
const FIXED_Y         := 2.0   # position Y de repos (reset) et minimum de suivi vertical
const Y_MAX           := 5.0   # Y maximum du suivi vertical
const Y_OFFSET        := 2.25  # décalage au-dessus du point médian Y des joueurs
const Y_LERP          := 0.0025 # vitesse de suivi vertical (lent et doux)
const FIXED_Z         := 8.0

var is_resetting : bool = false
var _reset_hold  : bool = false


func _process(_delta: float) -> void:
	if is_resetting:
		if not _reset_hold:
			position.x = lerp(position.x, 0.0,      0.02)
			position.y = lerp(position.y, FIXED_Y,   0.02)
			position.z = lerp(position.z, FIXED_Z,   0.02)
			fov        = lerp(fov,        FOV_MIN,    0.02)
		return

	var players := GameManager.players
	if not (players.has(1) and players.has(2)):
		return

	var p1: CharacterBody3D = players[1]
	var p2: CharacterBody3D = players[2]

	var p1x := p1.global_position.x
	var p2x := p2.global_position.x
	var p1y := p1.global_position.y
	var p2y := p2.global_position.y

	# Cible X : suit toujours le point médian des joueurs, clampé aux limites de la map
	var mid_x    : float = (p1x + p2x) / 2.0
	var target_x : float = clamp(mid_x, -X_CLAMP, X_CLAMP)

	# Cible Y : suit la moyenne des positions Y + offset, clampée
	var mid_y    := (p1y + p2y) * 0.5
	var target_y := clampf(mid_y + Y_OFFSET, FIXED_Y, Y_MAX)

	# Spread : distance horizontale entre joueurs + composante verticale de la caméra
	# → le FOV s'agrandit proportionnellement quand la caméra monte
	var horizontal_spread : float = abs(p1x - p2x)
	var vertical_spread   : float = max(0.0, (position.y - Y_OFFSET) * 2.0)
	var fov_from_horizontal : float = (horizontal_spread - 5.0) / 5.0
	var fov_from_vertical   : float = (vertical_spread   - 1.0) / 3.0
	var fov_factor          : float = clamp(max(fov_from_horizontal, fov_from_vertical), 0.0, 1.0)
	var target_fov          : float = lerp(32.0, 72.0, fov_factor)

	position.x = lerp(position.x, target_x, LERP_SPEED)
	position.y = lerp(position.y, target_y, Y_LERP)
	position.z = FIXED_Z
	fov        = lerp(fov, target_fov, FOV_LERP_SPEED)


func reset_to_origin() -> void:
	is_resetting = true
	_reset_hold  = false
	# Phase 1 : 2 secondes réelles de lerp vers l'origine (ignore time_scale)
	await get_tree().create_timer(2.0, true).timeout
	# Snap exact pour éviter les dérives sub-pixel
	position    = Vector3(0.0, FIXED_Y, FIXED_Z)
	fov         = FOV_MIN
	# Phase 2 : 2 secondes réelles caméra fixe, ne suit plus les joueurs
	_reset_hold = true
	await get_tree().create_timer(2.0, true).timeout
	is_resetting = false
	_reset_hold  = false


func reset_to_origin_quick(duration: float) -> void:
	is_resetting = true
	_reset_hold  = false
	# Phase 1 : lerp progressif vers l'origine pendant `duration` secondes réelles
	await get_tree().create_timer(duration, true).timeout
	# Snap exact
	position    = Vector3(0.0, FIXED_Y, FIXED_Z)
	fov         = FOV_MIN
	# Phase 2 : caméra fixe pendant `duration` secondes réelles
	_reset_hold = true
	await get_tree().create_timer(duration, true).timeout
	is_resetting = false
	_reset_hold  = false
