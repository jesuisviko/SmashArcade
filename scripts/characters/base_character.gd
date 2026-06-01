extends CharacterBody3D
class_name BaseCharacter

enum State {
	IDLE, RUN, JUMP, FALL,
	ATTACK_LIGHT, ATTACK_STRONG, ATTACK_UP, ATTACK_DOWN,
	ATTACK_AIR_LIGHT, ATTACK_AIR_STRONG, ATTACK_AIR_UP, ATTACK_AIR_DOWN,
	PARRY, HITSTUN, RESPAWNING, CROUCH,
}

const GRAVITY    := 32.0
const JUMP_SPEED := 12.0
const MAX_JUMPS  := 2

@export var player_id               : int   = 1
@export var char_height                     := 1.4
@export var char_radius                     := 0.35
@export var char_speed                      := 8.0
@export var weight_multiplier               := 1.0
@export var attack_light_damage             := 5.0
@export var attack_strong_damage            := 12.0
@export var attack_light_knockback          := 0.5
@export var attack_strong_knockback         := 3.0
@export var attack_duration                 := 0.2
@export var parry_duration                  := 0.15
@export var parry_cooldown                  := 0.5
@export var debug_mode              : bool  = false

var state          : State = State.IDLE
var jumps_left     : int   = MAX_JUMPS
var damage_percent : float = 0.0
var is_dead        : bool  = false
var is_invincible    : bool  = false
var facing_direction : float = 1.0   # 1.0 = droite, -1.0 = gauche

var _up_was_pressed  : bool  = false
var _attack_timer    : float = 0.0
var _parry_timer     : float = 0.0
var _parry_cd_timer  : float = 0.0
var _hitstun_timer         : float = 0.0
var _post_hitstun_grace    : float = 0.0
var _respawn_timer         : float = 0.0
var _blink_timer           : float = 0.0
var _soft_drop_timer       : float = 0.0

# Meshes de debug (créés uniquement si debug_mode = true)
var _debug_attack_mesh : MeshInstance3D = null
var _debug_hurt_mesh   : MeshInstance3D = null

@onready var _col_shape    : CollisionShape3D = $CollisionShape3D
@onready var _mesh         : MeshInstance3D   = $MeshInstance3D
@onready var _attack_hitbox: Area3D           = $AttackHitbox
@onready var _attack_shape : CollisionShape3D = $AttackHitbox/CollisionShape3D
@onready var _hurtbox      : Area3D           = $HurtBox
@onready var _hurt_shape   : CollisionShape3D = $HurtBox/CollisionShape3D


# ─── Init ────────────────────────────────────────────────────────────────────

func _ready() -> void:
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


# ─── Boucle principale ───────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	var input := InputManager.get_input(player_id)
	_tick_timers(delta)
	_handle_attack_input(input)
	_apply_gravity(delta)
	_apply_movement(input, delta)
	_update_soft_collision()   # masque collision avant move_and_slide
	move_and_slide()
	position.z = 0.0           # axe Z verrouillé en permanence
	_update_state(input)


# ─── Timers ──────────────────────────────────────────────────────────────────

func _tick_timers(delta: float) -> void:
	if _attack_timer > 0.0:
		_attack_timer -= delta
		if _attack_timer <= 0.0:
			_end_attack()

	if _parry_timer > 0.0:
		_parry_timer -= delta
		if _parry_timer <= 0.0:
			_end_parry()

	if _parry_cd_timer > 0.0:
		_parry_cd_timer -= delta

	if _hitstun_timer > 0.0:
		_hitstun_timer -= delta
		if _hitstun_timer <= 0.0 and state == State.HITSTUN:
			_end_hitstun()

	if _soft_drop_timer > 0.0:
		_soft_drop_timer -= delta

	if state == State.RESPAWNING:
		_respawn_timer -= delta
		_blink_timer   -= delta
		if _blink_timer <= 0.0:
			_mesh.visible = not _mesh.visible
			_blink_timer  = 0.1
		if _respawn_timer <= 0.0:
			_end_respawning()


func _end_hitstun() -> void:
	# velocity intentionnellement non modifiée — le momentum est conservé
	_post_hitstun_grace = 0.3
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

	if input["attack_light"]:
		var s: State = State.ATTACK_LIGHT
		if is_on_floor():
			if   input["up"]:   s = State.ATTACK_UP
			elif input["down"]: s = State.ATTACK_DOWN
		else:
			if   input["up"]:   s = State.ATTACK_AIR_UP
			elif input["down"]: s = State.ATTACK_AIR_DOWN
			else:               s = State.ATTACK_AIR_LIGHT
		_start_attack(s)

	elif input["attack_strong"]:
		var s: State = State.ATTACK_STRONG
		if is_on_floor():
			if   input["up"]:   s = State.ATTACK_UP
			elif input["down"]: s = State.ATTACK_DOWN
		else:
			s = State.ATTACK_AIR_STRONG
		_start_attack(s)

	elif input["parry"]:
		_start_parry()


func _start_attack(new_state: State) -> void:
	_set_state(new_state)
	_attack_timer             = attack_duration
	_attack_shape.disabled    = false    # ← FIX : shape actif pendant l'attaque
	_attack_hitbox.monitoring = true

	# Positionnement de l'hitbox selon la direction et le type d'attaque
	match new_state:
		State.ATTACK_UP, State.ATTACK_AIR_UP:
			_attack_hitbox.position = Vector3(0.0, char_height * 0.8, 0.0)
		State.ATTACK_DOWN:
			_attack_hitbox.position = Vector3(0.0, char_height * 0.2, 0.0)
		State.ATTACK_AIR_DOWN:
			_attack_hitbox.position = Vector3(0.0, -0.5, 0.0)
		_:
			_attack_hitbox.position = Vector3(facing_direction * (char_radius + 0.3), char_height * 0.5, 0.0)

	if debug_mode and _debug_attack_mesh:
		var mat := _debug_attack_mesh.material_override as StandardMaterial3D
		if new_state in [State.ATTACK_STRONG, State.ATTACK_AIR_STRONG]:
			mat.albedo_color = Color(1.0, 0.0, 0.0, 0.55)   # rouge = strong
		else:
			mat.albedo_color = Color(1.0, 1.0, 0.0, 0.55)   # jaune = light/directionnel
		_debug_attack_mesh.visible = true


func _end_attack() -> void:
	_attack_hitbox.monitoring = false
	_attack_shape.disabled    = true     # ← FIX : shape inactif hors attaque
	if debug_mode and _debug_attack_mesh:
		_debug_attack_mesh.visible = false
	if not (state == State.HITSTUN or state == State.PARRY):
		_set_state(State.IDLE)


func _is_attacking() -> bool:
	return state in [
		State.ATTACK_LIGHT, State.ATTACK_STRONG,
		State.ATTACK_UP,    State.ATTACK_DOWN,
		State.ATTACK_AIR_LIGHT,  State.ATTACK_AIR_STRONG,
		State.ATTACK_AIR_UP,     State.ATTACK_AIR_DOWN,
	]


# ─── Parry ───────────────────────────────────────────────────────────────────

func _start_parry() -> void:
	if _parry_cd_timer > 0.0:
		return
	_set_state(State.PARRY)
	is_invincible = true
	_parry_timer  = parry_duration


func _end_parry() -> void:
	is_invincible   = false
	_parry_cd_timer = parry_cooldown
	if state == State.PARRY:
		_set_state(State.IDLE)


# ─── Physique ────────────────────────────────────────────────────────────────

func _apply_gravity(delta: float) -> void:
	if state == State.RESPAWNING:
		velocity.y = 0.0
		velocity.x = 0.0
		return
	if state == State.HITSTUN:
		velocity.y -= 4.0 * delta              # gravité réduite pendant le vol
		velocity.x  = lerp(velocity.x, 0.0, 0.015)  # décélération horizontale douce
	elif is_on_floor():
		if velocity.y < 0.0:
			velocity.y = 0.0
		jumps_left = MAX_JUMPS
	else:
		velocity.y -= GRAVITY * delta


func _apply_movement(input: Dictionary, delta: float) -> void:
	if state == State.HITSTUN or _is_attacking() or state == State.PARRY \
			or state == State.RESPAWNING or state == State.CROUCH:
		_up_was_pressed = input["up"]
		return

	var dir := int(input["right"]) - int(input["left"])
	if _post_hitstun_grace > 0.0:
		_post_hitstun_grace -= delta
		velocity.x = lerp(velocity.x, dir * char_speed, 0.08)
	else:
		velocity.x = dir * char_speed
	if input["right"]:
		facing_direction = 1.0
	elif input["left"]:
		facing_direction = -1.0

	# Saut : déclenché sur le front montant de "up" uniquement
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
	# Entrée en CROUCH : réduire la CollisionShape et démarrer le soft drop
	if new_state == State.CROUCH:
		_start_crouch(prev_state)


# ─── Hitbox ──────────────────────────────────────────────────────────────────

func _on_attack_hitbox_area_entered(area: Area3D) -> void:
	if area.name != "HurtBox":
		return
	var target := area.get_parent()
	if target == self or target.is_dead:
		return

	if debug_mode:
		print("[P%d] HIT signal → %s" % [player_id, target.name])

	var damage        : float   = 0.0
	var base_knockback: float   = 0.0
	var knockback_angle: Vector2

	match state:
		State.ATTACK_LIGHT, State.ATTACK_AIR_LIGHT:
			damage          = attack_light_damage
			base_knockback  = attack_light_knockback
			knockback_angle = Vector2(sign(target.global_position.x - global_position.x), 0.3).normalized()
		State.ATTACK_STRONG, State.ATTACK_AIR_STRONG:
			damage          = attack_strong_damage
			base_knockback  = attack_strong_knockback
			knockback_angle = Vector2(sign(target.global_position.x - global_position.x), 0.3).normalized()
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

	CombatSystem.apply_hit(self, target, damage, base_knockback, knockback_angle)


# Flash orange sur la hurtbox debug quand le personnage reçoit un hit
func flash_hurtbox() -> void:
	if not debug_mode or _debug_hurt_mesh == null:
		return
	var mat := _debug_hurt_mesh.material_override as StandardMaterial3D
	mat.albedo_color = Color(1.0, 0.35, 0.0, 0.7)   # flash orange
	await get_tree().create_timer(0.15).timeout
	if is_instance_valid(_debug_hurt_mesh):
		# Retour à la couleur d'origine : vert P1, bleu P2
		mat.albedo_color = Color(0.0, 1.0, 0.0, 0.28) if player_id == 1 else Color(0.2, 0.4, 1.0, 0.28)


# ─── API publique ────────────────────────────────────────────────────────────

func jump() -> void:
	if jumps_left <= 0:
		return
	velocity.y = JUMP_SPEED
	jumps_left -= 1
	_set_state(State.JUMP)


# Appelé par combat_system
func enter_hitstun(knockback: Vector3, duration: float) -> void:
	if _is_attacking():
		_attack_hitbox.monitoring = false
		_attack_shape.disabled    = true     # ← FIX : shape inactif si hit interrompt l'attaque
		_attack_timer             = 0.0
		if debug_mode and _debug_attack_mesh:
			_debug_attack_mesh.visible = false
	_set_state(State.HITSTUN)
	if debug_mode:
		print("[P%d] HITSTUN %.2fs" % [player_id, duration])
	velocity       = knockback / weight_multiplier
	velocity.z     = 0.0
	_hitstun_timer = duration   # géré frame par frame dans _tick_timers()


func die() -> void:
	is_dead = true
	if debug_mode:
		print("[P%d] DEAD" % player_id)


func start_respawn_invincibility(duration: float) -> void:
	is_invincible  = true
	velocity       = Vector3.ZERO
	_respawn_timer = duration
	_blink_timer   = 0.1
	_set_state(State.RESPAWNING)


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
