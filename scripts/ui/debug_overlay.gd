extends CanvasLayer

var _ms_history: Array[float] = []
const HISTORY_SIZE = 240

@onready var _label_fps : Label   = $Panel/LabelFPS
@onready var _label_ms  : Label   = $Panel/LabelMS
@onready var _label_res : Label   = $Panel/LabelRes
@onready var _graph     : Control = $Panel/Graph


func _ready() -> void:
	_graph.draw.connect(_on_graph_draw)


func _process(delta: float) -> void:
	var fps := Engine.get_frames_per_second()
	var ms  := delta * 1000.0
	_label_fps.text = "FPS: %d" % fps
	_label_ms.text  = "MS: %.2f" % ms
	var internal_size := get_viewport().get_visible_rect().size
	var display_size  := DisplayServer.window_get_size()
	_label_res.text = "Res: %dx%d -> %dx%d" % [internal_size.x, internal_size.y, display_size.x, display_size.y]
	_ms_history.append(ms)
	if _ms_history.size() > HISTORY_SIZE:
		_ms_history.pop_front()
	_graph.queue_redraw()


func _on_graph_draw() -> void:
	if _ms_history.size() < 2:
		return
	var points := PackedVector2Array()
	for i in range(_ms_history.size()):
		var x := (float(i) / 240.0) * _graph.size.x
		var y: float = _graph.size.y - (clamp(_ms_history[i], 0.0, 33.0) / 33.0) * _graph.size.y
		points.append(Vector2(x, y))
	_graph.draw_polyline(points, Color.GREEN, 2.0)
