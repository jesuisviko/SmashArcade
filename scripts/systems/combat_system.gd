# AUTOLOAD À ENREGISTRER dans Project Settings → AutoLoad :
#   Nom : CombatSystem   Chemin : res://scripts/systems/combat_system.gd
#
# DÉPENDANCE : base_character.gd doit exposer :
#   var damage_percent: float = 0.0
#   func enter_hitstun(knockback: Vector3, duration: float) -> void

extends Node

@export var debug_mode: bool = false

# FPS cible — sert à convertir des frames en secondes
const TARGET_FPS := 50.0


func apply_hit(
		attacker: CharacterBody3D,
		target: CharacterBody3D,
		damage: float,
		base_knockback: float,
		knockback_angle: Vector2,
		forced_hitstun: float = -1.0
) -> void:
	# 1. Accumulation des dégâts
	target.damage_percent += damage

	# 2. Knockback — formule maison :
	#    0%  → base_knockback × 1
	#    50% → base_knockback × 2
	#    100%→ base_knockback × 3
	var knockback: float = base_knockback * (1.0 + target.damage_percent / 50.0) / target.weight_multiplier

	if debug_mode:
		print("dmg:", damage, " | %:", target.damage_percent, " | kb_base:", base_knockback, " | weight:", target.weight_multiplier, " | result:", knockback)

	# 3. Vecteur knockback 3D — Z toujours 0
	var dir          := knockback_angle.normalized()
	var knockback_3d := Vector3(dir.x, dir.y, 0.0) * knockback

	# 4. Tracking combo
	if target._combo_window_timer > 0.0:
		target.combo_count += 1
	else:
		target.combo_count = 1
	target._combo_window_timer = 1.0

	# 5. Hitstun : forced_hitstun ignore le combo_mult (ex. ATTACK_AIR_DOWN)
	var combo_mult   : float = 1.0 + min(0.05 * (target.combo_count - 1), 0.5)
	var hitstun_duration : float
	if forced_hitstun >= 0.0:
		hitstun_duration = forced_hitstun
	else:
		var hitstun_frames : int = max(8, int(knockback * 0.4))
		hitstun_duration = hitstun_frames / TARGET_FPS * combo_mult

	# Gel de l'attaquant sur hit aérien (AIR_LIGHT, AIR_STRONG) + bonus hitstun cible
	var attacker_bc := attacker as BaseCharacter
	var is_air_hit  : bool = attacker_bc != null and (
		attacker_bc.state == BaseCharacter.State.ATTACK_AIR_LIGHT or
		attacker_bc.state == BaseCharacter.State.ATTACK_AIR_STRONG
	)
	if is_air_hit:
		attacker_bc.enter_hitstun(Vector3.ZERO, hitstun_duration)

	if debug_mode:
		print("[HIT] P%s → P%s | dmg:%.0f | kb:%.2f | %%:%.0f | hitstun:%.2fs | combo:%d | air:%s" % [
			attacker.get("player_id"), target.get("player_id"),
			damage, knockback, target.damage_percent, hitstun_duration, target.combo_count, is_air_hit
		])

	target.enter_hitstun(knockback_3d, hitstun_duration + (0.1 if is_air_hit else 0.0))
