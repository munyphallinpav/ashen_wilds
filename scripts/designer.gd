extends ColorRect
## Dungeon Designer: free, cost-less customisation of a dungeon blueprint (Game.bp).
## Test Run enters it with rewards disabled; Create Seal makes an item that places it on the world.

var hud = null
var box: VBoxContainer
var scroll: ScrollContainer
var info: Label
var test_btn: Button


func setup(h):
	hud = h
	color = Color(0.05, 0.06, 0.1, 1.0)
	size = Vector2(480, 270)
	var t = UI.lbl("DUNGEON DESIGNER", 12, Color(1, 0.9, 0.4))
	t.position = Vector2(170, 4)
	add_child(t)
	scroll = ScrollContainer.new()
	scroll.position = Vector2(10, 24)
	scroll.size = Vector2(460, 192)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	box = VBoxContainer.new()
	box.custom_minimum_size = Vector2(440, 0)
	box.add_theme_constant_override("separation", 3)
	scroll.add_child(box)
	info = UI.lbl("", 7, Color(0.7, 0.9, 1))
	info.position = Vector2(12, 218)
	info.custom_minimum_size = Vector2(456, 0)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(info)
	var x = 12.0
	for spec in [["Test Run", 100], ["Create Seal", 100], ["Reset", 70], ["Back", 70]]:
		var b = UI.btn(spec[0], spec[1], 20, 9)
		b.position = Vector2(x, 244)
		b.pressed.connect(_action.bind(spec[0]))
		add_child(b)
		if spec[0] == "Test Run":
			test_btn = b
		x += spec[1] + 8.0
	visibility_changed.connect(func():
		if visible:
			refresh())


func _mob_types():
	var out = []
	for k in Game.MOBS:
		if k != "mimic" and Game.MOBS[k]["mode"] != "passive":
			out.append(k)
	return out


func _action(which):
	var bp = Game.bp
	match which:
		"Test Run":
			var err = Game.validate_bp(bp)
			if err != "":
				Game.notify(err)
				return
			if Game.cur_dungeon != null:
				Game.notify("Leave this dungeon first")
				return
			Game.save_bp()
			hud.set_panel("")
			Game.main.test_dungeon(bp)
		"Create Seal":
			var err2 = Game.validate_bp(bp)
			if err2 != "":
				Game.notify(err2)
				return
			var it = {"id": "dungeon_seal", "n": 1, "bp": bp.duplicate(true)}
			Game.player.add_item(it)
			Game.save_bp()
			Game.notify("Created seal: %s" % bp["name"])
		"Reset":
			Game.bp = Game.default_bp()
			Game.save_bp()
			refresh()
		"Back":
			Game.save_bp()
			hud.set_panel("pause")


func _row(label):
	var h = HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	var l = UI.lbl(label, 8, Color(1, 0.9, 0.5))
	l.custom_minimum_size = Vector2(120, 0)
	h.add_child(l)
	box.add_child(h)
	return h


func _stepper(label, text, dec, inc, big = null):
	var h = _row(label)
	var bs = []
	if big != null:
		bs.append(["<<", big[0]])
	bs.append(["<", dec])
	for b in bs:
		var bt = UI.btn(b[0], 22, 16, 8)
		bt.pressed.connect(func():
			b[1].call()
			refresh())
		h.add_child(bt)
	var v = UI.lbl(text, 8, Color.WHITE)
	v.custom_minimum_size = Vector2(120, 0)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_child(v)
	var ups = [[">", inc]]
	if big != null:
		ups.append([">>", big[1]])
	for b in ups:
		var bt2 = UI.btn(b[0], 22, 16, 8)
		bt2.pressed.connect(func():
			b[1].call()
			refresh())
		h.add_child(bt2)


func _num(label, key, lo, hi, step = 1, fmt = "%d", big = 0):
	var bp = Game.bp
	var bigc = null
	if big > 0:
		bigc = [func(): bp[key] = clampi(bp[key] - big, lo, hi), func(): bp[key] = clampi(bp[key] + big, lo, hi)]
	_stepper(label, fmt % bp[key], func(): bp[key] = clampi(bp[key] - step, lo, hi), func(): bp[key] = clampi(bp[key] + step, lo, hi), bigc)


func _cycle(arr, cur, d):
	return arr[(arr.find(cur) + d + arr.size()) % arr.size()]


func refresh():
	var bp = Game.bp
	var keep = scroll.scroll_vertical
	UI.clear(box)
	# name
	var nr = _row("Name")
	var le = LineEdit.new()
	le.text = bp["name"]
	le.max_length = 22
	le.custom_minimum_size = Vector2(200, 16)
	le.add_theme_font_size_override("font_size", 8)
	le.text_changed.connect(func(tx): bp["name"] = tx if tx.strip_edges() != "" else "My Dungeon")
	nr.add_child(le)
	var tog = func():
		bp["manual"] = not bp["manual"]
	_stepper("Customize by", "Drag & Drop layout" if bp["manual"] else "Option selection", tog, tog)
	var biomes = Game.DUNGEONS.keys()
	_stepper("Biome", Game.DUNGEONS[bp["biome"]]["name"],
		func():
			bp["biome"] = _cycle(biomes, bp["biome"], -1)
			bp["boss"] = Game.DUNGEONS[bp["biome"]]["boss"],
		func():
			bp["biome"] = _cycle(biomes, bp["biome"], 1)
			bp["boss"] = Game.DUNGEONS[bp["biome"]]["boss"])
	_stepper("Room size", Game.SIZE_NAMES[bp["size"]], func(): bp["size"] = maxi(0, bp["size"] - 1), func(): bp["size"] = mini(2, bp["size"] + 1))
	if not bp["manual"]:
		_num("Rooms per side", "grid", 2, 6, 1, "%d per side")
	_num("Difficulty rank", "rank", 1, 100, 1, "Rank %d", 10)
	if bp["manual"]:
		var bossesm = Game.BOSSES.keys()
		_stepper("Boss", Game.BOSSES[bp["boss"]]["name"], func(): bp["boss"] = _cycle(bossesm, bp["boss"], -1), func(): bp["boss"] = _cycle(bossesm, bp["boss"], 1))
		var er = Game.validate_bp(bp)
		var hr = _row("Layout")
		var eb = UI.btn("Open Layout Editor", 130, 18, 8)
		eb.pressed.connect(func(): hud.set_panel("layout"))
		hr.add_child(eb)
		var sl = UI.lbl("%d rooms, %d monsters, %d traps, %d chests%s" % [bp["map"]["rooms"].size(), Game.BpMap.count(bp, "mobs") + Game.BpMap.count(bp, "spawners"), Game.BpMap.count(bp, "traps"), Game.BpMap.count(bp, "chests"), "" if er == "" else " - " + er], 7, Color(0.7, 0.9, 1) if er == "" else Color(1, 0.6, 0.5))
		box.add_child(sl)
		info.text = "Hand-built dungeon: place rooms, monsters, traps, treasure and terrain yourself. Free to edit. Test runs give no loot, XP or gold."
		test_btn.disabled = Game.cur_dungeon != null
		scroll.set_deferred("scroll_vertical", keep)
		return
	_num("Monsters / room", "mobs", 0, 10)
	_num("Spawner devices", "spawners", 0, 12)
	_stepper("Random terrain", ["Off", "Few", "Some", "Many"][bp["terrain"]], func(): bp["terrain"] = maxi(0, bp["terrain"] - 1), func(): bp["terrain"] = mini(3, bp["terrain"] + 1))
	var bosses = Game.BOSSES.keys()
	_stepper("Boss", Game.BOSSES[bp["boss"]]["name"], func(): bp["boss"] = _cycle(bosses, bp["boss"], -1), func(): bp["boss"] = _cycle(bosses, bp["boss"], 1))
	_num("Mini bosses", "minis", 0, 8)
	var mt = [""] + _mob_types()
	_stepper("Mini boss type", "Random" if bp["mini_type"] == "" else Game.MOBS[bp["mini_type"]]["name"],
		func(): bp["mini_type"] = _cycle(mt, bp["mini_type"], -1), func(): bp["mini_type"] = _cycle(mt, bp["mini_type"], 1))
	var fl = ["Off", "Rare", "Normal", "Many"]
	for k in Game.TRAP_KINDS:
		_stepper(Game.TRAP_NAMES[k], fl[bp["traps"][k]], func(): bp["traps"][k] = maxi(0, bp["traps"][k] - 1), func(): bp["traps"][k] = mini(3, bp["traps"][k] + 1))
	var ml = UI.lbl("Monster types (none selected = biome default):", 8, Color(1, 0.9, 0.5))
	box.add_child(ml)
	var gc = GridContainer.new()
	gc.columns = 5
	gc.add_theme_constant_override("h_separation", 3)
	gc.add_theme_constant_override("v_separation", 3)
	box.add_child(gc)
	for m in _mob_types():
		var on = bp["mob_types"].has(m)
		var b = UI.btn(Game.MOBS[m]["name"], 84, 16, 8)
		b.modulate = Color(0.5, 1, 0.5) if on else Color(1, 1, 1, 0.75)
		b.pressed.connect(func():
			if bp["mob_types"].has(m):
				bp["mob_types"].erase(m)
			else:
				bp["mob_types"].append(m)
			refresh())
		gc.add_child(b)
	var rooms = bp["grid"] * bp["grid"] - 2
	info.text = "%d rooms + boss arena | ~%d monsters, %d mini bosses, %d spawners | Level %d, tier %d | Free to edit. Test runs give no loot, XP or gold." % [
		rooms, rooms * bp["mobs"], bp["minis"], bp["spawners"], bp["rank"], mini(bp["rank"] / 21, 4)]
	test_btn.disabled = Game.cur_dungeon != null
	scroll.set_deferred("scroll_vertical", keep)
