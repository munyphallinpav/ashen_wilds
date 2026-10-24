extends Panel
## Trader window: buy stock (and rolled gear from the smith), sell from the bag.

var hud
var npc_id = ""
var data = {}
var title
var gold_lbl
var buy_box
var sell_box
var gear_stock = []


func setup(h):
	hud = h
	title = UI.lbl("", 11, Color(1, 0.9, 0.4))
	title.position = Vector2(8, 4)
	add_child(title)
	gold_lbl = UI.lbl("", 9, Color(1, 0.85, 0.2))
	gold_lbl.position = Vector2(250, 6)
	add_child(gold_lbl)
	var bl = UI.lbl("BUY", 9, Color(0.6, 1, 0.6))
	bl.position = Vector2(8, 22)
	add_child(bl)
	var sl = UI.lbl("SELL", 9, Color(1, 0.7, 0.5))
	sl.position = Vector2(232, 22)
	add_child(sl)
	var sc1 = ScrollContainer.new()
	sc1.position = Vector2(8, 36)
	sc1.size = Vector2(216, 196)
	add_child(sc1)
	buy_box = VBoxContainer.new()
	buy_box.add_theme_constant_override("separation", 2)
	sc1.add_child(buy_box)
	var sc2 = ScrollContainer.new()
	sc2.position = Vector2(232, 36)
	sc2.size = Vector2(216, 196)
	add_child(sc2)
	sell_box = VBoxContainer.new()
	sell_box.add_theme_constant_override("separation", 2)
	sc2.add_child(sell_box)
	var hint = UI.lbl("T / Esc to leave", 8, Color(1, 1, 1, 0.7))
	hint.position = Vector2(8, 234)
	add_child(hint)


func open(id):
	npc_id = id
	data = Game.NPCS[id]
	title.text = data["name"]
	gear_stock = []
	var mode = data.get("gear", "none")
	if mode != "none":
		var st = Game.shop_stock.get(id)
		if st == null or Game.play_time - st["t"] > 600.0 or st["lvl"] != hud.player.level / 5:
			st = {"t": Game.play_time, "lvl": hud.player.level / 5, "items": []}
			var lvl = maxi(1, hud.player.level)
			var subs = []
			subs.append_array(Game.WEAPONS.keys())
			subs.append_array(Game.ARMORS.keys())
			subs.append_array(Game.ACCS.keys())
			if mode == "random":
				for i in range(10):
					var rar = mini(Items.roll_rarity(0.0, 0.0), 3)
					st["items"].append(Items.roll_gear(subs[randi() % subs.size()], lvl + randi_range(0, 3), rar))
			else:
				for i in range(5):
					var rar = [2, 3, 3, 4, 4, 5][randi() % 6]
					st["items"].append(Items.roll_gear(subs[randi() % subs.size()], lvl + randi_range(2, 8), rar))
			Game.shop_stock[id] = st
		gear_stock = st["items"]
	refresh()


func _buy_price(it):
	if Items.is_gear(it):
		return int(Items.value(it) * (5.0 if data.get("gear", "") == "limited" else 3.0))
	return int(Items.value(it) * 2.2) + 1


func _row(it, text, w, cb, enabled = true):
	var b = UI.btn(text, w, 24, 8)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.icon = Items.icon(it)
	b.expand_icon = true
	b.add_theme_constant_override("icon_max_width", 18)
	b.disabled = not enabled
	if Items.is_gear(it):
		b.add_theme_color_override("font_color", Items.color_of(it))
		b.add_theme_color_override("font_hover_color", Items.color_of(it).lightened(0.3))
		b.add_theme_color_override("font_disabled_color", Items.color_of(it).darkened(0.4))
	b.mouse_entered.connect(func(): hud.item_tip(it))
	b.mouse_exited.connect(hud.tip_hide)
	b.pressed.connect(cb)
	return b


func refresh():
	var p = hud.player
	if p == null or data.is_empty():
		return
	gold_lbl.text = "Your gold: %d     Bag %d/%d" % [p.gold, p.bag_size - p.free_slots(), p.bag_size]
	UI.clear(buy_box)
	UI.clear(sell_box)
	for id in data.get("stock", []):
		var it = Items.make(id, 1)
		var price = _buy_price(it)
		buy_box.add_child(_row(it, "%s  -%dg" % [Items.name_of(it), price], 212, _buy.bind(id, price), p.gold >= price))
	for i in range(gear_stock.size()):
		var g = gear_stock[i]
		if g == null:
			continue
		var price = _buy_price(g)
		buy_box.add_child(_row(g, "%s  -%dg" % [Items.name_of(g), price], 212, _buy_gear.bind(i, price), p.gold >= price))
	var any = false
	for i in range(p.inv.size()):
		var it = p.inv[i]
		if it == null:
			continue
		var cat = Items.cat_of(it)
		if cat == "gear":
			if data.get("gear", "none") == "none":
				continue
		elif not data.get("buys", []).has(cat):
			continue
		any = true
		var each = maxi(1, int(Items.value(it) * data["rate"]))
		if Items.is_gear(it):
			sell_box.add_child(_row(it, "%s  +%dg" % [Items.name_of(it), each], 212, _sell.bind(i, 1, each)))
		else:
			var row = HBoxContainer.new()
			row.add_theme_constant_override("separation", 2)
			row.add_child(_row(it, "%s x%d  +%dg" % [Items.name_of(it), it["n"], each], 176, _sell.bind(i, 1, each)))
			var ba = UI.btn("All", 34, 24, 8)
			ba.pressed.connect(_sell.bind(i, it["n"], each))
			row.add_child(ba)
			sell_box.add_child(row)
	if not any:
		sell_box.add_child(UI.lbl("Nothing this trader wants.", 8, Color(1, 1, 1, 0.6)))


func _buy(id, price):
	var p = hud.player
	var it = Items.make(id, 1)
	if p.gold < price:
		Game.notify("Not enough gold")
		return
	if not p.can_hold(it):
		Game.notify("Bag is full!")
		return
	p.gold -= price
	Audio.sfx("buy", 0.8)
	p.add_item(it)


func _buy_gear(i, price):
	var p = hud.player
	var g = gear_stock[i]
	if p.gold < price:
		Game.notify("Not enough gold")
		return
	if not p.can_hold(g):
		Game.notify("Bag is full!")
		return
	p.gold -= price
	p.add_item(g)
	gear_stock[i] = null


func _sell(i, n, each):
	var p = hud.player
	var it = p.inv[i]
	if it == null:
		return
	n = mini(n, it["n"])
	it["n"] -= n
	if it["n"] <= 0:
		p.inv[i] = null
	p.add_gold(n * each)
	p.inventory_changed.emit()
