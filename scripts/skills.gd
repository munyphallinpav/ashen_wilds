extends Node
## Autoload "Skills": skill-tree rules, passive bonuses and the casting code of every active skill.

# ------------------------------------------------------------------ tree rules
func rank(p, id):
	return int(p.ranks.get(id, 0))


func rank_cap(p, id):
	var s = Game.SKILLS[id]
	if p.level < s["lvl"]:
		return 0
	return mini(s["max"], 1 + int((p.level - s["lvl"]) / 3))


func available_to(p, id):
	var c = Game.SKILLS[id]["cls"]
	if c == "tome":
		return p.tomes.has(id)
	return c == "common" or c == p.char_id


func reqs_met(p, id):
	for r in Game.SKILLS[id]["req"]:
		if rank(p, r[0]) < r[1]:
			return false
	return true


func can_learn(p, id):
	if not available_to(p, id) or p.skill_pts <= 0:
		return false
	return rank(p, id) < rank_cap(p, id) and reqs_met(p, id)


func why_not(p, id):
	var s = Game.SKILLS[id]
	if p.skill_pts <= 0:
		return "No skill points"
	if p.level < s["lvl"]:
		return "Requires Lv %d" % s["lvl"]
	if not reqs_met(p, id):
		var r = s["req"][0]
		for q in s["req"]:
			if rank(p, q[0]) < q[1]:
				r = q
				break
		return "Requires %s rank %d" % [Game.SKILLS[r[0]]["name"], r[1]]
	if rank(p, id) >= s["max"]:
		return "Max rank"
	return "Level cap reached: reach Lv %d" % (s["lvl"] + 3 * rank(p, id))


func learn(p, id):
	if not can_learn(p, id):
		return false
	p.ranks[id] = rank(p, id) + 1
	p.skill_pts -= 1
	if Game.SKILLS[id]["type"] == "active" and not p.loadout.has(id):
		var idx = p.loadout.find("")
		if idx >= 0:
			p.loadout[idx] = id
	p.recalc()
	return true


func slot_skill(p, slot):
	var id = p.loadout[slot]
	if id != "" and rank(p, id) > 0:
		return id
	return ""


func slot_skill_any(p, slot):
	return p.loadout[slot]


func equip_skill(p, id, slot):
	if Game.SKILLS[id]["type"] != "active" or rank(p, id) <= 0:
		return false
	var old = p.loadout.find(id)
	if old >= 0:
		p.loadout[old] = p.loadout[slot]
	p.loadout[slot] = id
	return true


func mana_cost(p, id):
	var s = Game.SKILLS[id]
	return s["mana"] * (1.0 + 0.03 * (rank(p, id) - 1))


func passive_mods(p):
	var out = {}
	var low = p.hp < p.max_hp * 0.5
	for id in Game.SKILLS:
		var s = Game.SKILLS[id]
		var r = rank(p, id)
		if s["type"] != "passive" or r <= 0:
			continue
		for k in s["bonus"]:
			out[k] = out.get(k, 0.0) + s["bonus"][k] * r
		if low and s.has("low_bonus"):
			for k in s["low_bonus"]:
				out[k] = out.get(k, 0.0) + s["low_bonus"][k] * r
	return out


func dmg_base(p, id):
	var s = Game.SKILLS[id]
	var r = rank(p, id)
	var stat = p.stats["phy_atk"] if s["kind"] == "phy" else p.stats["mag_atk"]
	return stat * (s["mult"] + s["per"] * (r - 1))


# ------------------------------------------------------------------ casting
func cast(p, id):
	var s = Game.SKILLS[id]
	var r = rank(p, id)
	if r <= 0 or p.dead:
		return false
	if p.cd.get(id, 0.0) > 0.0:
		return false
	var cost = mana_cost(p, id)
	if p.mp < cost:
		Game.notify("Not enough mana")
		return false
	p.mp -= cost
	Audio.sfx("cast", 0.8, 1.0, 0.1)
	p.cd[id] = s["cd"] * (1.0 - minf(p.stats.get("cdr", 0.0), 0.4))
	p.cd_max[id] = p.cd[id]
	if has_method("_do_" + id):
		call("_do_" + id, p, s, r)
	else:
		_generic(p, id, s, r)
	return true


func _wait(p, t):
	await p.get_tree().create_timer(t / maxf(p.stats["atk_speed"], 0.5)).timeout


func _anim(p, name, dur):
	p.start_anim(name, dur)


func _arc_hit(p, id, s, reach, arc, kb, status, fx_kind, fx_dist, force_crit = false):
	var origin = p.origin()
	var d = p.aim
	var base = dmg_base(p, id)
	var magic = s["kind"] == "mag"
	for e in Game.enemies_in_arc(origin, d, reach, arc):
		Game.hit(e, Game.roll_damage(p, base, force_crit), origin, kb, s["elem"], magic, status)
	if fx_kind != "":
		var f = Game.spawn_fx(fx_kind, origin + d * fx_dist, {"rot": d.angle()})


# ---- Warrior
func _do_w_cleave(p, s, r):
	_anim(p, "attack", 0.35)
	await _wait(p, 0.12)
	if p.dead:
		return
	_arc_hit(p, "w_cleave", s, 40.0, 1.2, 130.0, [["burn", 3.0, 0.35]], "slash", 20.0)
	Game.spawn_fx("fire", p.origin() + p.aim * 28.0)
	p.shake(1.5)


func _do_w_bash(p, s, r):
	_anim(p, "attack", 0.35)
	await _wait(p, 0.12)
	if p.dead:
		return
	_arc_hit(p, "w_bash", s, 32.0, 1.0, 260.0, [["stun", 1.0 + r * 0.05, 0.0]], "bash", 22.0)
	p.shake(2.5)


func _do_w_whirl(p, s, r):
	_anim(p, "attack", 0.7)
	Game.spawn_fx("spin", p.origin())
	var n = s["hits"]
	for i in range(n):
		if p.dead:
			return
		Game.area_attack(p.origin(), 38.0, dmg_base(p, "w_whirl"), false, "wind", 120.0)
		p.invuln = maxf(p.invuln, 0.15)
		await p.get_tree().create_timer(0.11).timeout
	p.shake(1.5)


# ---- Ranger
func _do_r_pierce(p, s, r):
	_anim(p, "attack", 0.3)
	await _wait(p, 0.1)
	if p.dead:
		return
	Game.shoot({"position": p.origin() + p.aim * 10.0, "dir": p.aim, "speed": 340.0, "kind": "wind", "base": dmg_base(p, "r_pierce"),
		"magic": false, "element": "wind", "pierce": true, "life": 1.1, "kb": 120.0, "hit_fx": "wind"})


func _do_r_rain(p, s, r):
	_anim(p, "attack", 0.35)
	await _wait(p, 0.1)
	if p.dead:
		return
	var pos = p.target_pos(150.0)
	var ticks = s["ticks"] + int(r / 4)
	Game.zone({"position": pos, "radius": s["radius"], "dur": 3.0, "tick": 3.0 / ticks, "base": dmg_base(p, "r_rain"), "magic": false,
		"element": "water", "status": [["slow", 1.2, 0.35]], "fx": "rain", "kb": 20.0})


func _do_r_volley(p, s, r):
	_anim(p, "attack", 0.4)
	await _wait(p, 0.1)
	if p.dead:
		return
	var n = s["arrows"] + int(r / 8)
	for i in range(n):
		var a = p.aim.rotated((i - (n - 1) / 2.0) * 0.17)
		Game.shoot({"position": p.origin() + a * 10.0, "dir": a, "speed": 280.0, "kind": "fire", "base": dmg_base(p, "r_volley"),
			"magic": false, "element": "fire", "life": 0.9, "kb": 80.0, "hit_fx": "fire", "status": [["burn", 3.0, 0.3]]})


# ---- Assassin
func _do_a_shadow(p, s, r):
	_anim(p, "attack", 0.3)
	var start = p.global_position
	var target = p.dash_target(95.0 + r)
	Game.spawn_fx("dark", start + Vector2(0, -6))
	var hit_set = []
	var base = dmg_base(p, "a_shadow")
	var steps = 5
	p.invuln = maxf(p.invuln, 0.35)
	var tw = p.create_tween()
	tw.tween_property(p, "global_position", target, 0.16)
	for i in range(steps + 1):
		var pt = start.lerp(target, float(i) / steps) + Vector2(0, -6)
		Game.ghost_at(p, pt)
		for e in Game.enemies_in_circle(pt, 14.0):
			if not hit_set.has(e):
				hit_set.append(e)
				Game.hit(e, Game.roll_damage(p, base, true), pt, 100.0, "dark", false, [])
				Game.spawn_fx("slash", e.global_position + Vector2(0, -8), {"rot": randf() * TAU})
		await p.get_tree().create_timer(0.16 / steps).timeout
	Game.spawn_fx("dark", target + Vector2(0, -6))


func _do_a_flurry(p, s, r):
	_anim(p, "attack", 0.6)
	var n = s["hits"]
	for i in range(n):
		if p.dead:
			return
		p.start_anim("attack", 0.2)
		var origin = p.origin()
		var base = dmg_base(p, "a_flurry")
		for e in Game.enemies_in_arc(origin, p.aim, 34.0, 1.0):
			Game.hit(e, Game.roll_damage(p, base), origin, 40.0, "wind", false, [])
		Game.spawn_fx("slash", origin + p.aim * 20.0 + Vector2(randf_range(-4, 4), randf_range(-4, 4)), {"rot": p.aim.angle() + randf_range(-0.8, 0.8)})
		await p.get_tree().create_timer(0.08 / maxf(p.stats["atk_speed"], 0.5)).timeout


func _do_a_smoke(p, s, r):
	_anim(p, "cast", 0.35)
	await _wait(p, 0.1)
	if p.dead:
		return
	Game.zone({"position": p.global_position, "radius": s["radius"], "dur": s["dur"] + r * 0.1, "tick": 0.5, "base": 0.0, "magic": false,
		"element": "dark", "status": [["slow", 1.0, 0.4], ["weak", 1.0, 0.25]], "fx": "smoke",
		"player_buff": ["smoke", 1.0, {"move_pct": 0.3 + r * 0.01, "aspd_pct": 0.2}]})


# ---- Mage
func _do_m_fire(p, s, r):
	_anim(p, "cast", 0.35)
	await _wait(p, 0.12)
	if p.dead:
		return
	Game.shoot({"position": p.origin() + p.aim * 12.0, "dir": p.aim, "speed": 230.0, "kind": "fire", "base": dmg_base(p, "m_fire"), "magic": true,
		"element": "fire", "aoe": s["radius"] + r, "life": 1.3, "kb": 150.0, "hit_fx": "fire", "status": [["burn", 3.0, 0.4]]})


func _do_m_lance(p, s, r):
	_anim(p, "cast", 0.3)
	await _wait(p, 0.1)
	if p.dead:
		return
	Game.shoot({"position": p.origin() + p.aim * 12.0, "dir": p.aim, "speed": 320.0, "kind": "ice", "base": dmg_base(p, "m_lance"), "magic": true,
		"element": "water", "pierce": true, "life": 1.2, "kb": 100.0, "hit_fx": "water", "status": [["slow", 3.0, 0.4]]})


func _do_m_meteor(p, s, r):
	_anim(p, "cast", 0.5)
	var pos = p.target_pos(160.0)
	var rad = s["radius"] + r
	Game.telegraph(pos, rad, 0.95, Color(1.0, 0.45, 0.1))
	await p.get_tree().create_timer(0.6).timeout
	var m = Sprite2D.new()
	m.texture = Game.tex("res://assets/spells/meteor.png")
	m.position = pos + Vector2(60, -170)
	m.z_index = 60
	Game.entities.add_child(m)
	var tw = m.create_tween()
	tw.tween_property(m, "position", pos + Vector2(0, -20), 0.35).set_ease(Tween.EASE_IN)
	await tw.finished
	m.queue_free()
	if not is_instance_valid(p):
		return
	Game.spawn_fx("earth", pos, {"scl": rad / 30.0})
	Game.spawn_fx("fire", pos, {"scl": rad / 36.0})
	Game.area_attack(pos, rad, dmg_base(p, "m_meteor"), true, "earth", 260.0, [["burn", 3.0, 0.3], ["stun", 0.6, 0.0]])
	p.shake(5.0)


# ---- Priest
func _do_p_smite(p, s, r):
	_anim(p, "cast", 0.3)
	await _wait(p, 0.1)
	if p.dead:
		return
	var base = dmg_base(p, "p_smite")
	Game.shoot({"position": p.origin() + p.aim * 12.0, "dir": p.aim, "speed": 300.0, "kind": "light", "base": base, "magic": true,
		"element": "light", "life": 1.0, "kb": 90.0, "hit_fx": "light", "heal": base * s["heal"] * (1.0 + p.stats.get("heal_pct", 0.0))})


func _do_p_bless(p, s, r):
	_anim(p, "cast", 0.5)
	await _wait(p, 0.15)
	if p.dead:
		return
	var f = 0.15 + 0.01 * r
	p.add_buff("bless", s["dur"], {"phy_atk_pct": f, "mag_atk_pct": f, "phy_def_pct": f, "mag_def_pct": f, "hp_regen": p.max_hp * 0.01 * (1.0 + r * 0.05)})
	Game.spawn_fx("aura", p.global_position + Vector2(0, -8))
	Game.notify("Blessing: +%d%% Atk/Def" % int(f * 100))


func _do_p_curse(p, s, r):
	_anim(p, "cast", 0.4)
	await _wait(p, 0.1)
	if p.dead:
		return
	var pos = p.target_pos(150.0)
	Game.zone({"position": pos, "radius": s["radius"], "dur": s["dur"], "tick": 0.5, "base": dmg_base(p, "p_curse"), "magic": true, "element": "dark",
		"status": [["vuln", 1.2, 0.25 + 0.005 * r], ["weak", 1.2, 0.30], ["poison", 2.0, 0.3]], "fx": "zone", "tint": Color(0.7, 0.4, 1.0)})


# ---- Common
func _do_c_mend(p, s, r):
	_anim(p, "cast", 0.4)
	var total = (p.max_hp * (0.15 + 0.01 * r) + p.stats["mind"] * 2.0) * (1.0 + p.stats.get("heal_pct", 0.0))
	p.heal_over(total, 4.0)
	Game.spawn_fx("heal", p.global_position + Vector2(0, -6))


# ------------------------------------------------------------------ generic data-driven skills
func _col(a):
	return Color(a[0], a[1], a[2])


func _generic(p, id, s, r):
	var sp = s["spec"]
	var t = sp["t"]
	var base = dmg_base(p, id)
	var magic = s["kind"] == "mag"
	var elem = s["elem"]
	var status = []
	for st in sp.get("status", []):
		status.append([st[0], st[1], st[2]])
	if sp.has("stun"):
		status.append(["stun", sp["stun"] + r * 0.03, 0.0])
	var force = sp.get("crit", false)
	var heal_amt = base * sp.get("heal", 0.0) * (1.0 + p.stats.get("heal_pct", 0.0))
	match t:
		"arc":
			p.start_anim("attack", 0.4)
			await _wait(p, 0.1)
			var hits = int(sp.get("hits", 1))
			for i in range(hits):
				if p.dead:
					return
				var origin = p.origin()
				var n = 0
				for e in Game.enemies_in_arc(origin, p.aim, sp["reach"], sp["arc"]):
					Game.hit(e, Game.roll_damage(p, base, force), origin, sp.get("kb", 100.0), elem, magic, status)
					n += 1
				Game.spawn_fx(sp["fx"], origin + p.aim * sp.get("fxd", 22.0), {"rot": p.aim.angle()})
				if n > 0 and heal_amt > 0.0:
					p.heal(heal_amt)
				if hits > 1:
					p.start_anim("attack", 0.2)
					await p.get_tree().create_timer(sp.get("gap", 0.1) / maxf(p.stats["atk_speed"], 0.5)).timeout
		"nova":
			p.start_anim("cast", 0.4)
			await _wait(p, 0.1)
			if p.dead:
				return
			var n2 = Game.area_attack(p.origin(), sp["radius"], base, magic, elem, sp.get("kb", 100.0), status, force)
			Game.spawn_fx(sp["fx"], p.origin(), {"scl": sp.get("scl", 1.0)})
			if n2 > 0 and heal_amt > 0.0:
				p.heal(heal_amt)
			if sp.has("shake"):
				p.shake(sp["shake"])
		"proj":
			p.start_anim("attack" if s["kind"] == "phy" else "cast", 0.3)
			await _wait(p, 0.1)
			if p.dead:
				return
			var cnt = int(sp.get("n", 1))
			for i in range(cnt):
				var a = p.aim.rotated((i - (cnt - 1) / 2.0) * sp.get("spread", 0.0))
				Game.shoot({"position": p.origin() + a * 10.0, "dir": a, "speed": sp.get("speed", 300.0), "kind": sp["kind"], "base": base,
					"magic": magic, "element": elem, "pierce": sp.get("pierce", false), "aoe": sp.get("aoe", 0.0), "life": sp.get("life", 1.0),
					"kb": sp.get("kb", 90.0), "hit_fx": sp.get("hit_fx", ""), "status": status, "force_crit": force, "heal": heal_amt})
		"tgt":
			p.start_anim("cast", 0.4)
			var center = p.target_pos(sp["range"])
			var count = int(sp.get("count", 1))
			var tcol = _col(sp["tele"]) if sp.has("tele") else Color(1, 0.45, 0.2)
			var spots = []
			for i in range(count):
				var c = center + (Vector2.RIGHT.rotated(randf() * TAU) * randf_range(0.0, sp.get("scatter", 0.0)) if i > 0 or sp.get("scatter", 0.0) > 0.0 else Vector2.ZERO)
				spots.append(c)
				Game.telegraph(c, sp["radius"], sp["delay"] + 0.05, tcol)
			await p.get_tree().create_timer(sp["delay"]).timeout
			if not is_instance_valid(p) or p.dead:
				return
			for c in spots:
				Game.spawn_fx(sp["fx"], c, {"scl": sp["radius"] / 30.0})
				Game.area_attack(c, sp["radius"], base, magic, elem, sp.get("kb", 120.0), status, force)
				if heal_amt > 0.0:
					p.heal(heal_amt)
			p.shake(2.5)
		"zone":
			p.start_anim("cast", 0.4)
			await _wait(p, 0.1)
			if p.dead:
				return
			var pos = p.target_pos(sp["range"]) if sp.get("at", "cursor") == "cursor" else p.global_position
			var tint = _col(sp["tint"]) if sp.has("tint") else Color.WHITE
			Game.zone({"position": pos, "radius": sp["radius"], "dur": sp["dur"], "tick": sp["tick"], "base": base, "magic": magic,
				"element": elem, "status": status, "fx": sp["fx"], "tint": tint, "kb": 10.0})
		"dash", "dashhit":
			p.start_anim("run", 0.25)
			var dir = -p.aim if sp.get("back", false) else p.aim
			var start = p.global_position
			var target = p.dash_target(sp["dist"] + r, dir)
			p.invuln = maxf(p.invuln, sp.get("invuln", 0.3))
			var tw = p.create_tween()
			tw.tween_property(p, "global_position", target, sp.get("dur", 0.16))
			var hit_set = []
			for i in range(6):
				var pt = start.lerp(target, i / 5.0) + Vector2(0, -6)
				Game.ghost_at(p, pt)
				if t == "dashhit":
					for e in Game.enemies_in_circle(pt, 14.0):
						if not hit_set.has(e):
							hit_set.append(e)
							Game.hit(e, Game.roll_damage(p, base, force), pt, 100.0, elem, magic, status)
							Game.spawn_fx("slash", e.global_position + Vector2(0, -8), {"rot": randf() * TAU})
				await p.get_tree().create_timer(sp.get("dur", 0.16) / 5.0).timeout
			if sp.has("buff"):
				var b = sp["buff"]
				p.add_buff(b[0], b[1], b[2])
		"buff":
			p.start_anim("cast", 0.4)
			await _wait(p, 0.1)
			if p.dead:
				return
			var mods = {}
			for k in sp["mods"]:
				mods[k] = sp["mods"][k][0] + sp["mods"][k][1] * (r - 1)
			p.add_buff(sp["id"], sp["dur"] + r * 0.2, mods)
			Game.spawn_fx(sp["fx"], p.global_position + Vector2(0, -8))
			Game.notify("%s!" % s["name"])
		"heal":
			p.start_anim("cast", 0.4)
			var amt = (p.max_hp * (sp["pct"] + sp["per"] * (r - 1)) + p.stats["mind"] * 3.0) * (1.0 + p.stats.get("heal_pct", 0.0))
			p.heal(amt)
			Game.spawn_fx("heal", p.global_position + Vector2(0, -6))
		"cleanse":
			p.start_anim("cast", 0.4)
			p.statuses.clear()
			p.heal(p.max_hp * sp["pct"] * (1.0 + p.stats.get("heal_pct", 0.0)))
			p.add_buff("purify", sp["dur"], {"res_all": sp["res"][0] + sp["res"][1] * (r - 1)})
			Game.spawn_fx("heal", p.global_position + Vector2(0, -6))
			Game.spawn_fx("aura", p.global_position + Vector2(0, -8))
