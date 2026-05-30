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
		knockback_angle: Vector2
) -> void:
	# 1. Accumulation des dégâts
	target.damage_percent += damage

	# 2. Knockback — formule maison :
	#    0%  → base_knockback × 1
	#    50% → base_knockback × 2
	#    100%→ base_knockback × 3
	var knockback: float = base_knockback * (1.0 + target.damage_percent / 50.0) / target.weight_multiplier

	# DEBUG — print temporaire pour diagnostiquer les valeurs intermédiaires
	print("dmg:", damage, " | %:", target.damage_percent, " | kb_base:", base_knockback, " | weight:", target.weight_multiplier, " | result:", knockback)

	# 3. Hitstun : minimum 8 frames (0.16s) pour qu'un hit soit toujours ressenti
	var hitstun_frames   : int   = max(8, int(knockback * 0.4))
	var hitstun_duration : float = hitstun_frames / TARGET_FPS

	# 4. Vecteur knockback 3D — Z toujours 0
	var dir          := knockback_angle.normalized()
	var knockback_3d := Vector3(dir.x, dir.y, 0.0) * knockback

	if debug_mode:
		print("[HIT] P%s → P%s | dmg:%.0f | kb:%.2f | %%:%.0f | hitstun:%.2fs" % [
			attacker.get("player_id"), target.get("player_id"),
			damage, knockback, target.damage_percent, hitstun_duration
		])

	target.enter_hitstun(knockback_3d, hitstun_duration)
