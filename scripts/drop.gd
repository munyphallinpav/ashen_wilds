extends Node2D
## Item on the ground (item dict). Flies to the player when close.

var item = {"id": "wood", "n": 1}
var vel = Vector2.ZERO
var age = 0.0
var delay = 0.3
var spr
var glow


func _ready():
	add_to_group("drops")
	spr = Sprite2D.new()
	spr.texture = Items.icon(item)
	spr.scale = Vector2(0.8, 0.8)
	spr.position = Vector2(0, -5)
	add_child(spr)
	if Items.is_gear(item):
		spr.modulate = Color.WHITE.lerp(Items.color_of(item), 0.35)
		spr.scale = Vector2(0.7, 0.7)
		glow = Sprite2D.new()
		glow.texture = Game.tex("res://assets/items/elem_none.png")
		glow.modulate = Color(Items.color_of(item), 0.5)
		glow.position = Vector2(0, -4)
		glow.z_index = -1
		add_child(glow)
	vel = Vector2.RIGHT.rotated(randf() * TAU) * randf_range(25.0, 50.0)


func _process(delta):
	age += delta
	vel = vel.move_toward(Vector2.ZERO, 120.0 * delta)
	var np = position + vel * delta
	if Game.world.is_walkable(np):
		position = np
	spr.position.y = -5.0 + sin(age * 4.0) * 1.5
	if glow != null:
		glow.scale = Vector2.ONE * (1.0 + 0.15 * sin(age * 5.0))
	var p = Game.player
	if p != null and not p.dead:
		var dist = global_position.distance_to(p.global_position)
		if age > delay + 0.1 and dist < 44.0 and p.can_hold(item):
			position = position.move_toward(p.global_position, 140.0 * delta)
		if age > delay and dist < 8.0:
			if p.can_hold(item):
				p.add_item(item)
				Audio.sfx("pickup", 0.7, 1.0, 0.08)
				queue_free()
			else:
				Game.notify("Bag is full!")
	if age > 180.0:
		queue_free()
