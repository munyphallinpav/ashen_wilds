extends Panel
## Adventurer Guild: quests, the dungeon board, your listed dungeons and the roster of adventurer NPCs.

var hud
var board_box
var active_box
var title
const MAX_ACTIVE = 4
var tab = "quests"
var tabs = {}
var tab_btns = {}
var board_list
var mine_list
var seals_list
var heroes_list
var hero_detail
var hero_view = ""
var stash_lbl
var slots_lbl
var cut_lbl
var new_cut = 0.1
var refresh_t = 0.0


func _scroll(parent, pos, sz):
	var sc = ScrollContainer.new()
	sc.position = pos
	sc.size = sz
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(sc)
	var box = VBoxContainer.new()
	box.custom_minimum_size = Vector2(sz.x - 6, 0)
	box.add_theme_constant_override("separation", 3)
	sc.add_child(box)
	return box


func setup(h):
	hud = h
	title = UI.lbl("ADVENTURER GUILD", 11, Color(1, 0.9, 0.4))
	title.position = Vector2(8, 4)
	add_child(title)
	var x = 142.0
	for t in [["quests", "Quests", 52], ["board", "Dungeon Board", 84], ["mine", "My Dungeons", 76], ["heroes", "Adventurers", 70]]:
		var b = UI.btn(t[1], t[2], 16, 8)
		b.position = Vector2(x, 3)
		b.pressed.connect(_set_tab.bind(t[0]))
		add_child(b)
		tab_btns[t[0]] = b
		x += t[2] + 3.0
		var c = Control.new()
		c.size = Vector2(456, 250)
		add_child(c)
		tabs[t[0]] = c
	_build_quests(tabs["quests"])
	_build_board(tabs["board"])
	_build_mine(tabs["mine"])
	_build_heroes(tabs["heroes"])
	var hint = UI.lbl("T / Esc to leave.", 7, Color(1, 1, 1, 0.6))
	hint.position = Vector2(8, 238)
	add_child(hint)
	_set_tab("quests")


func _build_quests(root):
	var bl = UI.lbl("QUEST BOARD", 9, Color(0.6, 1, 0.6))
	bl.position = Vector2(8, 24)
	root.add_child(bl)
	var al = UI.lbl("YOUR QUESTS (max 4)", 9, Color(1, 0.8, 0.5))
	al.position = Vector2(232, 24)
	root.add_child(al)
	board_box = _scroll(root, Vector2(8, 38), Vector2(216, 194))
	active_box = _scroll(root, Vector2(232, 38), Vector2(216, 194))


func _build_board(root):
	var l = UI.lbl("DUNGEONS LISTED ON THE GUILD BOARD - owners earn a cut of the gold and items you win. Board runs give half gold / XP.", 7, Color(0.7, 0.9, 1))
	l.position = Vector2(8, 22)
	l.custom_minimum_size = Vector2(440, 0)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(l)
	board_list = _scroll(root, Vector2(8, 42), Vector2(440, 190))


func _build_mine(root):
	var a = UI.lbl("YOUR LISTED DUNGEONS", 9, Color(0.6, 1, 0.6))
	a.position = Vector2(8, 22)
	root.add_child(a)
	var b = UI.lbl("DUNGEON SEALS IN YOUR BAG", 9, Color(1, 0.8, 0.5))
	b.position = Vector2(232, 22)
	root.add_child(b)
	mine_list = _scroll(root, Vector2(8, 36), Vector2(216, 150))
	seals_list = _scroll(root, Vector2(232, 36), Vector2(216, 150))
	stash_lbl = UI.lbl("", 8, Color(1, 0.9, 0.5))
	stash_lbl.position = Vector2(8, 192)
	root.add_child(stash_lbl)
	var cb = UI.btn("Collect", 54, 16, 8)
	cb.position = Vector2(150, 190)
	cb.pressed.connect(func():
		Game.heroes_mgr.collect_stash()
		refresh())
	root.add_child(cb)
	slots_lbl = UI.lbl("", 8, Color(0.8, 0.9, 1))
	slots_lbl.position = Vector2(8, 212)
	root.add_child(slots_lbl)
	var sb = UI.btn("", 120, 16, 8)
	sb.name = "slotbtn"
	sb.position = Vector2(112, 210)
	sb.pressed.connect(_buy_slot)
	root.add_child(sb)
	cut_lbl = UI.lbl("", 8, Color(0.8, 0.9, 1))
	cut_lbl.position = Vector2(242, 212)
	root.add_child(cut_lbl)
	var m = UI.btn("-", 18, 16, 8)
	m.position = Vector2(380, 210)
	m.pressed.connect(func():
		new_cut = maxf(0.0, snappedf(new_cut - 0.05, 0.05))
		refresh())
	root.add_child(m)
	var pl = UI.btn("+", 18, 16, 8)
	pl.position = Vector2(402, 210)
	pl.pressed.connect(func():
		new_cut = minf(Game.CUT_MAX, snappedf(new_cut + 0.05, 0.05))
		refresh())
	root.add_child(pl)


func _build_heroes(root):
	heroes_list = _scroll(root, Vector2(8, 26), Vector2(440, 206))
	hero_detail = Control.new()
	hero_detail.size = Vector2(456, 250)
	hero_detail.visible = false
	root.add_child(hero_detail)


func _set_tab(t):
	tab = t
	for k in tabs:
		tabs[k].visible = k == t
		tab_btns[k].modulate = Color(1, 0.9, 0.4) if k == t else Color.WHITE
	if t != "heroes":
		hero_view = ""
	refresh()


func open():
	var p = hud.player
	if p.board.size() < 3 or Game.play_time - p.board_t > 600.0:
		p.board = []
		while p.board.size() < 4:
			p.board.append(Game.make_quest(p.level))
		p.board_t = Game.play_time
	hero_view = ""
	_set_tab("quests")


func open_hero(id):
	hero_view = id
	_set_tab("heroes")


func _process(delta):
	if not visible or tab != "heroes":
		return
	refresh_t += delta
	if refresh_t > 2.0:
		refresh_t = 0.0
		refresh()


func _card(q, progress, button_text, cb, enabled, ready):
	var pn = Panel.new()
	pn.custom_minimum_size = Vector2(208, 62)
	pn.add_theme_stylebox_override("panel", UI.style(Color(0.12, 0.16, 0.12) if ready else Color(0.1, 0.1, 0.15), Color(0.5, 0.5, 0.6) if not ready else Color(0.4, 1, 0.4), 1))
	var nm = UI.lbl(q["name"], 8, Color(1, 0.95, 0.7))
	nm.position = Vector2(4, 2)
	pn.add_child(nm)
	var info = UI.lbl("Rec. Lv %d   Reward: %dg  %d XP%s" % [q["level"], q["gold"], q["xp"], "  + gear" if q["gear"] else ""], 7, Color(1, 0.85, 0.4))
	info.position = Vector2(4, 14)
	pn.add_child(info)
	if progress >= 0:
		var pl = UI.lbl("Progress: %d / %d" % [progress, q["need"]], 8, Color(0.6, 1, 0.7) if ready else Color(0.9, 0.9, 0.9))
		pl.position = Vector2(4, 28)
		pn.add_child(pl)
	var b = UI.btn(button_text, 70, 18, 8)
	b.position = Vector2(132, 40)
	b.disabled = not enabled
	b.pressed.connect(cb)
	pn.add_child(b)
	return pn


func _row(w, h, border = Color(0.4, 0.4, 0.55)):
	var pn = Panel.new()
	pn.custom_minimum_size = Vector2(w, h)
	pn.add_theme_stylebox_override("panel", UI.style(Color(0.1, 0.1, 0.15), border, 1))
	return pn


func _add(pn, text, pos, size = 7, col = Color.WHITE):
	var l = UI.lbl(text, size, col)
	l.position = pos
	pn.add_child(l)
	return l


func refresh():
	var p = hud.player
	if p == null:
		return
	match tab:
		"quests":
			_refresh_quests(p)
		"board":
			_refresh_board()
		"mine":
			_refresh_mine(p)
		"heroes":
			_refresh_heroes()


func _refresh_quests(p):
	UI.clear(board_box)
	UI.clear(active_box)
	for q in p.board:
		var can = p.quests.size() < MAX_ACTIVE
		board_box.add_child(_card(q, -1, "Accept", _accept.bind(q), can, false))
	if p.board.size() == 0:
		board_box.add_child(UI.lbl("No quests right now.", 8, Color(1, 1, 1, 0.6)))
	for q in p.quests:
		var prog = p.quest_progress(q)
		var ready = p.quest_ready(q)
		var c = _card(q, prog, "Turn in", _turn_in.bind(q), ready, ready)
		var ab = UI.btn("Abandon", 52, 18, 7)
		ab.position = Vector2(76, 40)
		ab.pressed.connect(_abandon.bind(q))
		c.add_child(ab)
		active_box.add_child(c)
	if p.quests.size() == 0:
		active_box.add_child(UI.lbl("No active quests.\nAccept one from the board.", 8, Color(1, 1, 1, 0.6)))


func _bp_line(bp):
	var rooms = bp["map"]["rooms"].size() if bp.get("manual", false) else bp["grid"] * bp["grid"]
	return "%s | Boss: %s | %d rooms%s" % [Game.DUNGEONS[bp["biome"]]["name"], Game.BOSSES[bp["boss"]]["name"], rooms, " (hand-built)" if bp.get("manual", false) else ""]


func _refresh_board():
	UI.clear(board_list)
	var mgr = Game.heroes_mgr
	var arr = Game.listings.duplicate()
	arr.sort_custom(func(a, b): return a["bp"]["rank"] < b["bp"]["rank"])
	for l in arr:
		var rk = int(l["bp"]["rank"])
		var pn = _row(432, 38, Color(0.4, 0.8, 0.5) if l["owner"] == "player" else Color(0.4, 0.4, 0.55))
		_add(pn, "%s   Rank %d" % [l["name"], rk], Vector2(4, 2), 8, Color(1, 0.95, 0.7))
		_add(pn, "%s | Owner: %s | Reward cut %d%% | Played %d times" % [_bp_line(l["bp"]), mgr.owner_name(l), int(l["cut"] * 100.0), l["runs"]], Vector2(4, 15), 6, Color(0.8, 0.9, 1))
		var warn = rk > hud.player.level + 10
		_add(pn, "Too dangerous!" if warn else ("Good fit" if absi(rk - hud.player.level) <= 6 else ""), Vector2(4, 26), 6, Color(1, 0.5, 0.4) if warn else Color(0.5, 1, 0.6))
		var b = UI.btn("Enter", 50, 18, 8)
		b.position = Vector2(376, 10)
		b.pressed.connect(func(): Game.main.enter_listing(l))
		pn.add_child(b)
		board_list.add_child(pn)
	if arr.size() == 0:
		board_list.add_child(UI.lbl("No dungeons are listed yet. Adventurers list one when they reach levels 5, 10, 15...\nYou can list your own seals in the My Dungeons tab.", 8, Color(1, 1, 1, 0.6)))


func _refresh_mine(p):
	UI.clear(mine_list)
	UI.clear(seals_list)
	var mgr = Game.heroes_mgr
	var n = 0
	for l in Game.listings:
		if l["owner"] != "player":
			continue
		n += 1
		var pn = _row(208, 54, Color(0.4, 0.8, 0.5))
		_add(pn, l["name"], Vector2(4, 2), 8, Color(1, 0.95, 0.7))
		_add(pn, "Rank %d | Played %d | Earned %dg" % [l["bp"]["rank"], l["runs"], l["earned"]], Vector2(4, 14), 6, Color(0.8, 0.9, 1))
		_add(pn, "Cut: %d%%" % int(l["cut"] * 100.0), Vector2(4, 27), 7, Color(1, 0.9, 0.5))
		var m = UI.btn("-", 16, 14, 8)
		m.position = Vector2(46, 26)
		m.pressed.connect(func():
			l["cut"] = maxf(0.0, snappedf(l["cut"] - 0.05, 0.05))
			refresh())
		pn.add_child(m)
		var pl = UI.btn("+", 16, 14, 8)
		pl.position = Vector2(64, 26)
		pl.pressed.connect(func():
			l["cut"] = minf(Game.CUT_MAX, snappedf(l["cut"] + 0.05, 0.05))
			refresh())
		pn.add_child(pl)
		var wb = UI.btn("Withdraw", 56, 16, 7)
		wb.position = Vector2(148, 34)
		wb.pressed.connect(func():
			if mgr.withdraw(l):
				p.inventory_changed.emit()
			refresh())
		pn.add_child(wb)
		mine_list.add_child(pn)
	if n == 0:
		mine_list.add_child(UI.lbl("Nothing listed.\nList a seal from your bag.", 8, Color(1, 1, 1, 0.6)))
	var count = 0
	for i in range(p.inv.size()):
		var it = p.inv[i]
		if it == null or not it.has("bp"):
			continue
		count += 1
		var pn2 = _row(208, 40)
		_add(pn2, it["bp"]["name"], Vector2(4, 2), 8, Color(1, 0.95, 0.7))
		_add(pn2, "Rank %d | %s" % [it["bp"]["rank"], Game.DUNGEONS[it["bp"]["biome"]]["name"]], Vector2(4, 14), 6, Color(0.8, 0.9, 1))
		var b = UI.btn("List (%d%% cut)" % int(new_cut * 100.0), 80, 16, 7)
		b.position = Vector2(124, 20)
		b.disabled = n >= Game.listing_slots
		var idx = i
		b.pressed.connect(func():
			if mgr.list_seal(idx, new_cut):
				Game.notify("Dungeon listed on the guild board")
			refresh())
		pn2.add_child(b)
		seals_list.add_child(pn2)
	if count == 0:
		seals_list.add_child(UI.lbl("No dungeon seals in your bag.\nMake some in the Dungeon\nDesigner (Esc menu).", 8, Color(1, 1, 1, 0.6)))
	stash_lbl.text = "Earnings: %dg + %d items" % [Game.stash["gold"], Game.stash["items"].size()]
	slots_lbl.text = "Slots %d / %d" % [n, Game.listing_slots]
	var sb = tabs["mine"].get_node("slotbtn")
	if Game.listing_slots >= Game.SLOTS_MAX:
		sb.text = "Max slots"
		sb.disabled = true
	else:
		sb.text = "Buy slot (%dg)" % mgr.slot_cost()
		sb.disabled = p.gold < mgr.slot_cost()
	cut_lbl.text = "Cut for new listings: %d%%" % int(new_cut * 100.0)


func _buy_slot():
	var p = hud.player
	var c = Game.heroes_mgr.slot_cost()
	if Game.listing_slots >= Game.SLOTS_MAX or p.gold < c:
		return
	p.add_gold(-c)
	Game.listing_slots += 1
	refresh()


func _act_text(h):
	match h["act"]:
		"hunt":
			return "Hunting"
		"town":
			return "Resting in town"
		"quest":
			return "On a guild quest"
		"recall":
			return "Returning to town"
		"dungeon":
			var l = Game.heroes_mgr.get_listing(int(h["act_d"].get("listing", -1)))
			return "In dungeon: %s" % (l["name"] if l != null else "?")
	return h["act"]


func _refresh_heroes():
	UI.clear(heroes_list)
	var mgr = Game.heroes_mgr
	if hero_view != "":
		var h = mgr.get_hero(hero_view)
		if h != null:
			heroes_list.get_parent().visible = false
			hero_detail.visible = true
			_build_detail(h)
			return
		hero_view = ""
	heroes_list.get_parent().visible = true
	hero_detail.visible = false
	var arr = Game.heroes.duplicate()
	arr.sort_custom(func(a, b): return a["level"] > b["level"])
	_add_hint()
	for h in arr:
		var pn = _row(432, 30)
		_add(pn, "%s  -  %s Lv %d" % [h["name"], Game.CLASSES[h["cls"]]["name"], h["level"]], Vector2(4, 2), 8, mgr.CLS_COL[h["cls"]])
		_add(pn, "%dg | %s | %s" % [h["gold"], _act_text(h), h["last"]], Vector2(4, 15), 6, Color(0.8, 0.9, 1))
		var b = UI.btn("View", 44, 18, 8)
		b.position = Vector2(382, 6)
		var id = h["id"]
		b.pressed.connect(func():
			hero_view = id
			refresh())
		pn.add_child(b)
		heroes_list.add_child(pn)


func _add_hint():
	var l = UI.lbl("%d / %d adventurers. They hunt, quest, gear up and run the dungeons on the board. More join as you level." % [Game.heroes.size(), Game.HERO_MAX], 7, Color(0.7, 0.9, 1))
	heroes_list.add_child(l)


func _build_detail(h):
	UI.clear(hero_detail)
	var mgr = Game.heroes_mgr
	var info = Game.CLASSES[h["cls"]]
	var t = UI.lbl("%s - %s Lv %d" % [h["name"], info["name"], h["level"]], 11, mgr.CLS_COL[h["cls"]])
	t.position = Vector2(8, 22)
	hero_detail.add_child(t)
	var st = UI.lbl("HP %d / %d  |  Damage %d  |  Gold %dg  |  Potions %d\nKills %d  |  Defeats %d  |  Dungeon runs %d  |  Total earned %dg\nNow: %s - %s" % [
		int(h["hp"]), int(mgr.max_hp(h)), int(mgr.dmg(h)), h["gold"], h["potions"], h["kills"], h["deaths"], h["runs"], h["earned"], _act_text(h), h["last"]], 7, Color(0.85, 0.9, 1))
	st.position = Vector2(8, 38)
	hero_detail.add_child(st)
	var g = UI.lbl("EQUIPMENT", 8, Color(1, 0.8, 0.5))
	g.position = Vector2(8, 74)
	hero_detail.add_child(g)
	var y = 86.0
	for slot in h["gear"]:
		var it = h["gear"][slot]
		var l = UI.lbl("%s: %s (iLv %d)" % [slot.capitalize(), Items.name_of(it), it["ilvl"]], 7, Items.color_of(it))
		l.position = Vector2(8, y)
		hero_detail.add_child(l)
		y += 11.0
	var sk = UI.lbl("SKILLS", 8, Color(1, 0.8, 0.5))
	sk.position = Vector2(232, 74)
	hero_detail.add_child(sk)
	y = 86.0
	for id in h["skills"]:
		var s = Game.SKILLS[id]
		var l2 = UI.lbl("%s (%s)" % [s["name"], str(s.get("elem", "")).capitalize()], 7, Game.ELEM_COLOR.get(s.get("elem", ""), Color.WHITE))
		l2.position = Vector2(232, y)
		hero_detail.add_child(l2)
		y += 11.0
	var iv = UI.lbl("INVENTORY (%d)" % h["inv"].size(), 8, Color(1, 0.8, 0.5))
	iv.position = Vector2(232, 134)
	hero_detail.add_child(iv)
	var txt = ""
	for it in h["inv"]:
		txt += "%s x%d, " % [Items.name_of(it), int(it["n"])]
	var il = UI.lbl(txt if txt != "" else "(empty)", 6, Color(0.8, 0.8, 0.85))
	il.position = Vector2(232, 146)
	il.custom_minimum_size = Vector2(216, 0)
	il.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hero_detail.add_child(il)
	if h["listing"] >= 0:
		var lst = mgr.get_listing(h["listing"])
		if lst != null:
			var ll = UI.lbl("Owns dungeon: %s (Rank %d, cut %d%%)" % [lst["name"], lst["bp"]["rank"], int(lst["cut"] * 100.0)], 7, Color(0.6, 1, 0.7))
			ll.position = Vector2(8, 200)
			hero_detail.add_child(ll)
	var back = UI.btn("Back", 60, 18, 8)
	back.position = Vector2(8, 216)
	back.pressed.connect(func():
		hero_view = ""
		refresh())
	hero_detail.add_child(back)


func _accept(q):
	var p = hud.player
	if p.quests.size() >= MAX_ACTIVE:
		return
	p.board.erase(q)
	p.quests.append(q)
	Game.notify("Quest accepted: %s" % q["name"])
	refresh()


func _turn_in(q):
	hud.player.quest_turn_in(q)
	refresh()


func _abandon(q):
	hud.player.quests.erase(q)
	refresh()
