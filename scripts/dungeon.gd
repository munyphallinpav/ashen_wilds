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
var tiles = PackedByteArray()      # 0 wall, 1 floor
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
	n = g
	tw = g * PITCH + 2
	th = tw
	generate()


const PITCH = 18            # tiles per room cell
const CORR = 3              # corridor width (tiles)
var g = 3                   # rooms per side
var arena_rect = Rect2i()   # boss arena in tiles


func _tile_pos(x, y):
	return OFF + Vector2((x + 0.5) * 16.0, (y + 0.5) * 16.0)


func _carve(x0, y0, x1, y1):
	for y in range(mini(y0, y1), maxi(y0, y1) + 1):
		for x in range(mini(x0, x1), maxi(x0, x1) + 1):
			if x >= 1 and y >= 1 and x < tw - 1 and y < th - 1:
				tiles[y * tw + x] = 1


func generate():
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_val
	tiles.resize(tw * th)
	tiles.fill(0)
	seen.resize(tw * th)
	seen.fill(0)
	# --- rooms: one big room per grid cell, centred in its cell
	var rooms = {}   # Vector2i -> Rect2i (tiles)
	for cy in range(g):
		for cx in range(g):
			var rw = rng.randi_range(5, 6) * 2 + 1   # 11..13
			var rh = rng.randi_range(4, 6) * 2 + 1   # 9..13
			if cx == g - 1 and cy == g - 1:
				rw = 15
				rh = 15
			var mx = cx * PITCH + 1 + PITCH / 2
			var my = cy * PITCH + 1 + PITCH / 2
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
	# regular monster packs: 2-4 per room, spread out
	for c in cells:
		var r = rooms[c]
		for k in range(rng.randi_range(2, 4)):
			var t = info["mobs"][rng.randi() % info["mobs"].size()]
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
	for i in range(mini_count(1 + diff, shuffled.size())):
		var c3 = shuffled[i]
		var t2 = info["mini"][rng.randi() % info["mini"].size()]
		mobs.append({"uid": uid, "type": t2, "pos": _tile_pos(rooms[c3].get_center().x, rooms[c3].get_center().y), "level": level + 1 + diff, "mini": true})
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
	# traps: a few spikes and wall dart shooters, never in the start room
	for c5 in cells:
		var r5 = rooms[c5]
		if rng.randf() < 0.5:
			spikes.append({"pos": _tile_pos(rng.randi_range(r5.position.x + 2, r5.end.x - 3), rng.randi_range(r5.position.y + 2, r5.end.y - 3))})
		if rng.randf() < 0.25:
			var cy5 = r5.get_center().y
			var wy = r5.position.y + (1 if rng.randf() < 0.5 else r5.size.y - 2)
			if absi(wy - cy5) > half + 1:
				darts.append({"pos": OFF + Vector2((r5.position.x - 1) * 16.0 + 8.0, wy * 16.0 + 16.0), "dir": Vector2.RIGHT})


func mini_count(want, avail):
	return mini(want, avail)


func walkable(pos):
	var lp = pos - OFF
	var x = int(floor(lp.x / 16.0))
	var y = int(floor(lp.y / 16.0))
	if x < 0 or y < 0 or x >= tw or y >= th:
		return false
	return tiles[y * tw + x] == 1


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
	for y in range(th):
		for x in range(tw):
			var idx = base + 2
			if tiles[y * tw + x] == 1:
				idx = base + (0 if rng.randf() < 0.7 else 1)
			img.blit_rect(ts, Rect2i(idx * 16, 0, 16, 16), Vector2i(x * 16, y * 16))
	return ImageTexture.create_from_image(img)


func stars():
	return "*".repeat(diff + 1)
