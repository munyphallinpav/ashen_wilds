extends Node2D
## Overworld dungeon portal. Hidden until the player comes close, then press T to enter.

var rec = {}
var spr
var prompt
var found = false
var fade = 0.0


func _ready():
	add_to_group("interact")
	add_to_group("dentrance")
	spr = AnimatedSprite2D.new()
	spr.sprite_frames = Game.strip_frames("res://assets/world/portal_%s.png" % rec["biome"], 32, 32, 4, 7.0, true)
	spr.position = Vector2(0, -14)
	add_child(spr)
	spr.play("default")
	spr.modulate = Color(1, 1, 1, 0)
	prompt = Label.new()
	prompt.add_theme_font_size_override("font_size", 8)
	prompt.add_theme_color_override("font_outline_color", Color.BLACK)
	prompt.add_theme_constant_override("outline_size", 3)
	prompt.position = Vector2(-60, -44)
	prompt.custom_minimum_size = Vector2(120, 0)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.visible = false
	add_child(prompt)
	found = rec.get("found", false)
	var l = PointLight2D.new()
	var gt = GradientTexture2D.new()
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 96
	gt.height = 96
	var g = Gradient.new()
	g.set_color(0, Color(Color(Game.DUNGEONS[rec["biome"]]["color"]), 1.0))
	g.set_color(1, Color(0, 0, 0, 0))
	gt.gradient = g
	l.texture = gt
	l.energy = 0.7
	l.position = Vector2(0, -12)
	add_child(l)


func _process(delta):
	var p = Game.player
	if p == null or Game.cur_dungeon != null:
		return
	var dist = global_position.distance_to(p.global_position)
	if not found and dist < 110.0:
		found = true
		rec["found"] = true
		Game.notify("You discovered the %s!" % Game.DUNGEONS[rec["biome"]]["name"])
	fade = move_toward(fade, 1.0 if found else 0.0, delta * 1.5)
	spr.modulate.a = fade
	var near = found and dist < 34.0 and not Game.hud.ui_open()
	prompt.visible = near
	if near:
		var secs = int(rec["time_left"])
		prompt.text = "[T] Enter %s\nRank %d  (%d:%02d left)" % [Game.DUNGEONS[rec["biome"]]["name"], rec["level"], secs / 60, secs % 60]


func interact():
	if found and Game.cur_dungeon == null:
		Game.main.enter_dungeon(rec)
