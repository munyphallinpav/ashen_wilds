extends Control
# Polished resource bar: border, gradient fill, gloss, delayed damage trail, optional text.
var max_value = 100.0
var value = 100.0
var color = Color(0.85, 0.2, 0.2)
var trail_color = Color(1, 0.85, 0.5)
var text = ""
var font_size = 7
var shown = 100.0
var trail = 100.0
var flash = 0.0
var _last = -1.0


func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta):
	if _last < 0.0:
		_last = value
		shown = value
		trail = value
	if value < _last - 0.01:
		flash = 0.25
	_last = value
	shown = move_toward(shown, value, maxf(max_value, 1.0) * 1.5 * delta)
	if trail > shown:
		trail = maxf(shown, trail - maxf(max_value, 1.0) * 0.35 * delta)
	else:
		trail = shown
	flash = maxf(0.0, flash - delta)
	queue_redraw()


func _draw():
	var w = size.x
	var h = size.y
	var mx = maxf(max_value, 1.0)
	draw_rect(Rect2(0, 0, w, h), Color(0.02, 0.02, 0.05, 0.85))
	var iw = w - 2.0
	var ih = h - 2.0
	var tw = iw * clampf(trail / mx, 0.0, 1.0)
	var fw = iw * clampf(shown / mx, 0.0, 1.0)
	if tw > fw:
		draw_rect(Rect2(1, 1, tw, ih), trail_color)
	if fw > 0.0:
		draw_rect(Rect2(1, 1, fw, ih), color.darkened(0.35))
		draw_rect(Rect2(1, 1, fw, ceilf(ih * 0.6)), color)
		draw_rect(Rect2(1, 1, fw, 1), color.lightened(0.55))
		if flash > 0.0:
			draw_rect(Rect2(1, 1, fw, ih), Color(1, 1, 1, flash * 1.6))
	for i in range(1, 4):
		var x = 1.0 + iw * i / 4.0
		draw_line(Vector2(x, h - 2), Vector2(x, h - 1), Color(0, 0, 0, 0.5), 1.0)
	draw_rect(Rect2(0, 0, w, h), Color(0.85, 0.75, 0.45, 0.9), false, 1.0)
	if text != "":
		var f = ThemeDB.fallback_font
		var sz = f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var pos = Vector2((w - sz.x) / 2.0, h / 2.0 + sz.y / 2.0 - 2.0)
		draw_string(f, pos + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0, 0, 0, 0.9))
		draw_string(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1, 1, 1))
