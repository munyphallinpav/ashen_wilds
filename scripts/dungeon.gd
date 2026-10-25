extends RefCounted
## Dungeon layout: a grid of big open rooms joined by wide corridors; boss arena in the far corner.
## Generated deterministically from the dungeon record's seed. Lives at world offset OFF.

const OFF = Vector2(100000.0, 100000.0)

var biome = "forest"
var level = 5
var diff = 0
var seed_val = 1
var n = 11
var tw = 34
var th = 34
var tiles = PackedByteArray()      # 0 rock, 1 floor, 2 cliff, 3 water, 4 lava (walkable, burns), 5 built wall
var styles = PackedByteArray()     # colour style of custom terrain tiles (0-2)
const BLOCK_CODE = {"cliff": 2, "water": 3, "lava": 4, "wall": 5}
var seen = PackedByteArray()
var start_pos = Vector2.ZERO
var exit_pos = Vector2.ZERO
var boss_pos = Vector2.ZERO
var arena_cells = 4
var mobs = []        # {uid, type, pos, level, mini}
var chests = []      # {idx, pos}
var spikes = []      # {pos}
var darts = []       # {pos, dir}
var cells_open = []  # for debugging


func setup(rec):
	biome = rec["biome"]
	level = rec["level"]
	diff = rec["diff"]
	seed_val = rec["seed"]
	g = 3 + mini(2, (diff + 1) / 2)
	terrain_amt = 1 + (1 if diff >= 2 else 0)
	bp = rec.get("bp", null)
	if bp != null:
		g = clampi(int(bp["grid"]), 2, 6)
		match int(bp["size"]):
			0:
				pitch = 20; rw_lo = 5; rw_hi = 7; rh_lo = 4; rh_hi = 6; arena_sz = 17
			2:
				pitch = 32; rw_lo = 9; rw_hi = 13; rh_lo = 8; rh_hi = 12; arena_sz = 29
		mob_lo = maxi(0, int(bp["mobs"]) - 1) if int(bp["mobs"]) > 0 else 0
		mob_hi = int(bp["mobs"]) + 1 if int(bp["mobs"]) > 0 else 0
		mob_pool = bp["mob_types"].duplicate()
		mini_n = int(bp["minis"])
		if bp["mini_type"] != "":
			mini_pool = [bp["mini_type"]]
		spawner_n = int(bp["spawners"])
		boss_id = bp["boss"]
		terrain_amt = clampi(int(bp.get("terrain", 0)), 0, 3)
	n = g
	tw = g * pitch + 2
	th = tw
	generate()


var pitch = 26              # tiles per room cell (rooms are 15-21 tiles across by default)
# --- tunables (overridden by a custom dungeon blueprint)
var rw_lo = 7
var rw_hi = 10
var rh_lo = 6
var rh_hi = 9
var arena_sz = 23
var mob_lo = -1                # -1 = default for the difficulty
var mob_hi = -1
var mob_pool = []
var mini_n = -1
var mini_pool = []
var spawner_n = -1
var bp = null
var boss_id = ""
var terrain_amt = 0           # random terrain patches (0 off, 1 few, 2 some, 3 many)
const CORR = 3              # corridor width (tiles)
var g = 3                   # rooms per side
var arena_rect = Rect2i()   # boss arena in tiles
var traps = []              # {kind, pos, rect(Rect2 px), ...} bouncing boulders, gas vents, teleport runes, pits, falling booms
var spawners = []           # {uid, pos, type}
var mimics = []             # {pos, type}
var room_list = []          # Rect2 (px) of every ordinary room
const TRAP_TABLE = {
	"lava": ["spikes", "boulder", "boom", "dart"],
	"forest": ["dart", "gas", "pit", "mimic", "spikes"],
	"mushroom": ["gas", "teleport", "mimic", "spikes"],
	"plains": ["boulder", "pit", "dart", "boom"],
	"beach": ["gas", "pit", "teleport", "dart"],
	"cave": ["boom", "spikes", "mimic", "pit", "boulder"],
}


func _tile_pos(x, y):
	return OFF + Vector2((x + 0.5) * 16.0, (y + 0.5) * 16.0)


func _carve(x0, y0, x1, y1):
	for y in range(mini(y0, y1), maxi(y0, y1) + 1):
		for x in range(mini(x0, x1), maxi(x0, x1) + 1):
			if x >= 1 and y >= 1 and x < tw - 1 and y < th - 1:
				tiles[y * tw + x] = 1


func generate():
	if bp != null and bp.get("manual", false):
		_generate_manual()
		return
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_val
	tiles.resize(tw * th)
	tiles.fill(0)
	styles.resize(tw * th)
	styles.fill(0)
	seen.resize(tw * th)
	seen.fill(0)
	# --- rooms: one big room per grid cell, centred in its cell
	var rooms = {}   # Vector2i -> Rect2i (tiles)
	for cy in range(g):
		for cx in range(g):
			var rw = rng.randi_range(rw_lo, rw_hi) * 2 + 1   # 15..21 by default
			var rh = rng.randi_range(rh_lo, rh_hi) * 2 + 1    # 13..19 by default
			if cx == g - 1 and cy == g - 1:
				rw = arena_sz
				rh = arena_sz
			var mx = cx * pitch + 1 + pitch / 2
			var my = cy * pitch + 1 + pitch / 2
			var r = Rect2i(mx - rw / 2, my - rh / 2, rw, rh)
			rooms[Vector2i(cx, cy)] = r
			_carve(r.position.x, r.position.y, r.end.x - 1, r.end.y - 1)
	arena_rect = rooms[Vector2i(g - 1, g - 1)]
	# --- simple connections: random spanning tree plus a couple of extra links
	var links = {}
	var visited = {Vector2i(0, 0): true}
	var stack = [Vector2i(0, 0)]
	var degree = {}
	while stack.size() > 0:
		var c = stack[stack.size() - 1]
		var opts = []
		for o in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
			var nc = c + o
			if nc.x >= 0 and nc.y >= 0 and nc.x < g and nc.y < g and not visited.has(nc):
				opts.append(nc)
		if opts.size() == 0:
			stack.pop_back()
			continue
		var nc = opts[rng.randi() % opts.size()]
		visited[nc] = true
		links[[c, nc]] = true
		degree[c] = degree.get(c, 0) + 1
		degree[nc] = degree.get(nc, 0) + 1
		stack.append(nc)
	for i in range(g - 1):
		var c2 = Vector2i(rng.randi_range(0, g - 2), rng.randi_range(0, g - 2))
		var o2 = Vector2i(1, 0) if rng.randf() < 0.5 else Vector2i(0, 1)
		links[[c2, c2 + o2]] = true
		degree[c2] = degree.get(c2, 0) + 1
		degree[c2 + o2] = degree.get(c2 + o2, 0) + 1
	var half = CORR / 2
	for k in links:
		var ra = rooms[k[0]]
		var rb = rooms[k[1]]
		var ca = ra.get_center()
		var cb = rb.get_center()
		if k[0].y == k[1].y:
			_carve(ca.x, ca.y - half, cb.x, ca.y + half)
		else:
			_carve(ca.x - half, ca.y, ca.x + half, cb.y)
	if terrain_amt > 0:
		_apply_terrain(rooms, links)
	# --- key positions
	var r0 = rooms[Vector2i(0, 0)]
	exit_pos = _tile_pos(r0.get_center().x, r0.position.y + 1) + Vector2(0, -2)
	start_pos = exit_pos + Vector2(0, 26)
	boss_pos = _tile_pos(arena_rect.get_center().x, arena_rect.get_center().y)

	var info = Game.DUNGEONS[biome]
	var uid = 0
	var cells = []
	var dead_ends = []
	for cy in range(g):
		for cx in range(g):
			var c = Vector2i(cx, cy)
			if c == Vector2i(0, 0) or c == Vector2i(g - 1, g - 1):
				continue
			cells.append(c)
			if degree.get(c, 0) <= 1:
				dead_ends.append(c)
	# regular monster packs: 4-7 per room, spread out
	var dens = 4 + (1 if diff >= 2 else 0)
	var pool = mob_pool if mob_pool.size() > 0 else info["mobs"]
	var lo = dens if mob_lo < 0 else mob_lo
	var hi = dens + 3 if mob_hi < 0 else mob_hi
	for c in cells:
		var r = rooms[c]
		for k in range(rng.randi_range(lo, hi)):
			var t = pool[rng.randi() % pool.size()]
			var tx = rng.randi_range(r.position.x + 2, r.end.x - 3)
			var ty = rng.randi_range(r.position.y + 2, r.end.y - 3)
			mobs.append({"uid": uid, "type": t, "pos": _tile_pos(tx, ty), "level": maxi(1, level + rng.randi_range(-1, 1)), "mini": false})
			uid += 1
	# mini bosses in distinct rooms
	var shuffled = cells.duplicate()
	for i in range(shuffled.size() - 1, 0, -1):
		var j = rng.randi_range(0, i)
		var tmp = shuffled[i]
		shuffled[i] = shuffled[j]
		shuffled[j] = tmp
	var mpool = mini_pool if mini_pool.size() > 0 else (info["mini"] if bp == null else pool)
	for i in range(mini_count(1 + diff if mini_n < 0 else mini_n, shuffled.size())):
		var c3 = shuffled[i]
		var t2 = mpool[rng.randi() % mpool.size()]
		mobs.append({"uid": uid, "type": t2, "pos": _tile_pos(rooms[c3].get_center().x, rooms[c3].get_center().y), "level": level + 1 + diff, "mini": true})
		uid += 1
	# monster spawning devices: about every second room (at least 2)
	var sp_rooms = shuffled.duplicate()
	var nsp = maxi(2, cells.size() / 2) if spawner_n < 0 else spawner_n
	for i in range(nsp):
		var rs = rooms[sp_rooms[i % sp_rooms.size()]]
		var t3 = pool[rng.randi() % pool.size()]
		var off = Vector2i(rng.randi_range(-3, 3), rng.randi_range(-3, 3))
		var cc = rs.get_center() + off
		spawners.append({"uid": uid, "pos": _tile_pos(cc.x, cc.y), "type": t3})
		uid += 1
	# chests: dead-end rooms first, in a corner
	var order = dead_ends.duplicate()
	for c4 in cells:
		if not order.has(c4):
			order.append(c4)
	var want = 3 + diff
	for idx in range(mini(want, order.size())):
		var rr = rooms[order[idx]]
		chests.append({"idx": idx, "pos": _tile_pos(rr.end.x - 2, rr.position.y + 1)})
	# traps: each room gets 2-3 of the biome's trap kinds, 1-2 of each
	var table = TRAP_TABLE[biome]
	if bp != null:
		for c6 in cells:
			var r6 = rooms[c6]
			var rect6 = Rect2(OFF + Vector2(r6.position * 16), Vector2(r6.size * 16))
			room_list.append(rect6)
			for kd2 in bp["traps"]:
				var f = int(bp["traps"][kd2])
				var cnt2 = [0, 0, 1, 2][f]
				if f == 1 and rng.randf() < 0.4:
					cnt2 = 1
				for q2 in range(cnt2):
					_place_trap(kd2, r6, rect6, rng)
		table = []
	for c5 in (cells if bp == null else []):
		var r5 = rooms[c5]
		pass
		var tpool = table.duplicate()
		for i in range(tpool.size() - 1, 0, -1):
			var j2 = rng.randi_range(0, i)
			var tm = tpool[i]
			tpool[i] = tpool[j2]
			tpool[j2] = tm
		var kinds = tpool.slice(0, mini(tpool.size(), 2 + (1 if diff >= 2 else 0) + (1 if rng.randf() < 0.4 else 0)))
		var rect_px = Rect2(OFF + Vector2(r5.position * 16), Vector2(r5.size * 16))
		room_list.append(rect_px)
		for kd in kinds:
			var cnt = rng.randi_range(1, 2)
			for q in range(cnt):
				var tx2 = rng.randi_range(r5.position.x + 2, r5.end.x - 3)
				var ty2 = rng.randi_range(r5.position.y + 2, r5.end.y - 3)
				var tp = _tile_pos(tx2, ty2)
				match kd:
					"spikes":
						for sk in range(3):
							spikes.append({"pos": _tile_pos(clampi(tx2 + sk - 1, r5.position.x + 1, r5.end.x - 2), ty2)})
					"dart":
						var wy = rng.randi_range(r5.position.y + 2, r5.end.y - 3)
						if absi(wy - r5.get_center().y) > half + 1:
							darts.append({"pos": OFF + Vector2((r5.position.x - 1) * 16.0 + 8.0, wy * 16.0 + 16.0), "dir": Vector2.RIGHT})
							darts.append({"pos": OFF + Vector2(r5.end.x * 16.0 + 8.0, wy * 16.0 + 16.0), "dir": Vector2.LEFT})
					"mimic":
						mimics.append({"pos": tp, "type": "mimic"})
					_:
						if q == 0 or kd == "gas" or kd == "pit":
							traps.append({"kind": kd, "pos": tp, "rect": rect_px})
	if terrain_amt > 0:
		_fixup_entities()


## random cliffs / water / lava / walls in every room; doors, exit and boss area stay clear and no pocket is sealed off
func _apply_terrain(rooms, links):
	var BM = preload("res://scripts/bpmap.gd")
	var trng = RandomNumberGenerator.new()
	trng.seed = seed_val + 4242
	var m = {"rooms": {}, "links": [], "start": [0, 0], "boss": [g - 1, g - 1]}
	for c in rooms:
		var r = rooms[c]
		m["rooms"][BM.key(c.x, c.y)] = {"w": r.size.x, "h": r.size.y, "blocks": {}, "mobs": [], "traps": []}
	for lk in links:
		var id = BM.link_id(lk[0], lk[1])
		if id != "":
			m["links"].append(id)
	for c2 in rooms:
		var k = BM.key(c2.x, c2.y)
		var rd = m["rooms"][k]
		BM.roll_room(rd, m, k, {"terrain": true, "amt": terrain_amt}, trng, [], false)
		var r2 = rooms[c2]
		for bk in rd["blocks"]:
			var bc = BM.kc(bk)
			var i = (r2.position.y + bc.y) * tw + r2.position.x + bc.x
			var bv = rd["blocks"][bk]
			tiles[i] = BLOCK_CODE.get(str(bv[0]), 5)
			styles[i] = int(bv[1])


func _nearest_floor(pos):
	var lp = pos - OFF
	var tx = int(floor(lp.x / 16.0))
	var ty = int(floor(lp.y / 16.0))
	for r in range(0, 8):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var x = tx + dx
				var y = ty + dy
				if x >= 0 and y >= 0 and x < tw and y < th and tiles[y * tw + x] == 1:
					return _tile_pos(x, y)
	return null


func _fixup_entities():
	var keep = []
	for e in mobs:
		var p = _nearest_floor(e["pos"])
		if p != null:
			e["pos"] = p
			keep.append(e)
	mobs = keep
	for arr in [spawners, chests, mimics, traps]:
		var keep2 = []
		for e in arr:
			var p2 = _nearest_floor(e["pos"])
			if p2 != null:
				e["pos"] = p2
				keep2.append(e)
		arr.clear()
		arr.append_array(keep2)
	var keep3 = []
	for s in spikes:
		if tile_code(s["pos"]) == 1:
			keep3.append(s)
	spikes = keep3


func _place_trap(kd, r5, rect_px, rng, fx = -1, fy = -1):
	var half = CORR / 2
	var tx2 = rng.randi_range(r5.position.x + 2, r5.end.x - 3)
	var ty2 = rng.randi_range(r5.position.y + 2, r5.end.y - 3)
	if fx >= 0:
		tx2 = clampi(r5.position.x + fx, r5.position.x, r5.end.x - 1)
		ty2 = clampi(r5.position.y + fy, r5.position.y, r5.end.y - 1)
	var tp = _tile_pos(tx2, ty2)
	match kd:
		"spikes":
			for sk in range(3):
				spikes.append({"pos": _tile_pos(clampi(tx2 + sk - 1, r5.position.x + 1, r5.end.x - 2), ty2)})
		"dart":
			var wy = rng.randi_range(r5.position.y + 2, r5.end.y - 3)
			if fx >= 0:
				wy = ty2
			if fx >= 0 or absi(wy - r5.get_center().y) > half + 1:
				darts.append({"pos": OFF + Vector2((r5.position.x - 1) * 16.0 + 8.0, wy * 16.0 + 16.0), "dir": Vector2.RIGHT})
				darts.append({"pos": OFF + Vector2(r5.end.x * 16.0 + 8.0, wy * 16.0 + 16.0), "dir": Vector2.LEFT})
		"mimic":
			mimics.append({"pos": tp, "type": "mimic"})
		_:
			traps.append({"kind": kd, "pos": tp, "rect": rect_px})


func _pick_tile(r, e, rng):
	if int(e.get("x", -1)) >= 0:
		var t = Vector2i(r.position.x + clampi(int(e["x"]), 0, r.size.x - 1), r.position.y + clampi(int(e["y"]), 0, r.size.y - 1))
		if tiles[t.y * tw + t.x] == 1:
			return t
	for i in range(60):
		var t2 = Vector2i(rng.randi_range(r.position.x + 1, r.end.x - 2), rng.randi_range(r.position.y + 1, r.end.y - 2))
		if tiles[t2.y * tw + t2.x] == 1:
			return t2
	return r.get_center()


## hand-built dungeon from bp["map"]
func _generate_manual():
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_val
	tiles.resize(tw * th)
	tiles.fill(0)
	styles.resize(tw * th)
	styles.fill(0)
	seen.resize(tw * th)
	seen.fill(0)
	var m = bp["map"].duplicate(true)
	var maxd = pitch - 3
	var BM = preload("res://scripts/bpmap.gd")
	var rrng = RandomNumberGenerator.new()
	rrng.seed = seed_val + 777
	var rpool = mob_pool if mob_pool.size() > 0 else Game.DUNGEONS[biome]["mobs"]
	for rk in m["rooms"]:
		var rr = m["rooms"][rk]["rand"]
		if rr["live"]:
			BM.roll_room(m["rooms"][rk], m, rk, rr, rrng, rpool, false)
	var rooms = {}
	for k in m["rooms"]:
		var c = BM.kc(k)
		var rd = m["rooms"][k]
		var rw = clampi(int(rd["w"]), BM.MIN_ROOM, maxd)
		var rh = clampi(int(rd["h"]), BM.MIN_ROOM, maxd)
		var mx = c.x * pitch + 1 + pitch / 2
		var my = c.y * pitch + 1 + pitch / 2
		var r = Rect2i(mx - rw / 2, my - rh / 2, rw, rh)
		rooms[k] = r
		_carve(r.position.x, r.position.y, r.end.x - 1, r.end.y - 1)
		for bk in rd["blocks"]:
			var bc = BM.kc(bk)
			if bc.x < 0 or bc.y < 0 or bc.x >= rw or bc.y >= rh:
				continue
			var bv = rd["blocks"][bk]
			var i = (r.position.y + bc.y) * tw + r.position.x + bc.x
			tiles[i] = BLOCK_CODE.get(str(bv[0]), 5)
			styles[i] = clampi(int(bv[1]), 0, 2)
	var half = CORR / 2
	for lk in m["links"]:
		var e = BM.link_ends(lk)
		if not rooms.has(e[0]) or not rooms.has(e[1]):
			continue
		var ca = rooms[e[0]].get_center()
		var cb = rooms[e[1]].get_center()
		if ca.y == cb.y:
			_carve(ca.x, ca.y - half, cb.x, ca.y + half)
		else:
			_carve(ca.x - half, ca.y, ca.x + half, cb.y)
	var sk = BM.key(m["start"][0], m["start"][1])
	var bk2 = BM.key(m["boss"][0], m["boss"][1])
	var sr = rooms[sk]
	var ex_t = Vector2i(sr.get_center().x, sr.position.y + 1)
	_carve(ex_t.x - 1, ex_t.y, ex_t.x + 1, ex_t.y + 3)
	exit_pos = _tile_pos(ex_t.x, ex_t.y) + Vector2(0, -2)
	start_pos = exit_pos + Vector2(0, 26)
	arena_rect = rooms[bk2]
	var bc2 = arena_rect.get_center()
	_carve(bc2.x - 3, bc2.y - 2, bc2.x + 3, bc2.y + 4)
	boss_pos = _tile_pos(bc2.x, bc2.y)
	var info = Game.DUNGEONS[biome]
	var pool = mob_pool if mob_pool.size() > 0 else info["mobs"]
	var uid = 0
	var cidx = 0
	for k in rooms:
		var r2 = rooms[k]
		var rd2 = m["rooms"][k]
		var rect_px = Rect2(OFF + Vector2(r2.position * 16), Vector2(r2.size * 16))
		room_list.append(rect_px)
		for e in rd2["mobs"]:
			var t = e["t"] if Game.MOBS.has(e["t"]) and e["t"] != "mimic" else pool[rng.randi() % pool.size()]
			var tp = _pick_tile(r2, e, rng)
			var mn = bool(e.get("m", false))
			mobs.append({"uid": uid, "type": t, "pos": _tile_pos(tp.x, tp.y), "level": (level + 1 + diff) if mn else maxi(1, level + rng.randi_range(-1, 1)), "mini": mn})
			uid += 1
		for e in rd2["spawners"]:
			var t3 = e["t"] if Game.MOBS.has(e["t"]) and e["t"] != "mimic" else pool[rng.randi() % pool.size()]
			var tp3 = _pick_tile(r2, e, rng)
			spawners.append({"uid": uid, "pos": _tile_pos(tp3.x, tp3.y), "type": t3})
			uid += 1
		for e in rd2["traps"]:
			var tk = e["k"]
			if tk == "random":
				var tbl = TRAP_TABLE[biome]
				tk = tbl[rng.randi() % tbl.size()]
			if int(e["x"]) >= 0:
				_place_trap(tk, r2, rect_px, rng, int(e["x"]), int(e["y"]))
			else:
				_place_trap(tk, r2, rect_px, rng)
		for e in rd2["chests"]:
			var tp4 = _pick_tile(r2, e, rng)
			chests.append({"idx": cidx, "pos": _tile_pos(tp4.x, tp4.y)})
			cidx += 1


func tile_code(pos):
	var lp = pos - OFF
	var x = int(floor(lp.x / 16.0))
	var y = int(floor(lp.y / 16.0))
	if x < 0 or y < 0 or x >= tw or y >= th:
		return 0
	return tiles[y * tw + x]


func mini_count(want, avail):
	return mini(want, avail)


func walkable(pos):
	var lp = pos - OFF
	var x = int(floor(lp.x / 16.0))
	var y = int(floor(lp.y / 16.0))
	if x < 0 or y < 0 or x >= tw or y >= th:
		return false
	var tc = tiles[y * tw + x]
	return tc == 1 or tc == 4


func in_arena(pos):
	var lp = pos - OFF
	return Rect2(arena_rect.position * 16, arena_rect.size * 16).has_point(lp)


func reveal(pos, radius = 5):
	var lp = pos - OFF
	var cx = int(floor(lp.x / 16.0))
	var cy = int(floor(lp.y / 16.0))
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if dx * dx + dy * dy > radius * radius:
				continue
			var x = cx + dx
			var y = cy + dy
			if x >= 0 and y >= 0 and x < tw and y < th:
				seen[y * tw + x] = 1


func bake():
	var ts = Game.tex("res://assets/tiles/dungeon_tiles.png").get_image()
	ts.convert(Image.FORMAT_RGBA8)
	var base = Game.DUNGEONS[biome]["tile"] * 3
	var img = Image.create(tw * 16, th * 16, false, Image.FORMAT_RGBA8)
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_val + 5
	var cache = {}
	for y in range(th):
		for x in range(tw):
			var code = tiles[y * tw + x]
			if code >= 2:
				var ck = code * 10 + styles[y * tw + x]
				if not cache.has(ck):
					cache[ck] = _special_img(code, styles[y * tw + x], ts, base)
				img.blit_rect(cache[ck], Rect2i(0, 0, 16, 16), Vector2i(x * 16, y * 16))
				continue
			var idx = base + 2
			if code == 1:
				idx = base + (0 if rng.randf() < 0.7 else 1)
			img.blit_rect(ts, Rect2i(idx * 16, 0, 16, 16), Vector2i(x * 16, y * 16))
	return ImageTexture.create_from_image(img)


func _special_img(code, style, ts, base):
	var im = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	style = style % 3
	if code == 5:
		im.blit_rect(ts, Rect2i((base + 2) * 16, 0, 16, 16), Vector2i.ZERO)
		var tc = [Color(1, 1, 1), Color(0.6, 0.62, 0.85), Color(1.15, 0.95, 0.7)][style]
		for yy in range(16):
			for xx in range(16):
				var c = im.get_pixel(xx, yy)
				im.set_pixel(xx, yy, Color(c.r * tc.r, c.g * tc.g, c.b * tc.b, 1.0))
		return im
	var pal = {
		2: [Color(0.36, 0.27, 0.2), Color(0.3, 0.31, 0.36), Color(0.45, 0.2, 0.17)],
		3: [Color(0.15, 0.36, 0.72), Color(0.1, 0.52, 0.56), Color(0.07, 0.12, 0.3)],
		4: [Color(0.9, 0.36, 0.05), Color(0.78, 0.1, 0.06), Color(1.0, 0.75, 0.3)],
	}
	var bc = pal[code][style]
	var r2 = RandomNumberGenerator.new()
	r2.seed = code * 31 + style
	for yy in range(16):
		for xx in range(16):
			var nz = r2.randf() * 0.1 - 0.05
			var col = Color(bc.r + nz, bc.g + nz, bc.b + nz)
			if code == 2:
				if yy < 4:
					col = col.lightened(0.28)
				elif yy > 12:
					col = col.darkened(0.35)
				elif (xx * 3 + yy) % 9 == 0:
					col = col.darkened(0.18)
			elif code == 3:
				if (yy + (xx / 4) * 2) % 6 == 0:
					col = col.lightened(0.2)
			else:
				if sin(xx * 0.9 + yy * 0.5) + cos(yy * 0.8 - xx * 0.3) > 1.15:
					col = Color(1.0, 0.9, 0.4) if style != 1 else Color(1.0, 0.5, 0.2)
			im.set_pixel(xx, yy, col)
	return im


func stars():
	return "*".repeat(diff + 1)
