extends Node2D
## One-shot spell visual from Game.FX. Optional rotation / scale / tint.

var kind = "fire"
var rot = 0.0
var scl = 1.0
var tint = Color.WHITE


func _ready():
	z_index = 8
	var s = AnimatedSprite2D.new()
	s.sprite_frames = Game.fx_frames(kind)
	s.modulate = tint
	s.rotation = rot
	s.scale = Vector2(scl, scl)
	if kind == "heal" or kind == "aura":
		s.offset = Vector2(0, -10)
	s.animation_finished.connect(queue_free)
	add_child(s)
	s.play("default")
