extends RefCounted
## Dungeon layout: a maze of 2-tile corridors (cell pitch 3) with an open boss arena in the far corner.
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
	n = 11 + 2 * diff
	tw = n * 3 + 1
	th = tw
	generate()


func _cell_center(cx, cy):
	return OFF + Vector2((cx * 3 + 2) * 16.0, (cy * 3 + 2) * 16.0)


func _set_floor(x, y):
	if x >= 0 and y >= 0 and x < tw and y < th:
		tiles[y * tw + x] = 1


func _open_cell(cx, cy):
	for dy in range(2):
		for dx in range(2):
			_set_floor(cx * 3 + 1 + dx, cy * 3 + 1 + dy)


func _open_between(ax, ay, bx, by):
	if bx > ax:
		_set_floor(ax * 3 + 3, ay * 3 + 1)
		_set_floor(ax * 3 + 3, ay * 3 + 2)
	elif bx < ax:
		_set_floor(bx * 3 + 3, ay * 3 + 1)
		_set_floor(bx * 3 + 3, ay * 3 + 2)
	elif by > ay:
		_set_floor(ax * 3 + 1, ay * 3 + 3)
		_set_floor(ax * 3 + 2, ay * 3 + 3)
	else:
		_set_floor(ax * 3 + 1, by * 3 + 3)
		_set_floor(ax * 3 + 2, by * 3 + 3)


func generate():
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_val
	tiles.resize(tw * th)
	tiles.fill(0)
	seen.resize(tw * th)
	seen.fill(0)
	var visited = {}
	var degree = {}
	var stack = [Vector2i(0, 0)]
	visited[Vector2i(0, 0)] = true
	_open_cell(0, 0)
	degree[Vector2i(0, 0)] = 0
	while stack.size() > 0:
		var c = stack[stack.size() - 1]
		var opts = []
		for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nc = c + o
			if nc.x >= 0 and nc.y >= 0 and nc.x < n and nc.y < n and not visited.has(nc):
				opts.append(nc)
		if opts.size() == 0:
			stack.pop_back()
			continue
		var nc = opts[rng.randi() % opts.size()]
		visited[nc] = true
		degree[nc] = 1
		degree[c] = degree.get(c, 0) + 1
		_open_cell(nc.x, nc.y)
		_open_between(c.x, c.y, nc.x, nc.y)
		stack.append(nc)
	# extra loops so the maze is not a pure tree
	var loops = int(n * n * 0.1)
	for i in range(loops):
		var cx = rng.randi_range(0, n - 2)
		var cy = rng.randi_range(0, n - 2)
		if rng.randf() < 0.5:
			_open_between(cx, cy, cx + 1, cy)
		else:
			_open_between(cx, cy, cx, cy + 1)
	# boss arena: far corner, fully open
	var a0 = n - arena_cells
	for y in range(a0 * 3 + 1, n * 3 + 1 - 0):
		for x in range(a0 * 3 + 1, n * 3 + 1 - 0):
			if x < tw - 1 and y < th - 1:
				_set_floor(x, y)
	boss_pos = OFF + Vector2((a0 * 3 + 1 + (arena_cells * 3 - 1) / 2.0) * 16.0, (a0 * 3 + 1 + (arena_cells * 3 - 1) / 2.0) * 16.0)
	start_pos = _cell_center(0, 0) + Vector2(0, 14)
	exit_pos = _cell_center(0, 0) + Vector2(0, -2)

	var info = Game.DUNGEONS[biome]
	var uid = 0
	var free_cells = []
	var dead_ends = []
	for cy in range(n):
		for cx in range(n):
			if cx >= a0 and cy >= a0:
				continue
			if cx + cy < 3:
				continue
			free_cells.append(Vector2i(cx, cy))
			if degree.get(Vector2i(cx, cy), 0) <= 1:
				dead_ends.append(Vector2i(cx, cy))
	# regular monster packs
	for c in free_cells:
		if rng.randf() < 0.2:
			var count = rng.randi_range(1, 3)
			for k in range(count):
				var t = info["mobs"][rng.randi() % info["mobs"].size()]
				mobs.append({"uid": uid, "type": t, "pos": _cell_center(c.x, c.y) + Vector2(rng.randf_range(-8, 8), rng.randf_range(-8, 8)),
					"level": maxi(1, level + rng.randi_range(-1, 1)), "mini": false})
				uid += 1
	# mini bosses: randomly spread
	var minis = 3 + diff
	var shuffled = free_cells.duplicate()
	for i in range(shuffled.size() - 1, 0, -1):
		var j = rng.randi_range(0, i)
		var tmp = shuffled[i]
		shuffled[i] = shuffled[j]
		shuffled[j] = tmp
	for i in range(mini_count(minis, shuffled.size())):
		var c = shuffled[i]
		var t = info["mini"][rng.randi() % info["mini"].size()]
		mobs.append({"uid": uid, "type": t, "pos": _cell_center(c.x, c.y), "level": level + 1 + diff, "mini": true})
		uid += 1
	# chests: dead ends first
	var cidx = 0
	var ends = dead_ends.duplicate()
	for i in range(ends.size() - 1, 0, -1):
		var j = rng.randi_range(0, i)
		var tmp = ends[i]
		ends[i] = ends[j]
		ends[j] = tmp
	var want = maxi(4, int(n * n / 14.0))
	for c in ends:
		if cidx >= want:
			break
		chests.append({"idx": cidx, "pos": _cell_center(c.x, c.y) + Vector2(0, 4)})
		cidx += 1
	# traps
	for c in free_cells:
		if rng.randf() < 0.12:
			spikes.append({"pos": _cell_center(c.x, c.y) + Vector2([-8, 8][rng.randi() % 2], [-8, 8][rng.randi() % 2])})
		if rng.randf() < 0.07 and c.x > 0:
			var wx = c.x * 3
			var wy = c.y * 3 + 1
			if tiles[wy * tw + wx] == 0:
				darts.append({"pos": OFF + Vector2(wx * 16.0 + 8.0, wy * 16.0 + 16.0), "dir": Vector2.RIGHT})
		if rng.randf() < 0.05 and c.y > 0:
			var wx2 = c.x * 3 + 1
			var wy2 = c.y * 3
			if tiles[wy2 * tw + wx2] == 0:
				darts.append({"pos": OFF + Vector2(wx2 * 16.0 + 16.0, wy2 * 16.0 + 8.0), "dir": Vector2.DOWN})


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
	var a0 = (n - arena_cells) * 3 * 16.0
	return lp.x > a0 and lp.y > a0


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
