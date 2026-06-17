extends BaseCharacter

const AIR_ANIM_DELAY      := 0.8
const HIT_FLASH_INTERVAL  := 0.08

# Paires mirror : clé = animation courante, valeur = sa variante miroir
const MIRROR_PAIRS : Dictionary = {
	"Idle"       : "Idle_Mirror",
	"Idle_Mirror": "Idle",
	"jump"       : "jump_mirror",
	"jump_mirror": "jump",
	"fall"       : "fall_mirror",
	"fall_mirror": "fall",
}

# Animations qui doivent boucler en LOOP_LINEAR
const LOOP_LINEAR_ANIMS : Array = ["run", "fall", "fall_mirror"]

# Vitesses de lecture personnalisées (custom_speed, 3e param de play())
const ANIM_SPEEDS : Dictionary = {
	"heavy"                  : 1.75,
	"heavy_mirror"           : 1.75,
	"attack_up"              : 1.25,
	"attack_up_mirror"       : 1.25,
	"run"                    : 2.1,
	"parry"                  : 1.56,
	"parry_mirror"           : 1.56,
	"fall"                   : 1.4,
	"fall_mirror"            : 1.4,
	"attack_air_down"        : 2.95,
	"attack_air_down_mirror" : 2.95,
	"punch"                  : 2.25,
	"punch_mirror"           : 2.25,
	"attack_air_up"          : 2.0,
	"attack_air_up_mirror"   : 2.0,
	"stun_001"             : 2.0,
}

# Animations d'attaque/parry — forcées en LOOP_NONE à la première lecture
const ATTACK_ANIMS : Array = ["punch", "heavy", "attack_up", "attack_air_up", "attack_air_up_mirror", "attack_air_down", "parry", "stun_001"]

var _anim_player          : AnimationPlayer          = null
var _anim_facing          : float                    = 1.0
var _current_anim         : String                   = ""
var _air_anim_timer       : float                    = 0.0
var _direction_hold_timer : float                    = 0.0
var _hit_flash_timer      : float                    = 0.0
var _flash_materials      : Array[StandardMaterial3D] = []
var _flash_base_colors    : Array[Color]              = []
var _parry_dash_tinted    : bool                     = false
var _parry_dash_gray_timer: float                    = 0.0


func _ready() -> void:
	char_height       = 1.4
	char_radius       = 0.35
	weight_multiplier = 1.0
	char_speed        = 4.68
	super._ready()
	_anim_player = $Model/char_01_final/AnimationPlayer
	_collect_flash_materials($Model/char_01_final)
	_apply_player_color()
	# Knockbacks : buff global ×1.35 (ATTACK_AIR_UP ×2 au préalable). La croissance
	# avec le % est gérée par CombatSystem (formule exponentielle pow 1.8).
	_attack_configs = {
		"ATTACK_LIGHT": {
			"position"  : Vector3(0.5, 0.7, 0.0),
			"size"      : Vector3(0.6, 0.4, 0.3),
			"damage"    : 4.0,
			"knockback" : 3.544,  # 2.025 ×1.75
			"duration"  : 0.4,    # hit_delay (0.2) + fenêtre active (0.2)
			"hit_delay" : 0.2,
		},
		"ATTACK_STRONG": {
			"position"              : Vector3(0.6, 0.5, 0.0),
			"size"                  : Vector3(0.8, 0.6, 0.3),
			"damage"                : 9.0,
			"knockback"             : 6.562,  # 5.4 ×0.75 ×1.35 ×1.2
			"duration"              : 0.95,   # hit_delay (0.6) + fenêtre active (0.3) + cooldown (0.05)
			"hit_delay"             : 0.6,
			"hitbox_active_duration": 0.3,
		},
		"ATTACK_UP": {
			# Attaque montante au sol — bouton dédié (p*_attack_up)
			"position"        : Vector3(0.0, 1.2, 0.0),
			"size"            : Vector3(0.7, 0.6, 0.3),
			"damage"          : 10.0,
			"knockback"       : 3.31,   # 7.0 ×1.35 ×0.35
			"duration"        : 0.5,
			"hit_delay"       : 0.4,
			"knockback_angle" : Vector2(0.2, 1.0),
		},
		"ATTACK_AIR_LIGHT": {
			# Identique à ATTACK_LIGHT : même portée, même dégâts, même timing
			"position"  : Vector3(0.5, 0.7, 0.0),
			"size"      : Vector3(0.6, 0.4, 0.3),
			"damage"    : 4.0,
			"knockback" : 2.025,  # 1.5 ×1.35
			"duration"  : 0.35,   # hit_delay (0.2) + fenêtre active (0.15)
			"hit_delay" : 0.2,
		},
		"ATTACK_AIR_UP": {
			# Tourbillon vers le haut — hitbox large + impulsion verticale
			"position"        : Vector3(0.0, 0.7, 0.0),
			"size"            : Vector3(1.2, 1.2, 0.3),
			"damage"          : 3.6,    # 4.0 ×0.9
			"knockback"       : 4.05,   # 1.5 ×2 (air_up) ×1.35
			"duration"        : 0.5,
			"velocity_y"      : JUMP_SPEED * 1.6,
			"knockback_angle" : Vector2(0.0, 1.0),
		},
		"ATTACK_AIR_STRONG": {
			"position"  : Vector3(0.6, 0.7, 0.0),
			"size"      : Vector3(0.7, 0.7, 0.3),
			"damage"    : 7.0,
			"knockback" : 4.05,   # 3.0 ×1.35
			"duration"  : 0.9,    # hit_delay (0.6) + fenêtre active (0.3)
			"hit_delay" : 0.6,
		},
		"ATTACK_AIR_DOWN": {
			# Phase 1 (0.4 s gel) + Phase 2 (plongée) — timer géré par _start_attack (99.0)
			"position"       : Vector3(0.0, -0.4, 0.0),
			"size"           : Vector3(0.6, 0.5, 0.3),
			"damage"         : 8.0,
			"knockback"      : 6.75,   # 5.0 ×1.35
			"duration"       : 0.3,    # ignorée, remplacée par 99.0 dans _start_attack
			"knockback_angle": Vector2(0.0, -1.0),
			"forced_hitstun" : 0.3,
		},
	}


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_update_animation(delta)
	_process_hit_flash(delta)


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
			target_anim = "crouch"
		State.JUMP, State.FALL:
			if _air_anim_timer > 0.0:
				target_anim = "jump" if _anim_facing == 1.0 else "jump_mirror"
			else:
				target_anim = "fall" if _anim_facing == 1.0 else "fall_mirror"
		State.ATTACK_LIGHT, State.ATTACK_AIR_LIGHT:
			target_anim = "punch"
		State.ATTACK_STRONG, State.ATTACK_AIR_STRONG:
			target_anim = "heavy"
		State.ATTACK_UP:
			target_anim = "attack_up"
		State.ATTACK_AIR_UP:
			target_anim = "attack_air_up" if _anim_facing == 1.0 else "attack_air_up_mirror"
		State.ATTACK_AIR_DOWN:
			target_anim = "attack_air_down"
		State.PARRY:
			target_anim = "parry"
		State.HITSTUN:
			target_anim = "stun_001"
		_:
			return   # ATTACK_DOWN, RESPAWNING — garde la dernière animation

	if target_anim == _current_anim:
		return

	# Crouch et attaques : pas de boucle
	if (target_anim == "crouch" or target_anim in ATTACK_ANIMS) and _anim_player.has_animation(target_anim):
		_anim_player.get_animation(target_anim).loop_mode = Animation.LOOP_NONE

	# run / fall doivent boucler
	if target_anim in LOOP_LINEAR_ANIMS and _anim_player.has_animation(target_anim):
		_anim_player.get_animation(target_anim).loop_mode = Animation.LOOP_LINEAR

	# Swap mirror/normal : blend court — un seek() annulerait le crossfade
	var speed : float = ANIM_SPEEDS.get(target_anim, 1.0)
	if MIRROR_PAIRS.get(_current_anim, "") == target_anim:
		_anim_player.play(target_anim, 0.12, speed)
	else:
		_anim_player.play(target_anim, 0.25, speed)

	_current_anim = target_anim


func _apply_player_color() -> void:
	var player_color := Color(0.2, 0.4, 0.95, 1.0) if player_id == 1 else Color(0.9, 0.2, 0.2, 1.0)
	var light_tint   := player_color.lerp(Color(1.0, 1.0, 1.0, 1.0), 0.7)
	_apply_player_color_node($Model/char_01_final, player_color, light_tint)
	for i in range(_flash_materials.size()):
		_flash_base_colors[i] = _flash_materials[i].albedo_color


func _apply_player_color_node(node: Node, player_color: Color, light_tint: Color) -> void:
	if node is MeshInstance3D:
		var mi       := node as MeshInstance3D
		var is_chest := node.name.contains("chest_01")
		if mi.mesh:
			for s in mi.mesh.get_surface_count():
				var mat := mi.get_surface_override_material(s) as StandardMaterial3D
				if mat:
					if is_chest:
						mat.albedo_texture = null
						mat.albedo_color   = player_color
					else:
						mat.albedo_color = mat.albedo_color * light_tint
	for child in node.get_children():
		_apply_player_color_node(child, player_color, light_tint)


# Collecte et pré-duplique tous les matériaux StandardMaterial3D du modèle (appelé une fois dans _ready).
# La duplication évite de modifier le matériau partagé du mesh ; on garde les références pour le flash.
func _collect_flash_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh:
			for s in mi.mesh.get_surface_count():
				var mat := mi.mesh.surface_get_material(s)
				if mat is StandardMaterial3D:
					var dup := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
					mi.set_surface_override_material(s, dup)
					_flash_materials.append(dup)
					_flash_base_colors.append(dup.albedo_color)
	for child in node.get_children():
		_collect_flash_materials(child)


func _process_hit_flash(delta: float) -> void:
	if state == State.HITSTUN:
		_hit_flash_timer += delta
		var flash_on := int(_hit_flash_timer / HIT_FLASH_INTERVAL) % 2 == 0
		for i in range(_flash_materials.size()):
			var base := _flash_base_colors[i]
			_flash_materials[i].albedo_color = base * 1.8 if flash_on else base
	elif state == State.RESPAWNING:
		_hit_flash_timer += delta
		var flash_on := int(_hit_flash_timer / HIT_FLASH_INTERVAL) % 2 == 0
		for i in range(_flash_materials.size()):
			var base := _flash_base_colors[i]
			_flash_materials[i].albedo_color = base * Color(0.5, 0.7, 1.5, 1.0) if flash_on else base
	elif _parry_dash_timer > 0.0:
		_parry_dash_tinted    = true
		_parry_dash_gray_timer = 0.2
		for i in range(_flash_materials.size()):
			_flash_materials[i].albedo_color = _flash_base_colors[i] * Color(0.25, 0.25, 0.25, 1.0)
	elif _parry_dash_tinted:
		_parry_dash_gray_timer -= delta
		if _parry_dash_gray_timer > 0.0:
			for i in range(_flash_materials.size()):
				_flash_materials[i].albedo_color = _flash_base_colors[i] * Color(0.25, 0.25, 0.25, 1.0)
		else:
			_parry_dash_tinted = false
			for i in range(_flash_materials.size()):
				_flash_materials[i].albedo_color = _flash_base_colors[i]
	elif _hit_flash_timer > 0.0:
		_hit_flash_timer = 0.0
		for i in range(_flash_materials.size()):
			_flash_materials[i].albedo_color = _flash_base_colors[i]
