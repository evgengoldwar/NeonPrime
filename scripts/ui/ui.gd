extends RefCounted
## Фабрика элементов интерфейса. Все экраны собираются кодом из этих кирпичиков.

const BG := Color("#120e1a")
const PANEL := Color("#211a2c")
const PANEL2 := Color("#2e2440")
const PANEL3 := Color("#3c3054")
const ACCENT := Color("#b84ae0")
const GOLD := Color("#f2c443")
const SOUL := Color("#7fd8ff")
const TEXT := Color("#ece4f4")
const DIM := Color("#9a8fab")
const RED := Color("#e05656")
const GREEN := Color("#5cc87a")
const DARK := Color("#9b6bff")


static func style(bg: Color, radius: int = 14, border: Color = Color.TRANSPARENT, bw: int = 0, pad: int = 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	if bw > 0:
		s.border_color = border
		s.set_border_width_all(bw)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad
	s.content_margin_bottom = pad
	return s


static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 24
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(0.55, 0.5, 0.6))
	t.set_stylebox("normal", "Button", style(PANEL2, 14, ACCENT.darkened(0.4), 2, 12))
	t.set_stylebox("hover", "Button", style(PANEL3, 14, ACCENT, 2, 12))
	t.set_stylebox("pressed", "Button", style(ACCENT.darkened(0.3), 14, ACCENT, 2, 12))
	t.set_stylebox("disabled", "Button", style(PANEL.darkened(0.2), 14, Color(0.3, 0.3, 0.3), 2, 12))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_stylebox("panel", "PanelContainer", style(PANEL))
	t.set_stylebox("background", "ProgressBar", style(Color("#0a0810"), 8, Color.TRANSPARENT, 0, 0))
	t.set_stylebox("fill", "ProgressBar", style(RED, 8, Color.TRANSPARENT, 0, 0))
	return t


static func full(c: Control) -> Control:
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.offset_left = 0
	c.offset_top = 0
	c.offset_right = 0
	c.offset_bottom = 0
	return c


static func label(text: String, size: int = 24, color: Color = TEXT, align: int = HORIZONTAL_ALIGNMENT_LEFT, wrap: bool = true) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func title(text: String, size: int = 40) -> Label:
	var l := label(text, size, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	l.add_theme_color_override("font_outline_color", Color("#2a0a3a"))
	l.add_theme_constant_override("outline_size", 6)
	return l


static func button(text: String, cb: Callable, size: int = 26, min_h: int = 76) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.custom_minimum_size = Vector2(0, min_h)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if cb.is_valid():
		b.pressed.connect(cb)
	b.pressed.connect(func(): Sfx.play("click"))
	return b


static func tint_button(b: Button, color: Color) -> Button:
	b.add_theme_stylebox_override("normal", style(color.darkened(0.45), 14, color, 2, 12))
	b.add_theme_stylebox_override("hover", style(color.darkened(0.3), 14, color.lightened(0.2), 2, 12))
	b.add_theme_stylebox_override("pressed", style(color.darkened(0.15), 14, Color.WHITE, 2, 12))
	return b


static func vbox(sep: int = 12) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func hbox(sep: int = 12) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func panel(bg: Color = PANEL, radius: int = 14, pad: int = 14, border: Color = Color.TRANSPARENT, bw: int = 0) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", style(bg, radius, border, bw, pad))
	return p


static func margin(m: int = 16) -> MarginContainer:
	var mc := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		mc.add_theme_constant_override("margin_" + side, m)
	return mc


static func spacer(h: int = 0, expand: bool = false) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	if expand:
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func scroll() -> ScrollContainer:
	var s := ScrollContainer.new()
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	return s


static func ignore_mouse(n: Node) -> void:
	for ch in n.get_children():
		if ch is Control:
			ch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ignore_mouse(ch)


## Стандартная раскладка экрана: заголовок, прокручиваемое тело, нижняя панель.
static func screen_layout(root: Control, heading: String) -> Dictionary:
	var m := margin(16)
	full(m)
	root.add_child(m)
	var v := vbox(14)
	m.add_child(v)
	if heading != "":
		v.add_child(title(heading, 38))
	var sc := scroll()
	v.add_child(sc)
	var body := vbox(12)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(body)
	var footer := vbox(10)
	v.add_child(footer)
	return {"root": v, "body": body, "footer": footer, "scroll": sc}


static func top_bar(show_floor: bool = true) -> PanelContainer:
	var p := panel(PANEL, 12, 10)
	var h := hbox(18)
	p.add_child(h)
	h.add_child(label("Казна: %d" % int(Game.run.get("treasury", 0)), 24, GOLD, HORIZONTAL_ALIGNMENT_LEFT, false))
	h.add_child(label("Души: %d" % int(Game.run.get("souls", 0)), 24, SOUL, HORIZONTAL_ALIGNMENT_LEFT, false))
	if show_floor:
		var f := label("Этаж %d/%d" % [int(Game.run.get("floor", 1)), int(Game.run.get("floors_total", 3))], 24, TEXT, HORIZONTAL_ALIGNMENT_RIGHT, false)
		f.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(f)
	return p


# ---------------------------------------------------------------- карты

static func card_color(id: String) -> Color:
	return Data.TYPE_COLORS.get(Data.cards.get(id, {}).get("type", "trap"), Color.GRAY)


## Полная карточка (награды, магазин, колода). Размер ~ 200×290.
static func card_view(id: String, up: bool = false, w: int = 200) -> PanelContainer:
	var d: Dictionary = Data.cdef(id, up)
	var tc := card_color(id)
	var rc: Color = Data.RARITY_COLORS.get(d.rarity, Color.GRAY)
	var p := panel(Color("#1a1424"), 14, 10, tc, 4)
	p.custom_minimum_size = Vector2(w, int(w * 1.42))
	var v := vbox(6)
	p.add_child(v)
	var top := hbox(6)
	v.add_child(top)
	var cost := panel(DARK.darkened(0.35), 30, 4, DARK, 2)
	cost.custom_minimum_size = Vector2(40, 40)
	var cl := label(str(int(d.cost)), 24, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, false)
	cl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cost.add_child(cl)
	top.add_child(cost)
	var nm := label(Data.card_name(id, up), 22 if w >= 190 else 18, Color.WHITE if not up else GREEN)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(nm)
	v.add_child(label("%s · %s" % [Data.TYPE_NAMES.get(d.type, ""), Data.RARITY_NAMES.get(d.rarity, "")], 16, rc))
	var art := ColorRect.new()
	art.color = tc.darkened(0.6)
	art.custom_minimum_size = Vector2(0, int(w * 0.32))
	v.add_child(art)
	var glyph := label(card_glyph(id), int(w * 0.2), tc.lightened(0.3), HORIZONTAL_ALIGNMENT_CENTER, false)
	glyph.set_anchors_preset(Control.PRESET_FULL_RECT)
	glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	art.add_child(glyph)
	v.add_child(label(Data.card_text(id, up), 17 if w >= 190 else 15, TEXT))
	if d.type == "monster":
		v.add_child(label("HP %d   Атк %s" % [int(d.get("hp", 0)), "Ж" if d.get("special", "") == "mimic" else str(int(d.get("atk", 0)))], 20, RED))
	ignore_mouse(p)
	p.tooltip_text = Data.card_name(id, up) + "\n" + Data.card_text(id, up)
	return p


## Короткий символ для «иллюстрации» карты.
static func card_glyph(id: String) -> String:
	var d: Dictionary = Data.cards.get(id, {})
	var n: String = d.get("name", "?")
	return n.substr(0, 1)


## Компактная карта для руки и клеток коридора.
static func mini_card(c: Dictionary, w: int, h: int, cost_override: int = -1) -> PanelContainer:
	var up: bool = c.get("up", false) or c.get("temp_up", false)
	var d: Dictionary = Data.cdef(c.id, up)
	var tc := card_color(c.id)
	var border := tc
	if c.get("temp_up", false):
		border = GREEN
	var p := panel(tc.darkened(0.7), 10, 6, border, 3)
	p.custom_minimum_size = Vector2(w, h)
	var v := vbox(2)
	p.add_child(v)
	var top := hbox(4)
	v.add_child(top)
	var cost := cost_override if cost_override >= 0 else int(d.cost)
	top.add_child(label(str(cost), 20, DARK.lightened(0.3), HORIZONTAL_ALIGNMENT_LEFT, false))
	var nm := label(Data.card_name(c.id, up), 16, Color.WHITE if not up else GREEN)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(nm)
	var txt := label(Data.card_text(c.id, up), 13, DIM)
	txt.clip_text = true
	txt.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(txt)
	if d.type == "monster":
		v.add_child(label("HP %d Атк %s" % [int(c.get("hp", d.get("hp", 0))), "Ж" if d.get("special", "") == "mimic" else str(int(d.get("atk", 0)))], 16, RED, HORIZONTAL_ALIGNMENT_LEFT, false))
	ignore_mouse(p)
	return p


static func relic_view(id: String) -> PanelContainer:
	var r: Dictionary = Data.relics[id]
	var p := panel(PANEL2, 12, 10, GOLD.darkened(0.3), 2)
	var v := vbox(4)
	p.add_child(v)
	v.add_child(label(r.name, 22, GOLD))
	v.add_child(label(r.text, 18, TEXT))
	ignore_mouse(p)
	return p


# ---------------------------------------------------------------- всплывающие окна

## Затемнение + окно по центру. Возвращает {overlay, box}.
static func popup(parent: Node, heading: String, close_text: String = "Закрыть") -> Dictionary:
	var ov := ColorRect.new()
	ov.color = Color(0, 0, 0, 0.72)
	full(ov)
	ov.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(ov)
	var m := margin(28)
	full(m)
	ov.add_child(m)
	var center := CenterContainer.new()
	m.add_child(center)
	var p := panel(PANEL, 18, 18, ACCENT, 3)
	p.custom_minimum_size = Vector2(600, 0)
	center.add_child(p)
	var v := vbox(12)
	p.add_child(v)
	if heading != "":
		v.add_child(title(heading, 32))
	var body := vbox(10)
	v.add_child(body)
	if close_text != "":
		v.add_child(button(close_text, func(): ov.queue_free()))
	return {"overlay": ov, "box": body, "root": v}


static func info_popup(parent: Node, heading: String, text: String) -> void:
	var p := popup(parent, heading)
	p.box.add_child(label(text, 22))
	var help: String = Data.keyword_help(text)
	if help != "":
		p.box.add_child(label(help, 18, DIM))


static func card_popup(parent: Node, id: String, up: bool) -> void:
	var p := popup(parent, "")
	var c := CenterContainer.new()
	c.add_child(card_view(id, up, 300))
	p.box.add_child(c)
	var help: String = Data.keyword_help(Data.card_text(id, up))
	if help != "":
		p.box.add_child(label(help, 18, DIM))
	if not up and Data.cards[id].has("up"):
		p.box.add_child(label("Версия «+»: " + Data.card_text(id, true), 18, GREEN))
