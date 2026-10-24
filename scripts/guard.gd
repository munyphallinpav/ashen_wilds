extends Node2D
## Strong town guard. Strikes any monster that comes close to the walls.

const RANGE = 130.0
const DAMAGE = 600.0

var sprite
var cd = 0.5
var face = "down"
var bolts = []


func _ready():
	add_to_group("guard")
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = Game.char_frames("res://assets/characters/knight.png")
	sprite.position = Vector2(0, -12)
	sprite.scale = Vector2(1.1, 1.1)
	add_child(sprite)
	_face()
	var bt = create_tween().set_loops()
	bt.tween_interval(randf() * 1.5)
	bt.tween_property(sprite, "scale:y", 1.15, 0.9).set_trans(Tween.TRANS_SINE)
	bt.tween_property(sprite, "scale:y", 1.1, 0.9).set_trans(Tween.TRANS_SINE)
	var nm = Label.new()
	nm.text = "Town Guard"
	nm.add_theme_font_size_override("font_size", 6)
	nm.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	nm.add_theme_color_override("font_outline_color", Color.BLACK)
	nm.add_theme_constant_override("outline_size", 3)
	nm.position = Vector2(-30, -40)
	nm.custom_minimum_size = Vector2(60, 0)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(nm)
	var body = StaticBody2D.new()
	body.collision_layer = 1
	var cs = CollisionShape2D.new()
	var r = CircleShape2D.new()
	r.radius = 5.0
	cs.shape = r
	body.add_child(cs)
	add_child(body)


func _face():
	if face == "left" or face == "right":
		sprite.play("idle_side")
		sprite.flip_h = face == "left"
	else:
		sprite.play("idle_" + face)
		sprite.flip_h = false


func _physics_process(delta):
	for b in bolts.duplicate():
		b[1] -= delta
		if b[1] <= 0.0:
			bolts.erase(b)
	if not bolts.is_empty() or cd > 0.0:
		queue_redraw()
	cd -= delta
	if cd > 0.0 or get_tree().paused:
		return
	var best = null
	var bd = RANGE
	for e in get_tree().get_nodes_in_group("hurtable"):
		if not is_instance_valid(e) or e.is_in_group("dead") or not (e is Node2D):
			continue
		if e.get("hp") != null and e.hp <= 0.0:
			continue
		var d = global_position.distance_to(e.global_position)
		if d < bd:
			bd = d
			best = e
	if best == null:
		cd = 0.2
		return
	cd = 1.0
	var dir = best.global_position - global_position
	if absf(dir.x) > absf(dir.y):
		face = "right" if dir.x > 0 else "left"
	else:
		face = "down" if dir.y > 0 else "up"
	_face()
	bolts.append([best.global_position - global_position, 0.18])
	best.take_damage(DAMAGE, global_position, 120.0, "light", {"lvl": 100})


func _draw():
	for b in bolts:
		var a = b[1] / 0.18
		draw_line(Vector2(0, -14), b[0] + Vector2(0, -8), Color(1, 0.95, 0.6, a), 2.0)
		draw_circle(b[0] + Vector2(0, -8), 5.0 * a, Color(1, 1, 0.8, a))
