extends PointLight2D
## Lamp light: nearly off by day, warm and flickering at night.

var base = 0.9
var t = 0.0
var amount = 0.0


func _process(delta):
	t += delta
	amount = move_toward(amount, 1.0 if Game.is_night else 0.0, delta * 0.8)
	var flick = 1.0 + 0.1 * sin(t * 9.0 + position.x) + 0.06 * sin(t * 23.0)
	energy = base * flick * (0.04 + 0.96 * amount)
