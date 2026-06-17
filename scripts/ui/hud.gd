extends CanvasLayer

@onready var _p1_name   : Label         = $P1Panel/NameLabel
@onready var _p2_name   : Label         = $P2Panel/NameLabel
@onready var _p1_damage : Label         = $P1Panel/DamageLabel
@onready var _p2_damage : Label         = $P2Panel/DamageLabel
@onready var _p1_stocks : HBoxContainer = $P1Panel/StockIcons
@onready var _p2_stocks : HBoxContainer = $P2Panel/StockIcons
@onready var _kill_feed  : Label         = $KillFeedLabel
@onready var _countdown  : Label         = $CountdownLabel

var _kill_feed_timer    : float = 0.0
var _positions_captured : bool  = false
var _p1_damage_base     : Vector2 = Vector2.ZERO
var _p2_damage_base     : Vector2 = Vector2.ZERO
var _p1_shake_timer     : float = 0.0
var _p1_shake_intensity : float = 0.0
var _p2_shake_timer     : float = 0.0
var _p2_shake_intensity : float = 0.0
var _animating_icons    : Dictionary = {}
var _life_tweens        : Dictionary = {}


func _ready() -> void:
	_p1_name.add_theme_color_override("font_color", Color("#00d9e4"))
	_p2_name.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2, 1.0))
	for icon in _p1_stocks.get_children():
		icon.modulate = Color(0.0, 0.15, 0.45, 1.0)
	for icon in _p2_stocks.get_children():
		icon.modulate = Color(0.5, 0.08, 0.08, 1.0)


func _process(delta: float) -> void:
	if not _positions_captured:
		_p1_damage_base    = _p1_damage.position
		_p2_damage_base    = _p2_damage.position
		_positions_captured = true

	_refresh(1, _p1_damage, _p1_stocks)
	_refresh(2, _p2_damage, _p2_stocks)

	# Shake P1
	var pct_p1   : float = GameManager.players[1].damage_percent if GameManager.players.has(1) else 0.0
	var passive1 : float = _get_passive_shake(pct_p1)
	if _p1_shake_timer > 0.0:
		_p1_shake_timer -= delta
		if _p1_shake_timer < 0.0:
			_p1_shake_timer     = 0.0
			_p1_shake_intensity = 0.0
	var active1 : float = _p1_shake_intensity * clamp(_p1_shake_timer / 0.2, 0.0, 1.0)
	var total1  : float = passive1 + active1
	_p1_damage.position = _p1_damage_base + Vector2(randf_range(-total1, total1), randf_range(-total1, total1))

	# Shake P2
	var pct_p2   : float = GameManager.players[2].damage_percent if GameManager.players.has(2) else 0.0
	var passive2 : float = _get_passive_shake(pct_p2)
	if _p2_shake_timer > 0.0:
		_p2_shake_timer -= delta
		if _p2_shake_timer < 0.0:
			_p2_shake_timer     = 0.0
			_p2_shake_intensity = 0.0
	var active2 : float = _p2_shake_intensity * clamp(_p2_shake_timer / 0.2, 0.0, 1.0)
	var total2  : float = passive2 + active2
	_p2_damage.position = _p2_damage_base + Vector2(randf_range(-total2, total2), randf_range(-total2, total2))

	# Kill feed
	if _kill_feed_timer > 0.0:
		_kill_feed_timer -= delta
		if _kill_feed_timer <= 0.0:
			_kill_feed.visible = false


func show_countdown(text: String) -> void:
	_countdown.text    = text
	_countdown.visible = true


func hide_countdown() -> void:
	_countdown.visible = false


func show_kill_feed(player_id: int, remaining_stocks: int) -> void:
	if remaining_stocks > 0:
		_kill_feed.text = "Joueur %d OUT ! Vies restantes : %d" % [player_id, remaining_stocks]
	else:
		_kill_feed.text = "Joueur %d ELIMINÉ !" % player_id
	_kill_feed.visible  = true
	_kill_feed_timer    = 2.0


func trigger_percent_shake(player_id: int, intensity: float) -> void:
	if player_id == 1:
		_p1_shake_timer     = 0.2
		_p1_shake_intensity = max(_p1_shake_intensity, intensity * 11.2)
	else:
		_p2_shake_timer     = 0.2
		_p2_shake_intensity = max(_p2_shake_intensity, intensity * 11.2)


func _refresh(id: int, dmg_label: Label, stocks_box: HBoxContainer) -> void:
	if not GameManager.players.has(id):
		return

	var pct : float = GameManager.players[id].damage_percent
	dmg_label.text = "%.0f%%" % pct
	dmg_label.add_theme_color_override("font_color", get_percent_color(pct))

	var remaining : int  = GameManager.stocks.get(id, 0)
	var icons     : Array = stocks_box.get_children()
	for i : int in icons.size():
		if not _animating_icons.has(icons[i]):
			if id == 1:
				icons[i].visible = i < remaining
			else:
				icons[i].visible = i >= (icons.size() - remaining)


func get_percent_color(percent: float) -> Color:
	var white    := Color(1.0, 1.0, 1.0, 1.0)
	var orange   := Color(1.0, 0.6, 0.0, 1.0)
	var red      := Color(0.9, 0.1, 0.1, 1.0)
	var dark_red := Color(0.55, 0.05, 0.05, 1.0)
	var very_dark := Color(0.25, 0.0, 0.0, 1.0)
	if percent < 45.0:
		return white
	elif percent < 75.0:
		return white.lerp(orange, (percent - 45.0) / 30.0)
	elif percent < 130.0:
		return orange.lerp(red, (percent - 75.0) / 55.0)
	elif percent < 170.0:
		return red.lerp(dark_red, (percent - 130.0) / 40.0)
	else:
		return dark_red.lerp(very_dark, clamp((percent - 170.0) / 50.0, 0.0, 1.0))


func _get_life_icon(player_id: int, life_index: int) -> Control:
	var box : HBoxContainer = _p1_stocks if player_id == 1 else _p2_stocks
	var children : Array = box.get_children()
	var idx : int = life_index if player_id == 1 else (children.size() - 1) - life_index
	if idx < 0 or idx >= children.size():
		return null
	return children[idx] as Control


func lose_life(player_id: int, life_index: int) -> void:
	# Nettoie toutes les animations de vies en cours avant d'en démarrer une nouvelle
	for prev_icon in _animating_icons.keys():
		if _life_tweens.has(prev_icon):
			for t in _life_tweens[prev_icon]:
				if is_instance_valid(t):
					t.kill()
		prev_icon.visible       = false
		prev_icon.modulate.a    = 1.0
		prev_icon.self_modulate = Color(1, 1, 1, 1)
	_animating_icons.clear()
	_life_tweens.clear()

	var icon := _get_life_icon(player_id, life_index)
	if not icon:
		return
	_animating_icons[icon] = true
	icon.visible = true

	# Fondu progressif sur 4s — cleanup à la fin
	var fade_tween := create_tween()
	fade_tween.tween_property(icon, "modulate:a", 0.0, 4.0)
	fade_tween.tween_callback(func() -> void:
		icon.visible       = false
		icon.modulate.a    = 1.0
		icon.self_modulate = Color(1, 1, 1, 1)
		_animating_icons.erase(icon)
		_life_tweens.erase(icon)
	)
	# Clignotement en parallèle sur 3.9s via self_modulate.a (pas visible)
	# — évite le reflow du HBoxContainer qui causait le bug P2
	var blink_tween := create_tween()
	for i in range(26):
		if i % 2 == 0:
			blink_tween.tween_callback(func(): icon.self_modulate.a = 1.0)
		else:
			blink_tween.tween_callback(func(): icon.self_modulate.a = 0.0)
		blink_tween.tween_interval(0.15)

	_life_tweens[icon] = [fade_tween, blink_tween]


func _get_passive_shake(percent: float) -> float:
	if percent < 115.0:
		return 0.0
	return clamp((percent - 115.0) / 65.0, 0.0, 1.0) * 4.2
