extends Control
## Draws the map. mode "full" = whole world (click to set a waypoint, right-click to clear),
## mode "mini" = small corner minimap centred on the player.

const MINI_TILES = 35.0

var mode = "full"
var show_ore = true
var _s = 1.0
var _vo = Vector2.ZERO
var zoom = 1.0                      # full map only: 1 = whole world, up to MAX_ZOOM
var center = Vector2(Game.W / 2.0, Game.H / 2.0)   # view centre in tiles
var hover = Vector2(-1, -1)         # mouse position inside the control
var _drag = false
var _moved = false
const MAX_ZOOM = 8.0


func _ready():
	mouse_exited.connect(_mouse_exit)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP if mode == "full" else Control.MOUSE_FILTER_IGNORE
	if mode == "full":
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _process(_delta):
	if is_visible_in_tree():
		queue_redraw()


func center_on_player(z = 3.5):
	if Game.player != null:
		zoom = z
		center = Game.player.global_position / 16.0
		_clamp_view()


func reset_view():
	zoom = 1.0
	center = Vector2(Game.W / 2.0, Game.H / 2.0)


func zoom_by(f, anchor = null):
	var before = Vector2.ZERO
	if anchor != null:
		before = _vo + anchor / _s
	zoom = clampf(zoom * f, 1.0, MAX_ZOOM)
	if anchor != null:
		# keep the tile under the cursor fixed
		var view = Vector2(Game.W, Game.H) / zoom
		var s2 = size.x / view.x
		var vo = before - anchor / s2
		center = vo + view / 2.0
	_clamp_view()


func _clamp_view():
	var view = Vector2(Game.W, Game.H) / zoom
	center.x = clampf(center.x, view.x / 2.0, Game.W - view.x / 2.0)
	center.y = clampf(center.y, view.y / 2.0, Game.H - view.y / 2.0)


func _gui_input(event):
	if mode != "full" or Game.dlayout != null:
		return
	if event is InputEventMouseMotion:
		hover = event.position
		if _drag:
			if event.relative.length() > 0.0:
				_moved = true if (_moved or event.relative.length() > 1.5) else _moved
			if _moved:
				center -= event.relative / _s
				_clamp_view()
		return
	if not (event is InputEventMouseButton):
		return
	if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
		zoom_by(1.3, event.position)
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
		zoom_by(1.0 / 1.3, event.position)
	elif event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_drag = true
			_moved = false
		else:
			if _drag and not _moved and _pick_dungeon(event.position):
				pass
			elif _drag and not _moved:
				var wp = (_vo + event.position / _s) * 16.0
				wp.x = clampf(wp.x, 0.0, Game.W * 16.0)
				wp.y = clampf(wp.y, 0.0, Game.H * 16.0)
				Game.waypoint = wp
				Game.notify("Waypoint set")
			_drag = false
	elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		Game.waypoint = null
		Game.notify("Waypoint cleared")


func _pick_dungeon(pos):
	for rec in Game.dungeons:
		var dp = _mp(Vector2(rec["pos"][0], rec["pos"][1]))
		if dp.distance_to(pos) <= 8.0:
			Game.sel_dungeon = rec
			Game.notify("Selected: %s (Rank %d)" % [Game.DUNGEONS[rec["biome"]]["name"], rec["level"]])
			return true
	return false


func _mouse_exit():
	hover = Vector2(-1, -1)
	_drag = false


func _dcol(code, col_floor, col_wall):
	match code:
		1:
			return col_floor
		2:
			return Color(0.4, 0.3, 0.22)
		3:
			return Color(0.2, 0.4, 0.8)
		4:
			return Color(0.95, 0.4, 0.1)
	return col_wall


func _draw_dungeon(p):
	var lay = Game.dlayout
	var font = ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.03, 0.05))
	var tiles_view = float(lay.tw) if mode == "full" else MINI_TILES
	_s = size.x / tiles_view
	var off = Vector2.ZERO
	if mode == "mini":
		off = (p.global_position - lay.OFF) / 16.0 - Vector2(MINI_TILES, MINI_TILES) / 2.0
	_vo = off + lay.OFF / 16.0
	var col_floor = Color(0.55, 0.52, 0.45)
	var col_wall = Color(0.2, 0.19, 0.22)
	var x0 = maxi(0, int(off.x))
	var y0 = maxi(0, int(off.y))
	var x1 = mini(lay.tw, int(off.x + tiles_view) + 2) if mode == "mini" else lay.tw
	var y1 = mini(lay.th, int(off.y + tiles_view) + 2) if mode == "mini" else lay.th
	for y in range(y0, y1):
		for x in range(x0, x1):
			if lay.seen[y * lay.tw + x] == 0:
				continue
			draw_rect(Rect2((Vector2(x, y) - off) * _s, Vector2(_s + 0.5, _s + 0.5)), _dcol(lay.tiles[y * lay.tw + x], col_floor, col_wall))
	# markers
	var ex = (((lay.exit_pos - lay.OFF) / 16.0) - off) * _s
	draw_circle(ex, 3.0, Color(0.3, 1, 0.4))
	for c in get_tree().get_nodes_in_group("interact"):
		if c.has_method("interact") and c.get("opened") != null and not c.opened:
			var lp = (((c.global_position - lay.OFF) / 16.0) - off)
			if lay.seen[clampi(int(lp.y), 0, lay.th - 1) * lay.tw + clampi(int(lp.x), 0, lay.tw - 1)] == 1:
				draw_rect(Rect2(lp * _s - Vector2(2, 2), Vector2(4, 4)), Color(1, 0.85, 0.2))
	for b in get_tree().get_nodes_in_group("bosses"):
		var lpb = (((b.global_position - lay.OFF) / 16.0) - off)
		if lay.seen[clampi(int(lpb.y), 0, lay.th - 1) * lay.tw + clampi(int(lpb.x), 0, lay.tw - 1)] == 1:
			var bp = lpb * _s
			draw_colored_polygon(PackedVector2Array([bp + Vector2(0, -5), bp + Vector2(5, 0), bp + Vector2(0, 5), bp + Vector2(-5, 0)]), Color(0.9, 0.1, 0.1))
	var pp = (((p.global_position - lay.OFF) / 16.0) - off) * _s
	draw_circle(pp, 2.8, Color(1, 0.9, 0.2))
	draw_line(pp, pp + p.aim * 6.0, Color.WHITE, 1.0)
	if mode == "full":
		var name = "%s  Lv %d" % [Game.DUNGEONS[Game.cur_dungeon["biome"]]["name"], Game.cur_dungeon["level"]]
		draw_string_outline(font, Vector2(6, 12), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, 3, Color.BLACK)
		draw_string(font, Vector2(6, 12), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color.WHITE)
	draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.6), false, 1.0)


func font_for_grid():
	return ThemeDB.fallback_font


func _draw_grid(font, gw, gh):
	# faint grid every 20 tiles with coordinates on the edges
	var step = 20 if zoom < 3.0 else 10
	var gc = Color(1, 1, 1, 0.10)
	var x = int(ceil(_vo.x / step)) * step
	while (x - _vo.x) * _s < size.x:
		var px = (x - _vo.x) * _s
		draw_line(Vector2(px, 0), Vector2(px, size.y), gc, 1.0)
		draw_string(font, Vector2(px + 2, size.y - 2), str(x), HORIZONTAL_ALIGNMENT_LEFT, -1, 6, Color(1, 1, 1, 0.45))
		x += step
	var y = int(ceil(_vo.y / step)) * step
	while (y - _vo.y) * _s < size.y:
		var py = (y - _vo.y) * _s
		draw_line(Vector2(0, py), Vector2(size.x, py), gc, 1.0)
		draw_string(font, Vector2(2, py - 1), str(y), HORIZONTAL_ALIGNMENT_LEFT, -1, 6, Color(1, 1, 1, 0.45))
		y += step


func _mp(wp):
	return (wp / 16.0 - _vo) * _s


func _draw():
	var m = Game.map
	var p = Game.player
	if m == null or p == null:
		return
	if Game.dlayout != null:
		_draw_dungeon(p)
		return
	var gw = float(Game.W)
	var gh = float(Game.H)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.06, 0.1))
	if mode == "full":
		_clamp_view()
		var view = Vector2(gw, gh) / zoom
		_s = size.x / view.x
		_vo = center - view / 2.0
		draw_texture_rect_region(m.texture, Rect2(Vector2.ZERO, view * _s), Rect2(_vo, view))
		_draw_grid(font_for_grid(), gw, gh)
	else:
		_s = size.x / MINI_TILES
		_vo = p.global_position / 16.0 - Vector2(MINI_TILES, MINI_TILES) / 2.0
		var src = Rect2(_vo, Vector2(MINI_TILES, MINI_TILES)).intersection(Rect2(0, 0, gw, gh))
		if src.has_area():
			draw_texture_rect_region(m.texture, Rect2((src.position - _vo) * _s, src.size * _s), src)

	var font = ThemeDB.fallback_font
	# town: wall outline + house icon
	var vc = Vector2(gw * 8.0 + 8.0, gh * 8.0 + 8.0)
	if m.is_explored(vc):
		var wr = Rect2(_mp(vc - Vector2(Game.world.TOWN_HX, Game.world.TOWN_HY)), Vector2(Game.world.TOWN_HX, Game.world.TOWN_HY) * 2.0 / 16.0 * _s)
		draw_rect(wr, Color(0.85, 0.85, 0.95, 0.9), false, 1.0)
		var pt = _mp(vc)
		if mode == "full" or wr.size.x < 14.0:
			draw_rect(Rect2(pt - Vector2(3, 1), Vector2(6, 4)), Color(0.72, 0.54, 0.33))
			draw_colored_polygon(PackedVector2Array([pt + Vector2(-4, -1), pt + Vector2(0, -5), pt + Vector2(4, -1)]), Color(0.7, 0.25, 0.18))
		if mode == "full":
			draw_string_outline(font, pt + Vector2(-10, 12), "Town", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, 3, Color.BLACK)
			draw_string(font, pt + Vector2(-10, 12), "Town", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color.WHITE)
	# campfires placed by the player
	for f in get_tree().get_nodes_in_group("fire"):
		if f.placed and m.is_explored(f.global_position):
			draw_circle(_mp(f.global_position), 2.0, Color(1.0, 0.55, 0.15))
	# discovered ore deposits
	if mode == "full" and show_ore:
		for r in get_tree().get_nodes_in_group("resources"):
			if (r.kind == "iron" or r.kind == "coal") and m.is_explored(r.global_position):
				var op = _mp(r.global_position)
				draw_circle(op, 1.9, Color.WHITE)
				draw_circle(op, 1.3, Color(0.95, 0.55, 0.3) if r.kind == "iron" else Color(0.1, 0.1, 0.12))
	# discovered dungeon entrances
	for rec in Game.dungeons:
		var dp = _mp(Vector2(rec["pos"][0], rec["pos"][1]))
		if not Rect2(Vector2(2, 2), size - Vector2(4, 4)).has_point(dp):
			continue
		var dcol = Color(Game.DUNGEONS[rec["biome"]]["color"])
		var sz = 5.0 if mode == "full" else 4.0
		var poly = PackedVector2Array([dp + Vector2(0, -sz), dp + Vector2(sz, 0), dp + Vector2(0, sz), dp + Vector2(-sz, 0)])
		draw_colored_polygon(poly, dcol)
		draw_polyline(PackedVector2Array([poly[0], poly[1], poly[2], poly[3], poly[0]]), Color.WHITE, 1.0)
		if mode == "full" and Game.sel_dungeon == rec:
			draw_arc(dp, sz + 3.0, 0.0, TAU, 20, Color(0.4, 1, 0.5), 1.5)
		if mode == "full":
			var label = "%s  Rank %d" % [Game.DUNGEONS[rec["biome"]]["name"], rec["level"]]
			draw_string_outline(font, dp + Vector2(-30, -8), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, 3, Color.BLACK)
			draw_string(font, dp + Vector2(-30, -8), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, dcol.lightened(0.4))
	# waypoint
	if Game.waypoint != null:
		var wp = _mp(Game.waypoint)
		var inside = Rect2(Vector2(3, 3), size - Vector2(6, 6)).has_point(wp)
		if inside:
			draw_line(wp, wp + Vector2(0, -7), Color.WHITE, 1.0)
			draw_colored_polygon(PackedVector2Array([wp + Vector2(0, -7), wp + Vector2(5, -5), wp + Vector2(0, -3)]), Color(1, 0.2, 0.2))
		else:
			var e = wp.clamp(Vector2(4, 4), size - Vector2(4, 4))
			draw_circle(e, 3.0, Color(1, 0.2, 0.2))
		if mode == "mini":
			var tiles = int(p.global_position.distance_to(Game.waypoint) / 16.0)
			draw_string_outline(font, Vector2(3, size.y - 3), "WP %d" % tiles, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, 3, Color.BLACK)
			draw_string(font, Vector2(3, size.y - 3), "WP %d" % tiles, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 0.6, 0.6))
	# hover readout (tile coordinates + dungeon tooltip)
	if mode == "full" and hover.x >= 0.0:
		var tp = _vo + hover / _s
		var txt = "x %d  y %d" % [int(tp.x), int(tp.y)]
		for rec in Game.dungeons:
			var dp2 = _mp(Vector2(rec["pos"][0], rec["pos"][1]))
			if dp2.distance_to(hover) < 8.0:
				txt = "%s  Rank %d  (%d:%02d left)" % [Game.DUNGEONS[rec["biome"]]["name"], rec["level"], int(rec["time_left"]) / 60, int(rec["time_left"]) % 60]
				if rec.has("bp"):
					txt = "%s  Rank %d  (custom)" % [rec["bp"]["name"], rec["level"]]
		var tw = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x + 8.0
		draw_rect(Rect2(Vector2(size.x - tw - 2, 2), Vector2(tw, 11)), Color(0, 0, 0, 0.7))
		draw_string(font, Vector2(size.x - tw + 2, 10), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(1, 1, 0.8))
	if mode == "full":
		draw_string_outline(font, Vector2(size.x / 2.0 - 3, 9), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, 3, Color.BLACK)
		draw_string(font, Vector2(size.x / 2.0 - 3, 9), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color.WHITE)
	# player
	var pp = _mp(p.global_position)
	var pulse = 0.5 + 0.5 * sin(Time.get_ticks_msec() / 180.0)
	draw_circle(pp, 4.0 + pulse, Color(0, 0, 0, 0.6))
	draw_circle(pp, 2.6, Color(1, 0.9, 0.2))
	draw_line(pp, pp + p.aim * 6.0, Color.WHITE, 1.0)
	if mode == "mini":
		draw_string_outline(font, Vector2(size.x / 2.0 - 2, 9), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, 3, Color.BLACK)
		draw_string(font, Vector2(size.x / 2.0 - 2, 9), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color.WHITE)
	draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.6), false, 1.0)
