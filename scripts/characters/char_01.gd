extends BaseCharacter

func _ready() -> void:
	char_height       = 1.4
	char_radius       = 0.35
	weight_multiplier = 1.0
	char_speed        = 6.5
	player_id         = 1
	var anim_player = $Model/char_01/AnimationPlayer
	anim_player.call_deferred("play", "mixamo_com")
	anim_player.get_animation("mixamo_com").loop_mode = Animation.LOOP_LINEAR
	super._ready()
