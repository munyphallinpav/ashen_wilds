extends StaticBody2D
## Harvestable world object: trees, rocks, ores, herbs (hit them with any weapon; STR boosts gathering). Respawns after a while.

var kind = "oak"
var d = {}
var hp = 10.0
var alive = true
var radius = 8.0
var spr
var cs
var respawn_t = 0.0
var coll = 4


func _ready():
	d = Game.RES[kind]
	hp = d["hp"]
	radius = d["radius"]
	coll = d["coll"]
	add_to_group("resources")
	collision_layer = 1
	collision_mask = 0
	cs = CollisionShape2D.new()
	var c = CircleShape2D.new()
	c.radius = maxf(coll, 1)
	cs.shape = c
	cs.position = Vector2(0, -2)
	add_child(cs)
	spr = Sprite2D.new()
	add_child(spr)
	_set_tex(d["tex"])
	if kind in ["oak", "pine", "palm", "shroom", "dead"]:
		spr.material = Game.wind_material(1.7, 34.0)
	elif kind in ["herb", "mushpatch"]:
		spr.material = Game.wind_material(0.9, 12.0)
	set_process(false)


func _process(delta):
	respawn_t -= delta
	if respawn_t <= 0.0:
		_respawn()


func force_deplete(t_left):
	alive = false
	hp = 0.0
	cs.set_deferred("disabled", true)
	if d["stump"] != "":
		_set_tex(d["stump"])
	else:
		spr.visible = false
	respawn_t = t_left
	set_process(true)


func _set_tex(path):
	var t = Game.tex(path)
	spr.texture = t
	spr.offset = Vector2(0, -(t.get_height() / 2.0 - 3.0))


var chip_cd = 0.0


## Hit from a ranged / area attack: rate limited so zones and multi-ticks do not delete a tree instantly.
func chip(power, by):
	var now = Time.get_ticks_msec() / 1000.0
	if now < chip_cd:
		return
	chip_cd = now + 0.25
	take_hit(power, by)


func take_hit(power, by):
	if not alive:
		return
	hp -= power
	Audio.sfx("mine" if kind in ["iron", "coal"] else "chop", 0.7, 1.0, 0.1)
	Game.chips(global_position + Vector2(0, -10), d["chip"], 6)
	var tw = create_tween()
	tw.tween_property(spr, "position:x", 1.5, 0.04)
	tw.tween_property(spr, "position:x", -1.5, 0.04)
	tw.tween_property(spr, "position:x", 0.0, 0.04)
	if hp <= 0.0:
		_deplete(by)


func _deplete(by):
	alive = false
	var items = []
	for id in d["drops"]:
		var rg = d["drops"][id]
		var n = randi_range(rg[0], rg[1])
		if by != null and randf() * 100.0 < by.stats["drop"] * 0.5:
			n += 1
		if n > 0:
			items.append(Items.make(id, n))
	Items.scatter(items, global_position)
	if by != null:
		by.add_xp(d["xp"] * (1 + by.level / 10))
	cs.set_deferred("disabled", true)
	if d["stump"] != "":
		_set_tex(d["stump"])
	else:
		spr.visible = false
	Game.chips(global_position + Vector2(0, -8), d["chip"], 10)
	respawn_t = d["respawn"]
	set_process(true)


func _respawn():
	alive = true
	hp = d["hp"]
	cs.set_deferred("disabled", false)
	spr.visible = true
	_set_tex(d["tex"])
	set_process(false)
