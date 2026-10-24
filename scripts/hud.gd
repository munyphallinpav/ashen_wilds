extends CanvasLayer
## All UI is built in code: HUD, skill bar, windows (inventory / character / skills / crafting / shop / map), menus, save slots.
## `open_panel` names the open screen ("" = none). While any screen is open the game is paused.

const MapViewScript = preload("res://scripts/map_view.gd")
const WinInventory = preload("res://scripts/win_inventory.gd")
const WinCharacter = preload("res://scripts/win_character.gd")
const WinSkills = preload("res://scripts/win_skills.gd")
const WinCraft = preload("res://scripts/win_craft.gd")
const WinShop = preload("res://scripts/win_shop.gd")
const WinGuild = preload("res://scripts/win_guild.gd")
const WinSmith = preload("res://scripts/win_smith.gd")

signal character_chosen(id)

var player = null
var open_panel = "title"
var panels = {}
var wins = {}

var hp_bar
var mp_bar
var xp_bar
var hunger_bar
var lvl_label
var time_label
var run_label
const FancyBar = preload("res://scripts/fancy_bar.gd")
var gold_label
var buff_label
var quest_label
var points_label
var msg_box
var help_label
var death_label
var skill_ov = {}
var skill_key_lbl = {}
var quick_key_lbl = {}
var dash_key_lbl
var listening = ""
var controls_from = "pause"
var ctrl_btns = {}
var dash_ov
var skill_icon = {}
var skill_rank = {}
var quick_cnt = {}
var quick_icon = {}
var boss_box
var boss_name_lbl
var boss_bar

var tp_town_btn
var tp_dun_btn
var map_full
var minimap
var mini_btn
var mini_state = 1   # 0 hidden, 1 small, 2 large
var map_info
var dungeon_info
var ore_btn
var slots_panel
var slots_title
var slots_box
var slot_mode = "load"
var new_class_id = ""
var new_class_name = ""
var slot_from = "title"

var tip_panel
var tip_box
var tip2_panel
var tip2_box
var tip_scroll = 0.0
var tip_max = [0.0, 0.0]
var tip_hint
const TIP_MAX_H = 262.0
var fade_rect


func _build_vignette():
	var gt = GradientTexture2D.new()
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 1.0)
	gt.width = 256
	gt.height = 256
	var gr = Gradient.new()
	gr.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	gr.colors = PackedColorArray([Color(0.02, 0.05, 0.08, 0.0), Color(0.02, 0.05, 0.08, 0.0), Color(0.02, 0.05, 0.08, 0.42)])
	gt.gradient = gr
	var v = TextureRect.new()
	v.texture = gt
	v.position = Vector2.ZERO
	v.size = Vector2(480, 270)
	v.stretch_mode = TextureRect.STRETCH_SCALE
	v.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(v)


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	_build_vignette()
	_build_status()
	_build_bars()
	_build_misc()
	var wsize = Vector2(456, 250)
	var wpos = Vector2(12, 10)
	wins["inv"] = _make_window("inv", WinInventory, wpos, wsize)
	wins["char"] = _make_window("char", WinCharacter, wpos, wsize)
	wins["skills"] = _make_window("skills", WinSkills, wpos, wsize)
	wins["craft"] = _make_window("craft", WinCraft, wpos, wsize)
	wins["shop"] = _make_window("shop", WinShop, wpos, wsize)
	wins["guild"] = _make_window("guild", WinGuild, wpos, wsize)
	wins["smith"] = _make_window("smith", WinSmith, wpos, wsize)
	slots_panel = UI.panel(Vector2(60, 30), Vector2(360, 214))
	slots_panel.add_theme_stylebox_override("panel", UI.style(Color(0.07, 0.08, 0.12, 1.0), Color(0.6, 0.5, 0.3), 2))
	add_child(slots_panel)
	panels["load"] = slots_panel
	panels["save"] = slots_panel
	panels["new"] = slots_panel
	_build_slots()
	_build_map()
	_build_pause()
	_build_select()
	_build_title()
	_build_controls()
	_build_tip()
	Game.binds_changed.connect(refresh_keys)
	refresh_keys()
	set_panel("title")


func _make_window(name, script, pos, sz):
	var p = Panel.new()
	p.set_script(script)
	p.position = pos
	p.size = sz
	p.visible = false
	p.add_theme_stylebox_override("panel", UI.style(Color(0.07, 0.08, 0.12, 1.0), Color(0.6, 0.5, 0.3), 2))
	add_child(p)
	p.setup(self)
	panels[name] = p
	return p


# ------------------------------------------------------------ tooltip
func _build_tip():
	tip_panel = Panel.new()
	tip_panel.visible = false
	tip_panel.z_index = 100
	tip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip_panel.add_theme_stylebox_override("panel", UI.style(Color(0.04, 0.04, 0.08, 0.96), Color(0.8, 0.7, 0.4), 1))
	add_child(tip_panel)
	tip_box = VBoxContainer.new()
	tip_box.position = Vector2(5, 3)
	tip_box.add_theme_constant_override("separation", 0)
	tip_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip_panel.add_child(tip_box)
	tip2_panel = Panel.new()
	tip2_panel.visible = false
	tip2_panel.z_index = 100
	tip2_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip2_panel.add_theme_stylebox_override("panel", UI.style(Color(0.05, 0.06, 0.1, 0.96), Color(0.5, 0.6, 0.8), 1))
	add_child(tip2_panel)
	tip2_box = VBoxContainer.new()
	tip2_box.position = Vector2(5, 3)
	tip2_box.add_theme_constant_override("separation", 0)
	tip2_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip2_panel.add_child(tip2_box)
	tip_panel.clip_contents = true
	tip2_panel.clip_contents = true
	tip_hint = UI.lbl("Mouse wheel: scroll", 6, Color(1, 1, 0.6))
	tip_hint.z_index = 101
	tip_hint.visible = false
	tip_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tip_hint)


## Gear tooltip with a comparison against the worn item (second panel shows what is equipped).
func item_tip(it):
	var p = player
	if p == null or not Items.is_gear(it):
		tip_show(Items.lines(it, p.char_id if p != null else ""))
		return
	var other = Items.compare_target(it, p)
	if other != null and (is_same(other, it) or other == it):
		tip_show(Items.lines(it, p.char_id))
		return
	tip_show(Items.compare_lines(it, other, p.char_id), Items.lines(other, p.char_id) if other != null else null)


func tip_show(lines, extra = null):
	UI.clear(tip_box)
	var w = 90.0
	for l in lines:
		var lb = UI.lbl(l[0], 8, l[1])
		lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lb.custom_minimum_size = Vector2(150, 0)
		tip_box.add_child(lb)
	tip_panel.size = Vector2(160, 20 + lines.size() * 10)
	tip_box.size = Vector2(150, 10)
	tip_panel.visible = true
	tip2_panel.visible = false
	tip_scroll = 0.0
	tip_box.position.y = 3.0
	tip2_box.position.y = 3.0
	if extra != null:
		UI.clear(tip2_box)
		var hd = UI.lbl("Currently equipped", 7, Color(0.6, 0.75, 1.0))
		tip2_box.add_child(hd)
		for l in extra:
			var lb2 = UI.lbl(l[0], 8, l[1])
			lb2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			lb2.custom_minimum_size = Vector2(150, 0)
			tip2_box.add_child(lb2)
		tip2_panel.size = Vector2(160, 20 + extra.size() * 10)
		tip2_panel.visible = true
	_place_tip()
	# resize to fit after layout (next frame)
	get_tree().process_frame.connect(_fit_tip, CONNECT_ONE_SHOT)


func _fit_tip():
	if tip_panel.visible:
		var h1 = tip_box.get_combined_minimum_size().y + 8
		tip_panel.size = Vector2(160, minf(h1, TIP_MAX_H))
		tip_max = [maxf(0.0, h1 - TIP_MAX_H), 0.0]
		if tip2_panel.visible:
			var h2 = tip2_box.get_combined_minimum_size().y + 8
			tip2_panel.size = Vector2(160, minf(h2, TIP_MAX_H))
			tip_max[1] = maxf(0.0, h2 - TIP_MAX_H)
		_place_tip()
		_apply_tip_scroll()


func _apply_tip_scroll():
	tip_box.position.y = 3.0 - minf(tip_scroll, tip_max[0])
	tip2_box.position.y = 3.0 - minf(tip_scroll, tip_max[1])
	var scrollable = tip_max[0] > 0.0 or tip_max[1] > 0.0
	tip_hint.visible = scrollable and tip_panel.visible
	if tip_hint.visible:
		tip_hint.position = Vector2(tip_panel.position.x + 4, tip_panel.position.y + tip_panel.size.y - 9)


func _place_tip():
	var m = get_viewport().get_mouse_position()
	var p = m + Vector2(12, 8)
	if p.x + tip_panel.size.x > 478:
		p.x = m.x - tip_panel.size.x - 8
	if p.y + tip_panel.size.y > 268:
		p.y = 268 - tip_panel.size.y
	p.y = maxf(2.0, p.y)
	tip_panel.position = p
	if tip2_panel.visible:
		var q = Vector2(p.x + tip_panel.size.x + 4, p.y)
		if q.x + tip2_panel.size.x > 478:
			q.x = p.x - tip2_panel.size.x - 4
		if q.x < 2:
			q.x = 2
			p.x = q.x + tip2_panel.size.x + 4
			tip_panel.position = p
		q.y = minf(q.y, 268 - tip2_panel.size.y)
		tip2_panel.position = q
	_apply_tip_scroll()


func tip_hide():
	if tip_panel != null:
		tip_panel.visible = false
		tip2_panel.visible = false


# ------------------------------------------------------------ panel switching / pause
func set_panel(panel_name):
	open_panel = panel_name
	tip_hide()
	for p in panels.values():
		p.visible = false
	if panels.has(panel_name):
		panels[panel_name].visible = true
	if panel_name == "map" and map_full != null and Game.dlayout == null:
		map_full.center_on_player(2.2)
	get_tree().paused = panel_name != "" and panel_name != "title" and panel_name != "select" and panel_name != "new"
	_apply_minimap()
	refresh_active()


func cycle_minimap():
	mini_state = (mini_state + 1) % 3
	_apply_minimap()


func _apply_minimap():
	if minimap == null:
		return
	var sz = [0.0, 70.0, 110.0][mini_state]
	minimap.size = Vector2(sz, sz)
	minimap.position = Vector2(474.0 - sz, 12.0)
	minimap.modulate = Color(1, 1, 1, 0.9)
	minimap.visible = mini_state > 0 and player != null and open_panel == ""
	mini_btn.visible = player != null and open_panel == ""
	mini_btn.self_modulate = Color(1, 1, 1, 0.8) if mini_state > 0 else Color(1, 1, 1, 0.45)


func ui_open():
	return open_panel != "" or (player != null and player.dead)


func show_title():
	set_panel("title")


func refresh_active():
	if player == null:
		return
	match open_panel:
		"inv":
			wins["inv"].refresh()
		"char":
			wins["char"].refresh()
		"skills":
			wins["skills"].refresh()
		"craft":
			wins["craft"].refresh()
		"shop":
			wins["shop"].refresh()
		"guild":
			wins["guild"].refresh()
		"smith":
			wins["smith"].refresh()


func open_npc(npc_id):
	var kind = Game.NPCS[npc_id]["kind"]
	if kind == "guild":
		set_panel("guild")
		wins["guild"].open()
	elif kind == "smith":
		set_panel("smith")
		wins["smith"].refresh()
	else:
		open_shop(npc_id)


func open_shop(npc_id):
	set_panel("shop")
	wins["shop"].open(npc_id)


# ------------------------------------------------------------ build: always-on HUD
func _build_status():
	var tl = VBoxContainer.new()
	tl.position = Vector2(6, 5)
	tl.add_theme_constant_override("separation", 2)
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tl)
	lvl_label = UI.lbl("Lv 1", 9)
	hp_bar = FancyBar.new()
	hp_bar.color = Color(0.86, 0.2, 0.22)
	hp_bar.font_size = 8
	hp_bar.custom_minimum_size = Vector2(130, 12)
	mp_bar = FancyBar.new()
	mp_bar.color = Color(0.25, 0.5, 0.98)
	mp_bar.trail_color = Color(0.6, 0.8, 1.0)
	mp_bar.custom_minimum_size = Vector2(130, 9)
	xp_bar = UI.bar(Color(0.9, 0.8, 0.25), 130, 3)
	hunger_bar = UI.bar(Color(0.9, 0.55, 0.2), 130, 3)
	for n in [lvl_label, hp_bar, mp_bar, xp_bar, hunger_bar]:
		tl.add_child(n)
	run_label = UI.lbl("", 8, Color(0.6, 1, 0.6))
	run_label.position = Vector2(6, 90)
	add_child(run_label)
	gold_label = UI.lbl("0g", 9, Color(1, 0.85, 0.3))
	gold_label.position = Vector2(6, 54)
	add_child(gold_label)
	time_label = UI.lbl("Day", 8)
	time_label.position = Vector2(6, 66)
	add_child(time_label)
	buff_label = UI.lbl("", 8, Color(0.7, 1, 0.8))
	buff_label.position = Vector2(6, 78)
	add_child(buff_label)
	quest_label = UI.lbl("", 7, Color(1, 0.9, 0.6))
	quest_label.position = Vector2(300, 82)
	quest_label.custom_minimum_size = Vector2(176, 0)
	quest_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(quest_label)
	points_label = UI.lbl("", 8, Color(0.5, 1, 0.5))
	points_label.position = Vector2(6, 196)
	add_child(points_label)


func _build_bars():
	# skill bar (Q E R F V) + quick-use (1-4)
	var dp = UI.slot_panel(28)
	dp.position = Vector2(76, 238)
	add_child(dp)
	dp.add_child(UI.icon(Game.tex("res://assets/items/elem_wind.png"), 28))
	dash_ov = ColorRect.new()
	dash_ov.color = Color(0, 0, 0, 0.65)
	dash_ov.position = Vector2(2, 2)
	dash_ov.size = Vector2(24, 0)
	dash_ov.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dp.add_child(dash_ov)
	dash_key_lbl = UI.lbl("Dash", 6)
	dash_key_lbl.position = Vector2(2, -2)
	dp.add_child(dash_key_lbl)
	var x = 112.0
	for i in range(4):
		var p = UI.slot_panel(28)
		p.position = Vector2(x, 238)
		add_child(p)
		var ic = UI.icon(Game.tex("res://assets/items/elem_none.png"), 28)
		p.add_child(ic)
		var ov = ColorRect.new()
		ov.color = Color(0, 0, 0, 0.65)
		ov.position = Vector2(2, 2)
		ov.size = Vector2(24, 0)
		ov.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(ov)
		var k = UI.lbl("", 7)
		k.position = Vector2(2, -2)
		p.add_child(k)
		skill_key_lbl[i] = k
		var rk = UI.lbl("", 7, Color(1, 0.9, 0.4))
		rk.position = Vector2(14, 15)
		p.add_child(rk)
		skill_ov[i] = ov
		skill_icon[i] = ic
		skill_rank[i] = rk
		x += 30.0
	x += 14.0
	var qicons = ["potion_hp_1", "potion_mp_1", "cooked_meat", "campfire"]
	for i in range(4):
		var p = UI.slot_panel(28)
		p.position = Vector2(x, 238)
		add_child(p)
		var ic = UI.icon(Game.tex("res://assets/items/%s.png" % qicons[i]), 28)
		p.add_child(ic)
		var k = UI.lbl(str(i + 1), 7)
		k.position = Vector2(2, -2)
		p.add_child(k)
		quick_key_lbl[i + 1] = k
		var c = UI.lbl("0", 8, Color(1, 1, 0.6))
		c.position = Vector2(15, 15)
		p.add_child(c)
		quick_cnt[i + 1] = c
		quick_icon[i + 1] = ic
		x += 30.0


func _build_misc():
	msg_box = VBoxContainer.new()
	msg_box.position = Vector2(140, 34)
	msg_box.custom_minimum_size = Vector2(200, 0)
	msg_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(msg_box)
	help_label = UI.lbl("", 7, Color(1, 1, 1, 0.8))
	help_label.position = Vector2(6, 214)
	add_child(help_label)
	boss_box = Control.new()
	boss_box.position = Vector2(130, 4)
	boss_box.visible = false
	boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(boss_box)
	boss_name_lbl = UI.lbl("", 10, Color(1, 0.45, 0.35))
	boss_name_lbl.custom_minimum_size = Vector2(220, 0)
	boss_name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_box.add_child(boss_name_lbl)
	boss_bar = UI.bar(Color(0.8, 0.12, 0.12), 220, 8)
	boss_bar.position = Vector2(0, 16)
	boss_box.add_child(boss_bar)
	death_label = UI.lbl("YOU DIED\nRespawning at the village...", 16, Color(1, 0.3, 0.3))
	death_label.position = Vector2(130, 100)
	death_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	death_label.visible = false
	add_child(death_label)


# ------------------------------------------------------------ build: save / load slots
func _build_slots():
	slots_title = UI.lbl("", 11, Color(1, 0.9, 0.4))
	slots_title.position = Vector2(10, 6)
	slots_panel.add_child(slots_title)
	slots_box = VBoxContainer.new()
	slots_box.position = Vector2(10, 28)
	slots_box.add_theme_constant_override("separation", 3)
	slots_panel.add_child(slots_box)
	var back = UI.btn("Back", 60, 20, 9)
	back.position = Vector2(290, 188)
	back.pressed.connect(_slots_back)
	slots_panel.add_child(back)


func open_slots(mode, from_panel):
	slot_mode = mode
	slot_from = from_panel
	set_panel(mode)
	_refresh_slots()


func _refresh_slots():
	slots_title.text = "SAVE GAME" if slot_mode == "save" else ("CHOOSE A SAVE SLOT FOR YOUR %s" % new_class_name.to_upper() if slot_mode == "new" else "LOAD GAME")
	UI.clear(slots_box)
	for i in range(1, Game.SLOT_COUNT + 1):
		var info = Game.slot_summary(i) if Game.has_method("slot_summary") else Game.slot_summary(i)
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 3)
		var l = UI.lbl(("Slot %d: " % i) + (info if info != "" else "- empty -"), 8, Color(1, 1, 1) if info != "" else Color(1, 1, 1, 0.5))
		l.custom_minimum_size = Vector2(250, 22)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.clip_text = true
		row.add_child(l)
		var b = UI.btn("Save" if slot_mode == "save" else ("Start" if info == "" else "Overwrite") if slot_mode == "new" else "Load", 38 if slot_mode != "new" else 56, 22, 8)
		b.disabled = slot_mode == "load" and info == ""
		b.pressed.connect(_slot_action.bind(i))
		row.add_child(b)
		var db = UI.btn("Del", 28, 22, 8)
		db.disabled = info == ""
		db.pressed.connect(_slot_delete.bind(i))
		row.add_child(db)
		slots_box.add_child(row)


func _slot_action(i):
	if slot_mode == "new":
		Game.current_slot = i
		Game.delete_slot(i)
		character_chosen.emit(new_class_id)
	elif slot_mode == "save":
		Game.main.save_game(i)
		_refresh_slots()
	else:
		Game.main.load_game(i)


func _slot_delete(i):
	Game.delete_slot(i)
	_refresh_slots()


func _slots_back():
	set_panel(slot_from)


# ------------------------------------------------------------ build: map / pause / select / title
func _full_overlay(panel_name, color):
	var c = ColorRect.new()
	c.color = color
	c.size = Vector2(480, 270)
	c.visible = false
	add_child(c)
	panels[panel_name] = c
	return c


func _menu_column(parent, labels, callbacks, y = 90):
	var v = VBoxContainer.new()
	v.position = Vector2(170, y)
	v.add_theme_constant_override("separation", 6)
	parent.add_child(v)
	for i in range(labels.size()):
		var b = UI.btn(labels[i], 140, 26, 11)
		b.pressed.connect(callbacks[i])
		v.add_child(b)


func _build_map():
	var p = _full_overlay("map", Color(0.04, 0.05, 0.09, 0.95))
	var title = UI.lbl("MAP", 11, Color(1, 0.9, 0.4))
	title.position = Vector2(278, 6)
	p.add_child(title)
	map_full = MapViewScript.new()
	map_full.mode = "full"
	map_full.position = Vector2(10, 7)
	map_full.size = Vector2(256, 256)
	p.add_child(map_full)
	map_info = UI.lbl("", 8)
	map_info.position = Vector2(278, 22)
	p.add_child(map_info)
	dungeon_info = UI.lbl("", 7)
	dungeon_info.position = Vector2(278, 52)
	dungeon_info.custom_minimum_size = Vector2(190, 0)
	dungeon_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p.add_child(dungeon_info)
	var items = [[Color(1, 0.9, 0.2), "You"], [Color(0.7, 0.25, 0.18), "Town"], [Color(1, 0.55, 0.15), "Campfire"],
		[Color(0.95, 0.55, 0.3), "Iron ore"], [Color(0.1, 0.1, 0.12), "Coal"], [Color(1, 0.2, 0.2), "Waypoint"],
		[Color(1, 0.8, 0.4), "Dungeon"]]
	var n = 0
	for it in items:
		var lx = 280.0 + (n % 2) * 96.0
		var ly = 186.0 + (n / 2) * 10.0
		var sw = ColorRect.new()
		sw.color = it[0]
		sw.position = Vector2(lx, ly + 2)
		sw.size = Vector2(7, 7)
		p.add_child(sw)
		var l = UI.lbl(it[1], 7)
		l.position = Vector2(lx + 11, ly - 1)
		p.add_child(l)
		n += 1
	var zb = [["+", 16, func(): map_full.zoom_by(1.5)], ["-", 16, func(): map_full.zoom_by(1.0 / 1.5)],
		["Me", 24, func(): map_full.center_on_player()], ["All", 24, func(): map_full.reset_view()]]
	var zx = 380.0
	for b in zb:
		var bt = UI.btn(b[0], b[1], 14, 8)
		bt.position = Vector2(zx, 5)
		bt.pressed.connect(b[2])
		p.add_child(bt)
		zx += b[1] + 3.0
	title.text = "MAP"
	var hint = UI.lbl("Click: waypoint / select dungeon | Right-click: clear\nWheel: zoom | Drag: pan", 7, Color(1, 1, 1, 0.75))
	hint.position = Vector2(278, 227)
	p.add_child(hint)
	tp_town_btn = UI.btn("Teleport to Town", 190, 16, 8)
	tp_town_btn.position = Vector2(278, 140)
	tp_town_btn.pressed.connect(func():
		set_panel("")
		player.start_recall())
	p.add_child(tp_town_btn)
	tp_dun_btn = UI.btn("Teleport to Dungeon", 190, 16, 8)
	tp_dun_btn.position = Vector2(278, 160)
	tp_dun_btn.pressed.connect(func():
		if Game.sel_dungeon != null and Game.dungeons.has(Game.sel_dungeon):
			var rec = Game.sel_dungeon
			set_panel("")
			player.start_teleport_dungeon(rec))
	p.add_child(tp_dun_btn)
	ore_btn = UI.btn("Ore markers: ON", 100, 16, 8)
	ore_btn.position = Vector2(278, 248)
	ore_btn.pressed.connect(_toggle_ore)
	p.add_child(ore_btn)
	var close = UI.btn("Close (M)", 70, 16, 8)
	close.position = Vector2(396, 248)
	close.pressed.connect(func(): set_panel(""))
	p.add_child(close)
	minimap = MapViewScript.new()
	minimap.mode = "mini"
	minimap.position = Vector2(404, 6)
	minimap.size = Vector2(70, 70)
	minimap.visible = false
	add_child(minimap)
	mini_btn = UI.btn("Map", 20, 10, 6)
	mini_btn.position = Vector2(458, 1)
	mini_btn.tooltip_text = "Toggle minimap (N)"
	mini_btn.pressed.connect(cycle_minimap)
	add_child(mini_btn)


func _toggle_ore():
	map_full.show_ore = not map_full.show_ore
	ore_btn.text = "Ore markers: ON" if map_full.show_ore else "Ore markers: OFF"


func _build_controls():
	var p = _full_overlay("controls", Color(0.05, 0.06, 0.1, 1.0))
	var t = UI.lbl("CONTROLS", 14, Color(1, 0.9, 0.4))
	t.position = Vector2(200, 10)
	p.add_child(t)
	var sub = UI.lbl("Click a key box, then press the new key (Esc cancels). Conflicting keys are swapped.", 7, Color(0.8, 0.85, 1))
	sub.position = Vector2(80, 32)
	p.add_child(sub)
	var n = 0
	for b in Game.BIND_ACTIONS:
		var col = n / 5
		var row = n % 5
		var x = 30.0 + col * 220.0
		var y = 56.0 + row * 28.0
		var l = UI.lbl(b[1], 9)
		l.position = Vector2(x, y + 4)
		p.add_child(l)
		var kb = UI.btn("", 70, 20, 9)
		kb.position = Vector2(x + 100, y)
		kb.pressed.connect(_listen.bind(b[0]))
		p.add_child(kb)
		ctrl_btns[b[0]] = kb
		n += 1
	var fixed = UI.lbl("Fixed keys: WASD move, run toggle (rebindable), Space / Click attack, I bag, C character, K skills, B craft, M map, N minimap, T interact, H help, F5 save", 7, Color(1, 1, 1, 0.55))
	fixed.position = Vector2(20, 206)
	fixed.custom_minimum_size = Vector2(440, 0)
	fixed.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p.add_child(fixed)
	var rs = UI.btn("Reset to defaults", 110, 20, 9)
	rs.position = Vector2(120, 238)
	rs.pressed.connect(func(): Game.reset_binds())
	p.add_child(rs)
	var bk = UI.btn("Back", 80, 20, 9)
	bk.position = Vector2(250, 238)
	bk.pressed.connect(func(): set_panel(controls_from))
	p.add_child(bk)


func open_controls(from):
	controls_from = from
	listening = ""
	set_panel("controls")
	_refresh_controls()


func _listen(action):
	listening = action
	_refresh_controls()


func _refresh_controls():
	for a in ctrl_btns:
		ctrl_btns[a].text = "Press a key..." if listening == a else Game.key_label(a)
		ctrl_btns[a].self_modulate = Color(1, 0.9, 0.4) if listening == a else Color.WHITE


func _input(event):
	if tip_panel != null and tip_panel.visible and (tip_max[0] > 0.0 or tip_max[1] > 0.0) and event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN or event.button_index == MOUSE_BUTTON_WHEEL_UP:
			tip_scroll = clampf(tip_scroll + (22.0 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -22.0), 0.0, maxf(tip_max[0], tip_max[1]))
			_apply_tip_scroll()
			get_viewport().set_input_as_handled()
			return
	if listening != "" and event is InputEventKey and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		if event.keycode != KEY_ESCAPE:
			var err = Game.set_bind(listening, event.physical_keycode)
			if err != "":
				Game.notify(err)
		listening = ""
		_refresh_controls()


func _build_pause():
	var p = _full_overlay("pause", Color(0, 0, 0, 0.65))
	var t = UI.lbl("PAUSED", 18, Color(1, 0.9, 0.4))
	t.position = Vector2(200, 50)
	p.add_child(t)
	_menu_column(p, ["Resume", "Save Game", "Load Game", "Controls", "Quit to Title"],
		[func(): set_panel(""), func(): open_slots("save", "pause"), func(): open_slots("load", "pause"), func(): open_controls("pause"), _quit_to_title], 80)
	var vy = 90.0
	for row in [["Music", "music_vol"], ["Sound", "sfx_vol"]]:
		var l = UI.lbl(row[0], 9, Color(1, 0.9, 0.5))
		l.position = Vector2(332, vy)
		p.add_child(l)
		var sl = HSlider.new()
		sl.min_value = 0.0
		sl.max_value = 1.0
		sl.step = 0.05
		sl.value = Audio.get(row[1])
		sl.position = Vector2(332, vy + 14)
		sl.custom_minimum_size = Vector2(110, 14)
		sl.size = Vector2(110, 14)
		sl.value_changed.connect(func(v):
			Audio.set(row[1], v)
			Audio.save_volumes()
			if row[1] == "sfx_vol":
				Audio.sfx("click", 1.0))
		p.add_child(sl)
		vy += 44.0


func _quit_to_title():
	if Game.main != null and player != null and not player.dead:
		Game.main.save_game(Game.current_slot, true)
	Game.pending_load = null
	get_tree().paused = false
	get_tree().reload_current_scene()


func _build_title():
	var p = _full_overlay("title", Color(0.05, 0.07, 0.12, 1))
	var t = UI.lbl("ASHEN WILDS", 26, Color(1, 0.85, 0.4))
	t.position = Vector2(135, 36)
	p.add_child(t)
	var sub = UI.lbl("pixel-art action RPG / survival", 8, Color(1, 1, 1, 0.7))
	sub.position = Vector2(180, 72)
	p.add_child(sub)
	_menu_column(p, ["New Game", "Load Game", "Controls", "Quit"],
		[func(): set_panel("select"), func(): open_slots("load", "title"), func(): open_controls("title"), func(): get_tree().quit()], 105)


func _build_select():
	var p = _full_overlay("select", Color(0.05, 0.07, 0.12, 1))
	var t = UI.lbl("Choose your class", 16, Color(1, 0.85, 0.4))
	t.position = Vector2(165, 8)
	p.add_child(t)
	var x = 6
	for id in Game.CLASSES:
		var c = Game.CLASSES[id]
		var v = VBoxContainer.new()
		v.position = Vector2(x, 36)
		v.custom_minimum_size = Vector2(90, 0)
		v.add_theme_constant_override("separation", 2)
		var at = AtlasTexture.new()
		at.atlas = Game.tex(c["sheet"])
		at.region = Rect2(0, 0, 32, 32)
		var tr = TextureRect.new()
		tr.texture = at
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.custom_minimum_size = Vector2(70, 70)
		v.add_child(tr)
		var nm = UI.lbl(c["name"], 12, Color(1, 0.9, 0.5))
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(nm)
		var ds = UI.lbl(c["desc"], 7)
		ds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ds.custom_minimum_size = Vector2(90, 40)
		ds.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(ds)
		var st = ""
		for k in Game.STATS:
			st += "%s %d  " % [Game.STAT_NAMES[k], c["base"][k]]
		var sl = UI.lbl(st.strip_edges(), 7, Color(0.75, 0.85, 1))
		sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sl.custom_minimum_size = Vector2(90, 30)
		sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(sl)
		var b = UI.btn("Play", 0, 22, 10)
		b.pressed.connect(_pick.bind(id))
		v.add_child(b)
		p.add_child(v)
		x += 94
	var back = UI.btn("Back", 60, 20, 9)
	back.position = Vector2(210, 242)
	back.pressed.connect(func(): set_panel("title"))
	p.add_child(back)


func _pick(id):
	new_class_id = id
	new_class_name = Game.CLASSES[id]["name"]
	open_slots("new", "select")


# ------------------------------------------------------------ runtime
func bind_player(p):
	player = p
	_apply_minimap()
	p.inventory_changed.connect(refresh_active)
	p.stats_changed.connect(_on_stats)


func _help_text():
	var k = func(a): return Game.key_label(a)
	return "WASD move | %s run on/off | Mouse aim, Click/Space attack | %s / Right-click dash | %s %s %s %s skills (K to equip) | %s %s %s %s quick use\nI bag | C character | K skills | B craft | M map | N minimap | T talk | %s recall | F5 save (autosave every 60s) | Esc menu + key bindings | H hide" % [
		k.call("run"), k.call("dash"), k.call("skill_0"), k.call("skill_1"), k.call("skill_2"), k.call("skill_3"),
		k.call("quick_1"), k.call("quick_2"), k.call("quick_3"), k.call("quick_4"), k.call("recall")]


func refresh_keys():
	for i in skill_key_lbl:
		skill_key_lbl[i].text = Game.key_label("skill_%d" % i)
	for n in quick_key_lbl:
		quick_key_lbl[n].text = Game.key_label("quick_%d" % n)
	if dash_key_lbl != null:
		dash_key_lbl.text = "Dash " + Game.key_label("dash")
	if help_label != null:
		help_label.text = _help_text()
	_refresh_controls()
	if wins.has("skills") and player != null and open_panel == "skills":
		wins["skills"].refresh()


func _on_stats():
	if open_panel == "char" or open_panel == "skills":
		refresh_active()


func show_death(v):
	death_label.visible = v


func notify(text):
	var l = UI.lbl(text, 9, Color(1, 1, 0.8))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(240, 0)
	msg_box.add_child(l)
	if msg_box.get_child_count() > 4:
		msg_box.get_child(0).queue_free()
	var tw = l.create_tween()
	tw.tween_interval(2.4)
	tw.tween_property(l, "modulate:a", 0.0, 1.0)
	tw.tween_callback(l.queue_free)


func _toggle(panel_name):
	if open_panel == panel_name:
		set_panel("")
	elif open_panel == "":
		set_panel(panel_name)


func _unhandled_input(event):
	if open_panel == "title" or (open_panel == "select" and not (event is InputEventKey and event.keycode == KEY_ESCAPE)):
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if open_panel == "title":
			return
		elif open_panel == "select":
			set_panel("title")
		elif open_panel == "save" or open_panel == "load" or open_panel == "new":
			_slots_back()
		elif open_panel == "controls":
			set_panel(controls_from)
		elif open_panel != "":
			set_panel("")
		elif player != null and not player.dead:
			set_panel("pause")
		return
	if player == null:
		return
	if event.is_action_pressed("craft"):
		_toggle("craft")
	elif event.is_action_pressed("inventory"):
		_toggle("inv")
	elif event.is_action_pressed("character"):
		_toggle("char")
	elif event.is_action_pressed("skills"):
		_toggle("skills")
	elif event.is_action_pressed("minimap"):
		if open_panel == "":
			cycle_minimap()
	elif event.is_action_pressed("map"):
		_toggle("map")
	elif event.is_action_pressed("run"):
		Game.run_on = not Game.run_on
	elif event.is_action_pressed("recall"):
		if open_panel == "" and not player.dead:
			player.start_recall()
	elif event.is_action_pressed("help"):
		help_label.visible = not help_label.visible
	elif event.is_action_pressed("interact"):
		if open_panel == "shop" or open_panel == "guild" or open_panel == "smith":
			set_panel("")
	elif event.is_action_pressed("quicksave"):
		if open_panel == "" and not player.dead:
			Game.main.save_game(Game.current_slot)


func _process(_delta):
	if player == null:
		return
	if tip_panel.visible:
		_place_tip()
	hp_bar.max_value = player.max_hp
	hp_bar.value = player.hp
	hp_bar.text = "%d / %d" % [player.hp, player.max_hp]
	mp_bar.text = "%d" % player.mp
	run_label.text = "Running (%s)" % Game.key_label("run") if Game.run_on else ""
	mp_bar.max_value = player.max_mp
	mp_bar.value = player.mp
	xp_bar.max_value = Game.xp_need(player.level)
	xp_bar.value = player.xp if player.level < Game.MAX_LEVEL else Game.xp_need(player.level)
	hunger_bar.value = player.hunger
	lvl_label.text = "%s  Lv%d" % [player.cdata["name"], player.level]
	gold_label.text = "%dg" % player.gold
	var bt = ""
	for id in player.buffs:
		var nm = id.capitalize()
		if Game.FOOD_BUFFS.has(id):
			nm = Game.FOOD_BUFFS[id]["name"]
		bt += "%s %ds\n" % [nm, int(player.buffs[id]["t"])]
	for s in player.statuses:
		bt += "%s %ds\n" % [str(s[0]).capitalize(), int(s[1])]
	if player.hunger < 20.0:
		bt += "Hungry!\n"
	buff_label.text = bt
	var qt = ""
	for q in player.quests:
		var pr = player.quest_progress(q)
		qt += "%s %d/%d%s\n" % [q["name"], pr, q["need"], " (done!)" if pr >= q["need"] else ""]
	quest_label.text = qt
	if player.stat_pts > 0 or player.skill_pts > 0:
		var blink = 0.6 + 0.4 * sin(Time.get_ticks_msec() / 250.0)
		points_label.modulate = Color(1, 1, 1, blink)
		points_label.text = "C: %d stat pts   K: %d skill pts" % [player.stat_pts, player.skill_pts]
	else:
		points_label.text = ""
	var nb = null
	for b in get_tree().get_nodes_in_group("bosses"):
		if b.engaged:
			nb = b
			break
	boss_box.visible = nb != null and open_panel == ""
	if nb != null:
		boss_name_lbl.text = "Lv%d %s%s" % [nb.level, nb.boss_name, "  [ENRAGED]" if nb.enraged else ""]
		boss_bar.max_value = nb.max_hp
		boss_bar.value = nb.hp
	dash_ov.size.y = 24.0 * clampf(player.dash_cd / player.DASH_CD, 0.0, 1.0)
	for i in range(4):
		var sid = Skills.slot_skill_any(player, i)
		var learned = sid != "" and Skills.rank(player, sid) > 0
		if sid != "":
			skill_icon[i].texture = Game.skill_icon(sid)
			skill_icon[i].modulate = Color.WHITE
			if not learned:
				skill_icon[i].modulate = Color(0.3, 0.3, 0.35)
			elif player.mp < Skills.mana_cost(player, sid):
				skill_icon[i].modulate = Color(0.45, 0.45, 0.65)
			skill_rank[i].text = str(Skills.rank(player, sid)) if learned else ""
			var cdm = maxf(player.cd_max.get(sid, 1.0), 0.1)
			skill_ov[i].size.y = 24.0 * clampf(player.cd.get(sid, 0.0) / cdm, 0.0, 1.0)
		else:
			skill_ov[i].size.y = 0.0
	for n in range(1, 5):
		quick_cnt[n].text = str(player.quick_count(n))
		quick_icon[n].modulate = Color.WHITE if player.quick_count(n) > 0 else Color(0.35, 0.35, 0.4)
	if open_panel == "map" and Game.map != null:
		_update_map_info()
		_update_tp_buttons()
	if open_panel == "craft":
		wins["craft"].fire_lbl.text = "Campfire nearby: YES" if Game.near_fire(player.global_position) else "Campfire nearby: no"


func _update_tp_buttons():
	var indun = Game.cur_dungeon != null
	var in_town = Game.world != null and not indun and absf(player.position.x - Game.world.spawn_pos.x) < Game.world.TOWN_HX - 16.0 and absf(player.position.y - Game.world.spawn_pos.y) < Game.world.TOWN_HY - 16.0
	tp_town_btn.disabled = in_town
	tp_town_btn.text = "Teleport to Town" if player.recall_cd <= 0.0 else "Teleport to Town (%ds)" % ceili(player.recall_cd)
	tp_dun_btn.visible = not indun
	var rec = Game.sel_dungeon
	if rec != null and not Game.dungeons.has(rec):
		Game.sel_dungeon = null
		rec = null
	if rec == null:
		tp_dun_btn.text = "Click a dungeon on the map to teleport"
		tp_dun_btn.disabled = true
	else:
		var c = player.teleport_cost(rec)
		tp_dun_btn.text = "Teleport to %s (Rank %d) - %dg" % [Game.DUNGEONS[rec["biome"]]["name"], rec["level"], c]
		tp_dun_btn.disabled = player.gold < c


func _update_map_info():
	var tp = player.global_position / 16.0
	var txt = ""
	if Game.dlayout != null:
		txt = "%s\nRank %d" % [Game.DUNGEONS[Game.cur_dungeon["biome"]]["name"], Game.cur_dungeon["level"]]
		var minis_total = 0
		var minis_dead = 0
		for m in Game.dlayout.mobs:
			if m["mini"]:
				minis_total += 1
				if Game.cur_dungeon["state"]["killed"].has(m["uid"]):
					minis_dead += 1
		txt += "\nMini bosses: %d/%d defeated\nMain boss: %s" % [minis_dead, minis_total, "DEFEATED" if Game.cur_dungeon["state"]["boss"] else "alive (far corner)"]
		map_info.text = txt
		dungeon_info.text = "Green dot = exit, yellow = chests, red = main boss.\nExplore the rooms: the main boss waits in the open arena at the far end."
		return
	txt = "Pos %d, %d   %s\nExplored %d%% of the land" % [tp.x, tp.y, "Night" if Game.is_night else "Day", Game.map.percent()]
	if Game.waypoint != null:
		txt += "\nWaypoint: %d tiles away" % int(player.global_position.distance_to(Game.waypoint) / 16.0)
	map_info.text = txt
	var lines = ["DUNGEONS (nearest first)"]
	var rows = []
	for rec in Game.dungeons:
		var secs = int(rec["time_left"])
		var dist = int(player.global_position.distance_to(Vector2(rec["pos"][0], rec["pos"][1])) / 16.0)
		rows.append([dist, "%s  Rank %d  %d:%02d  (%d tiles)" % [Game.DUNGEONS[rec["biome"]]["name"], rec["level"], secs / 60, secs % 60, dist]])
	rows.sort_custom(func(a, b): return a[0] < b[0])
	for i in range(mini(rows.size(), 7)):
		lines.append(rows[i][1])
	if rows.size() > 7:
		lines.append("+%d more on the map" % (rows.size() - 7))
	if rows.is_empty():
		lines.append("None right now. They appear at random\nand collapse after a while.")
	dungeon_info.text = "\n".join(lines)
