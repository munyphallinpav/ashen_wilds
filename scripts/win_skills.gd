extends Panel
## Skill tree window. Class / Common / Tomes tabs, tiered rows, 4-slot loadout bar.
## Learn: left-click a node.  Equip: drag a learned active skill onto a slot, or right-click it (goes to the selected slot).
## Slots can be swapped by dragging one onto another, and cleared with right-click.

const COL_W = 88.0
const ROW_H = 66.0
const X0 = 14.0
const Y0 = 24.0
const NODE = 38.0

var hud
var tab = "class"
var area
var pts_lbl
var tab_btns = {}
var lines_ctl
var scroll
var sel_slot = 0
var slot_btns = []
var slot_icons = []
var slot_keys = []
var slot_names = []


func setup(h):
	hud = h
	var t = UI.lbl("SKILLS  (K to close)", 10, Color(1, 0.9, 0.5))
	t.position = Vector2(8, 4)
	add_child(t)
	pts_lbl = UI.lbl("", 10, Color(0.5, 1, 0.5))
	pts_lbl.position = Vector2(300, 5)
	add_child(pts_lbl)
	var kb = UI.btn("Keys...", 44, 14, 7)
	kb.position = Vector2(404, 4)
	kb.pressed.connect(func(): hud.open_controls("skills"))
	add_child(kb)
	var x = 8
	for tb in [["class", "Class"], ["common", "Common"], ["tome", "Tomes"]]:
		var b = UI.btn(tb[1], 64, 18, 9)
		b.position = Vector2(x, 22)
		b.pressed.connect(_set_tab.bind(tb[0]))
		add_child(b)
		tab_btns[tb[0]] = b
		x += 66
	var hint = UI.lbl("Click: learn   Drag or right-click: equip", 7, Color(0.8, 0.85, 1))
	hint.position = Vector2(214, 27)
	add_child(hint)
	# loadout bar: four slots, each with icon, key badge and skill name
	for i in range(4):
		var b = Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.position = Vector2(8 + i * 111, 44)
		b.size = Vector2(106, 30)
		b.clip_contents = true
		b.pressed.connect(func():
			sel_slot = i
			refresh())
		b.gui_input.connect(_slot_input.bind(i))
		b.set_drag_forwarding(_slot_drag.bind(i, b), _slot_can_drop, _slot_drop.bind(i))
		add_child(b)
		var ic = UI.icon(Game.tex("res://assets/items/elem_none.png"), 22)
		ic.position = Vector2(4, 4)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(ic)
		var kl = UI.lbl("", 9, Color(0.5, 1, 0.5))
		kl.position = Vector2(30, 0)
		kl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(kl)
		var nl = UI.lbl("", 7, Color(1, 1, 1, 0.9))
		nl.position = Vector2(30, 13)
		nl.custom_minimum_size = Vector2(74, 0)
		nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(nl)
		slot_btns.append(b)
		slot_icons.append(ic)
		slot_keys.append(kl)
		slot_names.append(nl)
	scroll = ScrollContainer.new()
	scroll.position = Vector2(8, 78)
	scroll.size = Vector2(440, 168)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	area = Control.new()
	area.custom_minimum_size = Vector2(424, 24 + 5 * ROW_H + 8)
	scroll.add_child(area)
	lines_ctl = Control.new()
	lines_ctl.size = area.custom_minimum_size
	lines_ctl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines_ctl.draw.connect(_draw_lines)
	area.add_child(lines_ctl)


# ------------------------------------------------------------ loadout slots (drag & drop)
func _slot_input(ev, i):
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT:
		var p = hud.player
		if p.loadout[i] != "":
			p.loadout[i] = ""
			Game.notify("Slot %d cleared" % (i + 1))
			refresh()


func _slot_drag(_pos, i, b):
	var p = hud.player
	var id = p.loadout[i]
	if id == "":
		return null
	var pv = UI.icon(Game.skill_icon(id), 28)
	b.set_drag_preview(pv)
	return {"skill": id, "from": i}


func _slot_can_drop(_pos, data):
	return typeof(data) == TYPE_DICTIONARY and data.has("skill")


func _slot_drop(_pos, data, i):
	var p = hud.player
	if data.has("from"):
		var f = data["from"]
		var tmp = p.loadout[i]
		p.loadout[i] = p.loadout[f]
		p.loadout[f] = tmp
	elif Skills.equip_skill(p, data["skill"], i):
		Game.notify("%s equipped (%s)" % [Game.SKILLS[data["skill"]]["name"], Game.key_label("skill_%d" % i)])
	sel_slot = i
	refresh()


func _node_drag(_pos, id, b):
	var p = hud.player
	var s = Game.SKILLS[id]
	if s["type"] != "active" or Skills.rank(p, id) <= 0:
		return null
	hud.tip_hide()
	b.set_drag_preview(UI.icon(Game.skill_icon(id), 28))
	return {"skill": id}


# ------------------------------------------------------------ tree
func _set_tab(t):
	tab = t
	scroll.scroll_vertical = 0
	refresh()


func _node_pos(id):
	var sk = Game.SKILLS[id]
	return Vector2(X0 + sk["pos"][0] * COL_W, Y0 + sk["pos"][1] * ROW_H)


func _ids():
	var out = []
	for id in Game.SKILLS:
		var c = Game.SKILLS[id]["cls"]
		if tab == "common" and c == "common":
			out.append(id)
		elif tab == "class" and c == hud.player.char_id:
			out.append(id)
		elif tab == "tome" and c == "tome":
			out.append(id)
	return out


func _draw_lines():
	var p = hud.player
	if p == null:
		return
	var font = ThemeDB.fallback_font
	var w = lines_ctl.size.x
	# tier bands
	for r in range(5):
		if r % 2 == 0:
			lines_ctl.draw_rect(Rect2(0, Y0 - 4 + r * ROW_H, w, ROW_H - 2), Color(1, 1, 1, 0.035))
	if tab == "tome":
		lines_ctl.draw_string(font, Vector2(X0, 12), "SPELL TOMES - buy the book at the Magic Shop, then rank it up here", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.75, 0.6, 1))
	else:
		lines_ctl.draw_string(font, Vector2(X0 + 26, 12), "ACTIVE SKILLS", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 0.8, 0.5))
		lines_ctl.draw_string(font, Vector2(X0 + 3 * COL_W + 22, 12), "PASSIVE SKILLS", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.6, 0.9, 1))
		lines_ctl.draw_line(Vector2(X0 + 2 * COL_W + 18, 4), Vector2(X0 + 2 * COL_W + 18, lines_ctl.size.y - 6), Color(1, 1, 1, 0.12), 1.0)
	for id in _ids():
		var a = _node_pos(id) + Vector2(NODE / 2.0, NODE / 2.0)
		for r in Game.SKILLS[id]["req"]:
			var b = _node_pos(r[0]) + Vector2(NODE / 2.0, NODE / 2.0)
			var ok = Skills.rank(p, r[0]) >= r[1]
			lines_ctl.draw_line(a, b, Color(0, 0, 0, 0.6), 4.0)
			lines_ctl.draw_line(a, b, Color(0.95, 0.8, 0.3) if ok else Color(0.4, 0.4, 0.5), 2.0)


func _tip(id):
	var p = hud.player
	var s = Game.SKILLS[id]
	var r = Skills.rank(p, id)
	var cap = Skills.rank_cap(p, id)
	var out = []
	var ecol = Game.ELEM_COLOR.get(s["elem"], Color.WHITE)
	out.append([s["name"], Color(1, 0.9, 0.4)])
	if s["cls"] == "tome" and not p.tomes.has(id):
		out.append(["Locked: buy the spell book at the Magic Shop in town.", Color(1, 0.5, 0.5)])
	var kind = "Passive" if s["type"] == "passive" else "Active"
	out.append(["%s  |  %s  |  Lv req %d" % [kind, s["elem"].capitalize() if s["elem"] != "none" else "No element", s["lvl"]], ecol])
	out.append([s["desc"], Color(0.9, 0.9, 0.95)])
	out.append(["Rank %d / %d   (cap now %d)" % [r, s["max"], cap], Color(0.7, 1, 0.7)])
	if s["type"] == "active":
		var ki = p.loadout.find(id)
		out.append(["Mana %d   Cooldown %.1fs   %s" % [int(s["mana"] * (1.0 + 0.03 * maxi(r - 1, 0))), s["cd"], ("Key: " + Game.key_label("skill_%d" % ki)) if ki >= 0 else "Not equipped"], Color(0.7, 0.8, 1)])
		if s["mult"] > 0.0:
			var stat = "Phy" if s["kind"] == "phy" else "Magic"
			var cur = s["mult"] + s["per"] * maxi(r - 1, 0)
			var nxt = s["mult"] + s["per"] * maxi(r, 0)
			out.append(["Damage: %d%% %s Atk%s" % [int(cur * 100), stat, ("  ->  %d%%" % int(nxt * 100)) if r < s["max"] else ""], Color(1, 0.8, 0.6)])
		if r > 0:
			out.append(["Drag onto a slot to equip", Color(0.6, 0.8, 1)])
	else:
		for k in s["bonus"]:
			out.append(["Per rank: %s" % _bonus_text(k, s["bonus"][k]), Color(0.7, 1, 0.9)])
	if r < s["max"] and not Skills.can_learn(p, id):
		out.append([Skills.why_not(p, id), Color(1, 0.5, 0.5)])
	elif r < s["max"]:
		out.append(["Click to learn", Color(0.5, 1, 0.5)])
	return out


func _bonus_text(k, v):
	if k.ends_with("_pct") or k in ["move_pct", "aspd_pct", "drop_pct", "heal_pct"]:
		return "+%.1f%% %s" % [v * 100.0, k.replace("_pct", "").replace("_", " ")]
	if k.ends_with("regen"):
		return "+%.2f %s/s" % [v, k.replace("_regen", "").to_upper()]
	return "+%s %s" % [str(v), k.replace("_", " ")]


func refresh():
	var p = hud.player
	if p == null:
		return
	for t in tab_btns:
		tab_btns[t].self_modulate = Color(1, 0.9, 0.4) if t == tab else Color.WHITE
	tab_btns["class"].text = p.cdata["name"]
	for i in range(4):
		var lid = p.loadout[i]
		slot_keys[i].text = "[%s]" % Game.key_label("skill_%d" % i)
		slot_names[i].text = Game.SKILLS[lid]["name"] if lid != "" else "- empty -"
		slot_icons[i].texture = Game.skill_icon(lid) if lid != "" else Game.tex("res://assets/items/elem_none.png")
		slot_icons[i].modulate = Color.WHITE if lid != "" else Color(0.4, 0.4, 0.45)
		var sel = i == sel_slot
		var col = Game.ELEM_COLOR.get(Game.SKILLS[lid]["elem"], Color(0.6, 0.6, 0.7)) if lid != "" else Color(0.35, 0.35, 0.42)
		slot_btns[i].add_theme_stylebox_override("normal", UI.style(Color(0.13, 0.12, 0.08) if sel else Color(0.1, 0.1, 0.15), Color(1, 0.9, 0.4) if sel else col, 2 if sel else 1))
		slot_btns[i].add_theme_stylebox_override("hover", UI.style(Color(0.18, 0.18, 0.24), Color(1, 0.9, 0.4) if sel else col, 2))
		slot_btns[i].add_theme_stylebox_override("pressed", UI.style(Color(0.2, 0.2, 0.26), Color(1, 0.9, 0.4), 2))
	pts_lbl.text = "Skill points: %d" % p.skill_pts
	for c in area.get_children():
		if c != lines_ctl:
			area.remove_child(c)
			c.queue_free()
	for id in _ids():
		var s = Game.SKILLS[id]
		var r = Skills.rank(p, id)
		var cap = Skills.rank_cap(p, id)
		var locked = s["cls"] == "tome" and not p.tomes.has(id)
		var b = Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.position = _node_pos(id)
		b.size = Vector2(NODE, NODE)
		var learnable = Skills.can_learn(p, id)
		var border = Color(0.4, 0.4, 0.5)
		if r > 0:
			border = Game.ELEM_COLOR.get(s["elem"], Color(0.9, 0.9, 0.9))
		if learnable:
			border = Color(0.4, 1, 0.4)
		var bw = 2 if s["type"] == "active" else 3
		var bg = Color(0.1, 0.1, 0.15) if r == 0 else Color(0.14, 0.14, 0.2)
		b.add_theme_stylebox_override("normal", UI.style(bg, border, bw))
		b.add_theme_stylebox_override("hover", UI.style(Color(0.18, 0.18, 0.26), border, bw))
		b.add_theme_stylebox_override("pressed", UI.style(Color(0.25, 0.25, 0.3), border, bw))
		var ic = UI.icon(Game.skill_icon(id), NODE)
		ic.modulate = Color.WHITE if (r > 0 or learnable) else Color(0.5, 0.5, 0.55)
		if locked:
			ic.modulate = Color(0.25, 0.25, 0.3)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(ic)
		var rk = UI.lbl("%d/%d" % [r, cap if cap > 0 else s["max"]], 7, Color(1, 1, 0.6) if r > 0 else Color(0.7, 0.7, 0.7))
		rk.position = Vector2(2, 27)
		rk.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(rk)
		if s["type"] == "active":
			var ki2 = p.loadout.find(id)
			if ki2 >= 0:
				var badge = ColorRect.new()
				badge.color = Color(0.15, 0.45, 0.2)
				badge.position = Vector2(NODE - 12, 0)
				badge.size = Vector2(12, 11)
				badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
				b.add_child(badge)
				var kl = UI.lbl(Game.key_label("skill_%d" % ki2).left(2), 7, Color.WHITE)
				kl.position = Vector2(NODE - 11, -1)
				kl.mouse_filter = Control.MOUSE_FILTER_IGNORE
				b.add_child(kl)
		b.pressed.connect(_learn.bind(id))
		b.gui_input.connect(_node_input.bind(id))
		b.set_drag_forwarding(_node_drag.bind(id, b), func(_a, _d): return false, func(_a, _d): pass)
		b.mouse_entered.connect(func(): hud.tip_show(_tip(id)))
		b.mouse_exited.connect(hud.tip_hide)
		area.add_child(b)
		var nm = UI.lbl(s["name"], 7, Color(1, 1, 1, 0.92))
		nm.position = _node_pos(id) + Vector2(-25, NODE + 1)
		nm.custom_minimum_size = Vector2(NODE + 50, 0)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		area.add_child(nm)
		if tab != "tome":
			var lv = UI.lbl("Lv %d" % s["lvl"], 6, Color(0.55, 0.9, 0.55) if p.level >= s["lvl"] else Color(1, 0.5, 0.5))
			lv.position = _node_pos(id) + Vector2(-25, NODE + 9)
			lv.custom_minimum_size = Vector2(NODE + 50, 0)
			lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lv.mouse_filter = Control.MOUSE_FILTER_IGNORE
			area.add_child(lv)
	lines_ctl.queue_redraw()


func _node_input(ev, id):
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT:
		var p = hud.player
		if Skills.equip_skill(p, id, sel_slot):
			Game.notify("%s equipped (%s)" % [Game.SKILLS[id]["name"], Game.key_label("skill_%d" % sel_slot)])
			sel_slot = (sel_slot + 1) % 4
		else:
			Game.notify("Learn an active skill first")
		refresh()


func _learn(id):
	var p = hud.player
	if Skills.learn(p, id):
		Game.float_text("%s Lv %d" % [Game.SKILLS[id]["name"], Skills.rank(p, id)], p.global_position, Color(1, 0.9, 0.4))
	else:
		Game.notify(Skills.why_not(p, id))
	refresh()
	hud.tip_show(_tip(id))
