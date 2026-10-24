extends Node2D
## Lingering area: damages / debuffs enemies (or the player when hostile) every tick. Optional looping visual.

var radius = 40.0
var dur = 3.0
var tick = 0.5
var base = 0.0
var magic = false
var element = ""
var status = []
var fx = "zone"
var kb = 0.0
var tint = Color.WHITE
var hostile = false
var dmg = 0.0
var lvl = 1
var player_buff = null
var t = 0.0
var acc = 0.0


func _ready():
	z_index = 1
	if fx != "":
		var s = AnimatedSprite2D.new()
		s.sprite_frames = Game.fx_frames(fx)
		s.modulate = Color(tint.r, tint.g, tint.b, 0.8)
		var sz = Game.FX[fx][1]
		var k = radius * 2.0 / float(sz) * 1.1
		s.scale = Vector2(k, k)
		add_child(s)
		s.play("default")


func _physics_process(delta):
	t += delta
	acc += delta
	if t >= dur:
		queue_free()
		return
	if acc < tick:
		return
	acc = 0.0
	var pl = Game.player
	if hostile:
		if pl != null and not pl.dead and global_position.distance_to(pl.global_position) <= radius:
			pl.take_damage(dmg, global_position, kb, element, {"magic": magic, "lvl": lvl, "status": status})
		return
	if base > 0.0:
		for e in Game.enemies_in_circle(global_position, radius):
			Game.hit(e, Game.roll_damage(pl, base), global_position, kb, element, magic, status)
	else:
		for e in Game.enemies_in_circle(global_position, radius):
			e.apply_statuses(status, 0.0)
	if player_buff != null and pl != null and global_position.distance_to(pl.global_position) <= radius:
		pl.add_buff(player_buff[0], player_buff[1], player_buff[2])
