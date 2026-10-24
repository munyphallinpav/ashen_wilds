extends Panel
## Inventory + equipment window: filter, sort, stack-merge, split, discard, equip with comparison.

var hud
var player
var sel = -1            # selected bag index, or -(1+slot_index) for equipment
var sel_equip = ""      # equipment slot name when an equipped item is selected
var filter = "all"
var grid
var info_lbl
var det_name
var det_text
var eq_row
var btns = {}
var dlg
var dlg_slider
var dlg_lbl
var dlg_mode = "split"
var filter_btns = {}
var expand_btn


func setup(h):
	hud = h
	var t = UI.lbl("INVENTORY  (I to close)", 10, Color(1, 0.9, 0.5))
	t.position = Vector2(8, 4)
	add_child(t)
	var fx = 8
	for f in [["all", "All"], ["gear", "Gear"], ["use", "Use"], ["mat", "Loot"]]:
		var b = UI.btn(f[1], 52, 16, 8)
		b.position = Vector2(fx, 22)
		b.pressed.connect(_set_filter.bind(f[0]))
		add_child(b)
		filter_btns[f[0]] = b
		fx += 54
	var sb = UI.btn("Sort", 44, 16, 8)
	sb.position = Vector2(8, 232)
	sb.pressed.connect(func(): hud.player.sort_inv())
	add_child(sb)
	var mb = UI.btn("Stack", 44, 16, 8)
	mb.position = Vector2(54, 232)
	mb.pressed.connect(func(): hud.player.merge_stacks())
	add_child(mb)
	info_lbl = UI.lbl("", 8, Color(1, 0.85, 0.3))
	info_lbl.position = Vector2(150, 5)
	add_child(info_lbl)
	var gs = ScrollContainer.new()
	gs.position = Vector2(8, 42)
	gs.size = Vector2(250, 186)
	gs.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(gs)
	grid = GridContainer.new()
	grid.columns = 8
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 2)
	gs.add_child(grid)
	expand_btn = UI.btn("Expand bag", 62, 16, 7)
	expand_btn.position = Vector2(104, 232)
	expand_btn.pressed.connect(func():
		hud.player.upgrade_bag()
		refresh())
	add_child(expand_btn)
	var eh = UI.lbl("Equipped", 8, Color(0.8, 0.9, 1))
	eh.position = Vector2(262, 22)
	add_child(eh)
	eq_row = Control.new()
	eq_row.position = Vector2(262, 34)
	add_child(eq_row)
	det_name = UI.lbl("", 10, Color(1, 0.9, 0.4))
	det_name.position = Vector2(262, 76)
	add_child(det_name)
	det_text = RichTextLabel.new()
	det_text.bbcode_enabled = true
	det_text.position = Vector2(262, 90)
	det_text.size = Vector2(190, 118)
	det_text.add_theme_font_size_override("normal_font_size", 8)
	det_text.add_theme_font_size_override("bold_font_size", 8)
	det_text.scroll_active = false
	det_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(det_text)
	var hb = HBoxContainer.new()
	hb.position = Vector2(262, 214)
	hb.add_theme_constant_override("separation", 3)
	add_child(hb)
	for k in [["use", "Use"], ["split", "Split"], ["discard", "Discard"]]:
		var b = UI.btn(k[1], 58, 22, 8)
		b.pressed.connect(_act.bind(k[0]))
		hb.add_child(b)
		btns[k[0]] = b
	_build_dialog()


func _build_dialog():
	dlg = Panel.new()
	dlg.position = Vector2(110, 90)
	dlg.size = Vector2(220, 64)
	dlg.visible = false
	dlg.z_index = 50
	add_child(dlg)
	dlg_lbl = UI.lbl("", 9)
	dlg_lbl.position = Vector2(8, 4)
	dlg.add_child(dlg_lbl)
	dlg_slider = HSlider.new()
	dlg_slider.position = Vector2(8, 22)
	dlg_slider.size = Vector2(204, 14)
	dlg_slider.step = 1
	dlg_slider.value_changed.connect(func(_v): _dlg_update())
	dlg.add_child(dlg_slider)
	var ok = UI.btn("OK", 60, 18, 8)
	ok.position = Vector2(44, 42)
	ok.pressed.connect(_dlg_ok)
	dlg.add_child(ok)
	var cn = UI.btn("Cancel", 60, 18, 8)
	cn.position = Vector2(116, 42)
	cn.pressed.connect(func(): dlg.visible = false)
	dlg.add_child(cn)


func _dlg_update():
	dlg_lbl.text = "%s %d" % ["Split off" if dlg_mode == "split" else "Discard", int(dlg_slider.value)]


func _set_filter(f):
	filter = f
	refresh()


func _passes(it):
	if it == null:
		return false
	var c = Items.cat_of(it)
	match filter:
		"gear":
			return c == "gear"
		"use":
			return c == "cons" or c == "food" or c == "place" or c == "book"
		"mat":
			return c == "mat"
	return true


func _sel_item() -> Variant:
	if sel_equip != "":
		return hud.player.equip[sel_equip]
	if sel >= 0 and sel < hud.player.inv.size():
		return hud.player.inv[sel]
	return null


func _item_button(it, i, is_eq, slot_name):
	var b = Button.new()
	b.custom_minimum_size = Vector2(28, 28)
	b.focus_mode = Control.FOCUS_NONE
	b.clip_contents = true
	if it != null:
		b.add_child(UI.icon(Items.icon(it), 28))
		if Items.is_gear(it):
			b.add_theme_stylebox_override("normal", UI.style(Color(0.1, 0.1, 0.14), Items.color_of(it), 2))
			b.add_theme_stylebox_override("hover", UI.style(Color(0.16, 0.16, 0.22), Items.color_of(it), 2))
			b.add_theme_stylebox_override("pressed", UI.style(Color(0.2, 0.2, 0.26), Items.color_of(it), 2))
		elif it["n"] > 1:
			var cl = UI.lbl(str(it["n"]), 7, Color(1, 1, 0.7))
			cl.position = Vector2(12, 16)
			b.add_child(cl)
		b.mouse_entered.connect(func(): hud.item_tip(it) if not is_eq else hud.tip_show(Items.lines(it, hud.player.char_id)))
		b.mouse_exited.connect(hud.tip_hide)
	elif is_eq:
		var nm = UI.lbl(slot_name.substr(0, 3).to_upper() + (slot_name.substr(slot_name.length() - 1) if slot_name.ends_with("1") or slot_name.ends_with("2") else ""), 6, Color(1, 1, 1, 0.35))
		nm.position = Vector2(4, 9)
		b.add_child(nm)
	var chosen = (is_eq and sel_equip == slot_name) or (not is_eq and sel_equip == "" and sel == i)
	if chosen:
		b.self_modulate = Color(1, 0.9, 0.4)
	if is_eq:
		b.pressed.connect(_select_equip.bind(slot_name))
	else:
		b.pressed.connect(_select.bind(i))
	return b


func _select(i):
	sel = i
	sel_equip = ""
	dlg.visible = false
	refresh()


func _select_equip(slot_name):
	sel_equip = slot_name
	sel = -1
	dlg.visible = false
	refresh()


func refresh():
	var p = hud.player
	if p == null:
		return
	for f in filter_btns:
		filter_btns[f].self_modulate = Color(1, 0.9, 0.4) if f == filter else Color.WHITE
	UI.clear(grid)
	UI.clear(eq_row)
	var shown = 0
	for i in range(p.inv.size()):
		var it = p.inv[i]
		if filter != "all" and not _passes(it):
			# keep grid shape: show dimmed empty slot
			var d = _item_button(null, i, false, "")
			d.disabled = true
			d.modulate = Color(1, 1, 1, 0.35)
			grid.add_child(d)
			continue
		grid.add_child(_item_button(it, i, false, ""))
		shown += 1
	var x = 0
	for s in Game.EQUIP_SLOTS:
		var b = _item_button(p.equip[s], -1, true, s)
		b.custom_minimum_size = Vector2(26, 26)
		b.size = Vector2(26, 26)
		b.position = Vector2(x, 0)
		eq_row.add_child(b)
		x += 27
	info_lbl.text = "Bag %d/%d  Gold %d" % [p.bag_size - p.free_slots(), p.bag_size, p.gold]
	var uc = p.bag_upgrade_cost()
	expand_btn.text = "MAX bag" if uc < 0 else "+%d slots %dg" % [Game.BAG_STEP, uc]
	expand_btn.disabled = uc < 0
	expand_btn.self_modulate = Color(0.6, 1, 0.6) if uc >= 0 and p.gold >= uc else Color.WHITE
	expand_btn.custom_minimum_size.x = 76
	expand_btn.size.x = 76
	expand_btn.position.x = 104
	_refresh_details()


func _stat_totals(it):
	return Items.totals(it)


func _refresh_details():
	var p = hud.player
	var it = _sel_item()
	for b in btns.values():
		b.disabled = true
	if it == null:
		det_name.text = ""
		det_text.text = "Select an item.\n\nEquipment can be swapped from your bag. Stackable items can be split; anything can be discarded."
		return
	det_name.text = Items.name_of(it)
	det_name.add_theme_color_override("font_color", Items.color_of(it))
	var txt = ""
	var lines = Items.lines(it, p.char_id)
	for i in range(1, lines.size()):
		var c = lines[i][1]
		txt += "[color=#%s]%s[/color]\n" % [c.to_html(false), lines[i][0]]
	# comparison with the equipped piece
	if Items.is_gear(it) and sel_equip == "":
		var cur = p.equip[p.equip_slot_for(it)]
		var a = _stat_totals(it)
		var b = _stat_totals(cur)
		var keys = {}
		for k in a:
			keys[k] = true
		for k in b:
			keys[k] = true
		txt += "\n[color=#aaaaaa]vs equipped:[/color]\n"
		if cur == null:
			txt += "[color=#88ff88](empty slot)[/color]\n"
		for k in keys:
			var dv = a.get(k, 0.0) - b.get(k, 0.0)
			if absf(dv) < 0.05:
				continue
			var col = "#88ff88" if dv > 0 else "#ff7777"
			txt += "[color=%s]%s%s %s[/color]\n" % [col, "+" if dv > 0 else "-", Items.stat_text(k, absf(dv)).substr(1), ""]
	det_text.text = txt
	if sel_equip != "":
		btns["use"].text = "Unequip"
		btns["use"].disabled = false
		btns["discard"].disabled = true
		btns["split"].disabled = true
	else:
		var c = Items.cat_of(it)
		btns["use"].text = "Equip" if c == "gear" else ("Learn" if c == "book" else "Place" if c == "place" else ("Eat" if c == "food" else ("Drink" if c == "cons" else "Use")))
		btns["use"].disabled = c == "mat"
		btns["discard"].disabled = false
		btns["split"].disabled = Items.is_gear(it) or it["n"] < 2


func _act(what):
	var p = hud.player
	var it = _sel_item()
	if it == null:
		return
	if what == "use":
		if sel_equip != "":
			p.unequip(sel_equip)
			sel_equip = ""
		else:
			var was_gear = Items.is_gear(it)
			p.use_slot(sel)
			if was_gear:
				sel = -1
	elif what == "split":
		dlg_mode = "split"
		dlg_slider.min_value = 1
		dlg_slider.max_value = it["n"] - 1
		dlg_slider.value = maxi(1, int(it["n"] / 2))
		_dlg_update()
		dlg.visible = true
		return
	elif what == "discard":
		if it["n"] > 1:
			dlg_mode = "discard"
			dlg_slider.min_value = 1
			dlg_slider.max_value = it["n"]
			dlg_slider.value = it["n"]
			_dlg_update()
			dlg.visible = true
			return
		p.discard(sel, 1)
		sel = -1
	refresh()


func _dlg_ok():
	var p = hud.player
	var n = int(dlg_slider.value)
	if dlg_mode == "split":
		p.split_stack(sel, n)
	else:
		p.discard(sel, n)
		if p.inv[sel] == null:
			sel = -1
	dlg.visible = false
	refresh()
