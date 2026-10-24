extends Panel
## Character window: level, XP, main stat allocation, derived stats.

var hud
var title
var pts_lbl
var rows = {}
var derived
var xp_lbl
var reset_btn
var portrait


func setup(h):
	hud = h
	var t = UI.lbl("CHARACTER  (C to close)", 10, Color(1, 0.9, 0.5))
	t.position = Vector2(8, 4)
	add_child(t)
	portrait = TextureRect.new()
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.position = Vector2(10, 22)
	portrait.size = Vector2(56, 56)
	add_child(portrait)
	title = UI.lbl("", 11, Color(1, 0.9, 0.4))
	title.position = Vector2(72, 24)
	add_child(title)
	xp_lbl = UI.lbl("", 8)
	xp_lbl.position = Vector2(72, 40)
	add_child(xp_lbl)
	var sc = ScrollContainer.new()
	sc.position = Vector2(4, 80)
	sc.size = Vector2(448, 166)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(sc)
	var body = Control.new()
	body.custom_minimum_size = Vector2(430, 330)
	sc.add_child(body)
	pts_lbl = UI.lbl("", 10, Color(0.5, 1, 0.5))
	pts_lbl.position = Vector2(6, 2)
	body.add_child(pts_lbl)
	var y = 20
	for k in Game.STATS:
		var n = UI.lbl(Game.STAT_NAMES[k], 10, Color(1, 0.95, 0.8))
		n.position = Vector2(6, y + 3)
		body.add_child(n)
		var v = UI.lbl("", 10)
		v.position = Vector2(50, y + 3)
		body.add_child(v)
		var hint = UI.lbl(Game.STAT_HELP[k], 7, Color(0.75, 0.8, 0.9))
		hint.position = Vector2(88, y + 5)
		body.add_child(hint)
		var b = UI.btn("+", 20, 18, 10)
		b.position = Vector2(216, y)
		b.pressed.connect(_add.bind(k, 1))
		body.add_child(b)
		var b5 = UI.btn("+5", 24, 18, 8)
		b5.position = Vector2(240, y)
		b5.pressed.connect(_add.bind(k, 5))
		body.add_child(b5)
		rows[k] = [v, b, b5]
		y += 22
	reset_btn = UI.btn("Reset points", 90, 18, 8)
	reset_btn.position = Vector2(6, 158)
	reset_btn.pressed.connect(func():
		hud.player.respec()
		refresh())
	body.add_child(reset_btn)
	derived = RichTextLabel.new()
	derived.bbcode_enabled = true
	derived.position = Vector2(280, 2)
	derived.size = Vector2(146, 320)
	derived.add_theme_font_size_override("normal_font_size", 8)
	derived.scroll_active = false
	derived.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(derived)


func _add(k, n):
	var p = hud.player
	for i in range(n):
		if not p.alloc_stat(k):
			break
	refresh()


func refresh():
	var p = hud.player
	if p == null:
		return
	var at = AtlasTexture.new()
	at.atlas = Game.tex(p.cdata["sheet"])
	at.region = Rect2(0, 0, 32, 32)
	portrait.texture = at
	title.text = "%s  Lv %d" % [p.cdata["name"], p.level]
	if p.level >= Game.MAX_LEVEL:
		xp_lbl.text = "MAX LEVEL"
	else:
		xp_lbl.text = "XP %d / %d" % [p.xp, Game.xp_need(p.level)]
	pts_lbl.text = "Stat points: %d" % p.stat_pts
	var g = p.gear_totals()
	for k in Game.STATS:
		var base = p.base_stat(k)
		var extra = g.get(k, 0.0)
		var txt = str(int(base))
		if extra > 0:
			txt += " (+%d)" % int(extra)
		rows[k][0].text = txt
		rows[k][1].disabled = p.stat_pts <= 0
		rows[k][2].disabled = p.stat_pts <= 0
	reset_btn.text = "Reset (%dg)" % p.respec_cost()
	reset_btn.disabled = p.gold < p.respec_cost()
	var s = p.stats
	var t = ""
	t += "[color=#ffd966]Combat[/color]\n"
	t += "HP  %d / %d\nMP  %d / %d\n" % [p.hp, p.max_hp, p.mp, p.max_mp]
	t += "Phy Atk  %d\nMagic Atk  %d\n" % [s["phy_atk"], s["mag_atk"]]
	t += "Phy Def  %d\nMagic Def  %d\n" % [s["phy_def"], s["mag_def"]]
	t += "Move Speed  %s\nAtk/Cast Spd  %s\n" % [UI.stat_val("move_speed", s["move_speed"]), UI.stat_val("atk_speed", s["atk_speed"])]
	t += "Crit Rate  %s\nCrit Damage  %s\n" % [UI.stat_val("crit_rate", s["crit_rate"]), UI.stat_val("crit_dmg", s["crit_dmg"])]
	t += "Drop Rate  +%s\n" % UI.stat_val("drop", s["drop"])
	t += "HP Regen  %s\nMP Regen  %s\n" % [UI.stat_val("hp_regen", s["hp_regen"]), UI.stat_val("mp_regen", s["mp_regen"])]
	t += "\n[color=#ffd966]Resistances[/color]\n"
	for e in Game.ELEMENTS:
		t += "[color=#%s]%s[/color]  %s\n" % [Game.ELEM_COLOR[e].to_html(false), e.capitalize(), UI.stat_val("res_" + e, s["res_" + e])]
	derived.text = t
