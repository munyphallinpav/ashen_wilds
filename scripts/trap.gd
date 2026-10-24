extends Node2D
## Dungeon traps. kind "spikes": cycles up/down and hurts when up. kind "dart": wall turret firing along `dir`.

var kind = "spikes"
var dir = Vector2.RIGHT
var level = 1
var t = 0.0
var spr
var cd = 0.0
var hit_cd = 0.0
var period = 3.2


func _ready():
	add_to_group("dnode")
	t = randf() * period
	spr = Sprite2D.new()
	if kind == "spikes":
		spr.texture = Game.tex("res://assets/world/spikes.png")
		spr.region_enabled = true
		spr.region_rect = Rect2(0, 0, 16, 16)
		spr.offset = Vector2(0, -8)
		z_index = -2
	else:
		spr.texture = Game.tex("res://assets/world/dart_trap.png")
		spr.offset = Vector2(0, -8)
		spr.rotation = dir.angle()
		spr.position = Vector2(0, -8)
		spr.offset = Vector2.ZERO
	add_child(spr)


func _process(delta):
	var p = Game.player
	if p == null or p.dead:
		return
	if kind == "spikes":
		t = fmod(t + delta, period)
		var f = 0
		if t > period - 1.0:
			f = 1 if t < period - 0.6 else 2
		spr.region_rect = Rect2(f * 16, 0, 16, 16)
		hit_cd = maxf(0.0, hit_cd - delta)
		if f == 2 and hit_cd <= 0.0 and p.global_position.distance_to(global_position) < 9.0:
			hit_cd = 0.8
			p.take_damage(p.max_hp * 0.08 + 6.0 * Game.mob_dmg_scale(level), global_position, 80.0, "", {"lvl": level, "magic": false})
	else:
		cd = maxf(0.0, cd - delta)
		var rel = p.global_position - global_position
		if cd <= 0.0 and rel.length() < 150.0:
			var along = rel.dot(dir)
			var perp = absf(rel.dot(dir.orthogonal()))
			if along > 10.0 and perp < 14.0:
				cd = 2.2
				Game.shoot({"position": global_position + dir * 8.0 + Vector2(0, -8), "dir": dir, "speed": 150.0, "kind": "arrow", "arrow": true,
					"hostile": true, "dmg": 8.0 * Game.mob_dmg_scale(level), "life": 1.6, "lvl": level, "kb": 60.0})
