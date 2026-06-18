extends Node

const ICON_BASE  := Vector2(500.0, 500.0)
const ICON_SCALE := 0.08   # 500 × 0.08 = 40px affiché
const _DIRS      := ["haut", "bas", "gauche", "droite"]

var _textures : Dictionary = {}
var _rects    : Dictionary = {}
var _camera   : Camera3D   = null


func _ready() -> void:
	for pid in [1, 2]:
		_textures[pid] = {}
		for dir in _DIRS:
			_textures[pid][dir] = load("res://assets/textures/ui/%s_P%d.png" % [dir, pid])
		var rect := TextureRect.new()
		rect.expand_mode         = TextureRect.EXPAND_KEEP_SIZE
		rect.stretch_mode        = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.custom_minimum_size = ICON_BASE
		rect.size                = ICON_BASE
		rect.scale               = Vector2(ICON_SCALE, ICON_SCALE)
		rect.visible             = false
		add_child(rect)
		_rects[pid] = rect


func _process(_delta: float) -> void:
	if not GameManager.round_started or GameManager.game_state != "fighting":
		for pid in [1, 2]:
			_rects[pid].visible = false
		return
	if not is_instance_valid(_camera):
		_camera = get_tree().get_first_node_in_group("camera") as Camera3D
		if not is_instance_valid(_camera):
			return

	var vp_size  := get_viewport().get_visible_rect().size
	var rendered := ICON_BASE * ICON_SCALE   # Vector2(40, 40) — taille visuelle réelle

	for pid in [1, 2]:
		var rect : TextureRect = _rects[pid]
		if not GameManager.players.has(pid):
			rect.visible = false
			continue

		var player := GameManager.players[pid] as BaseCharacter

		if not player.visible or player.state == BaseCharacter.State.RESPAWNING:
			rect.visible = false
			continue

		var world_pos  := player.global_position
		var is_behind  := _camera.is_position_behind(world_pos)
		var screen_pos := _camera.unproject_position(world_pos)

		if is_behind:
			screen_pos = vp_size - screen_pos

		var is_offscreen : bool = is_behind \
			or screen_pos.x < 0.0 or screen_pos.x > vp_size.x \
			or screen_pos.y < 0.0 or screen_pos.y > vp_size.y

		if not is_offscreen:
			rect.visible = false
			continue

		var dir_vec   := screen_pos - vp_size * 0.5
		var direction : String
		if abs(dir_vec.x) >= abs(dir_vec.y):
			direction = "droite" if dir_vec.x > 0.0 else "gauche"
		else:
			direction = "bas" if dir_vec.y > 0.0 else "haut"

		rect.texture = _textures[pid][direction]

		var pos : Vector2
		match direction:
			"gauche":
				pos.x = 0.0
				pos.y = clamp(screen_pos.y - rendered.y * 0.5, 0.0, vp_size.y - rendered.y)
			"droite":
				pos.x = vp_size.x - rendered.x
				pos.y = clamp(screen_pos.y - rendered.y * 0.5, 0.0, vp_size.y - rendered.y)
			"haut":
				pos.x = clamp(screen_pos.x - rendered.x * 0.5, 0.0, vp_size.x - rendered.x)
				pos.y = 0.0
			"bas":
				pos.x = clamp(screen_pos.x - rendered.x * 0.5, 0.0, vp_size.x - rendered.x)
				pos.y = vp_size.y - rendered.y

		rect.position = pos
		rect.visible  = true
