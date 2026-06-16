extends CanvasLayer

@onready var _p1_damage      : Label         = $P1Panel/DamageLabel
@onready var _p2_damage      : Label         = $P2Panel/DamageLabel
@onready var _p1_stocks      : HBoxContainer = $P1Panel/StockIcons
@onready var _p2_stocks      : HBoxContainer = $P2Panel/StockIcons
@onready var _kill_feed      : Label         = $KillFeedLabel

var _kill_feed_timer : float = 0.0


func _process(delta: float) -> void:
	_refresh(1, _p1_damage, _p1_stocks)
	_refresh(2, _p2_damage, _p2_stocks)
	if _kill_feed_timer > 0.0:
		_kill_feed_timer -= delta
		if _kill_feed_timer <= 0.0:
			_kill_feed.visible = false


func show_kill_feed(player_id: int, remaining_stocks: int) -> void:
	if remaining_stocks > 0:
		_kill_feed.text = "Joueur %d OUT ! Vies restantes : %d" % [player_id, remaining_stocks]
	else:
		_kill_feed.text = "Joueur %d ELIMINÉ !" % player_id
	_kill_feed.visible  = true
	_kill_feed_timer    = 2.0


func _refresh(id: int, dmg_label: Label, stocks_box: HBoxContainer) -> void:
	if not GameManager.players.has(id):
		return

	# ── Pourcentage ──────────────────────────────────────────────────────────
	var pct: float = GameManager.players[id].damage_percent
	dmg_label.text = "%.0f%%" % pct

	if pct < 50.0:
		dmg_label.add_theme_color_override("font_color", Color.WHITE)
	elif pct < 100.0:
		dmg_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.0))  # orange
	else:
		dmg_label.add_theme_color_override("font_color", Color(1.0, 0.15, 0.15))  # rouge

	# ── Stocks ───────────────────────────────────────────────────────────────
	var remaining: int = GameManager.stocks.get(id, 0)
	var icons: Array  = stocks_box.get_children()
	for i: int in icons.size():
		icons[i].visible = i < remaining
