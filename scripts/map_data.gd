extends RefCounted
## Fog-of-war map data: one pixel per world tile. Tiles are revealed as the player explores.

const UNKNOWN = Color(0.055, 0.063, 0.094, 1.0)
const REVEAL_RADIUS = 12

var explored = PackedByteArray()
var image
var texture
var last_tile = Vector2i(-9999, -9999)
var count = 0
var land_total = 1


func _init():
	explored.resize(Game.W * Game.H)
	image = Image.create(Game.W, Game.H, false, Image.FORMAT_RGBA8)
	image.fill(UNKNOWN)
	texture = ImageTexture.create_from_image(image)
	land_total = 0
	for t in Game.world.tiles:
		if t >= 2 and t != 9:
			land_total += 1


func tile_color(t, x, y):
	var c = Color(0.4, 0.4, 0.4)
	match t:
		0:
			c = Color(0.15, 0.31, 0.55)
		1:
			c = Color(0.27, 0.51, 0.78)
		2:
			c = Color(0.89, 0.81, 0.58)
		3:
			c = Color(0.38, 0.63, 0.28)
		4:
			c = Color(0.23, 0.44, 0.23)
		5:
			c = Color(0.55, 0.42, 0.26)
		6:
			c = Color(0.48, 0.5, 0.56)
		7:
			c = Color(0.55, 0.38, 0.6)
		8:
			c = Color(0.3, 0.24, 0.24)
		9:
			c = Color(0.9, 0.35, 0.1)
	# subtle checker so large areas do not look flat
	if (x + y) % 2 == 0:
		c = c.darkened(0.04)
	return c


func reveal(world_pos, radius = REVEAL_RADIUS):
	var tx = int(floor(world_pos.x / 16.0))
	var ty = int(floor(world_pos.y / 16.0))
	if Vector2i(tx, ty) == last_tile:
		return
	last_tile = Vector2i(tx, ty)
	var changed = false
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if dx * dx + dy * dy > radius * radius:
				continue
			var x = tx + dx
			var y = ty + dy
			if x < 0 or y < 0 or x >= Game.W or y >= Game.H:
				continue
			var i = y * Game.W + x
			if explored[i] == 0:
				explored[i] = 1
				count += 1
				image.set_pixel(x, y, tile_color(Game.world.tiles[i], x, y))
				changed = true
	if changed:
		texture.update(image)


func is_explored(world_pos):
	var x = int(floor(world_pos.x / 16.0))
	var y = int(floor(world_pos.y / 16.0))
	if x < 0 or y < 0 or x >= Game.W or y >= Game.H:
		return false
	return explored[y * Game.W + x] == 1


func percent():
	var land = 0
	for i in range(explored.size()):
		if explored[i] == 1 and Game.world.tiles[i] >= 2:
			land += 1
	return 100.0 * land / float(land_total)


func to_base64():
	return Marshalls.raw_to_base64(explored)


func load_base64(s):
	var raw = Marshalls.base64_to_raw(s)
	if raw.size() != explored.size():
		return
	explored = raw
	count = 0
	for y in range(Game.H):
		for x in range(Game.W):
			var i = y * Game.W + x
			if explored[i] == 1:
				count += 1
				image.set_pixel(x, y, tile_color(Game.world.tiles[i], x, y))
	texture.update(image)
	last_tile = Vector2i(-9999, -9999)
