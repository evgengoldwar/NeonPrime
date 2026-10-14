class_name UI
extends RefCounted
## Helpers that build neon-styled controls from code.


static func box(color: Color, fill_alpha := 0.10, radius := 22, border := 3, glow := 14) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(color.r * 0.15, color.g * 0.15, color.b * 0.15 + 0.03, 0.55 + fill_alpha)
	s.border_color = color
	s.set_border_width_all(border)
	s.set_corner_radius_all(radius)
	s.shadow_color = Color(color, 0.45)
	s.shadow_size = glow
	s.content_margin_left = 24
	s.content_margin_right = 24
	s.content_margin_top = 14
	s.content_margin_bottom = 14
	return s


static func glow_text(c: Control, color: Color, size: int) -> void:
	c.add_theme_font_size_override("font_size", size)
	c.add_theme_color_override("font_color", color.lightened(0.35))
	c.add_theme_color_override("font_shadow_color", Color(color, 0.85))
	c.add_theme_constant_override("shadow_offset_x", 0)
	c.add_theme_constant_override("shadow_offset_y", 0)
	c.add_theme_constant_override("shadow_outline_size", maxi(4, size / 5))


static func label(text: String, size := 32, color := Neon.CYAN, align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	glow_text(l, color, size)
	return l


static func button(text: String, color := Neon.CYAN, size := 34, min_height := 96, click_sound := true) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, min_height)
	b.focus_mode = Control.FOCUS_NONE
	glow_text(b, color, size)
	b.add_theme_color_override("font_hover_color", color.lightened(0.5))
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(0.4, 0.4, 0.5))
	var normal := box(color)
	var pressed := box(color, 0.35)
	pressed.bg_color = Color(color, 0.35)
	pressed.shadow_size = 26
	var disabled := box(Color(0.35, 0.35, 0.45), 0.0, 22, 2, 0)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", normal)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("hover_pressed", pressed)
	b.add_theme_stylebox_override("disabled", disabled)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	if click_sound:
		b.pressed.connect(func(): Sfx.play("click"))
	return b


static func panel(color := Neon.MAGENTA) -> PanelContainer:
	var p := PanelContainer.new()
	var s := box(color, 0.3, 28, 3, 22)
	s.bg_color = Color(0.03, 0.0, 0.08, 0.94)
	s.content_margin_left = 32
	s.content_margin_right = 32
	s.content_margin_top = 28
	s.content_margin_bottom = 28
	p.add_theme_stylebox_override("panel", s)
	return p


static func slider(value: float, color := Neon.CYAN) -> HSlider:
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(0, 56)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var track := StyleBoxFlat.new()
	track.bg_color = Color(color, 0.18)
	track.set_corner_radius_all(8)
	track.content_margin_top = 6
	track.content_margin_bottom = 6
	var fill := track.duplicate() as StyleBoxFlat
	fill.bg_color = color
	fill.shadow_color = Color(color, 0.6)
	fill.shadow_size = 8
	s.add_theme_stylebox_override("slider", track)
	s.add_theme_stylebox_override("grabber_area", fill)
	s.add_theme_stylebox_override("grabber_area_highlight", fill)
	var knob := _circle_texture(36, color)
	s.add_theme_icon_override("grabber", knob)
	s.add_theme_icon_override("grabber_highlight", knob)
	return s


static func toggle(on: bool, color := Neon.CYAN) -> CheckButton:
	var c := CheckButton.new()
	c.button_pressed = on
	c.focus_mode = Control.FOCUS_NONE
	c.custom_minimum_size = Vector2(96, 56)
	c.add_theme_icon_override("checked", _switch_texture(true, color))
	c.add_theme_icon_override("unchecked", _switch_texture(false, color))
	c.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return c


## Full-screen dimmer with a centred panel; returns [overlay, content_vbox].
static func overlay(parent: Node, color := Neon.MAGENTA) -> Array:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0.02, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 80)
	root.add_child(margin)
	var center := CenterContainer.new()
	margin.add_child(center)
	var p := panel(color)
	p.custom_minimum_size = Vector2(620, 0)
	center.add_child(p)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 22)
	p.add_child(vb)
	return [root, vb]


static func _circle_texture(size: int, color: Color) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := size / 2.0
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5 - c, y + 0.5 - c).length()
			var a := clampf(c - d, 0.0, 1.0)
			var col := Color.WHITE.lerp(color, clampf(d / c, 0.0, 1.0))
			img.set_pixel(x, y, Color(col, a))
	return ImageTexture.create_from_image(img)


static func _switch_texture(on: bool, color: Color) -> ImageTexture:
	var w := 92
	var h := 48
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var r := h / 2.0
	var track := Color(color, 0.85) if on else Color(0.3, 0.3, 0.4, 0.8)
	var knob_x := w - r if on else r
	for y in h:
		for x in w:
			var px := Vector2(x + 0.5, y + 0.5)
			var cx := clampf(px.x, r, w - r)
			var d := px.distance_to(Vector2(cx, r))
			var a := clampf(r - d, 0.0, 1.0)
			var col := track
			var kd := px.distance_to(Vector2(knob_x, r))
			if kd < r - 5.0:
				col = Color.WHITE
			img.set_pixel(x, y, Color(col, a * col.a))
	return ImageTexture.create_from_image(img)
