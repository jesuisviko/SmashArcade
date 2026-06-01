extends Camera3D

const FOV_MIN         := 32.0
const FOV_MAX         := 72.0
const DIST_ZOOM_START := 5.0    # distance minimale avant que le FOV commence à augmenter
const DIST_MAX        := 10.0   # distance de référence pour le zoom max
const X_CLAMP         := 8.0    # limite absolue du déplacement horizontal de la caméra
const LERP_SPEED      := 0.08
const FOV_LERP_SPEED  := 0.008
const FIXED_Y         := 2.0    # position Y de repos (snap game_over) et minimum de suivi
const Y_MAX           := 5.0    # Y maximum du suivi vertical
const Y_OFFSET        := 2.25   # décalage au-dessus du point médian Y des joueurs
const Y_LERP          := 0.0025 # vitesse de suivi vertical (lent et doux)
const FIXED_Z         := 8.0

const RESET_TARGET_Y   := 2.25  # cible Y en état RESETTING (= Y_OFFSET)
const RESET_TARGET_FOV := 65.0  # cible FOV en état RESETTING
const RESET_LERP       := 0.08  # vitesse du lerp de réinitialisation

enum CamState { NORMAL, RESETTING, FOCUSING }
var _cam_state    : int   = CamState.NORMAL
var _focus_target         = null  # CharacterBody3D — joueur ciblé en FOCUSING
var _focus_timer  : float = 0.0   # retour à NORMAL après 1 s sans RESPAWNING


func _process(delta: float) -> void:
	match _cam_state:
		CamState.NORMAL:
			_process_normal()
		CamState.RESETTING:
			_process_resetting()
		CamState.FOCUSING:
			_process_focusing(delta)


func _process_normal() -> void:
	var players := GameManager.players
	if not (players.has(1) and players.has(2)):
		return

	var p1: CharacterBody3D = players[1]
	var p2: CharacterBody3D = players[2]

	var p1x := p1.global_position.x
	var p2x := p2.global_position.x
	var p1y := p1.global_position.y
	var p2y := p2.global_position.y

	# Cible X : point médian brut pour le calcul d'overflow ; clamped_x = position réelle caméra
	var mid_x     : float = (p1x + p2x) / 2.0
	var target_x  : float = mid_x
	var clamped_x : float = clamp(target_x, -X_CLAMP, X_CLAMP)
	var overflow  : float = abs(target_x) - X_CLAMP

	# Cible Y : suit la moyenne des positions Y + offset, clampée
	var mid_y    := (p1y + p2y) * 0.5
	var target_y := clampf(mid_y + Y_OFFSET, FIXED_Y, Y_MAX)

	# FOV dynamique : spread horizontal et vertical indépendants
	var horizontal_spread   : float = abs(p1x - p2x)
	var vertical_spread     : float = max(0.0, (position.y - Y_OFFSET) * 2.0)
	var fov_from_horizontal : float = (horizontal_spread - 5.0) / 5.0
	var fov_from_vertical   : float = (vertical_spread   - 1.0) / 3.0
	var fov_factor          : float = clamp(max(fov_from_horizontal, fov_from_vertical), 0.0, 1.0)
	var target_fov          : float = lerp(32.0, 72.0, fov_factor)
	# FOV compensatoire quand le point médian dépasse le clamp latéral
	var overflow_fov        : float = clamp(overflow * 8.0, 0.0, 20.0)
	target_fov = min(target_fov + overflow_fov, 67.0)

	position.x = lerp(position.x, clamped_x, LERP_SPEED)
	position.y = lerp(position.y, target_y, Y_LERP)
	position.z = FIXED_Z
	fov        = lerp(fov, target_fov, FOV_LERP_SPEED)


# Lerp progressif vers la position centrale — actif de la mort jusqu'au respawn
func _process_resetting() -> void:
	position.x = lerp(position.x, 0.0,             RESET_LERP)
	position.y = lerp(position.y, RESET_TARGET_Y,  RESET_LERP)
	position.z = FIXED_Z
	fov        = lerp(fov,        RESET_TARGET_FOV, RESET_LERP)


# Zoom sur le joueur en RESPAWNING ; retour à NORMAL après 1 s ou fin de l'invincibilité
func _process_focusing(delta: float) -> void:
	_focus_timer -= delta

	if not is_instance_valid(_focus_target) or _focus_timer <= 0.0:
		_cam_state    = CamState.NORMAL
		_focus_target = null
		return

	var bc := _focus_target as BaseCharacter
	if bc == null or bc.state != BaseCharacter.State.RESPAWNING:
		_cam_state    = CamState.NORMAL
		_focus_target = null
		return

	position.x = lerp(position.x, _focus_target.global_position.x,            0.15)
	position.y = lerp(position.y, _focus_target.global_position.y + Y_OFFSET, 0.15)
	position.z = FIXED_Z
	fov        = lerp(fov, FOV_MIN, FOV_LERP_SPEED)


# ─── API publique ─────────────────────────────────────────────────────────────

# Appelé à la mort d'un joueur — lerp continu vers la position centrale
func start_reset() -> void:
	_focus_target = null
	_cam_state    = CamState.RESETTING


# Appelé au respawn — la caméra suit le joueur pendant son état RESPAWNING (max 1 s)
func start_focus(player_node: CharacterBody3D) -> void:
	_focus_target = player_node
	_focus_timer  = 1.0
	_cam_state    = CamState.FOCUSING


# Game over : lerp 2 s vers l'origine, snap exact, tenue 2 s
func reset_to_origin() -> void:
	_focus_target = null
	_cam_state    = CamState.RESETTING
	# Phase 1 : lerp progressif (process_always=true pour ignorer la pause)
	await get_tree().create_timer(2.0, true).timeout
	# Snap exact sur la cible RESETTING → _process_resetting() devient stationnaire
	position    = Vector3(0.0, RESET_TARGET_Y, FIXED_Z)
	fov         = RESET_TARGET_FOV
	# Phase 2 : caméra fixe (RESETTING maintient le bloc sur NORMAL)
	await get_tree().create_timer(2.0, true).timeout
	# La scène change après game_over — pas besoin de repasser en NORMAL
