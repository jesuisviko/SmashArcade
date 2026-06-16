extends Sprite3D

var _camera       : Camera3D = null
var base_position : Vector3  = Vector3.ZERO
var base_scale    : Vector3  = Vector3.ONE

func _ready() -> void:
	var cameras := get_tree().get_nodes_in_group("camera")
	if cameras.size() > 0:
		_camera = cameras[0] as Camera3D
	base_position = position
	base_scale    = scale * 0.65

func _process(_delta: float) -> void:
	if not _camera:
		return
	var parallax_strength := 0.65
	position.x = base_position.x + _camera.position.x * parallax_strength
	position.y = base_position.y + (_camera.position.y - 2.25) * parallax_strength * 0.5

	var fov_min    := 36.8
	var fov_max    := 67.0
	var fov_ref    := 50.0
	var compensation := tan(deg_to_rad(_camera.fov) / 2.0) / tan(deg_to_rad(fov_ref) / 2.0)
	scale = base_scale * compensation
