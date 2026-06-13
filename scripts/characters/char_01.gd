extends BaseCharacter

const AIR_ANIM_DELAY := 0.8

# Paires mirror : clé = animation courante, valeur = sa variante miroir
const MIRROR_PAIRS : Dictionary = {
	"Idle"              : "Idle_Mirror",
	"Idle_Mirror"       : "Idle",
	"jump"              : "jump_mirror",
	"jump_mirror"       : "jump",
	"fall"              : "fall_mirror",
	"fall_mirror"       : "fall",
	"crouch_walk"       : "crouch_walk_mirror",
	"crouch_walk_mirror": "crouch_walk",
}

# Animations qui doivent boucler en LOOP_LINEAR
const LOOP_LINEAR_ANIMS : Array = ["run", "fall", "fall_mirror"]

var _anim_player          : AnimationPlayer = null
var _anim_facing          : float           = 1.0   # direction reflétée par l'animation en cours
var _current_anim         : String          = ""
var _air_anim_timer       : float           = 0.0
var _direction_hold_timer : float           = 0.0


func _ready() -> void:
	char_height       = 1.4
	char_radius       = 0.35
	weight_multiplier = 1.0
	char_speed        = 4.68
	player_id         = 1
	super._ready()
	_anim_player = $Model/char_01_MOUVEMENTS/AnimationPlayer


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_update_animation(delta)


func set_initial_facing(direction: float) -> void:
	super.set_initial_facing(direction)
	_anim_facing = direction
	if _anim_player:
		var idle_anim := "Idle" if direction == 1.0 else "Idle_Mirror"
		_anim_player.play(idle_anim)
		_current_anim = idle_anim


# Hook virtuel appelé par base_character.jump() — saut simple ET double saut
func _on_jump() -> void:
	_air_anim_timer = AIR_ANIM_DELAY
	_current_anim   = ""   # force le replay de jump/jump_mirror


func _update_animation(delta: float) -> void:
	if not _anim_player:
		return

	var input := InputManager.get_input(player_id)
	var dir   := int(input["right"]) - int(input["left"])

	# Timer directionnel — swap _anim_facing après 0.2 s de changement maintenu
	if facing_direction != _anim_facing:
		_direction_hold_timer += delta
		if _direction_hold_timer >= 0.2:
			_anim_facing          = facing_direction
			_direction_hold_timer = 0.0
	else:
		_direction_hold_timer = 0.0

	# Timer aérien — décrément chaque frame en l'air
	if (state == State.JUMP or state == State.FALL) and _air_anim_timer > 0.0:
		_air_anim_timer -= delta

	# Table état → animation cible
	var target_anim := _current_anim

	match state:
		State.IDLE:
			target_anim = "Idle" if _anim_facing == 1.0 else "Idle_Mirror"
		State.RUN:
			target_anim = "run"
		State.CROUCH:
			if dir != 0:
				target_anim = "crouch_walk" if _anim_facing == 1.0 else "crouch_walk_mirror"
			else:
				target_anim = "crouch"
		State.JUMP, State.FALL:
			if _air_anim_timer > 0.0:
				target_anim = "jump" if _anim_facing == 1.0 else "jump_mirror"
			else:
				target_anim = "fall" if _anim_facing == 1.0 else "fall_mirror"
		_:
			return   # ATTACK_*, HITSTUN, PARRY, RESPAWNING — garde la dernière animation

	if target_anim == _current_anim:
		return

	# Crouch sans boucle
	if target_anim == "crouch" and _anim_player.has_animation("crouch"):
		_anim_player.get_animation("crouch").loop_mode = Animation.LOOP_NONE

	# run / fall doivent boucler
	if target_anim in LOOP_LINEAR_ANIMS and _anim_player.has_animation(target_anim):
		_anim_player.get_animation(target_anim).loop_mode = Animation.LOOP_LINEAR

	# Mirror swap seamless vs crossfade
	if MIRROR_PAIRS.get(_current_anim, "") == target_anim:
		# Préserve la position de lecture pour une continuité parfaite
		var pos := _anim_player.current_animation_position
		_anim_player.play(target_anim)
		_anim_player.seek(pos, true)
	else:
		var speed := 2.5 if target_anim == "run" else 1.0
		_anim_player.play(target_anim, 0.15, speed)

	_current_anim = target_anim
