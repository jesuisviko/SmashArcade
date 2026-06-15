extends CharacterBody3D
class_name BaseCharacter

enum State {
	IDLE, RUN, JUMP, FALL,
	ATTACK_LIGHT, ATTACK_STRONG, ATTACK_UP, ATTACK_DOWN,
	ATTACK_AIR_LIGHT, ATTACK_AIR_STRONG, ATTACK_AIR_UP, ATTACK_AIR_DOWN,
	PARRY, HITSTUN, RESPAWNING, CROUCH,
}

const GRAVITY    := 24.0
const JUMP_SPEED := 10.2
const MAX_JUMPS  := 2

@export var player_id               : int   = 1
@export var char_height                     := 1.4
@export var char_radius                     := 0.35
@export var char_speed                      := 4.68
@export var weight_multiplier               := 1.0
@export var attack_light_damage             := 5.0
@export var attack_strong_damage            := 12.0
@export var attack_light_knockback          := 0.5
@export var attack_strong_knockback         := 3.0
@export var attack_duration                 := 0.2
@export var parry_duration                  := 1.4
@export var parry_cooldown                  := 6.0
@export var debug_mode              : bool  = false

var state            : State = State.IDLE
var jumps_left       : int   = MAX_JUMPS
var damage_percent   : float = 0.0
var is_dead          : bool  = false
var is_invincible    : bool  = false
var facing_direction : float = 1.0   # 1.0 = droite, -1.0 = gauche
var _model_node      : Node3D = null

var _up_was_pressed  : bool  = false
var _turn_timer            : float = 0.0   # pivot auto en cours — verrouille la direction
var _turn_target_direction : float = 0.0   # direction cible du pivot (sign)
var _air_up_used     : bool  = false   # un seul ATTACK_AIR_UP avant de retoucher le sol
var _air_down_used   : bool  = false   # un seul ATTACK_AIR_DOWN avant de retoucher le sol
var _attack_timer    : float = 0.0
var _parry_timer          : float = 0.0
var _parry_cooldown_timer : float = 0.0
var _parry_light_hits     : int   = 0
var _post_hitstun_grace    : float = 0.0
var _respawn_timer         : float = 0.0
var _blink_timer           : float = 0.0
var _soft_drop_timer          : float = 0.0
var _hit_delay_timer          : float = 0.0
var _down_attack_phase        : int   = 0     # 0=inactif, 1=gel, 2=plongée
var _down_attack_freeze_timer : float = 0.0
var _attack_started_on_floor  : bool  = false

var combo_count          : int     = 0
var _combo_window_timer  : float   = 0.0    # 1 s pour compter un coup dans le combo
var _freeze_timer        : float   = 0.0    # gel du hitstun — knockback appliqué à expiration
var _pending_knockback   : Vector3 = Vector3.ZERO
var _knockback_gravity_timer : float = 0.0   # >0 = gravité réduite (Phase 1, 2 s après un knockback)
var _post_knockback_landing  : bool  = true  # false du lancement du knockback jusqu'à l'atterrissage
var _knockback_momentum           : float = 0.0   # magnitude horizontale stockée au lancement
var _was_on_floor                 : bool  = false # front montant d'atterrissage
var _hitstun_preserve_velocity    : bool  = false # true = gravité active + velocity conservée pendant HITSTUN

var _multihit_tick_timer      : float           = 0.0
var _is_juggled               : bool            = false
var _juggle_timer             : float           = 0.0
var _juggle_attacker          : BaseCharacter   = null

# Meshes de debug (créés uniquement si debug_mode = true)
var _debug_attack_mesh : MeshInstance3D = null
var _debug_hurt_mesh   : MeshInstance3D = null
var _debug_parry_mesh  : MeshInstance3D = null

# Configs d'attaque par état — peuplées par les sous-classes dans _ready()
var _attack_configs       : Dictionary = {}
var _active_attack_config : Dictionary = {}

@onready var _col_shape    : CollisionShape3D = $CollisionShape3D
@onready var _mesh         : MeshInstance3D   = $MeshInstance3D
@onready var _attack_hitbox: Area3D           = $AttackHitbox
@onready var _attack_shape : CollisionShape3D = $AttackHitbox/CollisionShape3D
@onready var _hurtbox      : Area3D           = $HurtBox
@onready var _hurt_shape   : CollisionShape3D = $HurtBox/CollisionShape3D


# ─── Init ────────────────────────────────────────────────────────────────────

func _ready() -> void:
	_model_node = get_node_or_null("Model")
	_apply_size()
	GameManager.register_player(player_id, self)
	_attack_hitbox.area_entered.connect(_on_attack_hitbox_area_entered)


func _apply_size() -> void:
	var half_h := char_height / 2.0

	var body_cap := CapsuleShape3D.new()
	body_cap.radius = char_radius
	body_cap.height = char_height
	_col_shape.shape    = body_cap
	_col_shape.position = Vector3(0.0, half_h, 0.0)

	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = char_radius
	body_mesh.height = char_height
	_mesh.mesh     = body_mesh
	_mesh.position = Vector3(0.0, half_h, 0.0)

	var hurt_cap := CapsuleShape3D.new()
	hurt_cap.radius = char_radius * 1.05
	hurt_cap.height = char_height
	_hurt_shape.shape = hurt_cap
	_hurtbox.position = Vector3(0.0, half_h, 0.0)

	# AttackHitbox — boîte aplatie, repositionnée par les sous-classes
	var attack_box := BoxShape3D.new()
	attack_box.size = Vector3(char_radius * 2.0, char_height * 0.4, 1.0)
	_attack_shape.shape = attack_box

	# Les joueurs se traversent — ils ne détectent que les layers des plateformes
	collision_layer = 1
	collision_mask  = 6   # layer 2 (hard) | layer 4 (soft) = 2 + 4

	if debug_mode:
		_setup_debug_meshes()


func _setup_debug_meshes() -> void:
	# ── AttackHitbox : boîte colorée, cachée par défaut ──────────────────────
	_debug_attack_mesh = MeshInstance3D.new()
	var ab    := BoxMesh.new()
	# XY = dimensions du shape ; Z = shape.size.z * node_scale.z = 1.0 * 0.1
	ab.size    = Vector3(char_radius * 2.0, char_height * 0.4, 0.1)
	_debug_attack_mesh.mesh = ab
	var mat_atk            := StandardMaterial3D.new()
	mat_atk.transparency    = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_atk.shading_mode    = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_atk.albedo_color    = Color(1.0, 1.0, 0.0, 0.55)   # jaune par défaut
	_debug_attack_mesh.material_override = mat_atk
	_debug_attack_mesh.visible           = false
	_attack_hitbox.add_child(_debug_attack_mesh)

	# ── HurtBox : capsule verte, toujours visible ─────────────────────────────
	_debug_hurt_mesh = MeshInstance3D.new()
	var hm   := CapsuleMesh.new()
	hm.radius = char_radius * 1.05
	hm.height = char_height
	_debug_hurt_mesh.mesh = hm
	var mat_hurt           := StandardMaterial3D.new()
	mat_hurt.transparency   = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_hurt.shading_mode   = BaseMaterial3D.SHADING_MODE_UNSHADED
	# P1 = vert, P2 = bleu
	mat_hurt.albedo_color   = Color(0.0, 1.0, 0.0, 0.28) if player_id == 1 else Color(0.2, 0.4, 1.0, 0.28)
	_debug_hurt_mesh.material_override = mat_hurt
	_hurtbox.add_child(_debug_hurt_mesh)

	# ── Parry : sphère bleue semi-transparente, cachée par défaut ────────────
	_debug_parry_mesh = MeshInstance3D.new()
	var sm   := SphereMesh.new()
	sm.radius = char_radius * 1.5
	sm.height = char_radius * 3.0
	_debug_parry_mesh.mesh     = sm
	var mat_parry              := StandardMaterial3D.new()
	mat_parry.transparency      = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_parry.shading_mode      = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_parry.albedo_color      = Color(0.2, 0.4, 1.0, 0.3)
	_debug_parry_mesh.material_override = mat_parry
	_debug_parry_mesh.position          = Vector3(0.0, char_height / 2.0, 0.0)
	_debug_parry_mesh.visible           = false
	add_child(_debug_parry_mesh)


# ─── Boucle principale ───────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	var input := InputManager.get_input(player_id)
	_handle_attack_input(input)
	_tick_timers(delta)
	_apply_gravity(delta)
	_apply_movement(input, delta)
	_update_soft_collision()   # masque collision avant move_and_slide
	if _is_juggled and is_instance_valid(_juggle_attacker):
		velocity          = Vector3.ZERO
		global_position.y = _juggle_attacker.global_position.y
		global_position.x = _juggle_attacker.global_position.x + 0.3 * _juggle_attacker.facing_direction
		position.z        = 0.0
	move_and_slide()
	position.z = 0.0
	_update_state(input)


# ─── Timers ──────────────────────────────────────────────────────────────────

func _tick_timers(delta: float) -> void:
	if _attack_timer > 0.0:
		_attack_timer -= delta
		if _attack_timer <= 0.0:
			_end_attack()

	if state == State.PARRY and _parry_timer > 0.0:
		_parry_timer -= delta
		if _parry_timer <= 0.0:
			_set_state(State.IDLE)
			_parry_cooldown_timer = parry_cooldown

	if _parry_cooldown_timer > 0.0:
		_parry_cooldown_timer -= delta

	if _soft_drop_timer > 0.0:
		_soft_drop_timer -= delta

	if _turn_timer > 0.0:
		_turn_timer -= delta

	# Délai avant activation de la hitbox
	if _hit_delay_timer > 0.0:
		_hit_delay_timer -= delta
		if _hit_delay_timer <= 0.0 and _is_attacking():
			_attack_shape.disabled    = false
			_attack_hitbox.monitoring = true
			if debug_mode and _debug_attack_mesh:
				_debug_attack_mesh.visible = true

	# ATTACK_AIR_DOWN phase 1 → phase 2 (gel → plongée)
	if _down_attack_phase == 1:
		_down_attack_freeze_timer -= delta
		if _down_attack_freeze_timer <= 0.0:
			_down_attack_phase        = 2
			velocity.y                = -JUMP_SPEED
			_attack_shape.disabled    = false
			_attack_hitbox.monitoring = true
			if debug_mode and _debug_attack_mesh:
				_debug_attack_mesh.visible = true

	# Combo window — décompte simple, pas d'action à l'expiration
	if _combo_window_timer > 0.0:
		_combo_window_timer = max(0.0, _combo_window_timer - delta)

	# Gel du hitstun — à expiration : lance le personnage avec le knockback stocké
	if _freeze_timer > 0.0:
		_freeze_timer -= delta
		if _freeze_timer <= 0.0 and state == State.HITSTUN:
			if not _hitstun_preserve_velocity:
				velocity   = _pending_knockback / weight_multiplier
				velocity.z = 0.0
			_hitstun_preserve_velocity = false
			combo_count         = 0
			_combo_window_timer = 0.0
			# Knockback appliqué → gravité réduite (Phase 1) jusqu'à l'atterrissage
			if _pending_knockback != Vector3.ZERO:
				_knockback_gravity_timer = 2.0
				_post_knockback_landing  = false
				_knockback_momentum      = abs(_pending_knockback.x / weight_multiplier)
			_end_hitstun()

	# Multi-hit ATTACK_AIR_UP — piloté par timer, indépendant de area_entered
	if state == State.ATTACK_AIR_UP and not _attack_shape.disabled:
		_multihit_tick_timer -= delta
		if _multihit_tick_timer <= 0.0:
			_air_up_multihit()
			_multihit_tick_timer = 0.1

	# Juggle — si la fenêtre expire sans nouveau coup : retombe librement, pas de knockback
	if _juggle_timer > 0.0:
		_juggle_timer -= delta
		if _juggle_timer <= 0.0 and _is_juggled:
			_is_juggled      = false
			_juggle_attacker = null
			_set_state(State.FALL)

	if state == State.RESPAWNING:
		_respawn_timer -= delta
		_blink_timer   -= delta
		if _blink_timer <= 0.0:
			_mesh.visible = not _mesh.visible
			_blink_timer  = 0.1
		if _respawn_timer <= 0.0:
			_end_respawning()


func _end_hitstun() -> void:
	_post_hitstun_grace = 0.3
	if debug_mode and _debug_hurt_mesh:
		var mat := _debug_hurt_mesh.material_override as StandardMaterial3D
		mat.albedo_color = Color(0.0, 1.0, 0.0, 0.28) if player_id == 1 else Color(0.2, 0.4, 1.0, 0.28)
	_set_state(State.JUMP if velocity.y > 0.0 else State.FALL)


func _end_respawning() -> void:
	is_invincible  = false
	_respawn_timer = 0.0
	_mesh.visible  = true
	_set_state(State.FALL)


# ─── Gestion des attaques ────────────────────────────────────────────────────

func _handle_attack_input(input: Dictionary) -> void:
	if state == State.HITSTUN or _is_attacking() or state == State.PARRY or state == State.RESPAWNING:
		return

	if input["attack_up"] and is_on_floor():
		if not _air_up_used:
			_start_attack(State.ATTACK_UP)
	elif input["attack_light"]:
		var s: State = State.ATTACK_LIGHT
		if is_on_floor():
			if input["down"]: s = State.ATTACK_DOWN
			_start_attack(s)
		else:
			if   input["up"]:   s = State.ATTACK_AIR_UP
			elif input["down"]: s = State.ATTACK_AIR_DOWN
			else:               s = State.ATTACK_AIR_LIGHT
			if s == State.ATTACK_AIR_UP and _air_up_used:
				return
			if s == State.ATTACK_AIR_DOWN and _air_down_used:
				return
			_start_attack(s)
			if   s == State.ATTACK_AIR_UP:   _air_up_used   = true
			elif s == State.ATTACK_AIR_DOWN: _air_down_used = true

	elif input["attack_strong"]:
		var s: State = State.ATTACK_STRONG
		if is_on_floor():
			if input["down"]: s = State.ATTACK_DOWN
			_start_attack(s)
		else:
			if   input["up"]: s = State.ATTACK_AIR_UP
			else:             s = State.ATTACK_AIR_STRONG
			if s == State.ATTACK_AIR_UP and _air_up_used:
				return
			_start_attack(s)
			if s == State.ATTACK_AIR_UP: _air_up_used = true

	elif input["parry"] and _parry_cooldown_timer <= 0.0 and state != State.HITSTUN and state != State.PARRY:
		_set_state(State.PARRY)
		_parry_timer      = parry_duration
		_parry_light_hits = 0


func _start_attack(new_state: State) -> void:
	_set_state(new_state)
	_attack_started_on_floor  = is_on_floor()
	_active_attack_config     = {}
	_hit_delay_timer          = 0.0
	_down_attack_phase        = 0
	_attack_shape.disabled    = true
	_attack_hitbox.monitoring = false
	if debug_mode and _debug_attack_mesh:
		_debug_attack_mesh.visible = false

	var state_key : String = State.find_key(new_state)
	if _attack_configs.has(state_key):
		var cfg : Dictionary = _attack_configs[state_key]
		var pos : Vector3    = cfg.get("position", Vector3.ZERO)
		pos.x               *= facing_direction
		_attack_hitbox.position = pos
		var box := _attack_shape.shape as BoxShape3D
		if box:
			box.size = cfg.get("size", box.size)
		_attack_timer         = cfg.get("duration", attack_duration)
		_active_attack_config = cfg

		if cfg.has("velocity_y"):
			velocity.y = cfg["velocity_y"]

		if new_state == State.ATTACK_AIR_DOWN:
			# Phase 1 : gel 0.4 s, hitbox inactive — timer géré par le système de phases
			_down_attack_phase        = 1
			_down_attack_freeze_timer = 0.4
			_attack_timer             = 99.0
			velocity                  = Vector3.ZERO
		elif new_state == State.ATTACK_AIR_UP:
			# Montée linéaire 0.8s — gravité coupée, hitbox active immédiatement, horizontal libre
			var jump_height : float   = (JUMP_SPEED * JUMP_SPEED) / (2.0 * GRAVITY)
			velocity.y                = jump_height * 0.65 / 0.8 * 1.25 * 1.8
			_attack_timer             = 0.8
			_multihit_tick_timer      = 0.0
			_attack_shape.disabled    = false
			_attack_hitbox.monitoring = true
			if debug_mode and _debug_attack_mesh:
				_debug_attack_mesh.visible = true
		elif cfg.get("hit_delay", 0.0) > 0.0:
			_hit_delay_timer = cfg["hit_delay"]
			# hitbox reste désactivée jusqu'à expiration du délai
		else:
			_attack_shape.disabled    = false
			_attack_hitbox.monitoring = true
			if debug_mode and _debug_attack_mesh:
				_debug_attack_mesh.visible = true

		if debug_mode and _debug_attack_mesh:
			var box_mesh := _debug_attack_mesh.mesh as BoxMesh
			if box_mesh:
				box_mesh.size = cfg.get("size", box_mesh.size)
			var mat       := _debug_attack_mesh.material_override as StandardMaterial3D
			var is_strong := new_state in [State.ATTACK_STRONG, State.ATTACK_AIR_STRONG]
			mat.albedo_color = Color(1.0, 0.0, 0.0, 0.55) if is_strong else Color(1.0, 1.0, 0.0, 0.55)
	else:
		_attack_timer = attack_duration
		match new_state:
			State.ATTACK_UP, State.ATTACK_AIR_UP:
				_attack_hitbox.position = Vector3(0.0, char_height * 0.8, 0.0)
			State.ATTACK_DOWN:
				_attack_hitbox.position = Vector3(0.0, char_height * 0.2, 0.0)
			State.ATTACK_AIR_DOWN:
				_attack_hitbox.position = Vector3(0.0, -0.5, 0.0)
			_:
				_attack_hitbox.position = Vector3(facing_direction * (char_radius + 0.3), char_height * 0.5, 0.0)
		_attack_shape.disabled    = false
		_attack_hitbox.monitoring = true
		if debug_mode and _debug_attack_mesh:
			var mat := _debug_attack_mesh.material_override as StandardMaterial3D
			if new_state in [State.ATTACK_STRONG, State.ATTACK_AIR_STRONG]:
				mat.albedo_color = Color(1.0, 0.0, 0.0, 0.55)
			else:
				mat.albedo_color = Color(1.0, 1.0, 0.0, 0.55)
			_debug_attack_mesh.visible = true


func _end_attack() -> void:
	_attack_timer            = 0.0
	_attack_started_on_floor = false
	# ATTACK_AIR_UP : libère les cibles jugglées — le dernier hit (apply_hit) les
	# propulse via la résolution normale du hitstun (_freeze_timer)
	if state == State.ATTACK_AIR_UP:
		for p in GameManager.players.values():
			var bc := p as BaseCharacter
			if bc == null or bc == self:
				continue
			if bc._is_juggled and bc._juggle_attacker == self:
				bc._is_juggled      = false
				bc._juggle_attacker = null
				bc._juggle_timer    = 0.0

	_attack_hitbox.monitoring = false
	_attack_shape.disabled    = true
	_hit_delay_timer          = 0.0
	_down_attack_phase        = 0
	if debug_mode and _debug_attack_mesh:
		_debug_attack_mesh.visible = false
	if not (state == State.HITSTUN or state == State.PARRY):
		_set_state(State.IDLE)


# ATTACK_AIR_UP — un tick de multi-hit : frappe toutes les cibles présentes dans la
# hitbox et rafraîchit leur fenêtre de juggle. Appelé par _tick_timers, pas par area_entered.
func _air_up_multihit() -> void:
	if _attack_shape.disabled:
		return
	if state == State.HITSTUN:
		return
	var dmg   : float   = _active_attack_config.get("damage",    attack_light_damage)
	var kb    : float   = _active_attack_config.get("knockback", attack_light_knockback)
	var angle : Vector2 = _active_attack_config.get("knockback_angle", Vector2(0.0, 1.0))
	for area in _attack_hitbox.get_overlapping_areas():
		if area.name != "HurtBox":
			continue
		var target := area.get_parent() as BaseCharacter
		if target == null or target == self or target.is_dead:
			continue
		CombatSystem.apply_hit(self, target, dmg, kb, angle)
		target._is_juggled      = true
		target._juggle_attacker = self
		target._juggle_timer    = 0.35
		if target.has_method("flash_hurtbox"):
			target.flash_hurtbox()


func _is_attacking() -> bool:
	return state in [
		State.ATTACK_LIGHT, State.ATTACK_STRONG,
		State.ATTACK_UP,    State.ATTACK_DOWN,
		State.ATTACK_AIR_LIGHT,  State.ATTACK_AIR_STRONG,
		State.ATTACK_AIR_UP,     State.ATTACK_AIR_DOWN,
	]


# ─── Parry ───────────────────────────────────────────────────────────────────


# ─── Physique ────────────────────────────────────────────────────────────────

func _apply_gravity(delta: float) -> void:
	if state == State.RESPAWNING:
		velocity.y = 0.0
		velocity.x = 0.0
		return
	if state == State.ATTACK_AIR_DOWN and _down_attack_phase >= 1:
		return   # gel (phase 1) et plongée (phase 2) : pas de gravité
	if state == State.ATTACK_AIR_UP:
		return   # montée linéaire contrôlée pendant 0.8s
	if _is_juggled:
		velocity = Vector3.ZERO
		return
	if state == State.HITSTUN and not _hitstun_preserve_velocity:
		return   # velocity figée à zéro pendant le gel — gravité reprend à l'expiration du _freeze_timer

	# Gravité réduite après un knockback (timer armé dans _tick_timers)
	if not is_on_floor():
		if _knockback_gravity_timer > 0.0:
			# Phase 1 : 2 s après le knockback → gravité / 2
			_knockback_gravity_timer -= delta
			velocity.y -= (GRAVITY / 2.0) * delta
			return
		elif not _post_knockback_landing and state == State.FALL:
			# Phase 2 : timer écoulé, descente jusqu'au sol → gravité / 1.5
			velocity.y -= (GRAVITY / 1.5) * delta
			return

	if is_on_floor():
		if velocity.y < 0.0:
			velocity.y = 0.0
		jumps_left = MAX_JUMPS
		if not _post_knockback_landing:
			# Fin de la séquence de knockback : réarme la gravité normale
			_post_knockback_landing  = true
			_knockback_gravity_timer = 0.0
	else:
		velocity.y -= GRAVITY * delta


func _apply_movement(input: Dictionary, delta: float) -> void:
	# Front montant d'atterrissage : friction instantanée 80% sur le momentum knockback
	if is_on_floor() and not _was_on_floor and _knockback_momentum > 0.0:
		_knockback_momentum *= 0.2
		velocity.x          *= 0.2
	_was_on_floor = is_on_floor()

	# Décélération rapide au sol pendant une attaque — le personnage freine mais ne peut pas se déplacer
	if (state == State.ATTACK_LIGHT or state == State.ATTACK_STRONG \
			or state == State.ATTACK_UP or state == State.ATTACK_DOWN) and is_on_floor():
		velocity.x      = lerp(velocity.x, 0.0, 0.3)
		_up_was_pressed = input["up"]
		return
	if state == State.PARRY:
		velocity.x      = lerp(velocity.x, 0.0, 0.3)
		_up_was_pressed = input["up"]
		return
	if _is_juggled or state == State.HITSTUN or state == State.RESPAWNING or state == State.CROUCH:
		_up_was_pressed = input["up"]
		return
	# ATTACK_AIR_UP : mouvement horizontal libre, saut bloqué — tous les autres états attaquants bloqués
	if _is_attacking() and state != State.ATTACK_AIR_UP:
		_up_was_pressed = input["up"]
		return

	var raw_dir := int(input["right"]) - int(input["left"])   # input brut : touche tenue ?
	var dir     := raw_dir

	# Retournement auto : on demande la direction opposée au facing courant.
	if _turn_timer <= 0.0 and raw_dir != 0 and sign(raw_dir) != sign(facing_direction):
		_turn_timer            = 0.2
		_turn_target_direction = float(sign(raw_dir))

	# Pendant le pivot : facing/rotation visent toujours la cible ; le déplacement
	# horizontal n'a lieu que si la touche est maintenue (sinon décélération sur place).
	var turning := _turn_timer > 0.0
	if turning:
		dir = int(_turn_target_direction)

	var target_speed := float(dir) * char_speed
	if _knockback_momentum > 0.0:
		var resistance  : float = clamp(_knockback_momentum / char_speed, 0.5, 8.0)
		var lerp_factor : float = 0.015 / resistance
		velocity.x          = lerp(velocity.x, target_speed, lerp_factor)
		var decay_rate  : float = max(0.005, 0.03 - damage_percent * 0.0001)
		_knockback_momentum = lerp(_knockback_momentum, 0.0, decay_rate)
		if _knockback_momentum < 0.1:
			_knockback_momentum = 0.0
	elif turning and raw_dir == 0:
		# Pivot visuel en cours mais touche relâchée → décélération sur place
		velocity.x = lerp(velocity.x, 0.0, 0.3)
	else:
		var accel := 12.0 if dir != 0 else 20.0
		var changing_dir := dir != 0 and ((dir > 0 and velocity.x < 0.0) or (dir < 0 and velocity.x > 0.0))
		velocity.x = lerp(velocity.x, target_speed, accel * (0.8 if changing_dir else 1.0) * delta)
	if dir > 0:
		facing_direction = 1.0
	elif dir < 0:
		facing_direction = -1.0
	if _model_node and dir != 0:
		var target_rot := -PI / 2 if facing_direction == -1.0 else PI / 2
		_model_node.rotation.y = lerp_angle(_model_node.rotation.y, target_rot, 0.15)

	# Saut : bloqué pendant ATTACK_AIR_UP
	if state != State.ATTACK_AIR_UP:
		if input["up"] and not _up_was_pressed and jumps_left > 0:
			jump()
	_up_was_pressed = input["up"]


# ─── State machine ───────────────────────────────────────────────────────────

func _update_state(input: Dictionary) -> void:
	if state == State.RESPAWNING:
		var any_input: bool = (input["left"] or input["right"] or input["up"] or input["down"]
				or input["attack_light"] or input["attack_strong"] or input["parry"])
		if any_input:
			_end_respawning()
		return
	# ATTACK_AIR_DOWN : atterrissage pendant la plongée → fin d'attaque normale
	if state == State.ATTACK_AIR_DOWN and _down_attack_phase >= 1 and is_on_floor():
		_down_attack_phase = 0
		_end_attack()
		return
	if _is_attacking() or state == State.HITSTUN or state == State.PARRY:
		return
	# CROUCH : maintenu tant que down est pressé et qu'on est au sol
	if state == State.CROUCH:
		if not input["down"] or not is_on_floor():
			_set_state(State.IDLE)
		return
	var has_h_input: bool = input["left"] or input["right"]
	var new_state: State  = State.IDLE
	if is_on_floor():
		if input["down"]:
			new_state = State.CROUCH
		elif has_h_input:
			new_state = State.RUN
	else:
		new_state = State.JUMP if velocity.y > 0.0 else State.FALL
	# Retour au sol : réarme les attaques aériennes pour le prochain saut
	if is_on_floor() and (new_state == State.IDLE or new_state == State.RUN):
		_air_up_used   = false
		_air_down_used = false
	_set_state(new_state)


func _set_state(new_state: State) -> void:
	if new_state == state:
		return
	var prev_state := state
	# Sortie de CROUCH : restaurer la CollisionShape
	if state == State.CROUCH and new_state != State.CROUCH:
		_end_crouch()
	if debug_mode and new_state in [
		State.ATTACK_LIGHT,     State.ATTACK_STRONG,
		State.ATTACK_UP,        State.ATTACK_DOWN,
		State.ATTACK_AIR_LIGHT, State.ATTACK_AIR_STRONG,
		State.ATTACK_AIR_UP,    State.ATTACK_AIR_DOWN,
		State.PARRY,
	]:
		print("[P%d] %s → %s" % [player_id, State.find_key(state), State.find_key(new_state)])
	state = new_state
	if debug_mode and _debug_parry_mesh:
		_debug_parry_mesh.visible = (new_state == State.PARRY)
	# Entrée en CROUCH : réduire la CollisionShape et démarrer le soft drop
	if new_state == State.CROUCH:
		_start_crouch(prev_state)


# ─── Hitbox ──────────────────────────────────────────────────────────────────

func _on_attack_hitbox_area_entered(area: Area3D) -> void:
	if state == State.HITSTUN:
		return
	if area.name != "HurtBox":
		return
	var target := area.get_parent()
	if target == self or target.is_dead:
		return

	if debug_mode:
		print("[P%d] HIT signal → %s" % [player_id, target.name])

	# ATTACK_AIR_UP : hits gérés par le timer multi-hit (_air_up_multihit) — ignore area_entered
	if state == State.ATTACK_AIR_UP:
		return

	var damage         : float   = 0.0
	var base_knockback : float   = 0.0
	var knockback_angle: Vector2

	if not _active_attack_config.is_empty():
		damage          = _active_attack_config.get("damage",    attack_light_damage)
		base_knockback  = _active_attack_config.get("knockback", attack_light_knockback)
		if _active_attack_config.has("knockback_angle"):
			knockback_angle = _active_attack_config["knockback_angle"]
		else:
			knockback_angle = Vector2(sign(target.global_position.x - global_position.x), 0.5).normalized()
	else:
		match state:
			State.ATTACK_LIGHT, State.ATTACK_AIR_LIGHT:
				damage          = attack_light_damage
				base_knockback  = attack_light_knockback
				knockback_angle = Vector2(sign(target.global_position.x - global_position.x), 0.5).normalized()
			State.ATTACK_STRONG, State.ATTACK_AIR_STRONG:
				damage          = attack_strong_damage
				base_knockback  = attack_strong_knockback
				knockback_angle = Vector2(sign(target.global_position.x - global_position.x), 0.5).normalized()
			State.ATTACK_UP, State.ATTACK_AIR_UP:
				damage          = attack_light_damage
				base_knockback  = attack_light_knockback
				knockback_angle = Vector2(0.0, 1.0)
			State.ATTACK_DOWN, State.ATTACK_AIR_DOWN:
				damage          = attack_light_damage
				base_knockback  = attack_light_knockback
				knockback_angle = Vector2(0.0, -1.0)
			_:
				return  # état non-attaquant : ignorer

	# Un seul hit par swing
	_attack_hitbox.monitoring = false

	if target.has_method("flash_hurtbox"):
		target.flash_hurtbox()

	var forced_hitstun : float = _active_attack_config.get("forced_hitstun", -1.0)
	CombatSystem.apply_hit(self, target, damage, base_knockback, knockback_angle, forced_hitstun)

	# ATTACK_AIR_DOWN — interrompt la plongée sur hit
	if state == State.ATTACK_AIR_DOWN:
		_attack_timer      = 0.0
		_down_attack_phase = 0
		velocity.y         = 0.0
		_attack_shape.disabled = true
		if debug_mode and _debug_attack_mesh:
			_debug_attack_mesh.visible = false
		_set_state(State.FALL)


# Flash orange sur la hurtbox debug quand le personnage reçoit un hit
func flash_hurtbox() -> void:
	if not debug_mode or _debug_hurt_mesh == null:
		return
	var mat := _debug_hurt_mesh.material_override as StandardMaterial3D
	mat.albedo_color = Color(1.0, 0.35, 0.0, 0.7)   # flash orange
	await get_tree().create_timer(0.15).timeout
	if is_instance_valid(_debug_hurt_mesh):
		# Violet si toujours en HITSTUN, sinon retour à la couleur normale
		if state == State.HITSTUN:
			mat.albedo_color = Color(0.6, 0.2, 0.8, 0.5)
		else:
			mat.albedo_color = Color(0.0, 1.0, 0.0, 0.28) if player_id == 1 else Color(0.2, 0.4, 1.0, 0.28)


# ─── API publique ────────────────────────────────────────────────────────────

func force_cancel_attack() -> void:
	_attack_timer        = 0.0
	_hit_delay_timer     = 0.0
	_multihit_tick_timer = 0.0
	_down_attack_phase   = 0
	_active_attack_config        = {}
	_attack_shape.disabled       = true
	_attack_hitbox.monitoring    = false
	_attack_hitbox.monitorable   = false
	if debug_mode and _debug_attack_mesh:
		_debug_attack_mesh.visible = false
	_is_juggled      = false
	_juggle_attacker = null
	# Casse le soft-lock : sortie d'état explicite (un stun éventuel l'écrasera ensuite)
	if not is_on_floor():
		_set_state(State.FALL)
	else:
		_set_state(State.IDLE)


func jump() -> void:
	if jumps_left <= 0:
		return
	velocity.y = JUMP_SPEED
	jumps_left -= 1
	_set_state(State.JUMP)
	_on_jump()


func _on_jump() -> void:
	pass   # hook virtuel — override dans les sous-classes


# Appelé par combat_system — gèle le personnage puis le lance à expiration de _freeze_timer
func enter_hitstun(knockback_3d: Vector3, duration: float) -> void:
	if _is_attacking():
		_attack_hitbox.monitoring = false
		_attack_shape.disabled    = true
		_attack_timer             = 0.0
		_hit_delay_timer          = 0.0
		_down_attack_phase        = 0
		if debug_mode and _debug_attack_mesh:
			_debug_attack_mesh.visible = false
	velocity           = Vector3.ZERO
	_freeze_timer      = duration        # rafraîchit tout gel en cours
	_pending_knockback = knockback_3d
	_set_state(State.HITSTUN)
	if debug_mode:
		print("[P%d] HITSTUN %.2fs | combo:%d" % [player_id, duration, combo_count])
	if debug_mode and _debug_hurt_mesh:
		var mat := _debug_hurt_mesh.material_override as StandardMaterial3D
		mat.albedo_color = Color(0.6, 0.2, 0.8, 0.5)   # violet = HITSTUN


func die() -> void:
	is_dead = true
	if debug_mode:
		print("[P%d] DEAD" % player_id)


func start_respawn_invincibility(duration: float) -> void:
	is_invincible       = true
	velocity            = Vector3.ZERO
	_respawn_timer      = duration
	_blink_timer        = 0.1
	combo_count         = 0
	_combo_window_timer = 0.0
	_freeze_timer       = 0.0
	_set_state(State.RESPAWNING)


func set_initial_facing(direction: float) -> void:
	facing_direction = direction
	if _model_node:
		_model_node.rotation.y = -PI / 2 if direction == -1.0 else PI / 2


# ─── Soft platforms ──────────────────────────────────────────────────────────

func _start_crouch(prev_state: State) -> void:
	var crouch_h        := char_height * 0.75
	var cap             := _col_shape.shape as CapsuleShape3D
	cap.height          = crouch_h
	_col_shape.position = Vector3(0.0, crouch_h / 2.0, 0.0)
	# Soft drop uniquement si la transition vient d'un état au sol intentionnel
	if prev_state == State.IDLE or prev_state == State.RUN:
		_soft_drop_timer = 0.4


func _end_crouch() -> void:
	var cap             := _col_shape.shape as CapsuleShape3D
	cap.height          = char_height
	_col_shape.position = Vector3(0.0, char_height / 2.0, 0.0)


func _update_soft_collision() -> void:
	if _soft_drop_timer > 0.0:
		collision_mask = 2      # passe à travers les soft platforms (drop volontaire)
	elif velocity.y > 0.0 and not is_on_floor():
		collision_mask = 2      # monte : passe à travers par le bas
	else:
		collision_mask = 6      # 2 (hard) | 4 (soft) : peut atterrir sur tout
