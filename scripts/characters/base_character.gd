extends CharacterBody3D

enum State {
	IDLE, RUN, JUMP, FALL,
	ATTACK_LIGHT, ATTACK_STRONG, ATTACK_UP, ATTACK_DOWN,
	ATTACK_AIR_LIGHT, ATTACK_AIR_STRONG, ATTACK_AIR_UP, ATTACK_AIR_DOWN,
	PARRY, HITSTUN,
}

const GRAVITY    := 20.0
const JUMP_SPEED := 12.0
const MAX_JUMPS  := 2

@export var player_id               : int   = 1
@export var char_height                     := 1.4
@export var char_radius                     := 0.35
@export var char_speed                      := 8.0
@export var weight_multiplier               := 1.0
@export var attack_light_damage             := 5.0
@export var attack_strong_damage            := 12.0
@export var attack_light_knockback          := 4.0
@export var attack_strong_knockback         := 10.0
@export var attack_duration                 := 0.2
@export var parry_duration                  := 0.15
@export var parry_cooldown                  := 0.5
@export var debug_mode              : bool  = false

var state          : State = State.IDLE
var jumps_left     : int   = MAX_JUMPS
var damage_percent : float = 0.0
var is_dead        : bool  = false
var is_invincible  : bool  = false

# Edge-detection du bouton "haut" pour ne sauter qu'une fois par pression
var _up_was_pressed  : bool  = false
# Timers décrémentés manuellement dans _physics_process
var _attack_timer    : float = 0.0
var _parry_timer     : float = 0.0
var _parry_cd_timer  : float = 0.0   # cooldown post-parry

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


# ─── Boucle principale ───────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	var input := InputManager.get_input(player_id)
	_tick_timers(delta)
	_handle_attack_input(input)
	_apply_gravity(delta)
	_apply_movement(input)
	move_and_slide()
	position.z = 0.0           # axe Z verrouillé en permanence
	_update_state(input)
	_check_death()


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


# ─── Gestion des attaques ────────────────────────────────────────────────────

func _handle_attack_input(input: Dictionary) -> void:
	if state == State.HITSTUN or _is_attacking() or state == State.PARRY:
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
			# ATTACK_UP / ATTACK_DOWN partagés avec attack_light (état unique,
			# le dommage diffère selon la source — à distinguer côté CombatSystem)
			if   input["up"]:   s = State.ATTACK_UP
			elif input["down"]: s = State.ATTACK_DOWN
		else:
			s = State.ATTACK_AIR_STRONG
		_start_attack(s)

	elif input["parry"]:
		_start_parry()


func _start_attack(new_state: State) -> void:
	_set_state(new_state)
	_attack_timer              = attack_duration
	_attack_hitbox.monitoring  = true


func _end_attack() -> void:
	_attack_hitbox.monitoring = false
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
	if is_on_floor():
		if velocity.y < 0.0:
			velocity.y = 0.0
		jumps_left = MAX_JUMPS
	else:
		velocity.y -= GRAVITY * delta


func _apply_movement(input: Dictionary) -> void:
	if state == State.HITSTUN or _is_attacking() or state == State.PARRY:
		_up_was_pressed = input["up"]
		return

	var dir := int(input["right"]) - int(input["left"])
	velocity.x = dir * char_speed

	# Saut : déclenché sur le front montant de "up" uniquement
	if input["up"] and not _up_was_pressed and jumps_left > 0:
		jump()
	_up_was_pressed = input["up"]


# ─── State machine ───────────────────────────────────────────────────────────

func _update_state(input: Dictionary) -> void:
	if _is_attacking() or state == State.HITSTUN or state == State.PARRY:
		return
	var has_h_input: bool = input["left"] or input["right"]
	var new_state: State  = State.IDLE
	if is_on_floor():
		new_state = State.RUN if has_h_input else State.IDLE
	else:
		# velocity.y > 0 = monte (JUMP), velocity.y <= 0 = descend (FALL)
		new_state = State.JUMP if velocity.y > 0.0 else State.FALL
	_set_state(new_state)


func _set_state(new_state: State) -> void:
	if new_state == state:
		return
	if debug_mode and new_state in [
		State.ATTACK_LIGHT,     State.ATTACK_STRONG,
		State.ATTACK_UP,        State.ATTACK_DOWN,
		State.ATTACK_AIR_LIGHT, State.ATTACK_AIR_STRONG,
		State.ATTACK_AIR_UP,    State.ATTACK_AIR_DOWN,
		State.PARRY,
	]:
		print("[P%d] %s → %s" % [player_id, State.find_key(state), State.find_key(new_state)])
	state = new_state


# ─── API publique ────────────────────────────────────────────────────────────

func jump() -> void:
	if jumps_left <= 0:
		return
	velocity.y = JUMP_SPEED
	jumps_left -= 1
	_set_state(State.JUMP)


# Appelé par combat_system
func enter_hitstun(knockback: Vector3, duration: float) -> void:
	# Annuler l'attaque en cours si besoin
	if _is_attacking():
		_attack_hitbox.monitoring = false
		_attack_timer             = 0.0
	_set_state(State.HITSTUN)
	if debug_mode:
		print("[P%d] HITSTUN %.2fs" % [player_id, duration])
	velocity   = knockback / weight_multiplier
	velocity.z = 0.0
	await get_tree().create_timer(duration).timeout
	if state == State.HITSTUN:
		_set_state(State.IDLE)


func _check_death() -> void:
	if is_dead:
		return
	if (global_position.y < -10.0
			or global_position.x < -15.0
			or global_position.x > 15.0):
		die()
		GameManager.player_died(player_id)


func die() -> void:
	is_dead = true
	if debug_mode:
		print("[P%d] DEAD" % player_id)
