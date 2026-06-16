extends Node

const SlashArc = preload("res://scripts/effects/slash_arc.gd")

var _canvas_layer : CanvasLayer = null
var _camera       : Camera3D    = null


func _ready() -> void:
	add_to_group("effects_manager")
	_canvas_layer       = CanvasLayer.new()
	_canvas_layer.layer = 85
	add_child(_canvas_layer)


func _get_camera() -> Camera3D:
	if is_instance_valid(_camera):
		return _camera
	var cams := get_tree().get_nodes_in_group("camera")
	if cams.size() > 0:
		_camera = cams[0] as Camera3D
	return _camera


func spawn_slash_arc(world_pos: Vector3, facing: float, attack_type: String = "light") -> void:
	print("[ARC] spawn_slash_arc — pos:", world_pos, " facing:", facing, " type:", attack_type)
	var arc : Node3D = SlashArc.new()
	arc.setup(world_pos, facing, attack_type)
	get_parent().add_child(arc)


func spawn_impact(world_pos: Vector3) -> void:
	var cam := _get_camera()
	if not cam:
		return
	var screen_pos := cam.unproject_position(world_pos)

	var p                    := CPUParticles2D.new()
	p.position                = screen_pos
	p.emitting                = true
	p.one_shot                = true
	p.amount                  = 8
	p.lifetime                = 0.3
	p.direction               = Vector2(0.0, -1.0)
	p.spread                  = 60.0
	p.initial_velocity_min    = 80.0
	p.initial_velocity_max    = 150.0
	p.gravity                 = Vector2(0.0, 300.0)
	p.scale_amount_min        = 0.3
	p.scale_amount_max        = 0.6
	p.color                   = Color(1.0, 0.9, 0.3)
	var gradient              := Gradient.new()
	gradient.set_color(0, Color(1.0, 0.95, 0.4, 1.0))
	gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	p.color_ramp = gradient
	_canvas_layer.add_child(p)
	get_tree().create_timer(p.lifetime + 0.1).timeout.connect(p.queue_free)
