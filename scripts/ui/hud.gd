extends CanvasLayer

@onready var _p1_damage : Label         = $P1Panel/DamageLabel
@onready var _p2_damage : Label         = $P2Panel/DamageLabel
@onready var _p1_stocks : HBoxContainer = $P1Panel/StockIcons
@onready var _p2_stocks : HBoxContainer = $P2Panel/StockIcons


func _process(_delta: float) -> void:
	_refresh(1, _p1_damage, _p1_stocks)
	_refresh(2, _p2_damage, _p2_stocks)


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
