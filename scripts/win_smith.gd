extends "res://scripts/win_craft.gd"
## Blacksmith: craft gear (forge always lit) and enchant / re-roll gear.


func setup(h):
	smith_mode = true
	super.setup(h)
	var title_lbl = get_child(0)
	title_lbl.text = "BLACKSMITH  (T / Esc to leave)"
	var eb = UI.btn("Enchant", 70, 16, 8)
	eb.position = Vector2(8 + 56 + 2 + 56 + 2 + 80 + 2 + 56 + 2, 22)
	eb.pressed.connect(func():
		filter = "enchant"
		refresh())
	add_child(eb)
	fbtns["enchant"] = eb
	fire_lbl.position = Vector2(340, 24)
	fire_lbl.text = ""
