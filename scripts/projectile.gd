extends Node2D
## Arrows, bolts and monster missiles. Set the vars through Game.shoot({...}).
## Player projectiles roll damage on impact from "base"; hostile ones deal fixed "dmg" to the player.

var kind = "fire"
var dir = Vector2.RIGHT
var speed = 200.0
var base = 10.0
var magic = false
var element = ""
var status = []
var aoe = 0.0
var pierce = false
var life = 1.5
var kb = 80.0
var hit_fx = ""
var tint = Color.WHITE
var arrow = false
var force_crit = false
var heal = 0.0
var hit_set = []
var hostile = false
var dmg = 10.0
var lvl = 1
var healed = false


func _ready():
	z_index = 6
	rotation = dir.angle()
	if arrow:
		var s = Sprite2D.new()
		s.texture = Game.tex("res://assets/items/arrow.png")
		s.rotation = PI / 2.0
		add_child(s)
	else:
		var a = AnimatedSprite2D.new()
		a.sprite_frames = Game.proj_frames(kind)
		a.modulate = tint
		add_child(a)
		a.play("default")


func _physics_process(delta):
	position += dir * speed * delta
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	if Game.world.blocks_proj(global_position):
		_impact(null)
		return
	if hostile:
		var pl = Game.player
		if pl != null and not pl.dead and global_position.distance_to(pl.global_position + Vector2(0, -8)) < 8.0:
			pl.take_damage(dmg, global_position - dir * 10.0, kb, element, {"magic": magic, "lvl": lvl, "status": status})
			if hit_fx != "":
				Game.spawn_fx(hit_fx, global_position, {"scl": 0.7})
			queue_free()
		return
	for r in get_tree().get_nodes_in_group("resources"):
		if r.alive and r.coll > 0 and absf(r.global_position.x - global_position.x) < 12.0 and absf(r.global_position.y - global_position.y) < 14.0:
			if global_position.distance_to(r.global_position + Vector2(0, -6)) < r.radius:
				r.take_hit(Game.gather_power() * 0.8, Game.player)
				_impact(null)
				return
	for e in get_tree().get_nodes_in_group("hurtable"):
		if not is_instance_valid(e) or hit_set.has(e):
			continue
		if global_position.distance_to(e.global_position + Vector2(0, -8)) < e.hit_radius + 5.0:
			_impact(e)
			if pierce:
				hit_set.append(e)
			else:
				return


func _impact(e):
	var pl = Game.player
	if hostile:
		queue_free()
		return
	if aoe > 0.0:
		Game.area_attack(global_position, aoe, base, magic, element, kb, status, force_crit)
		Game.spawn_fx(hit_fx if hit_fx != "" else "fire", global_position, {"scl": maxf(aoe / 34.0, 0.6)})
	elif e != null:
		Game.hit(e, Game.roll_damage(pl, base, force_crit), global_position - dir * 10.0, kb, element, magic, status)
		if hit_fx != "":
			Game.spawn_fx(hit_fx, global_position, {"scl": 0.7})
	if e != null and heal > 0.0 and not healed:
		healed = true
		pl.heal(heal)
	if e == null or not pierce:
		queue_free()
