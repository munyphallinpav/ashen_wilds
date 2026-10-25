extends ColorRect
## Drag & drop dungeon layout editor. Two views:
##  "map"  - the room grid: add / move / remove rooms, link neighbours, pick start and boss room
##  "room" - one room: drag monsters, spawners, traps and treasure in (random spot or pinned), paint terrain
const BM = preload("res://scripts/bpmap.gd")

var hud = null
var view = "map"
var sel = Vector2i(-1, -1)          # selected room cell (map view)
var room_key = ""                   # room being edited (room view)
var armed = null                    # {cat, id} chosen by clicking a palette chip
var mini_mode = false
var spawn_type = ""
var tab = "mob"
var block_style = 0

var title: Label
var map_ui: Control
var room_ui: Control
var map_canvas
var room_canvas
var info_lbl: Label
var grid_lbl: Label
var room_title: Label
var size_lbl: Label
var pal_box: Control
var armed_lbl: Label
var list_box: VBoxContainer
var tab_btns = {}


# ---------------------------------------------------------------- helper classes
class Chip extends Button:
	var data = {}

	func _get_drag_data(_at):
		var l = Label.new()
		l.text = text
		l.add_theme_font_size_override("font_size", 8)
		l.add_theme_color_override("font_color", Color(1, 1, 0.6))
		set_drag_preview(l)
		return data.duplicate()


class DropBtn extends Button:
	var ed = null
	var kind = "random"

	func _can_drop_data(_at, d):
		return d is Dictionary and ed._can_drop_here(kind, d)

	func _drop_data(_at, d):
		ed._drop_on(kind, d, null)


class MapCanvas extends Control:
	var ed = null

	func cell():
		return int(244.0 / Game.bp["grid"])

	func _cell_at(p):
		var cs = cell()
		return Vector2i(int(p.x / cs), int(p.y / cs))

	func _inner(c):
		var cs = cell()
		var gap = maxf(3.0, cs * 0.16)
		return Rect2(Vector2(c) * cs + Vector2(gap, gap), Vector2(cs - gap * 2.0, cs - gap * 2.0))

	func _bar(a, b):
		var ra = _inner(a)
		var rb = _inner(b)
		var cs = cell()
		var w = maxf(5.0, cs * 0.2)
		if a.y == b.y:
			var x0 = minf(ra.end.x, rb.end.x)
			var x1 = maxf(ra.position.x, rb.position.x)
			var cy = ra.get_center().y
			return Rect2(x0 - 1.0, cy - w / 2.0, x1 - x0 + 2.0, w)
		var y0 = minf(ra.end.y, rb.end.y)
		var y1 = maxf(ra.position.y, rb.position.y)
		var cx = ra.get_center().x
		return Rect2(cx - w / 2.0, y0 - 1.0, w, y1 - y0 + 2.0)

	func _draw():
		var g = Game.bp["grid"]
		var cs = cell()
		var m = Game.bp["map"]
		var font = ThemeDB.fallback_font
		draw_rect(Rect2(0, 0, cs * g, cs * g), Color(0.07, 0.08, 0.11))
		for y in range(g):
			for x in range(g):
				var c = Vector2i(x, y)
				var r = _inner(c)
				var k = BM.key(x, y)
				if not m["rooms"].has(k):
					draw_rect(r, Color(0.11, 0.12, 0.17))
					draw_rect(r, Color(0.2, 0.22, 0.3), false, 1.0)
					draw_string(font, r.position + Vector2(r.size.x / 2.0 - 3.0, r.size.y / 2.0 + 4.0), "+", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.3, 0.33, 0.45))
		for lk in m["links"]:
			pass
		for y in range(g):
			for x in range(g):
				var c2 = Vector2i(x, y)
				for d in [Vector2i(1, 0), Vector2i(0, 1)]:
					var n = c2 + d
					if n.x < g and n.y < g and m["rooms"].has(BM.key(x, y)) and m["rooms"].has(BM.key(n.x, n.y)):
						var on = m["links"].has(BM.link_id(c2, n))
						var br = _bar(c2, n)
						draw_rect(br, Color(0.95, 0.8, 0.35) if on else Color(0.2, 0.22, 0.3))
		for y in range(g):
			for x in range(g):
				var k2 = BM.key(x, y)
				if not m["rooms"].has(k2):
					continue
				var r2 = _inner(Vector2i(x, y))
				var rd = m["rooms"][k2]
				var st = m["start"][0] == x and m["start"][1] == y
				var bs = m["boss"][0] == x and m["boss"][1] == y
				var col = Color(0.3, 0.36, 0.5)
				if st:
					col = Color(0.2, 0.5, 0.3)
				elif bs:
					col = Color(0.6, 0.2, 0.2)
				draw_rect(r2, col)
				draw_rect(r2, Color(1, 0.9, 0.4) if ed.sel == Vector2i(x, y) else Color(0.7, 0.75, 0.9, 0.6), false, 2.0 if ed.sel == Vector2i(x, y) else 1.0)
				var tag = "START" if st else ("BOSS" if bs else "")
				if rd["rand"]["live"]:
					tag += " RND" if tag != "" else "RND"
				if tag != "":
					draw_string(font, r2.position + Vector2(2, 9), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color.WHITE)
				var txt = "%dm %dt %dc" % [rd["mobs"].size() + rd["spawners"].size(), rd["traps"].size(), rd["chests"].size()]
				if r2.size.x > 34.0:
					draw_string(font, r2.position + Vector2(2, r2.size.y - 3), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 6, Color(1, 1, 1, 0.85))

	func _hit_bar(p) -> Variant:
		var g = Game.bp["grid"]
		var m = Game.bp["map"]
		for y in range(g):
			for x in range(g):
				for d in [Vector2i(1, 0), Vector2i(0, 1)]:
					var a = Vector2i(x, y)
					var n = a + d
					if n.x < g and n.y < g and m["rooms"].has(BM.key(a.x, a.y)) and m["rooms"].has(BM.key(n.x, n.y)):
						if _bar(a, n).grow(2.0).has_point(p):
							return [a, n]
		return null

	func _gui_input(ev):
		if not (ev is InputEventMouseButton) or not ev.pressed:
			return
		var c = _cell_at(ev.position)
		var g = Game.bp["grid"]
		if c.x < 0 or c.y < 0 or c.x >= g or c.y >= g:
			return
		var k = BM.key(c.x, c.y)
		var has = Game.bp["map"]["rooms"].has(k)
		if ev.button_index == MOUSE_BUTTON_LEFT:
			var hb = _hit_bar(ev.position)
			if hb != null:
				ed.toggle_link(hb[0], hb[1])
			elif has and _inner(c).has_point(ev.position):
				ed.sel = c
				if ev.double_click:
					ed.open_room(c)
			elif not has and _inner(c).has_point(ev.position):
				ed.add_room(c)
			ed.refresh()
		elif ev.button_index == MOUSE_BUTTON_RIGHT and has:
			ed.remove_room(c)
			ed.refresh()

	func _get_drag_data(at):
		var c = _cell_at(at)
		var g = Game.bp["grid"]
		if c.x < 0 or c.y < 0 or c.x >= g or c.y >= g or not Game.bp["map"]["rooms"].has(BM.key(c.x, c.y)):
			return null
		var l = Label.new()
		l.text = "Room"
		l.add_theme_font_size_override("font_size", 8)
		set_drag_preview(l)
		return {"t": "cell", "c": c}

	func _can_drop_data(at, d):
		if not (d is Dictionary):
			return false
		var c = _cell_at(at)
		var g = Game.bp["grid"]
		if c.x < 0 or c.y < 0 or c.x >= g or c.y >= g:
			return false
		var has = Game.bp["map"]["rooms"].has(BM.key(c.x, c.y))
		if d.get("t", "") == "cell":
			return not has
		if d.get("t", "") == "chip":
			if d["id"] == "room":
				return not has
			return has
		return false

	func _drop_data(at, d):
		var c = _cell_at(at)
		if d["t"] == "cell":
			ed.move_room(d["c"], c)
		elif d["id"] == "room":
			ed.add_room(c)
		elif d["id"] == "start":
			ed.set_marker("start", c)
		elif d["id"] == "boss":
			ed.set_marker("boss", c)
		ed.sel = c
		ed.refresh()


class RoomCanvas extends Control:
	var ed = null
	var hover = Vector2i(-1, -1)
	var painting = 0

	func cs():
		var rd = ed.cur_room()
		return maxi(6, int(minf(292.0 / rd["w"], 236.0 / rd["h"])))

	func _tile_at(p):
		var c = cs()
		return Vector2i(int(floorf(p.x / c)), int(floorf(p.y / c)))

	func _in(t):
		var rd = ed.cur_room()
		return t.x >= 0 and t.y >= 0 and t.x < rd["w"] and t.y < rd["h"]

	func _pin_at(t) -> Variant:
		var rd = ed.cur_room()
		for arr in ["mobs", "spawners", "traps", "chests"]:
			var a = rd[arr]
			for i in range(a.size() - 1, -1, -1):
				if a[i]["x"] >= 0 and a[i]["x"] == t.x and a[i]["y"] == t.y:
					return [arr, i]
		return null

	func _draw():
		var rd = ed.cur_room()
		var c = cs()
		var w = rd["w"]
		var h = rd["h"]
		var font = ThemeDB.fallback_font
		for y in range(h):
			for x in range(w):
				draw_rect(Rect2(x * c, y * c, c, c), Color(0.30, 0.33, 0.28) if (x + y) % 2 == 0 else Color(0.27, 0.30, 0.25))
		# door lanes of linked neighbours (terrain there is cleared automatically)
		var m = Game.bp["map"]
		var rc = BM.kc(ed.room_key)
		for lk in m["links"]:
			var e = BM.link_ends(lk)
			var dirv = Vector2i.ZERO
			if e[0] == ed.room_key:
				dirv = Vector2i(1, 0) if lk.ends_with("r") else Vector2i(0, 1)
			elif e[1] == ed.room_key:
				dirv = Vector2i(-1, 0) if lk.ends_with("r") else Vector2i(0, -1)
			if dirv == Vector2i.ZERO:
				continue
			var cx = w / 2
			var cy = h / 2
			var lane = Rect2()
			if dirv.x != 0:
				lane = Rect2((cx if dirv.x > 0 else 0) * c, (cy - 1) * c, ((w - cx) if dirv.x > 0 else (cx + 1)) * c, 3 * c)
			else:
				lane = Rect2((cx - 1) * c, (cy if dirv.y > 0 else 0) * c, 3 * c, ((h - cy) if dirv.y > 0 else (cy + 1)) * c)
			draw_rect(lane, Color(1, 0.9, 0.4, 0.16))
		for bk in rd["blocks"]:
			var p = BM.kc(bk)
			if p.x >= w or p.y >= h:
				continue
			var bv = rd["blocks"][bk]
			var col = BM.BLOCK_COL[bv[0]]
			col = col.lightened(0.18 * (int(bv[1]) - 1)) if int(bv[1]) != 1 else col
			if int(bv[1]) == 1:
				col = col.darkened(0.15)
			draw_rect(Rect2(p.x * c, p.y * c, c, c), col)
			draw_rect(Rect2(p.x * c, p.y * c, c, c), Color(0, 0, 0, 0.35), false, 1.0)
		var s = m["start"]
		if s[0] == rc.x and s[1] == rc.y:
			draw_rect(Rect2((w / 2 - 1) * c, 1 * c, 3 * c, 4 * c), Color(0.3, 1, 0.5, 0.25))
			draw_string(font, Vector2((w / 2 - 1) * c, 3 * c), "EXIT/START", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(0.6, 1, 0.7))
		var b = m["boss"]
		if b[0] == rc.x and b[1] == rc.y:
			draw_circle(Vector2((w / 2 + 0.5) * c, (h / 2 + 0.5) * c), c * 1.6, Color(0.9, 0.15, 0.15, 0.35))
			draw_string(font, Vector2((w / 2 - 1) * c, (h / 2 + 0.5) * c + 3), "BOSS", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color.WHITE)
		for arr in ["mobs", "spawners", "traps", "chests"]:
			for e in rd[arr]:
				if e["x"] < 0 or e["x"] >= w or e["y"] >= h:
					continue
				var r = Rect2(e["x"] * c + 1, e["y"] * c + 1, c - 2, c - 2)
				draw_rect(r, ed.entry_col(arr, e))
				draw_rect(r, Color(1, 0.9, 0.2) if e.get("m", false) else Color(0, 0, 0, 0.6), false, 1.0)
				draw_string(font, r.position + Vector2(1, c - 4), ed.entry_tag(arr, e), HORIZONTAL_ALIGNMENT_LEFT, c, maxi(6, c / 2 + 1), Color(0, 0, 0))
		if _in(hover):
			draw_rect(Rect2(hover.x * c, hover.y * c, c, c), Color(1, 1, 1, 0.9), false, 1.0)
		draw_rect(Rect2(0, 0, w * c, h * c), Color(1, 1, 1, 0.5), false, 1.0)

	func _apply_paint(t):
		if ed.armed == null or not _in(t):
			return
		if ed.armed["cat"] == "block" or ed.armed["cat"] == "erase":
			ed.place(ed.armed["cat"], ed.armed["id"], t)

	func _gui_input(ev):
		if ev is InputEventMouseMotion:
			var t = _tile_at(ev.position)
			if t != hover:
				hover = t
				queue_redraw()
			if painting == 1:
				_apply_paint(t)
			elif painting == 2 and _in(t):
				ed.erase_at(t)
		elif ev is InputEventMouseButton:
			var t2 = _tile_at(ev.position)
			if not ev.pressed:
				painting = 0
				return
			if not _in(t2):
				return
			if ev.button_index == MOUSE_BUTTON_LEFT:
				if _pin_at(t2) != null and (ed.armed == null or ed.armed["cat"] not in ["block", "erase"]):
					return   # allow dragging an existing pin
				if ed.armed != null:
					painting = 1
					if ed.armed["cat"] == "block" or ed.armed["cat"] == "erase":
						ed.place(ed.armed["cat"], ed.armed["id"], t2)
					else:
						ed.place(ed.armed["cat"], ed.armed["id"], t2)
			elif ev.button_index == MOUSE_BUTTON_RIGHT:
				painting = 2
				ed.erase_at(t2)

	func _get_drag_data(at):
		var t = _tile_at(at)
		var pin = _pin_at(t)
		if pin == null:
			return null
		var e = ed.cur_room()[pin[0]][pin[1]]
		var l = Label.new()
		l.text = ed.entry_name(pin[0], e)
		l.add_theme_font_size_override("font_size", 8)
		l.add_theme_color_override("font_color", Color(1, 1, 0.6))
		set_drag_preview(l)
		return {"t": "pin", "arr": pin[0], "i": pin[1]}

	func _can_drop_data(at, d):
		return d is Dictionary and _in(_tile_at(at)) and ed._can_drop_here("tile", d)

	func _drop_data(at, d):
		ed._drop_on("tile", d, _tile_at(at))


# ---------------------------------------------------------------- build
func setup(h):
	hud = h
	color = Color(0.05, 0.06, 0.1, 1.0)
	size = Vector2(480, 270)
	title = UI.lbl("LAYOUT EDITOR", 11, Color(1, 0.9, 0.4))
	title.position = Vector2(8, 3)
	add_child(title)
	_build_map_ui()
	_build_room_ui()
	visibility_changed.connect(func():
		if visible:
			show_map())


func _slim(b, h):
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb = b.get_theme_stylebox(st, "Button")
		if sb != null:
			sb = sb.duplicate()
			sb.content_margin_top = 0
			sb.content_margin_bottom = 0
			sb.content_margin_left = 2
			sb.content_margin_right = 2
			b.add_theme_stylebox_override(st, sb)
	b.custom_minimum_size.y = h
	b.size.y = h
	b.clip_text = true


func _btn(parent, text, pos, w, cb, h = 16, fs = 8):
	var b = UI.btn(text, w, h, fs)
	b.position = pos
	b.pressed.connect(cb)
	parent.add_child(b)
	_slim(b, h)
	b.size.x = w
	return b


func _chip(parent, text, pos, w, data, cb = null):
	var c = Chip.new()
	c.text = text
	c.focus_mode = Control.FOCUS_NONE
	c.custom_minimum_size = Vector2(w, 15)
	c.size = Vector2(w, 15)
	c.position = pos
	c.add_theme_font_size_override("font_size", 7)
	c.data = data
	if cb != null:
		c.pressed.connect(cb)
	parent.add_child(c)
	_slim(c, 15)
	c.size.x = w
	return c


func _build_map_ui():
	map_ui = Control.new()
	map_ui.size = Vector2(480, 270)
	add_child(map_ui)
	map_canvas = MapCanvas.new()
	map_canvas.ed = self
	map_canvas.position = Vector2(8, 22)
	map_canvas.size = Vector2(244, 244)
	map_ui.add_child(map_canvas)
	var x = 262.0
	var l = UI.lbl("Grid size", 8, Color(1, 0.9, 0.5))
	l.position = Vector2(x, 24)
	map_ui.add_child(l)
	_btn(map_ui, "-", Vector2(x + 52, 22), 18, func(): _grid(-1))
	grid_lbl = UI.lbl("", 8)
	grid_lbl.position = Vector2(x + 76, 24)
	map_ui.add_child(grid_lbl)
	_btn(map_ui, "+", Vector2(x + 106, 22), 18, func(): _grid(1))
	var h1 = UI.lbl("Drag onto the grid:", 7, Color(0.7, 0.9, 1))
	h1.position = Vector2(x, 44)
	map_ui.add_child(h1)
	_chip(map_ui, "Room", Vector2(x, 55), 50, {"t": "chip", "id": "room"})
	_chip(map_ui, "Start", Vector2(x + 54, 55), 50, {"t": "chip", "id": "start"})
	_chip(map_ui, "Boss", Vector2(x + 108, 55), 50, {"t": "chip", "id": "boss"})
	var tr = DropBtn.new()
	tr.ed = self
	tr.kind = "trash"
	tr.text = "Trash: drop a room here"
	tr.focus_mode = Control.FOCUS_NONE
	tr.position = Vector2(x, 75)
	tr.custom_minimum_size = Vector2(158, 16)
	tr.size = Vector2(158, 16)
	tr.add_theme_font_size_override("font_size", 7)
	map_ui.add_child(tr)
	_slim(tr, 16)
	info_lbl = UI.lbl("", 7, Color(0.85, 0.9, 1))
	info_lbl.position = Vector2(x, 96)
	info_lbl.custom_minimum_size = Vector2(206, 0)
	info_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	map_ui.add_child(info_lbl)
	var h2 = UI.lbl("Link / add neighbour:", 7, Color(0.7, 0.9, 1))
	h2.position = Vector2(x, 138)
	map_ui.add_child(h2)
	_btn(map_ui, "Up", Vector2(x + 34, 148), 36, func(): _dir(Vector2i(0, -1)))
	_btn(map_ui, "Left", Vector2(x, 166), 36, func(): _dir(Vector2i(-1, 0)))
	_btn(map_ui, "Right", Vector2(x + 68, 166), 36, func(): _dir(Vector2i(1, 0)))
	_btn(map_ui, "Down", Vector2(x + 34, 184), 36, func(): _dir(Vector2i(0, 1)))
	_btn(map_ui, "Edit Room", Vector2(x + 112, 150), 70, func(): open_room(sel), 18)
	_btn(map_ui, "Remove", Vector2(x + 112, 172), 70, func():
		remove_room(sel)
		refresh(), 18)
	var tip = UI.lbl("Click: select | double-click: edit | click a gold/grey bar to link | right-click: remove", 6, Color(1, 1, 1, 0.5))
	tip.position = Vector2(x, 208)
	tip.custom_minimum_size = Vector2(206, 0)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	map_ui.add_child(tip)
	_btn(map_ui, "Test Run", Vector2(x, 246), 64, func(): hud.panels["designer"]._action("Test Run"), 18)
	_btn(map_ui, "Done", Vector2(x + 70, 246), 54, back, 18)
	_btn(map_ui, "Randomize all", Vector2(x + 130, 246), 78, randomize_all, 18, 7)


func _build_room_ui():
	room_ui = Control.new()
	room_ui.size = Vector2(480, 270)
	room_ui.visible = false
	add_child(room_ui)
	room_canvas = RoomCanvas.new()
	room_canvas.ed = self
	room_canvas.position = Vector2(8, 22)
	room_ui.add_child(room_canvas)
	room_title = UI.lbl("", 9, Color(1, 0.9, 0.5))
	room_title.position = Vector2(100, 5)
	room_ui.add_child(room_title)
	var x = 304.0
	size_lbl = UI.lbl("", 7, Color(0.8, 0.9, 1))
	size_lbl.position = Vector2(x, 25)
	room_ui.add_child(size_lbl)
	_btn(room_ui, "W-", Vector2(x + 50, 22), 22, func(): _resize(-2, 0), 14, 7)
	_btn(room_ui, "W+", Vector2(x + 74, 22), 22, func(): _resize(2, 0), 14, 7)
	_btn(room_ui, "H-", Vector2(x + 100, 22), 22, func(): _resize(0, -2), 14, 7)
	_btn(room_ui, "H+", Vector2(x + 124, 22), 22, func(): _resize(0, 2), 14, 7)
	var tx = x
	for t in [["mob", "Monster"], ["trap", "Trap"], ["chest", "Chest"], ["block", "Terrain"], ["rand", "Random"]]:
		var tb = _btn(room_ui, t[1], Vector2(tx, 40), 33, _set_tab.bind(t[0]), 15, 7)
		tab_btns[t[0]] = tb
		tx += 34.0
	pal_box = Control.new()
	pal_box.position = Vector2(x, 58)
	pal_box.size = Vector2(170, 112)
	room_ui.add_child(pal_box)
	var rz = DropBtn.new()
	rz.ed = self
	rz.kind = "random"
	rz.text = "Drop here = RANDOM spot"
	rz.focus_mode = Control.FOCUS_NONE
	rz.position = Vector2(x, 172)
	rz.custom_minimum_size = Vector2(170, 16)
	rz.size = Vector2(170, 16)
	rz.add_theme_font_size_override("font_size", 7)
	rz.pressed.connect(func():
		if armed != null and armed["cat"] in ["mob", "spawner", "trap", "chest"]:
			place(armed["cat"], armed["id"], null)
		else:
			Game.notify("Pick a monster, trap or treasure first"))
	room_ui.add_child(rz)
	_slim(rz, 16)
	rz.size.x = 170
	armed_lbl = UI.lbl("", 7, Color(0.6, 1, 0.7))
	armed_lbl.position = Vector2(x, 190)
	armed_lbl.custom_minimum_size = Vector2(170, 0)
	room_ui.add_child(armed_lbl)
	var sc = ScrollContainer.new()
	sc.position = Vector2(x, 200)
	sc.size = Vector2(170, 44)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	room_ui.add_child(sc)
	list_box = VBoxContainer.new()
	list_box.custom_minimum_size = Vector2(160, 0)
	list_box.add_theme_constant_override("separation", 1)
	sc.add_child(list_box)
	_btn(room_ui, "Back to map", Vector2(x, 248), 80, show_map, 18)
	_btn(room_ui, "Test Run", Vector2(x + 86, 248), 64, func(): hud.panels["designer"]._action("Test Run"), 18)


# ---------------------------------------------------------------- views
func show_map():
	view = "map"
	map_ui.visible = true
	room_ui.visible = false
	title.text = "LAYOUT EDITOR - ROOMS"
	armed = null
	refresh()


func open_room(c):
	if not Game.bp["map"]["rooms"].has(BM.key(c.x, c.y)):
		Game.notify("Select a room first")
		return
	room_key = BM.key(c.x, c.y)
	view = "room"
	map_ui.visible = false
	room_ui.visible = true
	title.text = "ROOM EDITOR"
	armed = null
	_set_tab(tab)
	refresh()


func back():
	if view == "room":
		show_map()
	else:
		Game.save_bp()
		hud.set_panel("designer")


func cur_room():
	return Game.bp["map"]["rooms"][room_key]


func refresh():
	if view == "map":
		var g = Game.bp["grid"]
		grid_lbl.text = "%d x %d" % [g, g]
		map_canvas.size = Vector2(map_canvas.cell() * g, map_canvas.cell() * g)
		map_canvas.queue_redraw()
		var m = Game.bp["map"]
		var t = "%d rooms | %d links | %d monsters | %d traps | %d chests\n" % [m["rooms"].size(), m["links"].size(), Game.BpMap.count(Game.bp, "mobs") + Game.BpMap.count(Game.bp, "spawners"), Game.BpMap.count(Game.bp, "traps"), Game.BpMap.count(Game.bp, "chests")]
		var k = BM.key(sel.x, sel.y)
		if m["rooms"].has(k):
			var rd = m["rooms"][k]
			t += "Selected (%d,%d): %dx%d tiles, %d monsters, %d traps, %d chests" % [sel.x, sel.y, rd["w"], rd["h"], rd["mobs"].size() + rd["spawners"].size(), rd["traps"].size(), rd["chests"].size()]
		else:
			t += "Click an empty slot to add a room."
		var err = Game.validate_bp(Game.bp)
		t += "\n" + ("Ready!" if err == "" else "! " + err)
		info_lbl.text = t
	else:
		var rd2 = cur_room()
		room_title.text = "Room %s" % room_key
		size_lbl.text = "Size %dx%d" % [rd2["w"], rd2["h"]]
		room_canvas.size = Vector2(rd2["w"] * room_canvas.cs(), rd2["h"] * room_canvas.cs())
		room_canvas.queue_redraw()
		_rebuild_list()
		_update_armed()


# ---------------------------------------------------------------- map operations
func _grid(d):
	var g = clampi(Game.bp["grid"] + d, 2, 6)
	if g == Game.bp["grid"]:
		return
	Game.bp["grid"] = g
	Game.bp["map"] = Game.BpMap.fix(Game.bp["map"], g, Game.bp["size"])
	if sel.x >= g or sel.y >= g:
		sel = Vector2i(-1, -1)
	refresh()


func add_room(c):
	var k = BM.key(c.x, c.y)
	if not Game.bp["map"]["rooms"].has(k):
		Game.bp["map"]["rooms"][k] = BM.new_room(Game.bp["size"])
		var m = Game.bp["map"]
		if m["rooms"].size() == 1:
			m["start"] = [c.x, c.y]


func remove_room(c):
	var m = Game.bp["map"]
	var k = BM.key(c.x, c.y)
	if not m["rooms"].has(k):
		return
	m["rooms"].erase(k)
	var keep = []
	for lk in m["links"]:
		var e = BM.link_ends(lk)
		if e[0] != k and e[1] != k:
			keep.append(lk)
	m["links"] = keep
	if m["start"][0] == c.x and m["start"][1] == c.y:
		m["start"] = [-1, -1]
	if m["boss"][0] == c.x and m["boss"][1] == c.y:
		m["boss"] = [-1, -1]


func move_room(a, b):
	var m = Game.bp["map"]
	var ka = BM.key(a.x, a.y)
	var kb = BM.key(b.x, b.y)
	if not m["rooms"].has(ka) or m["rooms"].has(kb):
		return
	m["rooms"][kb] = m["rooms"][ka]
	m["rooms"].erase(ka)
	var nl = []
	for lk in m["links"]:
		var e = BM.link_ends(lk)
		var ea = BM.kc(e[0]) if e[0] != ka else b
		var eb = BM.kc(e[1]) if e[1] != ka else b
		var id = BM.link_id(ea, eb)
		if id != "" and not nl.has(id):
			nl.append(id)
	m["links"] = nl
	if m["start"][0] == a.x and m["start"][1] == a.y:
		m["start"] = [b.x, b.y]
	if m["boss"][0] == a.x and m["boss"][1] == a.y:
		m["boss"] = [b.x, b.y]


func toggle_link(a, b):
	var id = BM.link_id(a, b)
	if id == "":
		return
	var l = Game.bp["map"]["links"]
	if l.has(id):
		l.erase(id)
	else:
		l.append(id)


func set_marker(which, c):
	var m = Game.bp["map"]
	if not m["rooms"].has(BM.key(c.x, c.y)):
		return
	var other = "boss" if which == "start" else "start"
	if m[other][0] == c.x and m[other][1] == c.y:
		m[other] = [-1, -1]
	m[which] = [c.x, c.y]


func _dir(d):
	var m = Game.bp["map"]
	if not m["rooms"].has(BM.key(sel.x, sel.y)):
		Game.notify("Select a room first")
		return
	var n = sel + d
	var g = Game.bp["grid"]
	if n.x < 0 or n.y < 0 or n.x >= g or n.y >= g:
		Game.notify("Edge of the grid - make the grid bigger")
		return
	add_room(n)
	toggle_link(sel, n)
	refresh()


# ---------------------------------------------------------------- room operations
func _set_tab(t):
	tab = t
	for k in tab_btns:
		tab_btns[k].modulate = Color(1, 0.9, 0.4) if k == t else Color.WHITE
	UI.clear(pal_box)
	match t:
		"mob":
			var i = 0
			for id in Game.MOBS:
				if id == "mimic" or Game.MOBS[id]["mode"] == "passive":
					continue
				var c = _chip(pal_box, Game.MOBS[id]["name"], Vector2((i % 3) * 57, (i / 3) * 16), 55, {"t": "chip", "cat": "mob", "id": id}, _arm.bind("mob", id))
				c.name = "mob_" + id
				i += 1
			var mc = _chip(pal_box, "Mini: OFF", Vector2((i % 3) * 57, (i / 3) * 16), 55, {"t": "chip", "cat": "mob", "id": ""}, func():
				mini_mode = not mini_mode
				_set_tab("mob"))
			if mini_mode:
				mc.text = "Mini: ON"
				mc.modulate = Color(1, 0.9, 0.3)
			i += 1
			_chip(pal_box, "Spawner", Vector2((i % 3) * 57, (i / 3) * 16), 55, {"t": "chip", "cat": "spawner", "id": spawn_type}, func(): _arm("spawner", spawn_type))
			i += 1
			var rm = _chip(pal_box, "Random monster", Vector2((i % 3) * 57, (i / 3) * 16), 112, {"t": "chip", "cat": "mob", "id": ""}, _arm.bind("mob", ""))
			rm.add_theme_color_override("font_color", Color(1, 0.9, 0.4))
		"trap":
			var j = 0
			for k in Game.TRAP_KINDS:
				_chip(pal_box, Game.TRAP_NAMES[k], Vector2((j % 2) * 86, (j / 2) * 18), 84, {"t": "chip", "cat": "trap", "id": k}, _arm.bind("trap", k))
				j += 1
			var rt = _chip(pal_box, "Random trap", Vector2((j % 2) * 86, (j / 2) * 18), 84, {"t": "chip", "cat": "trap", "id": "random"}, _arm.bind("trap", "random"))
			rt.add_theme_color_override("font_color", Color(1, 0.9, 0.4))
			var hl3 = UI.lbl("Random monster / trap: the type is\nrolled every run. Pin it to a tile or\ndrop it on the RANDOM box.", 7, Color(0.8, 0.9, 1))
			hl3.position = Vector2(0, 84)
			pal_box.add_child(hl3)
		"chest":
			_chip(pal_box, "Treasure chest", Vector2(0, 0), 110, {"t": "chip", "cat": "chest", "id": ""}, _arm.bind("chest", ""))
			var hl = UI.lbl("Drag a chest into the room, or\nuse the RANDOM button below.", 7, Color(0.8, 0.9, 1))
			hl.position = Vector2(0, 22)
			pal_box.add_child(hl)
		"block":
			var j2 = 0
			for k2 in BM.BLOCKS:
				var bc = _chip(pal_box, BM.BLOCK_NAMES[k2], Vector2((j2 % 2) * 86, (j2 / 2) * 18), 84, {"t": "chip", "cat": "block", "id": k2}, _arm.bind("block", k2))
				bc.add_theme_color_override("font_color", BM.BLOCK_COL[k2].lightened(0.45))
				j2 += 1
			_btn(pal_box, "Style: %d" % (block_style + 1), Vector2(0, 38), 84, func():
				block_style = (block_style + 1) % 3
				_set_tab("block"), 15, 7)
			_chip(pal_box, "Eraser", Vector2(86, 38), 84, {"t": "chip", "cat": "erase", "id": ""}, _arm.bind("erase", ""))
			var hl2 = UI.lbl("Click or drag on the room to paint.\nStyle 1-3 changes the terrain colour.\nRight-click erases.", 7, Color(0.8, 0.9, 1))
			hl2.position = Vector2(0, 58)
			pal_box.add_child(hl2)
		"rand":
			var rr = cur_room()["rand"]
			var names = ["Few", "Some", "Many"]
			var l = UI.lbl("Randomize this room with:", 7, Color(1, 0.9, 0.5))
			pal_box.add_child(l)
			var xx = 0
			for k in [["terrain", "Terrain"], ["mobs", "Monsters"], ["traps", "Traps"]]:
				var b = _btn(pal_box, "%s: %s" % [k[1], "ON" if rr[k[0]] else "off"], Vector2(xx, 12), 56, func():
					rr[k[0]] = not rr[k[0]]
					_set_tab("rand"), 15, 7)
				if rr[k[0]]:
					b.add_theme_color_override("font_color", Color(0.6, 1, 0.6))
				xx += 57
			_btn(pal_box, "Amount: " + names[rr["amt"] - 1], Vector2(0, 30), 84, func():
				rr["amt"] = rr["amt"] % 3 + 1
				_set_tab("rand"), 15, 7)
			var lv = _btn(pal_box, "Re-roll each run: " + ("ON" if rr["live"] else "off"), Vector2(86, 30), 84, func():
				rr["live"] = not rr["live"]
				_set_tab("rand"), 15, 7)
			if rr["live"]:
				lv.add_theme_color_override("font_color", Color(0.6, 1, 0.6))
			_btn(pal_box, "Randomize now", Vector2(0, 48), 84, randomize_current, 16, 7)
			var hl4 = UI.lbl("Randomize now: fills the room with new\nrandom stuff (replaces ticked parts).\nRe-roll each run: adds fresh random\nstuff whenever the dungeon is built.\nDoors, exit and boss area stay clear.", 6, Color(0.8, 0.9, 1))
			hl4.position = Vector2(0, 66)
			pal_box.add_child(hl4)
	_update_armed()


func randomize_current():
	var rd = cur_room()
	var rr = rd["rand"]
	if not (rr["terrain"] or rr["mobs"] or rr["traps"]):
		Game.notify("Turn on Terrain, Monsters or Traps first")
		return
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	BM.roll_room(rd, Game.bp["map"], room_key, rr, rng, _pool(), true)
	refresh()


func randomize_all():
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var m = Game.bp["map"]
	for k in m["rooms"]:
		if k == BM.key(m["start"][0], m["start"][1]):
			BM.roll_room(m["rooms"][k], m, k, {"terrain": true, "mobs": false, "traps": false, "amt": 2}, rng, _pool(), true)
		else:
			BM.roll_room(m["rooms"][k], m, k, {"terrain": true, "mobs": true, "traps": true, "amt": 2}, rng, _pool(), true)
	Game.notify("Rooms randomized")
	refresh()


func _pool():
	return Game.bp["mob_types"] if Game.bp["mob_types"].size() > 0 else Game.DUNGEONS[Game.bp["biome"]]["mobs"]


func _arm(cat, id):
	armed = {"cat": cat, "id": id}
	if cat == "mob":
		spawn_type = id
	_update_armed()


func _update_armed():
	if armed_lbl == null:
		return
	if armed == null:
		armed_lbl.text = "Click a chip, then the room - or drag it in."
	else:
		var nm = armed["id"]
		if armed["cat"] == "mob":
			nm = (Game.MOBS[nm]["name"] if Game.MOBS.has(nm) else "Random monster") + (" (mini)" if mini_mode else "")
		elif armed["cat"] == "trap":
			nm = Game.TRAP_NAMES[nm]
		elif armed["cat"] == "block":
			nm = BM.BLOCK_NAMES[nm] + " / " + BM.STYLE_NAMES[nm][block_style]
		elif armed["cat"] == "erase":
			nm = "Eraser"
		elif armed["cat"] == "chest":
			nm = "Treasure"
		elif armed["cat"] == "spawner":
			nm = "Spawner (%s)" % (Game.MOBS[nm]["name"] if Game.MOBS.has(nm) else "biome mix")
		armed_lbl.text = "Armed: " + str(nm)


func _resize(dw, dh):
	var rd = cur_room()
	var mx = BM.max_dim(Game.bp["size"])
	rd["w"] = clampi(rd["w"] + dw, BM.MIN_ROOM, mx)
	rd["h"] = clampi(rd["h"] + dh, BM.MIN_ROOM, mx)
	for arr in ["mobs", "spawners", "traps", "chests"]:
		for e in rd[arr]:
			if e["x"] >= rd["w"]:
				e["x"] = rd["w"] - 1
			if e["y"] >= rd["h"]:
				e["y"] = rd["h"] - 1
	for bk in rd["blocks"].keys():
		var p = BM.kc(bk)
		if p.x >= rd["w"] or p.y >= rd["h"]:
			rd["blocks"].erase(bk)
	refresh()


func place(cat, id, t):
	var rd = cur_room()
	var x = t.x if t != null else -1
	var y = t.y if t != null else -1
	match cat:
		"mob":
			rd["mobs"].append({"t": id, "x": x, "y": y, "m": mini_mode})
		"spawner":
			rd["spawners"].append({"t": id, "x": x, "y": y})
		"trap":
			rd["traps"].append({"k": id, "x": x, "y": y})
		"chest":
			rd["chests"].append({"x": x, "y": y})
		"block":
			if t != null:
				rd["blocks"][BM.key(x, y)] = [id, block_style]
		"erase":
			if t != null:
				erase_at(t)
	Audio.sfx("click", 0.5)
	refresh()


func erase_at(t):
	var rd = cur_room()
	var pin = room_canvas._pin_at(t)
	if pin != null:
		rd[pin[0]].remove_at(pin[1])
	else:
		rd["blocks"].erase(BM.key(t.x, t.y))
	refresh()


func _can_drop_here(where, d):
	var t = d.get("t", "")
	if where == "trash":
		return t == "cell"
	if where == "random":
		return (t == "chip" and d.get("cat", "") in ["mob", "spawner", "trap", "chest"]) or t == "pin"
	if where == "tile":
		return t == "chip" and d.get("cat", "") != "" or t == "pin"
	return false


func _drop_on(where, d, tile):
	if where == "trash":
		remove_room(d["c"])
		refresh()
		return
	var x = tile.x if tile != null else -1
	var y = tile.y if tile != null else -1
	if d["t"] == "pin":
		var rd = cur_room()
		var e = rd[d["arr"]][d["i"]]
		e["x"] = x
		e["y"] = y
		refresh()
		return
	if d["cat"] == "mob":
		spawn_type = d["id"]
	place(d["cat"], d["id"], tile)


# ---------------------------------------------------------------- entry presentation
func entry_name(arr, e):
	match arr:
		"mobs":
			return ("* " if e.get("m", false) else "") + (Game.MOBS[e["t"]]["name"] if Game.MOBS.has(e["t"]) else "Random monster")
		"spawners":
			return "Spawner: " + (Game.MOBS[e["t"]]["name"] if Game.MOBS.has(e["t"]) else "biome mix")
		"traps":
			return Game.TRAP_NAMES[e["k"]]
	return "Treasure chest"


func entry_tag(arr, e):
	match arr:
		"mobs":
			return (Game.MOBS[e["t"]]["name"].substr(0, 2) if Game.MOBS.has(e["t"]) else "??")
		"spawners":
			return "Sp"
		"traps":
			return Game.TRAP_NAMES[e["k"]].substr(0, 2)
	return "$"


func entry_col(arr, e):
	match arr:
		"mobs":
			return Color.from_hsv(float(hash(e["t"]) % 1000) / 1000.0, 0.55, 0.95)
		"spawners":
			return Color(0.75, 0.45, 0.95)
		"traps":
			return Color.from_hsv(float(hash(e["k"]) % 1000) / 1000.0, 0.8, 0.85).lerp(Color(1, 0.3, 0.3), 0.3)
	return Color(1, 0.85, 0.25)


func _rebuild_list():
	UI.clear(list_box)
	var rd = cur_room()
	for arr in ["mobs", "spawners", "traps", "chests"]:
		for i in range(rd[arr].size()):
			var e = rd[arr][i]
			var row = HBoxContainer.new()
			row.add_theme_constant_override("separation", 2)
			var txt = entry_name(arr, e) + ("  (random)" if e["x"] < 0 else "  @%d,%d" % [e["x"], e["y"]])
			var l = UI.lbl(txt, 7, entry_col(arr, e).lightened(0.3))
			l.custom_minimum_size = Vector2(140, 0)
			row.add_child(l)
			var xb = UI.btn("x", 14, 12, 7)
			_slim(xb, 12)
			xb.pressed.connect(func():
				rd[arr].remove_at(rd[arr].find(e))
				refresh())
			row.add_child(xb)
			list_box.add_child(row)
