extends Node2D
## Entry point: title menu -> world + player (new game or loaded save), day/night, dungeon spawning / entering / leaving, saving.

const WorldScript = preload("res://scripts/world.gd")
const HudScript = preload("res://scripts/hud.gd")
const PlayerScript = preload("res://scripts/player.gd")
const MapScript = preload("res://scripts/map_data.gd")
const BossScript = preload("res://scripts/boss.gd")
const DungeonScript = preload("res://scripts/dungeon.gd")
const EntranceScript = preload("res://scripts/dungeon_entrance.gd")
const ChestScript = preload("res://scripts/chest.gd")
const TrapScript = preload("res://scripts/trap.gd")
const ExitScript = preload("res://scripts/exit_portal.gd")
const DAY_LEN = 360.0
const MAX_DUNGEONS = 8

var world
var entities
var hud
var tint
var cam
var tod = 0.25
var started = false
var spawn_t = 0.0
var dungeon_t = 0.0
var next_id = 1
var entrances = {}
var return_pos = Vector2.ZERO
var d_ground = null
var shake_amt = 0.0
var boss_node = null


func _ready():
	randomize()
	Game.main = self
	Game.world = null
	Game.entities = null
	Game.player = null
	Game.map = null
	Game.waypoint = null
	Game.dungeons = []
	Game.cur_dungeon = null
	Game.dlayout = null
	Game.play_time = 0.0
	get_tree().paused = false
	RenderingServer.set_default_clear_color(Color("2f6fa8"))
	tint = CanvasModulate.new()
	add_child(tint)
	hud = HudScript.new()
	add_child(hud)
	Game.hud = hud
	hud.character_chosen.connect(_new_game)
	if Game.pending_load != null:
		var d = Game.pending_load
		Game.pending_load = null
		_begin(int(d["seed"]), str(d["char"]), d)
	else:
		hud.show_title()


func _new_game(char_id):
	_begin(randi(), char_id, null)
	save_game(Game.current_slot, true)


func _begin(seed_val, char_id, data):
	world = WorldScript.new()
	add_child(world)
	entities = Node2D.new()
	entities.y_sort_enabled = true
	add_child(entities)
	Game.world = world
	Game.entities = entities
	world.generate(seed_val, entities)
	Game.map = MapScript.new()
	Game.waypoint = null

	var p = PlayerScript.new()
	p.char_id = char_id
	p.position = world.spawn_pos
	entities.add_child(p)
	Game.player = p
	cam = Camera2D.new()
	cam.position = Vector2(0, -10)
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 8.0
	_overworld_limits()
	p.add_child(cam)
	cam.make_current()
	_build_ambient()
	hud.bind_player(p)

	if data != null:
		_restore(data, p)
	else:
		p.new_game_kit()
		world.populate()
		for i in range(5):
			_spawn_dungeon(true)
		Game.notify("Welcome! Spend your starting points: C = stats, K = skills. T talks / interacts. H = help.")
	started = true
	hud.set_panel("")


func _overworld_limits():
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = Game.W * 16
	cam.limit_bottom = Game.H * 16


func shake(a):
	shake_amt = maxf(shake_amt, a)


func _restore(d, p):
	p.apply_save(d["player"])
	tod = float(d.get("tod", 0.25))
	if d.has("explored"):
		Game.map.load_base64(str(d["explored"]))
	if d.get("waypoint") != null:
		Game.waypoint = Vector2(d["waypoint"][0], d["waypoint"][1])
	Game.play_time = float(d.get("play_time", 0.0))
	next_id = int(d.get("next_id", 1))
	for r in d.get("dungeons", []):
		var rec = r
		rec["id"] = int(rec["id"])
		rec["level"] = int(rec["level"])
		rec["diff"] = int(rec["diff"])
		rec["seed"] = int(rec["seed"])
		var st = rec["state"]
		var killed = []
		for k in st["killed"]:
			killed.append(int(k))
		st["killed"] = killed
		var opened = []
		for k in st["opened"]:
			opened.append(int(k))
		st["opened"] = opened
		Game.dungeons.append(rec)
		_make_entrance(rec)
	for m in d.get("mobs", []):
		if Game.MOBS.has(m["t"]):
			world.spawn_mob(m["t"], Vector2(m["x"], m["y"]), int(m["lv"]), bool(m.get("mini", false)), float(m["hp"]))
	for c in d.get("campfires", []):
		world.add_campfire(Vector2(c[0], c[1]), true)
	for dep in d.get("depleted", []):
		var i = int(dep[0])
		if i >= 0 and i < world.res_nodes.size():
			world.res_nodes[i].force_deplete(float(dep[1]))
	Game.notify("Game loaded")


# ------------------------------------------------------------ saving / loading
func make_save():
	var pdata = Game.player.make_save()
	if Game.cur_dungeon != null:
		pdata["pos"] = [return_pos.x, return_pos.y]
	var d = {"version": 3, "time": Time.get_datetime_string_from_system(false, true), "play_time": Game.play_time,
		"seed": world.seed_val, "tod": tod, "char": Game.player.char_id, "player": pdata,
		"mobs": [], "campfires": [], "depleted": [], "next_id": next_id, "dungeons": Game.dungeons,
		"explored": Game.map.to_base64(),
		"waypoint": [Game.waypoint.x, Game.waypoint.y] if Game.waypoint != null else null}
	if Game.cur_dungeon == null:
		for e in get_tree().get_nodes_in_group("hurtable"):
			if e.is_in_group("dnode") or e.is_in_group("bosses"):
				continue
			d["mobs"].append({"t": e.type, "x": e.global_position.x, "y": e.global_position.y, "hp": e.hp, "lv": e.level, "mini": e.mini})
	for f in get_tree().get_nodes_in_group("fire"):
		if f.placed:
			d["campfires"].append([f.global_position.x, f.global_position.y])
	for i in range(world.res_nodes.size()):
		var r = world.res_nodes[i]
		if not r.alive:
			d["depleted"].append([i, r.respawn_t])
	return d


func save_game(slot, auto = false):
	if not started:
		return
	if Game.write_slot(slot, make_save()):
		Game.current_slot = slot
		Game.notify(("Autosaved (slot %d)" if auto else "Saved to slot %d") % slot)
	else:
		Game.notify("Save failed!")


func load_game(slot):
	var d = Game.read_slot(slot)
	if d == null:
		Game.notify("Slot %d is empty or corrupt" % slot)
		return
	Game.pending_load = d
	Game.current_slot = slot
	get_tree().paused = false
	get_tree().reload_current_scene()


# ------------------------------------------------------------ ambient particles (pollen / fireflies / embers / spores)
var ambient
var ambient_t = 0.0


func _build_ambient():
	ambient = CPUParticles2D.new()
	ambient.local_coords = false
	ambient.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	ambient.emission_rect_extents = Vector2(250, 150)
	ambient.lifetime = 7.0
	ambient.preprocess = 7.0
	ambient.direction = Vector2(1, -0.3)
	ambient.spread = 180.0
	ambient.z_index = 20
	var gr = Gradient.new()
	gr.add_point(0.15, Color(1, 1, 1, 1))
	gr.add_point(0.85, Color(1, 1, 1, 1))
	gr.set_color(0, Color(1, 1, 1, 0))
	gr.set_color(gr.get_point_count() - 1, Color(1, 1, 1, 0))
	ambient.color_ramp = gr
	cam.add_child(ambient)
	_update_ambient()


func _update_ambient():
	if ambient == null or Game.player == null:
		return
	var biome = world.biome_at(Game.player.global_position) if Game.cur_dungeon == null else "dungeon"
	var amount = 26
	var col = Color(1, 1, 0.82, 0.7)
	var vmin = 3.0
	var vmax = 8.0
	var grav = Vector2.ZERO
	var smin = 1.0
	var smax = 2.0
	if Game.cur_dungeon != null:
		col = Color(0.8, 0.8, 0.9, 0.4)
		amount = 18
	elif Game.is_night:
		col = Color(0.85, 1.0, 0.35, 0.95)   # fireflies
		amount = 34
		smin = 1.6
		smax = 2.8
	elif biome == "volcanic":
		col = Color(1.0, 0.5, 0.15, 0.9)
		amount = 44
		vmin = 6.0
		vmax = 14.0
		grav = Vector2(0, -10)
	elif biome == "mushroom":
		col = Color(0.85, 0.55, 1.0, 0.8)
		amount = 36
		grav = Vector2(0, -4)
	elif biome == "mountain":
		col = Color(0.9, 0.9, 0.95, 0.45)
		amount = 16
	elif biome == "forest":
		col = Color(0.7, 0.95, 0.45, 0.75)   # drifting leaves
		amount = 24
		grav = Vector2(2, 4)
	ambient.amount = amount
	ambient.color = col
	ambient.initial_velocity_min = vmin
	ambient.initial_velocity_max = vmax
	ambient.gravity = grav
	ambient.scale_amount_min = smin
	ambient.scale_amount_max = smax
	ambient.emitting = true


# ------------------------------------------------------------ world simulation
func _notification(what):
	# closing the window saves first
	if what == NOTIFICATION_WM_CLOSE_REQUEST and started and Game.player != null and not Game.player.dead:
		save_game(Game.current_slot, true)


const AUTOSAVE_SECS = 60.0
var autosave_t = 0.0


func _process(delta):
	if not started:
		return
	var p = Game.player
	autosave_t += delta
	if autosave_t >= AUTOSAVE_SECS:
		autosave_t = 0.0
		if not p.dead:
			save_game(Game.current_slot, true)
	if Game.cur_dungeon == null:
		Game.map.reveal(p.global_position)
		tod += delta / DAY_LEN
		var k = 0.5 + 0.5 * sin(tod * TAU)
		tint.color = Color(0.32, 0.38, 0.65).lerp(Color(1, 1, 1), smoothstep(0.2, 0.7, k))
		Game.is_night = k < 0.3
		hud.time_label.text = "Night - beware!" if Game.is_night else "Day"
		ambient_t += delta
		if ambient_t > 1.5:
			ambient_t = 0.0
			_update_ambient()
		spawn_t += delta
		if spawn_t > 5.0:
			spawn_t = 0.0
			_manage_spawns()
		_tick_dungeons(delta)
	else:
		Game.dlayout.reveal(p.global_position)
		Game.is_night = false
		hud.time_label.text = Game.DUNGEONS[Game.cur_dungeon["biome"]]["name"]
	# camera shake
	if shake_amt > 0.05:
		cam.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_amt
		shake_amt = move_toward(shake_amt, 0.0, delta * 14.0)
	else:
		cam.offset = Vector2.ZERO
	# interact key
	if Input.is_action_just_pressed("interact") and not hud.ui_open() and not p.dead:
		_interact()


func _interact():
	var best = null
	var bd = 40.0
	for n in get_tree().get_nodes_in_group("interact"):
		if not is_instance_valid(n):
			continue
		var dd = n.global_position.distance_to(Game.player.global_position)
		if dd < bd:
			bd = dd
			best = n
	if best != null:
		best.interact()


func _manage_spawns():
	var animals = 0
	var monsters = 0
	for e in get_tree().get_nodes_in_group("hurtable"):
		if e.is_in_group("dnode"):
			continue
		if e.d["mode"] == "passive":
			animals += 1
		elif e.d["mode"] == "hostile":
			monsters += 1
	var want_m = 90 if Game.is_night else 64
	if monsters < want_m or animals < 14:
		for i in range(2):
			var pos = world.random_land_pos(Game.player.global_position, 260.0, 380.0)
			if pos != Vector2.ZERO:
				var t = world.pick_type(pos)
				if t == "":
					continue
				var passive = Game.MOBS[t]["mode"] == "passive"
				if (passive and animals < 14) or (not passive and monsters < want_m):
					world.spawn_mob(t, pos)


# ------------------------------------------------------------ dungeon records
func _tick_dungeons(delta):
	for rec in Game.dungeons.duplicate():
		rec["time_left"] -= delta
		if rec["time_left"] <= 0.0:
			if rec.get("found", false):
				Game.notify("The %s has collapsed..." % Game.DUNGEONS[rec["biome"]]["name"])
			_remove_dungeon(rec)
	dungeon_t += delta
	if dungeon_t > 25.0:
		dungeon_t = 0.0
		if Game.dungeons.size() < MAX_DUNGEONS and randf() < 0.55:
			_spawn_dungeon(false)


func _spawn_dungeon(initial):
	var p = Game.player
	var center = Vector2(Game.W * 8.0, Game.H * 8.0)
	for i in range(120):
		var pos = Vector2(randf_range(64.0, Game.W * 16.0 - 64.0), randf_range(64.0, Game.H * 16.0 - 64.0))
		var tx = int(pos.x / 16.0)
		var ty = int(pos.y / 16.0)
		if not world.open_area(tx, ty, 1):
			continue
		var b = Game.TILE_BIOME.get(world.tile_at(pos), "")
		if b == "":
			continue
		if absf(pos.x - center.x) < WorldScript.TOWN_HX + 110.0 and absf(pos.y - center.y) < WorldScript.TOWN_HY + 110.0:
			continue
		if not initial and pos.distance_to(p.global_position) < 260.0:
			continue
		var close = false
		for r in Game.dungeons:
			if Vector2(r["pos"][0], r["pos"][1]).distance_to(pos) < 320.0:
				close = true
		if close:
			continue
		var dtype = Game.BIOMES[b]["dungeon"]
		var lvl = _roll_rank(p.level)
		var diff = mini(lvl / 21, 4)
		var rec = {"id": next_id, "biome": dtype, "pos": [pos.x, pos.y], "level": lvl, "diff": diff, "seed": randi(),
			"time_left": randf_range(720.0, 1080.0), "found": false, "rank": lvl,
			"state": {"killed": [], "opened": [], "boss": false, "treasure": false}, "cleared": false}
		next_id += 1
		Game.dungeons.append(rec)
		_make_entrance(rec)
		if not initial:
			Game.notify("A strange energy stirs in the %s..." % Game.BIOMES[b]["name"])
		return


## Dungeon rank 1-100: mostly near the player's level, sometimes much harder.
func _roll_rank(plv):
	var r = randi() % 100
	var rank = plv + randi_range(-4, 6)
	if r >= 70 and r < 92:
		rank = plv + randi_range(5, 18)
	elif r >= 92:
		rank = plv + randi_range(15, 40)
	return clampi(rank, 1, Game.MAX_LEVEL)


func _make_entrance(rec):
	var n = EntranceScript.new()
	n.rec = rec
	n.position = Vector2(rec["pos"][0], rec["pos"][1])
	entities.add_child(n)
	entrances[rec["id"]] = n


func _remove_dungeon(rec):
	Game.dungeons.erase(rec)
	if entrances.has(rec["id"]):
		if is_instance_valid(entrances[rec["id"]]):
			entrances[rec["id"]].queue_free()
		entrances.erase(rec["id"])


# ------------------------------------------------------------ entering / leaving
func enter_dungeon(rec):
	if Game.cur_dungeon != null:
		return
	var p = Game.player
	return_pos = p.global_position + Vector2(0, 22)
	var lay = DungeonScript.new()
	lay.setup(rec)
	Game.cur_dungeon = rec
	Game.dlayout = lay
	d_ground = Sprite2D.new()
	d_ground.texture = lay.bake()
	d_ground.centered = false
	d_ground.position = DungeonScript.OFF
	d_ground.z_index = -10
	add_child(d_ground)
	RenderingServer.set_default_clear_color(Color.BLACK)
	tint.color = Color(0.72, 0.72, 0.85)
	cam.limit_left = int(DungeonScript.OFF.x)
	cam.limit_top = int(DungeonScript.OFF.y)
	cam.limit_right = int(DungeonScript.OFF.x) + lay.tw * 16
	cam.limit_bottom = int(DungeonScript.OFF.y) + lay.th * 16
	cam.reset_smoothing()
	p.global_position = lay.start_pos
	cam.reset_smoothing()
	var st = rec["state"]
	var ex = ExitScript.new()
	ex.position = lay.exit_pos
	entities.add_child(ex)
	for m in lay.mobs:
		if st["killed"].has(m["uid"]):
			continue
		var e = world.spawn_mob(m["type"], m["pos"], m["level"], m["mini"])
		e.uid = m["uid"]
		e.diff = rec["diff"] * 0.5
	for c in lay.chests:
		var ch = ChestScript.new()
		ch.idx = c["idx"]
		ch.level = rec["level"]
		ch.diff = rec["diff"]
		ch.opened = st["opened"].has(c["idx"])
		ch.position = c["pos"]
		entities.add_child(ch)
	for s in lay.spikes:
		var tr = TrapScript.new()
		tr.kind = "spikes"
		tr.level = rec["level"]
		tr.position = s["pos"]
		entities.add_child(tr)
	for dt in lay.darts:
		var tr2 = TrapScript.new()
		tr2.kind = "dart"
		tr2.dir = dt["dir"]
		tr2.level = rec["level"]
		tr2.position = dt["pos"]
		entities.add_child(tr2)
	if not st["boss"]:
		var b = BossScript.new()
		b.boss_id = Game.DUNGEONS[rec["biome"]]["boss"]
		b.level = rec["level"] + 2 + rec["diff"]
		b.diff = rec["diff"] * 0.5
		b.position = lay.boss_pos
		b.add_to_group("dnode")
		entities.add_child(b)
		boss_node = b
	else:
		_spawn_treasure(rec, lay.boss_pos)
	Game.notify("%s - Rank %d" % [Game.DUNGEONS[rec["biome"]]["name"], rec["level"]])
	hud.set_panel("")


func _spawn_treasure(rec, pos):
	var ch = ChestScript.new()
	ch.idx = 999
	ch.gold_chest = true
	var uniques = Items.boss_unique_for(Game.DUNGEONS[rec["biome"]]["boss"])
	ch.unique_id = uniques[hash(rec["seed"]) % uniques.size()]
	ch.level = rec["level"] + 2 + rec["diff"]
	ch.diff = rec["diff"]
	ch.opened = rec["state"]["treasure"]
	ch.position = pos + Vector2(0, 40)
	entities.add_child(ch)
	var ex = ExitScript.new()
	ex.position = pos + Vector2(-34, 40)
	entities.add_child(ex)


func leave_dungeon(_ok):
	var rec = Game.cur_dungeon
	if rec == null:
		return
	for n in get_tree().get_nodes_in_group("dnode"):
		if is_instance_valid(n):
			n.queue_free()
	for n in get_tree().get_nodes_in_group("interact"):
		if is_instance_valid(n) and n.has_method("interact") and n.get_script() == ExitScript:
			n.queue_free()
	for n in get_tree().get_nodes_in_group("drops"):
		if is_instance_valid(n):
			n.queue_free()
	if d_ground != null:
		d_ground.queue_free()
		d_ground = null
	Game.cur_dungeon = null
	Game.dlayout = null
	boss_node = null
	RenderingServer.set_default_clear_color(Color("2f6fa8"))
	_overworld_limits()
	Game.player.global_position = return_pos
	cam.reset_smoothing()
	if rec["state"]["boss"]:
		_remove_dungeon(rec)
		Game.notify("The dungeon crumbles behind you.")
	hud.set_panel("")


func dungeon_mob_killed(uid):
	var rec = Game.cur_dungeon
	if rec != null and not rec["state"]["killed"].has(uid):
		rec["state"]["killed"].append(uid)


func dungeon_boss_killed(boss):
	var rec = Game.cur_dungeon
	if rec == null:
		return
	rec["state"]["boss"] = true
	rec["cleared"] = true
	Game.player.quest_event("dungeon", "")
	await get_tree().create_timer(1.5).timeout
	if Game.cur_dungeon == rec:
		_spawn_treasure(rec, Game.dlayout.boss_pos)
		Game.notify("DUNGEON CLEARED! Open the golden treasure chest.")


func chest_opened(ch):
	var rec = Game.cur_dungeon
	if rec == null:
		return
	if ch.gold_chest:
		rec["state"]["treasure"] = true
	elif not rec["state"]["opened"].has(ch.idx):
		rec["state"]["opened"].append(ch.idx)
