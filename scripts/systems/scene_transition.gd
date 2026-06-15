# AUTOLOAD À ENREGISTRER dans Project Settings → AutoLoad :
#   Nom : SceneTransition   Chemin : res://scripts/systems/scene_transition.gd

extends CanvasLayer

var _rect : ColorRect

func _ready() -> void:
	layer = 100
	_rect = ColorRect.new()
	_rect.color = Color.BLACK
	_rect.modulate.a = 0.0
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rect)


func transition_to(scene_path: String) -> void:
	var tween := create_tween()
	tween.tween_property(_rect, "modulate:a", 1.0, 0.25)
	tween.tween_interval(0.1)
	tween.tween_callback(get_tree().change_scene_to_file.bind(scene_path))
	tween.tween_interval(0.05)
	tween.tween_property(_rect, "modulate:a", 0.0, 0.25)
