extends Node2D
## Campfire: cooking/smelting station (craft recipes marked "fire" need you standing near one) + night light.


var placed = true   # false for the village fire (not saved, recreated by the world)


func _ready():
	add_to_group("fire")
	var s = AnimatedSprite2D.new()
	s.sprite_frames = Game.strip_frames("res://assets/world/campfire.png", 16, 16, 3, 7.0, true)
	s.offset = Vector2(0, -5)
	add_child(s)
	s.play("default")
	var l = PointLight2D.new()
	var gt = GradientTexture2D.new()
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 128
	gt.height = 128
	var g = Gradient.new()
	g.set_color(0, Color(1.0, 0.7, 0.35, 1.0))
	g.set_color(1, Color(0, 0, 0, 0))
	gt.gradient = g
	l.texture = gt
	l.energy = 0.9
	l.position = Vector2(0, -6)
	add_child(l)
	var tw = create_tween().set_loops()
	tw.tween_property(l, "energy", 1.2, 0.25)
	tw.tween_property(l, "energy", 0.8, 0.3)
