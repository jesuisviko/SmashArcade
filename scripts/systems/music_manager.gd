# AUTOLOAD À ENREGISTRER dans Project Settings → AutoLoad :
#   Nom : MusicManager   Chemin : res://scripts/systems/music_manager.gd

extends Node

var _asp_a   : AudioStreamPlayer = null
var _asp_b   : AudioStreamPlayer = null
var _primary : AudioStreamPlayer = null
var _tween   : Tween             = null
var _current_path : String       = ""

# Pool SFX — round-robin pour permettre des sons simultanés (P1 + P2 en même temps)
const SFX_POOL_SIZE := 4
var _sfx_pool     : Array[AudioStreamPlayer] = []
var _sfx_pool_idx : int = 0

const COMBAT1_PATH           := "res://assets/sfx/Combat_music_1.mp3"
const SUDDEN_DEATH2_PATH     := "res://assets/sfx/sudden_death_2.mp3"
const SUDDEN_DEATH_LOOP_PATH := "res://assets/sfx/sudden_death_1(no).mp3"
const WIN_MUSIC_PATH         := "res://assets/sfx/win_music.mp3"
const WIN_MUSIC2_PATH        := "res://assets/sfx/win_music_2.mp3"
const DUCK_DB                := 3.74   # -35% en linéaire (-linear_to_db(0.65))


func _ready() -> void:
	_asp_a = AudioStreamPlayer.new()
	_asp_b = AudioStreamPlayer.new()
	add_child(_asp_a)
	add_child(_asp_b)
	_primary = _asp_a
	for i in range(SFX_POOL_SIZE):
		var asp := AudioStreamPlayer.new()
		add_child(asp)
		_sfx_pool.append(asp)


# ─── SFX ─────────────────────────────────────────────────────────────────────

func play_sfx(path: String) -> void:
	var asp := _sfx_pool[_sfx_pool_idx]
	_sfx_pool_idx = (_sfx_pool_idx + 1) % SFX_POOL_SIZE
	asp.stream = load(path)
	asp.play()


func play_random_sfx(base_name: String, count: int) -> void:
	var idx := randi_range(1, count)
	play_sfx("res://assets/sfx/%s_%d.mp3" % [base_name, idx])


# ─── Volume duck (mort / respawn) ────────────────────────────────────────────

func duck_volume(amount_db: float) -> void:
	_primary.volume_db -= amount_db


func restore_volume(amount_db: float) -> void:
	_primary.volume_db += amount_db


# ─── Musique principale ───────────────────────────────────────────────────────

func play_music(path: String, fade_in: float = 0.0) -> void:
	_kill_tween()
	_disconnect_all()
	_current_path      = path
	_primary.stream    = load(path)
	_primary.volume_db = -80.0 if fade_in > 0.0 else 0.0
	_primary.play()
	match path:
		COMBAT1_PATH:
			_primary.finished.connect(_on_combat1_finished)
		WIN_MUSIC_PATH:
			_primary.finished.connect(_on_win_music_finished)
	if fade_in > 0.0:
		_tween = create_tween()
		_tween.tween_property(_primary, "volume_db", 0.0, fade_in)


func stop_music(fade_out: float = 0.0) -> void:
	_kill_tween()
	_disconnect_all()
	_current_path = ""
	if fade_out > 0.0:
		var asp := _primary
		_tween = create_tween()
		_tween.tween_property(asp, "volume_db", -80.0, fade_out)
		_tween.tween_callback(asp.stop)
	else:
		_primary.stop()


func crossfade_to(path: String, fade_out: float = 0.0, fade_in: float = 0.0) -> void:
	_kill_tween()
	var old_asp := _primary
	_disconnect_all()
	_primary = _asp_b if _primary == _asp_a else _asp_a

	_current_path      = path
	_primary.stream    = load(path)
	_primary.volume_db = -80.0
	_primary.play()

	if path == SUDDEN_DEATH2_PATH:
		_primary.finished.connect(_on_sudden_death2_finished)

	var out_dur := maxf(fade_out, 0.001)
	var in_dur  := maxf(fade_in,  0.001)

	_tween = create_tween().set_parallel(true)
	_tween.tween_property(old_asp, "volume_db", -80.0, out_dur)
	_tween.tween_property(_primary, "volume_db", 0.0, in_dur)
	_tween.chain().tween_callback(old_asp.stop)


# ─── Callbacks de fin de piste ────────────────────────────────────────────────

func _on_combat1_finished() -> void:
	if _current_path == COMBAT1_PATH:
		play_music("res://assets/sfx/Combat_music_2.mp3", 2.0)


func _on_win_music_finished() -> void:
	if _current_path == WIN_MUSIC_PATH:
		crossfade_to(WIN_MUSIC2_PATH, 1.0, 1.0)


func _on_sudden_death2_finished() -> void:
	if GameManager.game_state == "game_over":
		return
	_disconnect_all()
	_current_path      = SUDDEN_DEATH_LOOP_PATH
	_primary.stream    = load(SUDDEN_DEATH_LOOP_PATH)
	_primary.volume_db = 0.0
	_primary.play()
	_primary.finished.connect(_on_sudden_death_loop_finished)


func _on_sudden_death_loop_finished() -> void:
	if GameManager.game_state == "game_over":
		_primary.finished.disconnect(_on_sudden_death_loop_finished)
		return
	_primary.play()


# ─── Utilitaires ─────────────────────────────────────────────────────────────

func _disconnect_all() -> void:
	for asp : AudioStreamPlayer in [_asp_a, _asp_b]:
		if asp.finished.is_connected(_on_combat1_finished):
			asp.finished.disconnect(_on_combat1_finished)
		if asp.finished.is_connected(_on_win_music_finished):
			asp.finished.disconnect(_on_win_music_finished)
		if asp.finished.is_connected(_on_sudden_death2_finished):
			asp.finished.disconnect(_on_sudden_death2_finished)
		if asp.finished.is_connected(_on_sudden_death_loop_finished):
			asp.finished.disconnect(_on_sudden_death_loop_finished)


func _kill_tween() -> void:
	if is_instance_valid(_tween):
		_tween.kill()
	_tween = null
