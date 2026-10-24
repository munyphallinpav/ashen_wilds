extends Node2D
## Dungeon exit portal (press T).

var prompt


func _ready():
	add_to_group("interact")
	add_to_group("dnode")
	var s = AnimatedSprite2D.new()
	s.sprite_frames = Game.strip_frames("res://assets/world/dungeon_exit.png", 32, 32, 2, 3.0, true)
	s.position = Vector2(0, -14)
	add_child(s)
	s.play("default")
	prompt = Label.new()
	prompt.text = "[T] Leave dungeon"
	prompt.add_theme_font_size_override("font_size", 8)
	prompt.add_theme_color_override("font_outline_color", Color.BLACK)
	prompt.add_theme_constant_override("outline_size", 3)
	prompt.position = Vector2(-38, -42)
	prompt.visible = false
	add_child(prompt)


func _process(_d):
	var p = Game.player
	prompt.visible = p != null and global_position.distance_to(p.global_position) < 30.0 and not Game.hud.ui_open()


func interact():
	Game.main.leave_dungeon(true)
