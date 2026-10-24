extends Node2D
## Procedural open world. Tile ids: 0 deep water, 1 shallow water, 2 sand, 3 grass, 4 forest, 5 dirt, 6 stone.
## Ground is baked into ONE texture (fast); animated water sits underneath and shows through water tiles.

const ResScript = preload("res://scripts/resource_node.gd")
const EnemyScript = preload("res://scripts/enemy.gd")
const FireScript = preload("res://scripts/campfire.gd")
const NpcScript = preload("res://scripts/npc.gd")
const WallScript = preload("res://scripts/town_wall.gd")
const GuardScript = preload("res://scripts/guard.gd")

const TOWN_HX = 256.0   # half width of the wall rectangle (px)
const TOWN_HY = 208.0
const TOWN_TX = 19      # flat town ground half size in tiles
const TOWN_TY = 16
const MIN_REGION = 40   # biome patches smaller than this are merged into their surroundings

var tiles = PackedByteArray()
var spawn_pos = Vector2.ZERO
var rng = RandomNumberGenerator.new()
var water_sprite
var water_a
var water_b
var water_t = 0.0
var water_flip = false
var seed_val = 0
var res_nodes = []


func generate(seed_val, entities):
	self.seed_val = seed_val
	rng.seed = seed_val
	var gw = Game.W
	var gh = Game.H
	var cx = gw / 2
	var cy = gh / 2

	var n = FastNoiseLite.new()
	n.seed = seed_val
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = 0.022
	n.fractal_octaves = 4
	var n2 = FastNoiseLite.new()      # forest vs plains
	n2.seed = seed_val + 77
	n2.frequency = 0.05
	var n3 = FastNoiseLite.new()      # volcanic regions
	n3.seed = seed_val + 313
	n3.frequency = 0.028
	var n4 = FastNoiseLite.new()      # mushroom regions
	n4.seed = seed_val + 911
	n4.frequency = 0.03
	var n5 = FastNoiseLite.new()      # lava pockets
	n5.seed = seed_val + 41
	n5.frequency = 0.09

	var elev = PackedFloat32Array()
	elev.resize(gw * gh)
	for y in range(gh):
		for x in range(gw):
			var dd = Vector2(x - cx, y - cy).length() / (gw * 0.5)
			var fall = pow(clampf(dd, 0.0, 1.0), 2.2)
			elev[y * gw + x] = n.get_noise_2d(x, y) * 0.5 + 0.5 - fall * 0.85
	var sorted = elev.duplicate()
	sorted.sort()
	var cnt = sorted.size() - 1
	var t_deep = sorted[int(0.20 * cnt)]
	var t_shallow = sorted[int(0.27 * cnt)]
	var t_sand = sorted[int(0.31 * cnt)]
	# mountains / dirt are ranked over land outside the town meadow so they actually appear around it
	var outer = []
	for y in range(gh):
		for x in range(gw):
			if elev[y * gw + x] >= t_sand and Vector2(x - cx, y - cy).length() > 30.0:
				outer.append(elev[y * gw + x])
	outer.sort()
	var t_dirt = outer[int(0.80 * (outer.size() - 1))]
	var t_stone = outer[int(0.89 * (outer.size() - 1))]
	# noise percentiles over land only (biome proportions are guaranteed)
	var v3 = []
	var v4 = []
	for y in range(gh):
		for x in range(gw):
			if elev[y * gw + x] >= t_sand and Vector2(x - cx, y - cy).length() > 26.0:
				v3.append(n3.get_noise_2d(x, y))
				v4.append(n4.get_noise_2d(x, y))
	v3.sort()
	v4.sort()
	var t_volc = v3[int(0.86 * (v3.size() - 1))] if v3.size() > 0 else 2.0
	var t_mush = v4[int(0.84 * (v4.size() - 1))] if v4.size() > 0 else 2.0

	tiles.resize(gw * gh)
	for y in range(gh):
		for x in range(gw):
			var e = elev[y * gw + x]
			var dc = Vector2(x - cx, y - cy).length()
			var t = 3
			if e < t_deep:
				t = 0
			elif e < t_shallow:
				t = 1
			elif e < t_sand:
				t = 2
			else:
				if dc > 26.0 and n3.get_noise_2d(x, y) >= t_volc:
					t = 8
					if n5.get_noise_2d(x, y) > 0.28:
						t = 9
				elif dc > 26.0 and n4.get_noise_2d(x, y) >= t_mush:
					t = 7
				elif e >= t_stone:
					t = 6
				elif e >= t_dirt:
					t = 5
				else:
					t = 4 if n2.get_noise_2d(x, y) > 0.08 else 3
			tiles[y * gw + x] = t
	_refine_biomes(gw, gh)
	_stamp_town(gw, gh, cx, cy)

	_bake_ground(gw, gh)

	water_a = Game.tex("res://assets/tiles/water_a.png")
	water_b = Game.tex("res://assets/tiles/water_b.png")
	water_sprite = Sprite2D.new()
	water_sprite.texture = water_a
	water_sprite.centered = false
	water_sprite.region_enabled = true
	water_sprite.region_rect = Rect2(0, 0, gw * 16, gh * 16)
	water_sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	water_sprite.z_index = -20
	add_child(water_sprite)

	# resources by biome: [kind, probability]
	var table = {
		2: [["palm", 0.014], ["rock", 0.004]],
		3: [["oak", 0.010], ["herb", 0.014], ["rock", 0.006]],
		4: [["oak", 0.075], ["pine", 0.05], ["herb", 0.02]],
		5: [["rock", 0.03], ["pine", 0.012], ["coal", 0.005]],
		6: [["rock", 0.055], ["iron", 0.03], ["coal", 0.022]],
		7: [["shroom", 0.08], ["mushpatch", 0.045]],
		8: [["dead", 0.022], ["coal", 0.03], ["iron", 0.015], ["rock", 0.02]],
	}
	for y in range(2, gh - 2):
		for x in range(2, gw - 2):
			if absi(x - cx) <= TOWN_TX + 3 and absi(y - cy) <= TOWN_TY + 3:
				continue
			var t = tiles[y * gw + x]
			if not table.has(t):
				continue
			var r = rng.randf()
			var kind = ""
			var acc = 0.0
			for e in table[t]:
				acc += e[1]
				if r < acc:
					kind = e[0]
					break
			if kind != "":
				var node = ResScript.new()
				node.kind = kind
				node.position = Vector2(x * 16 + 8 + rng.randf_range(-4, 4), y * 16 + 14 + rng.randf_range(-3, 3))
				entities.add_child(node)
				res_nodes.append(node)

	_build_village(entities, cx, cy)
	spawn_pos = Vector2(cx * 16 + 8, (cy + 3) * 16)


func open_area(x, y, rad):
	for dy in range(-rad, rad + 1):
		for dx in range(-rad, rad + 1):
			var xx = x + dx
			var yy = y + dy
			if xx < 0 or yy < 0 or xx >= Game.W or yy >= Game.H or tiles[yy * Game.W + xx] < 2 or tiles[yy * Game.W + xx] == 9:
				return false
	return true


func _dist_from(gw, gh, pred, cap):
	# multi-source BFS distance (4-neighbour, capped) from every tile whose id satisfies pred
	var dist = PackedInt32Array()
	dist.resize(gw * gh)
	dist.fill(cap)
	var q = []
	for i in range(gw * gh):
		if pred.call(tiles[i]):
			dist[i] = 0
			q.append(i)
	var head = 0
	while head < q.size():
		var i = q[head]
		head += 1
		var d = dist[i]
		if d + 1 >= cap:
			continue
		var x = i % gw
		var y = i / gw
		for o in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
			var nx = x + o[0]
			var ny = y + o[1]
			if nx < 0 or ny < 0 or nx >= gw or ny >= gh:
				continue
			var j = ny * gw + nx
			if dist[j] > d + 1:
				dist[j] = d + 1
				q.append(j)
	return dist


func _remove_specks(gw, gh, ids, fill):
	# flood-fill patches of the given tile ids and convert any patch smaller than MIN_REGION
	var seen = PackedByteArray()
	seen.resize(gw * gh)
	for s in range(gw * gh):
		if seen[s] == 1 or not (tiles[s] in ids):
			continue
		var comp = [s]
		seen[s] = 1
		var head = 0
		while head < comp.size():
			var i = comp[head]
			head += 1
			var x = i % gw
			var y = i / gw
			for o in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
				var nx = x + o[0]
				var ny = y + o[1]
				if nx < 0 or ny < 0 or nx >= gw or ny >= gh:
					continue
				var j = ny * gw + nx
				if seen[j] == 0 and tiles[j] in ids:
					seen[j] = 1
					comp.append(j)
		if comp.size() < MIN_REGION:
			for i in comp:
				tiles[i] = fill


## Gives biomes breathing room: no tiny patches, scorched ring around volcanic land, grass buffers between
## incompatible biomes (volcanic / mushroom / mountain / forest) and a shore strip between water and lava.
func _refine_biomes(gw, gh):
	_remove_specks(gw, gh, [6], 5)
	_remove_specks(gw, gh, [7], 3)
	_remove_specks(gw, gh, [8, 9], 5)
	# volcanic keeps away from water: sand-to-ash shore strip becomes dirt
	var d_water = _dist_from(gw, gh, func(t): return t <= 1, 6)
	for i in range(gw * gh):
		if tiles[i] >= 8 and d_water[i] < 5:
			tiles[i] = 5
	var d_volc = _dist_from(gw, gh, func(t): return t >= 8, 12)
	for i in range(gw * gh):
		var t = tiles[i]
		if t == 7 and d_volc[i] < 10:
			tiles[i] = 3            # mushroom never touches volcanic land
		elif t == 6 and d_volc[i] < 3:
			tiles[i] = 5
		elif (t == 3 or t == 4) and d_volc[i] in [1, 2]:
			tiles[i] = 5            # scorched edge
	var d_mush = _dist_from(gw, gh, func(t): return t == 7, 6)
	for i in range(gw * gh):
		var t = tiles[i]
		if (t == 4 or t == 6) and d_mush[i] in [1, 2, 3]:
			tiles[i] = 3            # open meadow between mushroom grove and forest / mountain
	var d_mount = _dist_from(gw, gh, func(t): return t == 6, 4)
	for i in range(gw * gh):
		if tiles[i] == 5 and d_mount[i] == 0:
			continue
		if tiles[i] == 4 and d_mount[i] == 1:
			tiles[i] = 3


func _stamp_town(gw, gh, cx, cy):
	for y in range(cy - TOWN_TY - 3, cy + TOWN_TY + 4):
		for x in range(cx - TOWN_TX - 3, cx + TOWN_TX + 4):
			var i = y * gw + x
			var inside = absi(x - cx) <= TOWN_TX and absi(y - cy) <= TOWN_TY
			if inside or tiles[i] < 2 or tiles[i] >= 6:
				tiles[i] = 3
	# meadow ring: no mountain / bare dirt right outside the walls (low-level hunting ground)
	for y in range(cy - TOWN_TY - 8, cy + TOWN_TY + 9):
		for x in range(cx - TOWN_TX - 8, cx + TOWN_TX + 9):
			if x < 0 or y < 0 or x >= gw or y >= gh:
				continue
			var t = tiles[y * gw + x]
			if t == 5 or t == 6:
				tiles[y * gw + x] = 3
	# dirt roads leaving the four gates
	for k in range(TOWN_TY + 1, TOWN_TY + 14):
		for o in [-1, 0, 1]:
			for s in [-1, 1]:
				_road_tile(gw, cx + o, cy + s * k)
	for k in range(TOWN_TX + 1, TOWN_TX + 14):
		for o in [-1, 0, 1]:
			for s in [-1, 1]:
				_road_tile(gw, cx + s * k, cy + o)


func _road_tile(gw, x, y):
	if x < 0 or y < 0 or x >= Game.W or y >= Game.H:
		return
	if tiles[y * gw + x] >= 2 and tiles[y * gw + x] != 9:
		tiles[y * gw + x] = 5


func _bake_ground(gw, gh):
	var ts = Game.tex("res://assets/tiles/tileset.png").get_image()
	ts.convert(Image.FORMAT_RGBA8)
	var dec = Game.tex("res://assets/tiles/decor.png").get_image()
	dec.convert(Image.FORMAT_RGBA8)
	var img = Image.create(gw * 16, gh * 16, false, Image.FORMAT_RGBA8)
	for y in range(gh):
		for x in range(gw):
			var t = tiles[y * gw + x]
			var idx = -1
			if t == 0:
				idx = 6
			elif t == 2:
				idx = 4
			elif t == 3:
				idx = 0 if rng.randf() < 0.65 else 1
			elif t == 4:
				idx = 2
			elif t == 5:
				idx = 3
			elif t == 6:
				idx = 5
			elif t == 7:
				idx = 8 if rng.randf() < 0.6 else 9
			elif t == 8:
				idx = 10
			elif t == 9:
				idx = 11
			elif t == 1 and _near_land(x, y, gw, gh):
				idx = 7
			if idx >= 0:
				img.blit_rect(ts, Rect2i(idx * 16, 0, 16, 16), Vector2i(x * 16, y * 16))
			if (t == 3 or t == 4) and rng.randf() < 0.1:
				var di = rng.randi_range(0, 5)
				if di == 4 and t != 4:
					di = 3
				img.blend_rect(dec, Rect2i(di * 16, 0, 16, 16), Vector2i(x * 16, y * 16))
	_paint_town(img, gw, gh)
	var ground = Sprite2D.new()
	ground.texture = ImageTexture.create_from_image(img)
	ground.centered = false
	ground.z_index = -10
	add_child(ground)


func _paint_town(img, gw, gh):
	# cobblestone roads (3 tiles wide, gate to gate) and a round plaza around the fountain
	var cob = Game.tex("res://assets/tiles/cobble.png").get_image()
	cob.convert(Image.FORMAT_RGBA8)
	var cx = gw / 2
	var cy = gh / 2
	for y in range(cy - TOWN_TY, cy + TOWN_TY + 1):
		for x in range(cx - TOWN_TX, cx + TOWN_TX + 1):
			var dx = x - cx
			var dy = y - cy
			var road = (absi(dx) <= 1) or (absi(dy) <= 1)
			var plaza = Vector2(dx, dy).length() <= 4.3
			if road or plaza:
				var v = rng.randi_range(0, 1)
				img.blit_rect(cob, Rect2i(v * 16, 0, 16, 16), Vector2i(x * 16, y * 16))
	# a ring of lighter stone around the plaza edge
	var ring = Color(0.74, 0.7, 0.62)
	for y in range((cy - 6) * 16, (cy + 7) * 16):
		for x in range((cx - 6) * 16, (cx + 7) * 16):
			var dd = Vector2(x - (cx * 16 + 8), y - (cy * 16 + 8)).length()
			if dd >= 66.0 and dd <= 69.0:
				img.set_pixel(x, y, ring)


func _near_land(x, y, gw, gh):
	for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var nx = x + o.x
		var ny = y + o.y
		if nx >= 0 and ny >= 0 and nx < gw and ny < gh and tiles[ny * gw + nx] >= 2:
			return true
	return false


func _build_village(entities, cx, cy):
	var c = Vector2(cx * 16 + 8, cy * 16 + 8)
	_build_walls(entities, c)
	add_prop(entities, "res://assets/world/fountain.png", c + Vector2(0, 6), Vector2(36, 12))
	# shop buildings: NPC stands in front of each door (Game.NPCS pos is relative to the centre)
	for id in Game.NPCS:
		var nd = Game.NPCS[id]
		var base = c + Vector2(nd["pos"][0], nd["pos"][1]) - Vector2(0, 20)
		add_prop(entities, "res://assets/world/bld_%s.png" % id, base, Vector2(46, 14))
		add_prop(entities, "res://assets/world/barrel.png", base + Vector2(35, 2), Vector2(9, 5))
		add_prop(entities, "res://assets/world/crate.png", base + Vector2(-36, 2), Vector2(11, 5))
	# lamps along the two roads
	var lamps = []
	for k in range(1, 5):
		for sx in [-1, 1]:
			for sy in [-1, 1]:
				lamps.append(Vector2(sx * 26, sy * (k * 48 - 10)))
				lamps.append(Vector2(sx * (k * 64 - 10), sy * 26))
	for p in lamps:
		if absf(p.x) < TOWN_HX - 20.0 and absf(p.y) < TOWN_HY - 20.0:
			add_prop(entities, "res://assets/world/lamp.png", c + p, Vector2(4, 3))
	for p in [Vector2(-44, 14), Vector2(44, 14), Vector2(-44, -26), Vector2(44, -26)]:
		add_prop(entities, "res://assets/world/bench.png", c + p, Vector2(20, 5))
	# flower beds and benches in the open quarters between shops and walls
	for sx in [-1, 1]:
		for sy in [-1, 1]:
			for fp in [Vector2(30, 50), Vector2(128, 30), Vector2(220, 50), Vector2(128, 190)]:
				var q = Vector2(fp.x * sx, fp.y * sy)
				if absf(q.y) < TOWN_HY - 14.0 and absf(q.x) < TOWN_HX - 20.0:
					add_prop(entities, "res://assets/world/flowerbed.png", c + q, Vector2(24, 6))
			add_prop(entities, "res://assets/world/bench.png", c + Vector2(sx * 128, sy * 46), Vector2(20, 5))
			add_prop(entities, "res://assets/world/barrel.png", c + Vector2(sx * 236, sy * 180), Vector2(9, 5))
			add_prop(entities, "res://assets/world/crate.png", c + Vector2(sx * 222, sy * 182), Vector2(11, 5))
	# banners at the gates
	for p in [Vector2(-22, -TOWN_HY + 6), Vector2(22, -TOWN_HY + 6), Vector2(-22, TOWN_HY - 4), Vector2(22, TOWN_HY - 4),
			Vector2(-TOWN_HX + 6, -22), Vector2(-TOWN_HX + 6, 30), Vector2(TOWN_HX - 6, -22), Vector2(TOWN_HX - 6, 30)]:
		add_prop(entities, "res://assets/world/banner.png", c + p, Vector2.ZERO)
	add_campfire(c + Vector2(176, 150), false)
	for id in Game.NPCS:
		var npc = NpcScript.new()
		npc.npc_id = id
		npc.position = c + Vector2(Game.NPCS[id]["pos"][0], Game.NPCS[id]["pos"][1])
		entities.add_child(npc)


func _build_walls(entities, c):
	# rectangular wall, 4 gates (N/S/E/W) each flanked by two guards
	var nx = int(TOWN_HX / 16.0)
	var ny = int(TOWN_HY / 16.0)
	for i in range(-nx, nx + 1):
		for sy in [-TOWN_HY, TOWN_HY]:
			if abs(i) <= 1:
				continue
			_wall(entities, c + Vector2(i * 16, sy), abs(i) == 2 or abs(i) == nx)
	for j in range(-ny, ny + 1):
		for sx in [-TOWN_HX, TOWN_HX]:
			if abs(j) <= 1 or abs(j) == ny:
				continue
			_wall(entities, c + Vector2(sx, j * 16 + 6), abs(j) == 2)
	var gx = TOWN_HX - 16.0
	var gy = TOWN_HY - 16.0
	var spots = [Vector2(-40, -gy), Vector2(40, -gy), Vector2(-40, gy + 8), Vector2(40, gy + 8),
		Vector2(-gx, -40), Vector2(-gx, 46), Vector2(gx, -40), Vector2(gx, 46)]
	var faces = ["down", "down", "up", "up", "right", "right", "left", "left"]
	for k in range(spots.size()):
		var g = GuardScript.new()
		g.face = faces[k]
		g.position = c + spots[k]
		entities.add_child(g)


func _wall(entities, pos, tower):
	var wl = WallScript.new()
	wl.tower = tower
	wl.position = pos
	entities.add_child(wl)


func add_prop(entities, path, pos, coll):
	var b = StaticBody2D.new()
	b.position = pos
	b.collision_layer = 1
	b.collision_mask = 0
	var s = Sprite2D.new()
	var t = Game.tex(path)
	s.texture = t
	s.offset = Vector2(0, -(t.get_height() / 2.0 - 3.0))
	b.add_child(s)
	if coll != Vector2.ZERO:
		var cs = CollisionShape2D.new()
		var r = RectangleShape2D.new()
		r.size = coll
		cs.shape = r
		cs.position = Vector2(0, -coll.y / 2.0)
		b.add_child(cs)
	entities.add_child(b)


func add_campfire(pos, placed = true):
	var f = FireScript.new()
	f.position = pos
	f.placed = placed
	Game.entities.add_child(f)
	return f


# ------------------------------------------------------------ queries
func tile_at(pos):
	var x = int(floor(pos.x / 16.0))
	var y = int(floor(pos.y / 16.0))
	if x < 0 or y < 0 or x >= Game.W or y >= Game.H:
		return -1
	return tiles[y * Game.W + x]


func is_walkable(pos):
	if Game.dlayout != null:
		return Game.dlayout.walkable(pos)
	var t = tile_at(pos)
	return t >= 2 and t != 9


func blocks_proj(pos):
	if Game.dlayout != null:
		return not Game.dlayout.walkable(pos)
	return false


func biome_at(pos):
	return Game.TILE_BIOME.get(tile_at(pos), "")


func level_at(pos):
	var b = biome_at(pos)
	var base = Game.BIOMES[b]["lvl"] if b != "" else 0
	var center = Vector2(Game.W * 8.0, Game.H * 8.0)
	var dist = pos.distance_to(center) / 16.0
	return clampi(1 + base + int(dist / 6.0) + randi_range(0, 2), 1, Game.MAX_LEVEL)


func _process(delta):
	water_t += delta
	if water_t > 0.6:
		water_t = 0.0
		water_flip = not water_flip
		water_sprite.texture = water_b if water_flip else water_a


# ------------------------------------------------------------ mobs
func spawn_mob(type, pos, level = -1, mini = false, hp_value = -1.0):
	var e = EnemyScript.new()
	e.type = type
	e.level = level if level > 0 else level_at(pos)
	e.mini = mini
	e.hp = hp_value
	e.position = pos
	Game.entities.add_child(e)
	if Game.cur_dungeon != null:
		e.add_to_group("dnode")
	return e


## Choose a monster type for the biome at pos (weighted). Returns "" if none.
func pick_type(pos):
	var b = biome_at(pos)
	if b == "":
		return ""
	var mobs = Game.BIOMES[b]["mobs"]
	var total = 0
	for k in mobs:
		total += mobs[k]
	var r = randi() % total
	for k in mobs:
		r -= mobs[k]
		if r < 0:
			return k
	return ""


func random_land_pos(around, rmin, rmax):
	var center = Vector2(Game.W * 8.0, Game.H * 8.0)
	for i in range(40):
		var pos
		if around == null:
			pos = Vector2(randf_range(48.0, Game.W * 16.0 - 48.0), randf_range(48.0, Game.H * 16.0 - 48.0))
		else:
			pos = around + Vector2.RIGHT.rotated(randf() * TAU) * randf_range(rmin, rmax)
		var t = tile_at(pos)
		if t < 2 or t == 9:
			continue
		if absf(pos.x - center.x) < TOWN_HX + 60.0 and absf(pos.y - center.y) < TOWN_HY + 60.0:
			continue
		return pos
	return Vector2.ZERO


func populate():
	for i in range(int(110.0 * Game.W * Game.H / 25600.0)):
		var p = random_land_pos(null, 0, 0)
		if p != Vector2.ZERO:
			var t = pick_type(p)
			if t != "":
				spawn_mob(t, p)
