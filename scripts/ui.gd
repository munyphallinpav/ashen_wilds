extends Node
## Autoload "UI": small widget factories shared by the HUD and the windows.

func lbl(text, size = 9, color = Color.WHITE):
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 3)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func bar(color, w = 120, h = 9):
	var b = ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(w, h)
	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.6)
	var fg = StyleBoxFlat.new()
	fg.bg_color = color
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fg)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


func style(bg, border, bw = 1):
	var sb = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(2)
	return sb


func slot_panel(sz, border = Color(0.7, 0.7, 0.75, 0.5), bw = 1):
	var p = Panel.new()
	p.custom_minimum_size = Vector2(sz, sz)
	p.size = Vector2(sz, sz)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", style(Color(0.08, 0.08, 0.12, 0.85), border, bw))
	return p


func icon(texture, sz):
	var tr = TextureRect.new()
	tr.texture = texture
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.position = Vector2(2, 2)
	tr.size = Vector2(sz - 4, sz - 4)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


func btn(text, w = 0, h = 20, size = 9):
	var b = Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(w, h)
	b.add_theme_font_size_override("font_size", size)
	return b


func clear(node):
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()


func panel(pos, sz):
	var p = Panel.new()
	p.position = pos
	p.size = sz
	p.visible = false
	return p


func stat_val(k, v):
	if k in ["move_speed"]:
		return "%d%%" % int(v * 100)
	if k in ["atk_speed"]:
		return "%d%%" % int(v * 100)
	if k in ["crit_rate", "crit_dmg", "drop"] or k.begins_with("res_"):
		return "%.1f%%" % v
	if k.ends_with("regen"):
		return "%.1f/s" % v
	return str(int(round(v)))
