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
	var attacker_bc := attacker as BaseCharacter
	var target_bc   := target   as BaseCharacter

	# Parry — le défenseur reste en PARRY et encaisse des dégâts/knockback réduits.
	# L'attaquant est stun si l'attaque est cassante (AIR_DOWN / UP-sol) ou au 2e light parryé.
	if target_bc != null and target_bc.state == BaseCharacter.State.PARRY:
		# Capture l'état d'attaque AVANT le cancel — force_cancel_attack() change l'état
		var atk_state    : int  = attacker_bc.state if attacker_bc != null else -1
		var atk_on_floor : bool = attacker_bc != null and attacker_bc._attack_started_on_floor
		if attacker_bc != null:
			attacker_bc.force_cancel_attack()

		# Réductions uniformes — toujours appliquées, quel que soit le type d'attaque
		damage         *= 0.1
		base_knockback *= 0.05
		target.damage_percent += damage

		var is_breaking : bool = (
			atk_state == BaseCharacter.State.ATTACK_AIR_DOWN or
			(atk_state == BaseCharacter.State.ATTACK_UP and atk_on_floor) or
			atk_state == BaseCharacter.State.ATTACK_STRONG
		)
		var is_light : bool = (
			atk_state == BaseCharacter.State.ATTACK_LIGHT or
			atk_state == BaseCharacter.State.ATTACK_AIR_LIGHT
		)

		if is_breaking and attacker_bc != null:
			if debug_mode:
				print("[PARRY COUNTER] %s a counter-parryé ATTACK_AIR_DOWN/UP de %s — attaquant stun 1.5s" % [target.name, attacker.name])
			attacker_bc._freeze_timer              = 1.5
			attacker_bc._pending_knockback         = Vector3.ZERO
			attacker_bc._hitstun_preserve_velocity = true
			attacker_bc._parry_stunned             = true
			attacker_bc._set_state(BaseCharacter.State.HITSTUN)
		elif is_light and attacker_bc != null:
			target_bc._parry_light_hits += 1
			if debug_mode:
				print("[PARRY] %s a parryé un light de %s (%d/2) | dmg réduit: %.1f | kb réduit: %.2f" % [target.name, attacker.name, target_bc._parry_light_hits, damage, base_knockback])
			if target_bc._parry_light_hits >= 2:
				attacker_bc._parry_stunned = true
				attacker_bc.enter_hitstun(Vector3.ZERO, 1.5)
				target_bc._parry_light_hits = 0
		else:
			if debug_mode:
				print("[PARRY] %s a parryé un coup de %s | dmg réduit: %.1f | kb réduit: %.2f" % [target.name, attacker.name, damage, base_knockback])

		return  # stoppe le fall-through vers les dégâts normaux

	# 1. Accumulation des dégâts
	target.damage_percent += damage

	# 2. Knockback — croissance exponentielle (pow 1.8) :
	#    0% → ×1   |   100% → ~×3.5   |   200% → ~×7
	var damage_factor : float = pow(1.0 + target.damage_percent / 100.0, 1.6)
	var knockback     : float = base_knockback * damage_factor / target.weight_multiplier

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
	elif attacker_bc != null and attacker_bc.state == BaseCharacter.State.ATTACK_LIGHT:
		hitstun_duration = 0.35 * combo_mult
	elif attacker_bc != null and attacker_bc.state == BaseCharacter.State.ATTACK_STRONG:
		hitstun_duration = 0.7 * combo_mult
	else:
		var hitstun_frames : int = max(8, int(knockback * 0.4))
		hitstun_duration = hitstun_frames / TARGET_FPS * combo_mult

	# Gel de l'attaquant sur hit aérien (AIR_LIGHT, AIR_STRONG) + bonus hitstun cible
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
	# Mini knockback immédiat (phase 1 : 0.15s) — appliqué après enter_hitstun (qui zero la velocity)
	# Angle Y fortement réduit pour ce mini knockback uniquement
	# Phase 2 : gel (_mini_knockback_phase expire → velocity = 0) jusqu'à _freeze_timer
	# Phase 3 : knockback complet (_freeze_timer expire → _pending_knockback appliqué)
	if target_bc != null:
		var mini_angle := Vector2(knockback_angle.x, knockback_angle.y * 0.2)
		var mini_dir   := Vector3(mini_angle.x, mini_angle.y, 0.0).normalized()
		target.velocity                   = mini_dir * base_knockback * 0.15 / target_bc.weight_multiplier
		target_bc._mini_knockback_phase   = 0.15
