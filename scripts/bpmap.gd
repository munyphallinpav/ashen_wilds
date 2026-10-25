extends RefCounted
## Hand-built dungeon layouts (Dungeon Designer drag & drop mode).
## bp["map"] = {rooms: {"x,y": room}, links: ["x,y,r" | "x,y,d"], start: [x,y], boss: [x,y]}
## room = {w, h, mobs:[{t,x,y,m}], spawners:[{t,x,y}], traps:[{k,x,y}], chests:[{x,y}], blocks:{"x,y":[kind,style]}}
## x,y of an entry is room-local; -1 means "random spot in the room".

const PITCH = [20, 26, 32]
const MIN_ROOM = 9
const BLOCKS = ["wall", "cliff", "water", "lava"]
const BLOCK_NAMES = {"wall": "Wall", "cliff": "Cliff", "water": "Water", "lava": "Lava"}
const STYLE_NAMES = {
	"wall": ["Stone", "Dark", "Sandstone"],
	"cliff": ["Earth", "Slate", "Crimson"],
	"water": ["Lake", "Teal", "Abyss"],
	"lava": ["Magma", "Crimson", "White-hot"],
}
const BLOCK_COL = {"wall": Color(0.45, 0.45, 0.5), "cliff": Color(0.5, 0.38, 0.26), "water": Color(0.2, 0.45, 0.85), "lava": Color(0.95, 0.4, 0.1)}


static func key(x, y):
	return "%d,%d" % [x, y]


static func kc(k):
	var p = str(k).split(",")
	return Vector2i(int(p[0]), int(p[1]))


static func max_dim(size):
	return PITCH[clampi(size, 0, 2)] - 3


static func new_room(size, arena = false):
	var w = PITCH[size] - 7
	var h = PITCH[size] - 9
	if arena:
		w = max_dim(size)
		h = max_dim(size)
	return {"w": w, "h": h, "mobs": [], "spawners": [], "traps": [], "chests": [], "blocks": {},
		"rand": {"terrain": false, "mobs": false, "traps": false, "amt": 2, "live": false}}


static func default_map(biome, g, size):
	var m = {"rooms": {}, "links": [], "start": [0, 0], "boss": [0, 0]}
	var order = []
	for y in range(g):
		var row = range(g) if y % 2 == 0 else range(g - 1, -1, -1)
		for x in row:
			order.append(Vector2i(x, y))
	var mobs = Game.DUNGEONS[biome]["mobs"]
	var tr = ["boulder", "gas", "pit", "boom", "spikes", "dart"]
	for i in range(order.size()):
		var c = order[i]
		var last = i == order.size() - 1
		var room = new_room(size, last)
		if i > 0 and not last:
			for j in range(4):
				room["mobs"].append({"t": mobs[(i + j) % mobs.size()], "x": -1, "y": -1, "m": false})
			room["traps"].append({"k": tr[i % tr.size()], "x": -1, "y": -1})
			if i % 3 == 0:
				room["chests"].append({"x": -1, "y": -1})
		m["rooms"][key(c.x, c.y)] = room
		if i > 0:
			var p = order[i - 1]
			if p.y == c.y:
				m["links"].append(key(mini(p.x, c.x), c.y) + ",r")
			else:
				m["links"].append(key(c.x, p.y) + ",d")
	m["boss"] = [order[order.size() - 1].x, order[order.size() - 1].y]
	return m


static func link_ends(lk):
	var p = str(lk).split(",")
	var x = int(p[0])
	var y = int(p[1])
	if p[2] == "r":
		return [key(x, y), key(x + 1, y)]
	return [key(x, y), key(x, y + 1)]


## link id for two adjacent cells (order independent)
static func link_id(a, b):
	if a.y == b.y and absi(a.x - b.x) == 1:
		return key(mini(a.x, b.x), a.y) + ",r"
	if a.x == b.x and absi(a.y - b.y) == 1:
		return key(a.x, mini(a.y, b.y)) + ",d"
	return ""


static func fix(m, g, size):
	if not (m is Dictionary) or not m.has("rooms") or not (m["rooms"] is Dictionary):
		return default_map("forest", g, size)
	var out = {"rooms": {}, "links": [], "start": [0, 0], "boss": [0, 0]}
	var mx = max_dim(size)
	for k in m["rooms"]:
		var c = kc(k)
		if c.x < 0 or c.y < 0 or c.x >= g or c.y >= g:
			continue
		var r = m["rooms"][k]
		if not (r is Dictionary):
			continue
		var nr = new_room(size)
		nr["w"] = clampi(int(r.get("w", nr["w"])), MIN_ROOM, mx) | 1
		nr["h"] = clampi(int(r.get("h", nr["h"])), MIN_ROOM, mx) | 1
		nr["w"] = mini(nr["w"], mx if mx % 2 == 1 else mx - 1)
		nr["h"] = mini(nr["h"], mx if mx % 2 == 1 else mx - 1)
		for e in r.get("mobs", []):
			if e is Dictionary:
				nr["mobs"].append({"t": str(e.get("t", "")), "x": int(e.get("x", -1)), "y": int(e.get("y", -1)), "m": bool(e.get("m", false))})
		for e in r.get("spawners", []):
			if e is Dictionary:
				nr["spawners"].append({"t": str(e.get("t", "")), "x": int(e.get("x", -1)), "y": int(e.get("y", -1))})
		for e in r.get("traps", []):
			if e is Dictionary and (Game.TRAP_KINDS.has(str(e.get("k", ""))) or str(e.get("k", "")) == "random"):
				nr["traps"].append({"k": str(e["k"]), "x": int(e.get("x", -1)), "y": int(e.get("y", -1))})
		for e in r.get("chests", []):
			if e is Dictionary:
				nr["chests"].append({"x": int(e.get("x", -1)), "y": int(e.get("y", -1))})
		var rr = r.get("rand", {})
		if rr is Dictionary:
			nr["rand"] = {"terrain": bool(rr.get("terrain", false)), "mobs": bool(rr.get("mobs", false)), "traps": bool(rr.get("traps", false)),
				"amt": clampi(int(rr.get("amt", 2)), 1, 3), "live": bool(rr.get("live", false))}
		var bl = r.get("blocks", {})
		if bl is Dictionary:
			for bk in bl:
				var bv = bl[bk]
				if bv is Array and bv.size() >= 2 and BLOCKS.has(str(bv[0])):
					nr["blocks"][bk] = [str(bv[0]), clampi(int(bv[1]), 0, 2)]
		out["rooms"][key(c.x, c.y)] = nr
	for lk in m.get("links", []):
		var e = link_ends(lk)
		if out["rooms"].has(e[0]) and out["rooms"].has(e[1]) and not out["links"].has(str(lk)):
			out["links"].append(str(lk))
	var s = m.get("start", [0, 0])
	var b = m.get("boss", [0, 0])
	out["start"] = [int(s[0]), int(s[1])]
	out["boss"] = [int(b[0]), int(b[1])]
	return out


static func validate(bp):
	if not bp.get("manual", false):
		return ""
	var m = bp["map"]
	var rooms = m["rooms"]
	if rooms.size() < 2:
		return "Add at least 2 rooms"
	var s = key(m["start"][0], m["start"][1])
	var b = key(m["boss"][0], m["boss"][1])
	if not rooms.has(s):
		return "Pick a start room"
	if not rooms.has(b):
		return "Pick a boss room"
	if s == b:
		return "Start and boss must be different rooms"
	var adj = {}
	for lk in m["links"]:
		var e = link_ends(lk)
		if rooms.has(e[0]) and rooms.has(e[1]):
			adj[e[0]] = adj.get(e[0], []) + [e[1]]
			adj[e[1]] = adj.get(e[1], []) + [e[0]]
	var seen = {s: true}
	var q = [s]
	while q.size() > 0:
		var c = q.pop_back()
		for n in adj.get(c, []):
			if not seen.has(n):
				seen[n] = true
				q.append(n)
	if not seen.has(b):
		return "The boss room is not connected to the start"
	if seen.size() < rooms.size():
		return "%d room(s) are not connected to the start" % (rooms.size() - seen.size())
	return ""


static func count(bp, what):
	var n = 0
	for k in bp["map"]["rooms"]:
		n += bp["map"]["rooms"][k][what].size()
	return n


# ---------------------------------------------------------------- randomizer
## Tiles that must stay open: the centre, every door lane, the exit area (start room) and the boss area.
static func protect(m, k, rd):
	var w = rd["w"]
	var h = rd["h"]
	var cx = w / 2
	var cy = h / 2
	var p = {}
	for dx in range(-2, 3):
		for dy in range(-2, 3):
			p[Vector2i(cx + dx, cy + dy)] = true
	for lk in m["links"]:
		var e = link_ends(lk)
		var dv = Vector2i.ZERO
		if e[0] == k:
			dv = Vector2i(1, 0) if str(lk).ends_with("r") else Vector2i(0, 1)
		elif e[1] == k:
			dv = Vector2i(-1, 0) if str(lk).ends_with("r") else Vector2i(0, -1)
		if dv == Vector2i.ZERO:
			continue
		if dv.x != 0:
			for x in range(cx if dv.x > 0 else 0, (w if dv.x > 0 else cx + 1)):
				for dy in range(-2, 3):
					p[Vector2i(x, cy + dy)] = true
		else:
			for y in range(cy if dv.y > 0 else 0, (h if dv.y > 0 else cy + 1)):
				for dx in range(-2, 3):
					p[Vector2i(cx + dx, y)] = true
	if k == key(m["start"][0], m["start"][1]):
		for x in range(cx - 2, cx + 3):
			for y in range(0, 7):
				p[Vector2i(x, y)] = true
	if k == key(m["boss"][0], m["boss"][1]):
		for x in range(cx - 4, cx + 5):
			for y in range(cy - 3, cy + 6):
				p[Vector2i(x, y)] = true
	return p


## true when every non-solid tile is reachable from the room centre (lava counts as walkable)
static func _connected(w, h, blocks):
	var solid = {}
	for bk in blocks:
		if blocks[bk][0] != "lava":
			solid[kc(bk)] = true
	var total = w * h - solid.size()
	var start = Vector2i(w / 2, h / 2)
	if solid.has(start):
		return false
	var seen = {start: true}
	var q = [start]
	while q.size() > 0:
		var c = q.pop_back()
		for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n = c + o
			if n.x < 0 or n.y < 0 or n.x >= w or n.y >= h or seen.has(n) or solid.has(n):
				continue
			seen[n] = true
			q.append(n)
	return seen.size() == total


static func _free_tiles(rd, avoid, rng, n):
	var out = []
	var tries = 0
	while out.size() < n and tries < n * 30:
		tries += 1
		var t = Vector2i(rng.randi_range(1, rd["w"] - 2), rng.randi_range(1, rd["h"] - 2))
		if avoid.has(t):
			continue
		var bv = rd["blocks"].get(key(t.x, t.y), null)
		if bv != null:
			continue
		out.append(t)
	return out


## Randomise terrain / monsters / traps of one room. replace = clear that category first.
## Doors, the centre, the exit and the boss area are never blocked, and no walkable pocket is ever sealed off.
static func roll_room(rd, m, k, opts, rng, mob_pool, replace):
	var prot = protect(m, k, rd)
	var is_boss = k == key(m["boss"][0], m["boss"][1])
	var is_start = k == key(m["start"][0], m["start"][1])
	var amt = clampi(int(opts.get("amt", 2)), 1, 3)
	var area = rd["w"] * rd["h"] / 260.0
	if opts.get("terrain", false):
		if replace:
			rd["blocks"] = {}
		var n = maxi(1, int(round([2, 4, 7][amt - 1] * area)))
		var kinds = ["wall", "wall", "cliff", "cliff", "water", "water", "water", "lava", "lava", "lava"]
		for i in range(n):
			var kind = kinds[rng.randi() % kinds.size()]
			var style = rng.randi() % 3
			var c = Vector2i(rng.randi_range(1, rd["w"] - 2), rng.randi_range(1, rd["h"] - 2))
			var added = []
			var steps = rng.randi_range(1, 4) + amt * 2
			for s in range(steps):
				if c.x >= 1 and c.y >= 1 and c.x < rd["w"] - 1 and c.y < rd["h"] - 1 and not prot.has(c) and not rd["blocks"].has(key(c.x, c.y)):
					rd["blocks"][key(c.x, c.y)] = [kind, style]
					added.append(key(c.x, c.y))
				c += [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)][rng.randi() % 4]
			if not _connected(rd["w"], rd["h"], rd["blocks"]):
				for ak in added:
					rd["blocks"].erase(ak)
	if opts.get("mobs", false) and not is_boss:
		if replace:
			rd["mobs"] = []
		var avoid = {}
		if is_start:
			for x in range(rd["w"] / 2 - 4, rd["w"] / 2 + 5):
				for y in range(0, 9):
					avoid[Vector2i(x, y)] = true
		var cnt = maxi(1, int(round([2, 4, 6][amt - 1] * area)))
		for t in _free_tiles(rd, avoid, rng, cnt):
			var bv = rd["blocks"].get(key(t.x, t.y), null)
			rd["mobs"].append({"t": mob_pool[rng.randi() % mob_pool.size()], "x": t.x, "y": t.y, "m": false})
	if opts.get("traps", false) and not is_boss:
		if replace:
			rd["traps"] = []
		var cnt2 = maxi(1, int(round([1, 2, 4][amt - 1] * area)))
		for t2 in _free_tiles(rd, prot, rng, cnt2):
			rd["traps"].append({"k": Game.TRAP_KINDS[rng.randi() % Game.TRAP_KINDS.size()], "x": t2.x, "y": t2.y})
