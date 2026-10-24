extends Node2D
## Warning circle that fills up before a big attack lands.

var radius = 40.0
var dur = 1.0
var col = Color(1, 0.3, 0.1)
var t = 0.0


func _ready():
	z_index = 0


func _process(delta):
	t += delta
	if t >= dur:
		queue_free()
	queue_redraw()


func _draw():
	var k = clampf(t / dur, 0.0, 1.0)
	draw_circle(Vector2.ZERO, radius, Color(col.r, col.g, col.b, 0.12 + 0.18 * k))
	draw_circle(Vector2.ZERO, radius * k, Color(col.r, col.g, col.b, 0.28))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(col.r, col.g, col.b, 0.9), 1.5)
