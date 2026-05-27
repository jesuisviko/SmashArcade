# AUTOLOAD À ENREGISTRER dans Project Settings → AutoLoad :
#   Nom : CombatSystem   Chemin : res://scripts/systems/combat_system.gd
#
# DÉPENDANCE : base_character.gd doit exposer :
#   var damage_percent: float = 0.0
#   func enter_hitstun(knockback: Vector3, duration: float) -> void

extends Node

@export var debug_mode: bool = false

# Ratio frames de hitstun par unité de knockback
const HITSTUN_RATIO := 0.4
# FPS cible — sert à convertir des frames en secondes
const TARGET_FPS    := 50.0


func apply_hit(
		attacker: CharacterBody3D,
		target: CharacterBody3D,
		damage: float,
		base_knockback: float,
		knockback_angle: Vector2
) -> void:
	# 1. Accumulation des dégâts (le % mis à jour entre dans la formule)
	target.damage_percent += damage

	# 2. Magnitude du knockback — formule style Smash Bros
	var knockback_magnitude: float = (
		(damage * 0.1 + 2.0)
		* (1.0 + target.damage_percent / 100.0)
		* base_knockback
		/ target.weight_multiplier
	)

	# 3. Hitstun : plus le knockback est fort, plus il dure
	var hitstun_frames: int  = int(knockback_magnitude * HITSTUN_RATIO)
	var hitstun_duration: float = hitstun_frames / TARGET_FPS

	# 4. Vecteur knockback 3D — Z toujours 0
	var dir := knockback_angle.normalized()
	var knockback_3d := Vector3(dir.x, dir.y, 0.0) * knockback_magnitude

	if debug_mode:
		print("[HIT] P%s → P%s | dmg:%.0f | kb:%.1f | %%:%.0f" % [
			attacker.get("player_id"), target.get("player_id"),
			damage, knockback_magnitude, target.damage_percent
		])

	target.enter_hitstun(knockback_3d, hitstun_duration)
