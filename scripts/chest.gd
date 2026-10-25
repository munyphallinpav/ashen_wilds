extends StaticBody2D
## Treasure chest. Press T next to it. Gold chests (boss reward) hold a unique item.

var idx = 0
var gold_chest = false
var unique_id = ""
var level = 1
var diff = 0
var opened = false
var mimic = false        # looks like a chest, bites when opened
var spr
var prompt


func _ready():
	add_to_group("interact")
	add_to_group("dnode")
	collision_layer = 1
	collision_mask = 0
	var cs = CollisionShape2D.new()
	var r = RectangleShape2D.new()
	r.size = Vector2(12, 7)
	cs.shape = r
	cs.position = Vector2(0, -3)
	add_child(cs)
	spr = Sprite2D.new()
	spr.texture = Game.tex("res://assets/world/chest_gold.png" if gold_chest else "res://assets/world/chest.png")
	spr.region_enabled = true
	spr.region_rect = Rect2(16 if opened else 0, 0, 16, 16)
	spr.offset = Vector2(0, -8)
	add_child(spr)
	prompt = Label.new()
	prompt.text = "[T] Open"
	prompt.add_theme_font_size_override("font_size", 8)
	prompt.add_theme_color_override("font_outline_color", Color.BLACK)
	prompt.add_theme_constant_override("outline_size", 3)
	prompt.position = Vector2(-16, -28)
	prompt.visible = false
	add_child(prompt)


func _process(_d):
	var p = Game.player
	prompt.visible = p != null and not opened and global_position.distance_to(p.global_position) < 30.0 and not Game.hud.ui_open()


func interact():
	if opened:
		return
	if mimic:
		opened = true
		Game.notify("It's a MIMIC!")
		Audio.sfx("boss_roar", 0.7, 1.4)
		Game.main.shake(3.0)
		var e = Game.world.spawn_mob("mimic", global_position, level + 1)
		e.diff = diff * 0.5
		e.angry = true
		queue_free()
		return
	opened = true
	Audio.sfx("chest", 1.0)
	spr.region_rect = Rect2(16, 0, 16, 16)
	var p = Game.player
	var loot = []
	var luck = p.stats["drop"]
	if gold_chest:
		loot.append(Items.roll_gear(Game.UNIQUES[unique_id]["sub"], level + 2, 4 if randf() > 0.12 else 5, unique_id))
		loot.append(Items.roll_random_gear(level, maxi(3, Items.roll_rarity(luck * 0.5, 2.0 + diff)), luck, diff))
		loot.append(Items.make("potion_hp_2", 3))
		p.add_gold(int(40.0 * (3.0 + level * 2.2)))
		Game.notify("Treasure! %s" % Items.name_of(loot[0]))
	else:
		p.add_gold(int(randf_range(0.8, 1.6) * (3.0 + level * 2.2) * (2.0 + diff)))
		if randf() < 0.55 + diff * 0.05:
			loot.append(Items.roll_random_gear(level, -1, luck, 0.6 + diff * 0.5))
		for i in range(2):
			var pool = ["potion_hp_1", "potion_mp_1", "potion_hp_2", "potion_mp_2", "iron_ore", "herb", "mushroom", "coal"]
			loot.append(Items.make(pool.pick_random(), randi_range(1, 3)))
	Game.spawn_fx("light", global_position + Vector2(0, -6), {"scl": 0.7})
	Items.scatter(loot, global_position + Vector2(0, 10))
	if Game.main != null:
		Game.main.chest_opened(self)
