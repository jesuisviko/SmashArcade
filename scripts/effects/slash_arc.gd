extends Node3D

var _world_pos   : Vector3             = Vector3.ZERO
var _facing      : float               = 1.0
var _attack_type : String              = "light"
var _material    : StandardMaterial3D  = null


func setup(world_pos: Vector3, facing: float, attack_type: String = "light") -> void:
	_world_pos   = world_pos
	_facing      = facing
	_attack_type = attack_type


func _ready() -> void:
	var is_strong := _attack_type == "strong"

	# Paramètres différenciés light / strong
	var color      := Color(1.0, 0.85, 0.1, 1.0) if is_strong else Color(1.0, 1.0, 1.0, 1.0)
	var s0         := 0.35 if is_strong else 0.3
	var s1         := 1.6  if is_strong else 1.2
	var sweep_back := 0.1 if is_strong else 0.15   # recul initial (arrière du hitbox)
	var sweep_fwd  := 0.4  if is_strong else 0.2    # avancée finale (devant le hitbox)

	var quad       := QuadMesh.new()
	quad.size       = Vector2(0.65, 0.65)

	_material                          = StandardMaterial3D.new()
	_material.transparency             = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.shading_mode             = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.no_depth_test            = true
	_material.albedo_texture           = _build_arc_texture()
	_material.albedo_color             = color
	_material.emission_enabled         = true
	_material.emission                 = Color(color.r, color.g, color.b)
	_material.emission_energy_multiplier = 48.0 if is_strong else 32.0

	var mi              := MeshInstance3D.new()
	mi.mesh              = quad
	mi.material_override = _material
	add_child(mi)

	# Position de départ : légèrement en arrière du hitbox dans le sens opposé au facing
	position = Vector3(_world_pos.x - _facing * sweep_back, _world_pos.y, _world_pos.z)
	scale    = Vector3(_facing * s0, s0, 1.0)

	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "position:x", _world_pos.x + _facing * sweep_fwd, 0.15)
	tween.tween_property(self, "scale:x",    _facing * s1,                        0.1)
	tween.tween_property(self, "scale:y",    s1,                                  0.1)
	tween.tween_property(_material, "albedo_color:a", 0.0, 0.35)
	tween.chain().tween_callback(queue_free)


func _build_arc_texture() -> ImageTexture:
	var s   := 64
	var c   := float(s) * 0.5
	var ro  := c - 1.0
	var ri  := ro * 0.42
	var a0  := deg_to_rad(-65.0)
	var a1  := deg_to_rad( 65.0)
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	for y in range(s):
		for x in range(s):
			var dx    := float(x) - c
			var dy    := float(y) - c
			var dist  := sqrt(dx * dx + dy * dy)
			if dist < ri or dist > ro:
				continue
			var angle := atan2(dy, dx)
			if angle < a0 or angle > a1:
				continue
			var ring_t    : float = (dist - ri) / (ro - ri)
			var ring_fade : float = 1.0 - abs(ring_t - 0.5) * 2.0
			var arc_t     : float = (angle - a0) / (a1 - a0)
			var arc_fade  : float = smoothstep(0.0, 0.12, arc_t) * smoothstep(1.0, 0.88, arc_t)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, pow(ring_fade, 0.2) * pow(arc_fade, 0.5)))
	return ImageTexture.create_from_image(img)
