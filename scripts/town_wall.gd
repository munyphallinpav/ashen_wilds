extends Node2D
## One 16px chunk of the town wall (drawn procedurally, solid). tower = taller gate tower.

var tower = false


func _ready():
	var b = StaticBody2D.new()
	b.collision_layer = 1
	b.collision_mask = 0
	var cs = CollisionShape2D.new()
	var r = RectangleShape2D.new()
	r.size = Vector2(16, 12)
	cs.shape = r
	cs.position = Vector2(0, -6)
	b.add_child(cs)
	add_child(b)


func _draw():
	var h = 30.0 if tower else 22.0
	var base = Color(0.52, 0.52, 0.58) if not tower else Color(0.42, 0.42, 0.5)
	draw_rect(Rect2(-8, -h, 16, h), base)
	draw_rect(Rect2(-8, -h, 16, 3), Color(0.68, 0.68, 0.74))
	# bricks
	var dark = Color(0.34, 0.34, 0.4)
	var y = -h + 6.0
	var row = 0
	while y < 0.0:
		draw_line(Vector2(-8, y), Vector2(8, y), dark, 1.0)
		var off = 0.0 if row % 2 == 0 else 4.0
		for x in [-4.0 + off, 4.0 + off]:
			if x > -8.0 and x < 8.0:
				draw_line(Vector2(x, y), Vector2(x, minf(y + 5.0, 0.0)), dark, 1.0)
		y += 5.0
		row += 1
	# battlements
	if tower:
		for i in range(-1, 2):
			draw_rect(Rect2(i * 6 - 2, -h - 4, 4, 4), Color(0.68, 0.68, 0.74))
	draw_rect(Rect2(-8, -2, 16, 2), Color(0.22, 0.22, 0.27))
