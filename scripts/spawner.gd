extends Node2D
## Monster spawning device. Destroy it to stop the flow of monsters (it also drops gold).
## Set biome, type (monster to spawn), level, diff, uid, hp scaling before adding.

var biome = "forest"
var type = "slime"
var level = 1
var diff = 0.0
var uid = -1
var hp = 100.0
var max_hp = 100.0
var hit_radius = 10.0
var spawn_t = 3.0
var alive_kids = []
var t = 0.0
var spr
var glow
var bar_t = 0.0
const NAMES = {"lava": "Magma Vent", "forest": "Root Nest", "mushroom": "Spore Pod", "plains": "Ruined Totem", "beach": "Coral Hive", "cave": "Bone Altar"}
const COLORS = {"lava": Color("#ff8a2a"), "forest": Color("#7ae060"), "mushroom": Color("#d8a0ff"), "plains": Color("#f0e070"), "beach": Color("#60e0f0"), "cave": Color("#d0d8ea")}


func _ready():
	add_to_group("hurtable")
	add_to_group("dnode")
	max_hp = 60.0 * Game.mob_hp_scale(maxi(level, 1)) * (1.0 + diff * 0.3)
	hp = max_hp
	spr = Sprite2D.new()
	spr.texture = Game.tex("res://assets/world/spawner_%s.png" % biome)
	spr.offset = Vector2(0, -14)
	add_child(spr)
	glow = Sprite2D.new()
	glow.texture = Game.light_tex()
	glow.position = Vector2(0, -16)
	glow.scale = Vector2(0.35, 0.35)
	glow.modulate = Color(COLORS[biome], 0.5)
	var m = CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = m
	add_child(glow)
	var body = StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var cs = CollisionShape2D.new()
	var r = RectangleShape2D.new()
	r.size = Vector2(16, 8)
	cs.shape = r
	cs.position = Vector2(0, -4)
	body.add_child(cs)
	add_child(body)


func _process(delta):
	t += delta
	var pulse = 0.5 + 0.5 * sin(t * 3.0)
	glow.modulate.a = 0.35 + 0.35 * pulse
	bar_t = maxf(0.0, bar_t - delta)
	queue_redraw()
	var p = Game.player
	if p == null or p.dead or Game.dlayout == null:
		return
	alive_kids = alive_kids.filter(func(k): return is_instance_valid(k) and not k.is_in_group("dead"))
	if p.global_position.distance_to(global_position) > 170.0:
		return
	spawn_t -= delta
	if spawn_t <= 0.0 and alive_kids.size() < 3:
		spawn_t = 7.0 - minf(2.5, diff * 0.8)
		_spawn()


func _spawn():
	if Game.dlayout == null:
		return
	var ang = randf() * TAU
	var pos = global_position + Vector2(cos(ang), sin(ang)) * 18.0
	if not Game.dlayout.walkable(pos):
		pos = global_position + Vector2(0, 18)
	var e = Game.world.spawn_mob(type, pos, level)
	e.diff = diff
	e.angry = true
	alive_kids.append(e)
	Game.spawn_fx("smoke", pos, {"scl": 0.7})
	Audio.sfx("portal", 0.35, 1.6, 0.5)


func take_damage(amount, _from_pos, _kb = 0.0, element = "", opts = {}):
	if hp <= 0.0:
		return
	var dm = maxf(1.0, amount * Game.def_factor(Game.mob_def(maxi(level, 1)) * 1.5, opts.get("lvl", 1)))
	hp -= dm
	bar_t = 4.0
	Game.float_text(str(int(round(dm))), global_position + Vector2(0, -20), Color(1, 0.9, 0.4), 8)
	Audio.sfx("hit", 0.8)
	spr.modulate = Color(1.6, 0.8, 0.8)
	create_tween().tween_property(spr, "modulate", Color.WHITE, 0.15)
	if hp <= 0.0:
		_destroy()


func _destroy():
	remove_from_group("hurtable")
	Audio.sfx("enemy_die", 1.0, 0.7)
	Game.main.shake(2.0)
	Game.spawn_fx("fire", global_position + Vector2(0, -10), {"scl": 1.0})
	Game.notify("%s destroyed" % NAMES[biome])
	var cur = Game.cur_dungeon
	if cur != null and uid >= 0 and not cur["state"]["killed"].has(uid):
		cur["state"]["killed"].append(uid)
	var p = Game.player
	if p != null:
		p.add_gold(int(8.0 * (2.0 + level * 1.5)))
		p.add_xp(int(6.0 * level + 10))
	queue_free()


func _draw():
	if bar_t > 0.0 and hp < max_hp:
		var w = 24.0
		draw_rect(Rect2(-w / 2.0 - 1, -37, w + 2, 5), Color(0.02, 0.02, 0.05, 0.9))
		draw_rect(Rect2(-w / 2.0, -36, w * clampf(hp / max_hp, 0.0, 1.0), 3), COLORS[biome])
		draw_string(ThemeDB.fallback_font, Vector2(-w / 2.0 - 4, -40), NAMES[biome], HORIZONTAL_ALIGNMENT_LEFT, -1, 6, Color(1, 1, 1, 0.95))
