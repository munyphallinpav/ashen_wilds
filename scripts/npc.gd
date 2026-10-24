extends Node2D
## Village trader. Stand close and press T to trade (data in Game.NPCS).

var npc_id = "merchant"
var data = {}
var sprite
var prompt


func _ready():
	data = Game.NPCS[npc_id]
	add_to_group("npc")
	add_to_group("interact")
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = Game.char_frames("res://assets/characters/%s.png" % data["style"])
	sprite.position = Vector2(0, -12)
	add_child(sprite)
	sprite.play("idle_down")
	var bt = create_tween().set_loops()
	bt.tween_interval(randf() * 1.5)
	bt.tween_property(sprite, "scale:y", 1.035, 0.9).set_trans(Tween.TRANS_SINE)
	bt.tween_property(sprite, "scale:y", 1.0, 0.9).set_trans(Tween.TRANS_SINE)
	var nm = Label.new()
	nm.text = data["name"]
	nm.add_theme_font_size_override("font_size", 7)
	nm.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	nm.add_theme_color_override("font_outline_color", Color.BLACK)
	nm.add_theme_constant_override("outline_size", 3)
	nm.position = Vector2(-44, 3)
	nm.custom_minimum_size = Vector2(88, 0)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(nm)
	prompt = Label.new()
	prompt.text = "[T] Trade"
	prompt.add_theme_font_size_override("font_size", 8)
	prompt.add_theme_color_override("font_outline_color", Color.BLACK)
	prompt.add_theme_constant_override("outline_size", 3)
	prompt.position = Vector2(-20, -66)
	prompt.visible = false
	add_child(prompt)
	# solid so the player cannot walk through
	var body = StaticBody2D.new()
	body.collision_layer = 1
	var cs = CollisionShape2D.new()
	var c = CircleShape2D.new()
	c.radius = 4.0
	cs.shape = c
	cs.position = Vector2(0, -3)
	body.add_child(cs)
	add_child(body)


func _process(_delta):
	var p = Game.player
	if p == null:
		return
	var near = global_position.distance_to(p.global_position) < 52.0
	prompt.visible = near and not Game.hud.ui_open()
	if near:
		sprite.play("idle_side")
		sprite.flip_h = p.global_position.x < global_position.x
	else:
		sprite.play("idle_down")
		sprite.flip_h = false


func interact():
	Game.hud.open_npc(npc_id)
