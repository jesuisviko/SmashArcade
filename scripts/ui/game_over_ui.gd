extends CanvasLayer

const FONT_PATH := "res://assets/textures/ui/paladins.ttf"

var _winner_label : Label  = null
var _options      : Array  = []
var _selected     : int    = 0
var _pulse_timer  : float  = 0.0
var _active       : bool   = false
var _prev_left    : Array  = [false, false]
var _prev_right   : Array  = [false, false]


func _ready() -> void:
	layer   = 20
	visible = false

	var font := load(FONT_PATH) as FontFile

	_winner_label = Label.new()
	_winner_label.add_theme_font_override("font", font)
	_winner_label.add_theme_font_size_override("font_size", 72)
	_winner_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	_winner_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	_winner_label.add_theme_constant_override("outline_size", 8)
	_winner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_winner_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_winner_label.offset_top    = 40.0
	_winner_label.offset_bottom = 140.0
	add_child(_winner_label)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 80)
	hbox.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hbox.offset_top    = -120.0
	hbox.offset_bottom = -20.0
	add_child(hbox)

	for txt in ["REJOUER", "MENU PRINCIPAL"]:
		var lbl := Label.new()
		lbl.add_theme_font_override("font", font)
		lbl.add_theme_font_size_override("font_size", 48)
		lbl.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		lbl.add_theme_constant_override("outline_size", 6)
		lbl.text = txt
		hbox.add_child(lbl)
		_options.append(lbl)


func show_result(winner_id: int) -> void:
	_winner_label.text = "JOUEUR %d GAGNE !" % winner_id
	var color := Color("#00d9e4") if winner_id == 1 else Color(0.9, 0.2, 0.2, 1.0)
	_winner_label.add_theme_color_override("font_color", color)
	_selected     = 0
	_pulse_timer  = 0.0
	_active       = true
	visible       = true


func _process(delta: float) -> void:
	if not _active:
		return

	# Détection edges left/right des deux joueurs
	for pid in [1, 2]:
		var idx       : int  = pid - 1
		var cur_left  : bool = Input.is_action_pressed("p%d_left"  % pid)
		var cur_right : bool = Input.is_action_pressed("p%d_right" % pid)

		if cur_left  and not _prev_left[idx]:
			_navigate(-1)
		if cur_right and not _prev_right[idx]:
			_navigate(1)
		if Input.is_action_just_pressed("p%d_attack_light" % pid):
			_confirm()

		_prev_left[idx]  = cur_left
		_prev_right[idx] = cur_right

	# Reset scale des options non sélectionnées
	for i in _options.size():
		if i != _selected:
			_options[i].pivot_offset = _options[i].size / 2.0
			_options[i].scale        = Vector2.ONE

	# Pulse sur l'option sélectionnée (sin rapide ±8%)
	_pulse_timer += delta
	var s   : float = 1.0 + sin(_pulse_timer * 8.0) * 0.08
	var opt : Label = _options[_selected]
	opt.pivot_offset = opt.size / 2.0
	opt.scale        = Vector2(s, s)


func _navigate(dir: int) -> void:
	_selected    = wrapi(_selected + dir, 0, _options.size())
	_pulse_timer = 0.0
	MusicManager.play_sfx("res://assets/sfx/buttonrollover.mp3")


func _confirm() -> void:
	_active = false
	MusicManager.play_sfx("res://assets/sfx/buttonclickrelease.mp3")
	match _selected:
		0:
			get_node("/root/SceneTransition").transition_to("res://scenes/ui/character_select.tscn")
		1:
			get_node("/root/SceneTransition").transition_to("res://scenes/ui/title_screen.tscn")
