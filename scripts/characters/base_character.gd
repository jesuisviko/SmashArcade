extends CharacterBody3D

enum State { IDLE, RUN, JUMP, FALL, ATTACK, HITSTUN }

const GRAVITY    := 20.0
const JUMP_SPEED := 12.0
const MAX_JUMPS  := 2

@export var player_id         : int   = 1
@export var char_height               := 1.4
@export var char_radius               := 0.35
@export var char_speed                := 8.0
@export var weight_multiplier         := 1.0

var state      : State = State.IDLE
var jumps_left : int   = MAX_JUMPS

# Edge-detection du bouton "haut" pour ne sauter qu'une fois par pression
var _up_was_pressed := false

@onready var _col_shape    : CollisionShape3D = $CollisionShape3D
@onready var _mesh         : MeshInstance3D   = $MeshInstance3D
@onready var _attack_hitbox: Area3D           = $AttackHitbox
@onready var _attack_shape : CollisionShape3D = $AttackHitbox/CollisionShape3D
@onready var _hurtbox      : Area3D           = $HurtBox
@onready var _hurt_shape   : CollisionShape3D = $HurtBox/CollisionShape3D


func _ready() -> void:
	_apply_size()


func _apply_size() -> void:
	var half_h := char_height / 2.0

	# Body collision
	var body_cap := CapsuleShape3D.new()
	body_cap.radius = char_radius
	body_cap.height = char_height
	_col_shape.shape    = body_cap
	_col_shape.position = Vector3(0.0, half_h, 0.0)

	# Mesh placeholder
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = char_radius
	body_mesh.height = char_height
	_mesh.mesh     = body_mesh
	_mesh.position = Vector3(0.0, half_h, 0.0)

	# HurtBox — couvre tout le corps, légèrement plus large
	var hurt_cap := CapsuleShape3D.new()
	hurt_cap.radius = char_radius * 1.05
	hurt_cap.height = char_height
	_hurt_shape.shape = hurt_cap
	_hurtbox.position = Vector3(0.0, half_h, 0.0)

	# AttackHitbox — boîte aplatie, dimensions relatives au gabarit
	# Repositionnée par les sous-classes selon l'attaque
	var attack_box := BoxShape3D.new()
	attack_box.size = Vector3(char_radius * 2.0, char_height * 0.4, 1.0)
	_attack_shape.shape = attack_box


func _physics_process(delta: float) -> void:
	var input := InputManager.get_input(player_id)
	_apply_gravity(delta)
	_apply_movement(input)
	move_and_slide()
	position.z = 0.0  # axe Z verrouillé en permanence
	_update_state(input)


func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		if velocity.y < 0.0:
			velocity.y = 0.0
		jumps_left = MAX_JUMPS
	else:
		velocity.y -= GRAVITY * delta


func _apply_movement(input: Dictionary) -> void:
	if state == State.HITSTUN:
		# On ne consomme pas le input mais on garde la cohérence de l'edge-detection
		_up_was_pressed = input["up"]
		return

	var dir := int(input["right"]) - int(input["left"])
	velocity.x = dir * char_speed

	# Saut : déclenché sur le front montant de "up" uniquement
	if input["up"] and not _up_was_pressed and jumps_left > 0:
		jump()
	_up_was_pressed = input["up"]


func _update_state(input: Dictionary) -> void:
	if state == State.ATTACK or state == State.HITSTUN:
		return
	var has_h_input: bool = input["left"] or input["right"]
	if is_on_floor():
		state = State.RUN if has_h_input else State.IDLE
	else:
		# velocity.y > 0 = monte (JUMP), velocity.y <= 0 = descend (FALL)
		state = State.JUMP if velocity.y > 0.0 else State.FALL


func jump() -> void:
	if jumps_left <= 0:
		return
	velocity.y = JUMP_SPEED
	jumps_left -= 1
	state = State.JUMP


# Appelé par combat_system
func enter_hitstun(knockback: Vector3, duration: float) -> void:
	velocity   = knockback / weight_multiplier
	velocity.z = 0.0
	state      = State.HITSTUN
	await get_tree().create_timer(duration).timeout
	if state == State.HITSTUN:
		state = State.IDLE
