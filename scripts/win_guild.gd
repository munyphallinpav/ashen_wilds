extends Panel
## Adventurer Guild: accept quests from the board, track and turn them in.

var hud
var board_box
var active_box
var title
const MAX_ACTIVE = 4


func setup(h):
	hud = h
	title = UI.lbl("ADVENTURER GUILD", 11, Color(1, 0.9, 0.4))
	title.position = Vector2(8, 4)
	add_child(title)
	var bl = UI.lbl("QUEST BOARD", 9, Color(0.6, 1, 0.6))
	bl.position = Vector2(8, 22)
	add_child(bl)
	var al = UI.lbl("YOUR QUESTS (max 4)", 9, Color(1, 0.8, 0.5))
	al.position = Vector2(232, 22)
	add_child(al)
	var sc1 = ScrollContainer.new()
	sc1.position = Vector2(8, 36)
	sc1.size = Vector2(216, 196)
	sc1.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(sc1)
	board_box = VBoxContainer.new()
	board_box.custom_minimum_size = Vector2(210, 0)
	board_box.add_theme_constant_override("separation", 3)
	sc1.add_child(board_box)
	var sc2 = ScrollContainer.new()
	sc2.position = Vector2(232, 36)
	sc2.size = Vector2(216, 196)
	sc2.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(sc2)
	active_box = VBoxContainer.new()
	active_box.custom_minimum_size = Vector2(210, 0)
	active_box.add_theme_constant_override("separation", 3)
	sc2.add_child(active_box)
	var hint = UI.lbl("T / Esc to leave. New quests appear over time.", 8, Color(1, 1, 1, 0.7))
	hint.position = Vector2(8, 236)
	add_child(hint)


func open():
	var p = hud.player
	if p.board.size() < 3 or Game.play_time - p.board_t > 600.0:
		var keep = []
		p.board = []
		while p.board.size() < 4:
			p.board.append(Game.make_quest(p.level))
		p.board_t = Game.play_time
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


func refresh():
	var p = hud.player
	if p == null:
		return
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
