extends Panel
## Crafting window: gear and consumable recipes; fire recipes need a campfire nearby.

var hud
var list_box
var filter = "all"
var fbtns = {}
var fire_lbl
var smith_mode = false
var sel_enchant = null
var msg_lbl


func setup(h):
	hud = h
	var t = UI.lbl("CRAFTING  (B to close)", 10, Color(1, 0.9, 0.5))
	t.position = Vector2(8, 4)
	add_child(t)
	var x = 8
	for f in [["all", "All"], ["gear", "Gear"], ["use", "Potions / Food"], ["mat", "Materials"]]:
		var b = UI.btn(f[1], 80 if f[0] == "use" else 56, 16, 8)
		b.position = Vector2(x, 22)
		b.pressed.connect(func():
			filter = f[0]
			refresh())
		add_child(b)
		fbtns[f[0]] = b
		x += b.custom_minimum_size.x + 2
	fire_lbl = UI.lbl("", 8)
	fire_lbl.position = Vector2(290, 24) if not smith_mode else Vector2(350, 24)
	add_child(fire_lbl)
	var sc = ScrollContainer.new()
	sc.position = Vector2(8, 42)
	sc.size = Vector2(440, 186)
	add_child(sc)
	msg_lbl = UI.lbl("", 8, Color(1, 0.95, 0.6))
	msg_lbl.position = Vector2(8, 232)
	add_child(msg_lbl)
	list_box = GridContainer.new()
	list_box.columns = 2
	list_box.add_theme_constant_override("h_separation", 4)
	list_box.add_theme_constant_override("v_separation", 3)
	sc.add_child(list_box)


func _kind(r):
	if r.has("gear"):
		return "gear"
	var d = Game.ITEMS[r["out"]]
	if d["cat"] in ["cons", "food"]:
		return "use"
	return "mat"


func refresh():
	var p = hud.player
	if p == null:
		return
	for f in fbtns:
		fbtns[f].self_modulate = Color(1, 0.9, 0.4) if f == filter else Color.WHITE
	var near = Game.near_fire(p.global_position) or smith_mode
	if filter != "enchant":
		msg_lbl.text = ""
	fire_lbl.text = ("Forge lit" if smith_mode else "Campfire nearby: YES") if near else "Campfire nearby: no"
	fire_lbl.add_theme_color_override("font_color", Color(0.5, 1, 0.5) if near else Color(1, 0.6, 0.5))
	UI.clear(list_box)
	list_box.columns = 2
	if filter == "enchant":
		_refresh_enchant(p)
		return
	for r in Game.RECIPES:
		if filter != "all" and _kind(r) != filter:
			continue
		var can = p.can_afford(r["needs"]) and (not r.get("fire", false) or near)
		var b = Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(212, 36)
		b.clip_contents = true
		if can:
			b.add_theme_stylebox_override("normal", UI.style(Color(0.1, 0.18, 0.12), Color(0.4, 0.9, 0.4), 1))
		else:
			b.modulate = Color(0.75, 0.75, 0.8)
		var ic_tex
		if r.has("gear"):
			ic_tex = Game.tex("res://assets/items/gear_%s.png" % r["gear"])
		else:
			ic_tex = Game.tex("res://assets/items/%s.png" % r["out"])
		b.add_child(UI.icon(ic_tex, 32))
		var nm = UI.lbl(r["name"] + (" (fire)" if r.get("fire", false) else ""), 8, Color(1, 0.95, 0.7))
		nm.position = Vector2(36, 1)
		b.add_child(nm)
		var need_lbl = RichTextLabel.new()
		need_lbl.bbcode_enabled = true
		need_lbl.position = Vector2(36, 12)
		need_lbl.size = Vector2(172, 24)
		need_lbl.scroll_active = false
		need_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		need_lbl.add_theme_font_size_override("normal_font_size", 7)
		var t = ""
		for k in r["needs"]:
			var have = p.count(k)
			var need = r["needs"][k]
			var col = "#9fe89f" if have >= need else "#ff8a7a"
			t += "[color=%s]%d/%d %s[/color]   " % [col, have, need, Game.ITEMS[k]["name"]]
		need_lbl.text = t
		b.add_child(need_lbl)
		if r.has("gear"):
			b.mouse_entered.connect(hud.tip_show.bind([["Random rarity", Color(0.8, 0.9, 1)], ["Stats scale with your level", Color(0.8, 0.9, 1)], ["Higher LUCK = better odds", Color(0.8, 0.9, 1)]]))
			b.mouse_exited.connect(hud.tip_hide)
		b.pressed.connect(func():
			p.craft(r)
			refresh())
		list_box.add_child(b)


func _refresh_enchant(p):
	var entries = []
	for sl in p.equip:
		if p.equip[sl] != null:
			entries.append([p.equip[sl], "E"])
	for it in p.inv:
		if it != null and Items.is_gear(it):
			entries.append([it, ""])
	list_box.columns = 1
	var have = p.count("iron_ingot")
	if msg_lbl.text == "":
		msg_lbl.text = "Enchanting needs Iron Ingots (you have %d). Smelt them under Materials: Iron Ore + Coal." % have
	if entries.size() == 0:
		list_box.add_child(UI.lbl("You have no gear to enchant.", 8, Color(1, 1, 1, 0.6)))
	for e in entries:
		var it = e[0]
		var row = Panel.new()
		row.custom_minimum_size = Vector2(430, 34)
		row.add_theme_stylebox_override("panel", UI.style(Color(0.09, 0.09, 0.13), Items.color_of(it), 1))
		row.add_child(UI.icon(Items.icon(it), 32))
		var nm = UI.lbl("%s%s" % [Items.name_of(it), "  [equipped]" if e[1] == "E" else ""], 8, Items.color_of(it))
		nm.position = Vector2(36, 1)
		row.add_child(nm)
		var ec = p.enchant_cost(it)
		var info = UI.lbl("Next +%d: %dg + %d Iron Ingot  (%d%% success)" % [int(it.get("ench", 0)) + 1, ec["gold"], ec["ingots"], int(p.enchant_chance(it) * 100)], 7, Color(0.8, 0.9, 1))
		info.position = Vector2(36, 13)
		row.add_child(info)
		var rc = p.reroll_cost(it)
		var info2 = UI.lbl("Re-roll affixes: %dg + %d Iron Ingot" % [rc["gold"], rc["ingots"]], 7, Color(1, 0.85, 0.5))
		info2.position = Vector2(36, 23)
		row.add_child(info2)
		var can_e = int(it.get("ench", 0)) < 10 and p.gold >= ec["gold"] and have >= ec["ingots"]
		var can_r = it["u"] == "" and it["aff"].size() > 0 and p.gold >= rc["gold"] and have >= rc["ingots"]
		if int(it.get("ench", 0)) >= 10:
			info.text = "Max enchant (+10)"
		elif not can_e:
			info.add_theme_color_override("font_color", Color(1, 0.55, 0.5))
		if it["aff"].size() == 0:
			info2.text = "Re-roll: item has no affixes (Uncommon+ only)"
		elif it["u"] != "":
			info2.text = "Re-roll: unique items cannot be re-rolled"
		elif not can_r:
			info2.add_theme_color_override("font_color", Color(1, 0.55, 0.5))
		var b = UI.btn("Enchant", 56, 16, 7)
		b.position = Vector2(300, 2)
		b.disabled = not can_e
		b.add_theme_stylebox_override("normal", UI.style(Color(0.15, 0.3, 0.18), Color(0.4, 0.9, 0.4), 1))
		b.add_theme_stylebox_override("disabled", UI.style(Color(0.1, 0.1, 0.12), Color(0.3, 0.3, 0.3), 1))
		b.pressed.connect(func():
			var before = int(it.get("ench", 0))
			p.enchant(it)
			if int(it.get("ench", 0)) > before:
				msg_lbl.text = "SUCCESS! %s" % Items.name_of(it)
			else:
				msg_lbl.text = "Enchant failed - materials lost."
			refresh())
		row.add_child(b)
		var b2 = UI.btn("Re-roll", 56, 16, 7)
		b2.position = Vector2(300, 18)
		b2.disabled = not can_r
		b2.add_theme_stylebox_override("normal", UI.style(Color(0.3, 0.22, 0.1), Color(0.95, 0.7, 0.3), 1))
		b2.add_theme_stylebox_override("disabled", UI.style(Color(0.1, 0.1, 0.12), Color(0.3, 0.3, 0.3), 1))
		b2.pressed.connect(func():
			p.reroll(it)
			msg_lbl.text = "Affixes re-rolled: %s" % Items.name_of(it)
			refresh())
		row.add_child(b2)
		row.mouse_entered.connect(func(): hud.item_tip(it))
		row.mouse_exited.connect(hud.tip_hide)
		list_box.add_child(row)
