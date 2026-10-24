extends Node
## Autoload "Audio": sound effects + context-aware background music with crossfades.
## Tracks: title, town, wild_day, wild_night, boss, and one per dungeon biome (lava, forest, mushroom, plains, beach, cave).

const TRACKS = ["title", "town", "wild_day", "wild_night", "boss", "lava", "forest", "mushroom", "plains", "beach", "cave"]
var music_vol = 0.7
var sfx_vol = 0.8
var cur = ""
var players = []
var active = 0
var sfx_pool = []
var sfx_cache = {}
var last_play = {}
var t = 0.0
var fade_t = 1.0


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in range(2):
		var p = AudioStreamPlayer.new()
		p.volume_db = -80.0
		add_child(p)
		players.append(p)
	for i in range(14):
		var p = AudioStreamPlayer.new()
		add_child(p)
		sfx_pool.append(p)
	_load_settings()


func _vol_db(v):
	return -80.0 if v <= 0.001 else linear_to_db(v)


func _load_settings():
	if not FileAccess.file_exists(Game.SETTINGS_PATH):
		return
	var f = FileAccess.open(Game.SETTINGS_PATH, FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) == TYPE_DICTIONARY:
		music_vol = float(data.get("music_vol", music_vol))
		sfx_vol = float(data.get("sfx_vol", sfx_vol))


func save_volumes():
	var data = {}
	if FileAccess.file_exists(Game.SETTINGS_PATH):
		var f = FileAccess.open(Game.SETTINGS_PATH, FileAccess.READ)
		var d = JSON.parse_string(f.get_as_text())
		if typeof(d) == TYPE_DICTIONARY:
			data = d
	data["music_vol"] = music_vol
	data["sfx_vol"] = sfx_vol
	var w = FileAccess.open(Game.SETTINGS_PATH, FileAccess.WRITE)
	w.store_string(JSON.stringify(data))


func sfx(name, vol = 1.0, pitch = 1.0, min_gap = 0.05):
	var now = Time.get_ticks_msec() / 1000.0
	if now - last_play.get(name, -10.0) < min_gap:
		return
	last_play[name] = now
	if not sfx_cache.has(name):
		var path = "res://assets/sfx/%s.ogg" % name
		sfx_cache[name] = load(path) if ResourceLoader.exists(path) else null
	var s = sfx_cache[name]
	if s == null or sfx_vol <= 0.001:
		return
	for p in sfx_pool:
		if not p.playing:
			p.stream = s
			p.volume_db = _vol_db(sfx_vol * vol)
			p.pitch_scale = pitch * randf_range(0.94, 1.06)
			p.play()
			return


func _stream(name):
	var s = load("res://assets/music/%s.ogg" % name)
	if s is AudioStreamOggVorbis:
		s = s.duplicate()
		s.loop = true
	return s


func play_music(name):
	if name == cur:
		return
	cur = name
	var old = players[active]
	active = 1 - active
	var np = players[active]
	np.stream = _stream(name)
	np.volume_db = -80.0
	np.play()
	fade_t = 0.0
	if old.playing and old.stream != null:
		pass


func _context():
	var p = Game.player
	if Game.main == null or not is_instance_valid(Game.main) or not Game.main.started or p == null or not is_instance_valid(p) or Game.world == null:
		return "title"
	if Game.cur_dungeon != null:
		if Game.dlayout != null and not Game.cur_dungeon["state"]["boss"] and Game.dlayout.in_arena(p.global_position):
			return "boss"
		return Game.cur_dungeon["biome"]
	var w = Game.world
	if absf(p.position.x - w.spawn_pos.x) < w.TOWN_HX and absf(p.position.y - w.spawn_pos.y) < w.TOWN_HY:
		return "town"
	return "wild_night" if Game.is_night else "wild_day"


func _process(delta):
	t += delta
	if t > 0.5:
		t = 0.0
		var want = _context()
		if want == "boss" and cur != "boss":
			sfx("boss_roar", 0.9)
		play_music(want)
	# crossfade
	fade_t = minf(1.0, fade_t + delta / 1.6)
	var target = _vol_db(music_vol * 0.55)
	var np = players[active]
	var op = players[1 - active]
	if np.playing:
		np.volume_db = lerpf(-60.0, target, fade_t) if music_vol > 0.001 else -80.0
		if fade_t < 1.0:
			np.volume_db = linear_to_db(lerpf(0.001, db_to_linear(target), fade_t))
		else:
			np.volume_db = target if music_vol > 0.001 else -80.0
	if op.playing:
		if fade_t >= 1.0:
			op.stop()
		else:
			op.volume_db = linear_to_db(maxf(0.0001, lerpf(db_to_linear(target), 0.0001, fade_t)))
