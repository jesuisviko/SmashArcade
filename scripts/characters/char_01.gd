extends BaseCharacter

func _ready() -> void:
	char_height       = 1.4
	char_radius       = 0.35
	weight_multiplier = 1.0
	char_speed        = 6.5
	player_id         = 1
	var anim_player = $Model/char_01_idle_test/AnimationPlayer
	anim_player.call_deferred("play", "!Main|mixamo_com|Layer0")
	anim_player.get_animation("!Main|mixamo_com|Layer0").loop_mode = Animation.LOOP_LINEAR
	super._ready()
