extends RefCounted
## Фабрика элементов интерфейса в пиксельном стиле.
## Рамки и кнопки — 9-patch текстуры из assets/sprites/ui, шрифт — Tiny5 (сетка 8 px).

const BG := Color("#16111d")
const PANEL := Color("#241c30")
const PANEL2 := Color("#30264a")
const PANEL3 := Color("#45385a")
const ACCENT := Color("#c159c9")
const GOLD := Color("#feae34")
const SOUL := Color("#2ce8f5")
const TEXT := Color("#f4f0ff")
const DIM := Color("#b9aed2")
const RED := Color("#e43b44")
const GREEN := Color("#63c74d")
const DARK := Color("#9d6bff")
const INK := Color("#18141e")

const FONT_PATH := "res://assets/fonts/Handjet-Regular.ttf"
const PIXEL_FONT_PATH := "res://assets/fonts/Tiny5-Regular.ttf"
const SPR := "res://assets/sprites/"
const FRAME_MARGIN := 6
const COLUMN := 720


# ---------------------------------------------------------------- ресурсы

static func tex(path: String) -> Texture2D:
	if not path.begins_with("res://"):
		path = SPR + path + ".png"
	if ResourceLoader.exists(path):
		return load(path)
	return null


## Основной шрифт для текста: Handjet — высокие чёткие буквы, хорошо читается.
static func font() -> Font:
	var f = load(FONT_PATH)
	if f is FontFile:
		f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		f.hinting = TextServer.HINTING_LIGHT
	return f


## Пиксельный шрифт для крупных заголовков: Tiny5 на сетке 8 px.
static func pixel_font() -> Font:
	var f = load(PIXEL_FONT_PATH)
	if f is FontFile:
		f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		f.hinting = TextServer.HINTING_NONE
		f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	return f


## Размер текста: не меньше 24, чтобы мелкие подписи не сливались.
static func fs(size: int) -> int:
	return maxi(24, size + 4)


## Размер пиксельного заголовка: кратен 8, чтобы Tiny5 оставался чётким.
static func pfs(size: int) -> int:
	return maxi(24, int(round(size / 8.0)) * 8)


# ---------------------------------------------------------------- стили

static func style(bg: Color, _radius: int = 0, border: Color = Color.TRANSPARENT, bw: int = 0, pad: int = 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.anti_aliasing = false
	if bw > 0:
		s.border_color = border
		s.set_border_width_all(2 if bw <= 2 else 4)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad
	s.content_margin_bottom = pad
	return s


## 9-patch из assets/sprites/ui/<name>.png
static func frame(name: String, pad: int = 12) -> StyleBox:
	var t := tex("ui/" + name)
	if t == null:
		return style(PANEL, 0, INK, 2, pad)
	var s := StyleBoxTexture.new()
	s.texture = t
	# Рамки карт: углы 8×8 (×3, мелкие ×2) не растягиваются, узор по краю повторяется.
	var card := name.begins_with("card_") and name != "card_selected"
	var mg := FRAME_MARGIN
	if card:
		mg = 16 if name.ends_with("_small") else 24
	if card:
		s.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
		s.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	s.texture_margin_left = mg
	s.texture_margin_right = mg
	s.texture_margin_top = mg
	s.texture_margin_bottom = mg
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad
	s.content_margin_bottom = pad
	return s


static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = 28
	t.set_color("font_color", "Label", TEXT)
	for cls in ["Button", "CheckButton", "OptionButton"]:
		t.set_color("font_color", cls, TEXT)
		t.set_color("font_hover_color", cls, Color.WHITE)
		t.set_color("font_pressed_color", cls, GOLD)
		t.set_color("font_focus_color", cls, TEXT)
		t.set_color("font_disabled_color", cls, Color("#9a90b0"))
		t.set_color("font_outline_color", cls, INK)
		t.set_constant("outline_size", cls, 6)
	t.set_stylebox("normal", "Button", frame("btn"))
	t.set_stylebox("hover", "Button", frame("btn_hover"))
	t.set_stylebox("pressed", "Button", frame("btn_pressed"))
	t.set_stylebox("disabled", "Button", frame("btn_disabled"))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		t.set_stylebox(st, "CheckButton", StyleBoxEmpty.new())
	t.set_stylebox("normal", "OptionButton", frame("btn"))
	t.set_stylebox("hover", "OptionButton", frame("btn_hover"))
	t.set_stylebox("pressed", "OptionButton", frame("btn_pressed"))
	t.set_stylebox("focus", "OptionButton", StyleBoxEmpty.new())
	t.set_stylebox("panel", "PanelContainer", frame("panel"))
	t.set_stylebox("panel", "PopupMenu", frame("panel"))
	t.set_stylebox("background", "ProgressBar", frame("bar_bg", 0))
	t.set_stylebox("fill", "ProgressBar", frame("bar_hp", 0))
	t.set_stylebox("panel", "TooltipPanel", frame("panel", 8))
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_stylebox("scroll", "VScrollBar", style(Color(0, 0, 0, 0.3), 0, Color.TRANSPARENT, 0, 2))
	t.set_stylebox("grabber", "VScrollBar", style(PANEL3, 0, Color.TRANSPARENT, 0, 4))
	t.set_stylebox("grabber_highlight", "VScrollBar", style(DIM, 0, Color.TRANSPARENT, 0, 4))
	t.set_stylebox("grabber_pressed", "VScrollBar", style(GOLD, 0, Color.TRANSPARENT, 0, 4))
	return t


static func full(c: Control) -> Control:
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.offset_left = 0
	c.offset_top = 0
	c.offset_right = 0
	c.offset_bottom = 0
	return c


# ---------------------------------------------------------------- текст

static func label(text: String, size: int = 24, color: Color = TEXT, align: int = HORIZONTAL_ALIGNMENT_LEFT, wrap: bool = true) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fs(size))
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", INK)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_constant_override("line_spacing", 2)
	l.horizontal_alignment = align
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func title(text: String, size: int = 40) -> Label:
	var l := label(text, size, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	l.add_theme_font_override("font", pixel_font())
	l.add_theme_font_size_override("font_size", pfs(size))
	l.add_theme_color_override("font_outline_color", INK)
	l.add_theme_constant_override("outline_size", 8)
	l.add_theme_color_override("font_shadow_color", Color("#5e3810"))
	l.add_theme_constant_override("shadow_offset_y", 4)
	return l


# ---------------------------------------------------------------- картинки

## Пиксельная картинка, увеличенная в целое число раз.
static func icon(path: String, scale: int = 4) -> TextureRect:
	var r := TextureRect.new()
	var t := tex(path)
	r.texture = t
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var sz := Vector2(12, 12) if t == null else t.get_size()
	r.custom_minimum_size = sz * scale
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func card_icon(id: String, scale: int = 5) -> TextureRect:
	return icon("cards/" + id, scale)


static func hero_icon(id: String, scale: int = 4) -> TextureRect:
	var path := "heroes/" + id
	if tex(path) == null:
		path = "heroes/warrior"
	return icon(path, scale)


## Значок с числом: [♥ 12]
static func stat(icon_name: String, value: String, color: Color = TEXT, size: int = 24) -> HBoxContainer:
	var h := hbox(4)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var i := icon("icons/" + icon_name, 3)
	i.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(i)
	var l := label(value, size, color, HORIZONTAL_ALIGNMENT_LEFT, false)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(l)
	return h


## Плиточный фон (пол или стена локации).
static func tiled(path: String) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex(path)
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.stretch_mode = TextureRect.STRETCH_TILE
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	full(r)
	return r


## Затемнённый фон экрана с плиткой и виньеткой.
static func backdrop(root: Control, tile: String = "tiles/floor_menu", dim: float = 0.55) -> void:
	var t := tiled(tile)
	root.add_child(t)
	var shade := ColorRect.new()
	shade.color = Color(BG, dim)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	full(shade)
	root.add_child(shade)


# ---------------------------------------------------------------- кнопки

static func button(text: String, cb: Callable, size: int = 26, min_h: int = 76) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", fs(size))
	b.custom_minimum_size = Vector2(0, maxi(56, min_h))
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if cb.is_valid():
		b.pressed.connect(cb)
	b.pressed.connect(func(): Sfx.play("click"))
	return b


## Цветная кнопка: красная, зелёная, золотая, фиолетовая или синяя рамка.
static func tint_button(b: Button, color: Color) -> Button:
	var kind := "btn_purple"
	var best := 99.0
	for pair in [[RED, "btn_red"], [GREEN, "btn_green"], [GOLD, "btn_gold"], [ACCENT, "btn_purple"], [SOUL, "btn_blue"]]:
		var c: Color = pair[0]
		var dist := absf(c.r - color.r) + absf(c.g - color.g) + absf(c.b - color.b)
		if dist < best:
			best = dist
			kind = pair[1]
	b.add_theme_stylebox_override("normal", frame(kind))
	b.add_theme_stylebox_override("hover", frame(kind + "_hover"))
	b.add_theme_stylebox_override("pressed", frame("btn_pressed"))
	return b


## Колонка шириной с телефон по центру экрана: на планшете и в горизонтали
## интерфейс не растягивается, а остаётся посередине.
static func column(root: Control, pad: int = 12) -> MarginContainer:
	var m := margin(pad)
	m.anchor_left = 0.5
	m.anchor_right = 0.5
	m.anchor_bottom = 1.0
	m.offset_left = -COLUMN / 2.0
	m.offset_right = COLUMN / 2.0
	root.add_child(m)
	return m


## Кнопка паузы со значком.
static func pause_button(cb: Callable, size: int = 64) -> Button:
	var b := button("", cb, 24, size)
	b.custom_minimum_size = Vector2(size, size)
	b.size_flags_horizontal = Control.SIZE_SHRINK_END
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# Значок по центру с отступом от рамки, а не во всю кнопку.
	var c := CenterContainer.new()
	full(c)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(icon("icons/pause", 3))
	b.add_child(c)
	return b


## Кнопка-картинка (без текста).
static func icon_button(path: String, cb: Callable, scale: int = 3, min_size: int = 64) -> Button:
	var b := button("", cb, 24, min_size)
	b.custom_minimum_size = Vector2(min_size, min_size)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var i := icon(path, scale)
	full(i)
	b.add_child(i)
	return b


# ---------------------------------------------------------------- контейнеры

static func vbox(sep: int = 12) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func hbox(sep: int = 12) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


## Панель. Стандартные цвета дают текстурную рамку, остальные — плоскую пиксельную.
static func panel(bg: Color = PANEL, _radius: int = 0, pad: int = 14, border: Color = Color.TRANSPARENT, bw: int = 0) -> PanelContainer:
	var p := PanelContainer.new()
	var sb: StyleBox
	if border == Color.TRANSPARENT and bg == PANEL:
		sb = frame("panel", pad)
	elif border == Color.TRANSPARENT and bg == PANEL2:
		sb = frame("panel_light", pad)
	elif border == Color.TRANSPARENT:
		sb = style(bg, 0, INK, 2, pad)
	else:
		sb = style(bg, 0, border, bw, pad)
	p.add_theme_stylebox_override("panel", sb)
	return p


static func framed(name: String, pad: int = 14) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", frame(name, pad))
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


static func center(c: Control) -> CenterContainer:
	var cc := CenterContainer.new()
	cc.add_child(c)
	return cc


static func ignore_mouse(n: Node) -> void:
	for ch in n.get_children():
		if ch is Control:
			ch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ignore_mouse(ch)


## Стандартная раскладка экрана: заголовок, прокручиваемое тело, нижняя панель.
static func screen_layout(root: Control, heading: String, tile: String = "tiles/floor_menu") -> Dictionary:
	backdrop(root, tile)
	# Колонка не шире экрана телефона: на широком экране всё остаётся по центру.
	var m := margin(16)
	m.anchor_left = 0.5
	m.anchor_right = 0.5
	m.anchor_bottom = 1.0
	m.offset_left = -COLUMN / 2.0
	m.offset_right = COLUMN / 2.0
	root.add_child(m)
	var v := vbox(14)
	m.add_child(v)
	if heading != "":
		v.add_child(title(heading, 40))
	var sc := scroll()
	v.add_child(sc)
	var body := vbox(12)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(body)
	var footer := vbox(10)
	v.add_child(footer)
	return {"root": v, "body": body, "footer": footer, "scroll": sc}


static func top_bar(show_floor: bool = true) -> PanelContainer:
	var p := framed("panel_dark", 10)
	var h := hbox(24)
	p.add_child(h)
	h.add_child(stat("coin", str(int(Game.run.get("treasury", 0))), GOLD))
	h.add_child(stat("soul", str(int(Game.run.get("souls", 0))), SOUL))
	if show_floor:
		var f := label("ЭТАЖ %d/%d" % [int(Game.run.get("floor", 1)), int(Game.run.get("floors_total", 3))], 24, TEXT, HORIZONTAL_ALIGNMENT_RIGHT, false)
		f.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		f.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		h.add_child(f)
	return p


# ---------------------------------------------------------------- карты

static func card_color(id: String) -> Color:
	return Data.TYPE_COLORS.get(Data.cards.get(id, {}).get("type", "trap"), Color.GRAY)


## Рамка типа карты. small — для мини-карт, клеток боя и значков.
static func card_frame(id: String, small: bool = false) -> String:
	return "card_" + str(Data.cards.get(id, {}).get("type", "trap")) + ("_small" if small else "")


## Значок стоимости: кристалл Тьмы с числом.
static func cost_badge(cost: int, size: int = 24) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(36, 36)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var i := icon("icons/dark", 4)
	i.position = Vector2(2, 2)
	i.size = Vector2(32, 32)
	c.add_child(i)
	var l := label(str(cost), size, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, false)
	l.add_theme_color_override("font_outline_color", INK)
	l.add_theme_constant_override("outline_size", 6)
	l.size = Vector2(36, 36)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	c.add_child(l)
	return c


## Полная карточка (награды, магазин, колода).
static func card_view(id: String, up: bool = false, w: int = 200, lvl: int = 1) -> PanelContainer:
	var d: Dictionary = Data.cdef(id, up, lvl)
	var p := framed(card_frame(id, w < 190), 18 if w >= 280 else 14)
	# Большие карточки (окно карты) ниже: иначе под текстом пустое поле.
	# Высота с запасом под самый длинный текст: все карточки одного размера.
	p.custom_minimum_size = Vector2(w, int(w * (1.15 if w >= 280 else 1.78)))
	var v := vbox(6)
	p.add_child(v)
	# Шапка: стоимость и название в одну строку.
	var top := hbox(6)
	v.add_child(top)
	top.add_child(cost_badge(int(d.cost)))
	var name_text: String = Data.card_name(id, up)
	var nm := label(name_text, _name_size(name_text, w), GREEN if up else TEXT, HORIZONTAL_ALIGNMENT_LEFT, false)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nm.clip_text = true
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nm.custom_minimum_size = Vector2(10, 0)
	top.add_child(nm)
	# Картинка крупная, фон и рамка картинки — цвета редкости.
	var rc: Color = Data.RARITY_COLORS.get(d.rarity, DIM)
	var art := PanelContainer.new()
	art.add_theme_stylebox_override("panel", style(rc.darkened(0.82), 0, rc.darkened(0.25), 2, 4))
	var art_icon := card_icon(id, clampi(w / 30, 5, 12))
	# Запас снизу под табличку уровня, чтобы она не закрывала рисунок.
	art.custom_minimum_size = Vector2(0, art_icon.custom_minimum_size.y + 46)
	var ac := center(art_icon)
	ac.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	ac.custom_minimum_size = Vector2(0, art_icon.custom_minimum_size.y + 6)
	art.add_child(ac)
	# На картинке: слева вверху тип, справа вверху редкость, снизу по центру уровень
	# (PanelContainer уважает флаги размера детей).
	var tic := icon("icons/type_" + str(d.type), 4 if w >= 190 else 3)
	tic.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	tic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	tic.tooltip_text = Data.TYPE_NAMES.get(d.type, "")
	art.add_child(tic)
	var gem := rarity_gem(d.rarity, 4 if w >= 190 else 3)
	gem.size_flags_horizontal = Control.SIZE_SHRINK_END
	gem.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	art.add_child(gem)
	if lvl > 1:
		var lb := level_badge(lvl, 16)
		lb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		lb.size_flags_vertical = Control.SIZE_SHRINK_END
		art.add_child(lb)
	v.add_child(art)
	# Текст не раздувает карточку: все карточки одного размера.
	var txt := label(Data.card_text(id, up, lvl), 20 if w >= 280 else 16, TEXT)
	txt.size_flags_vertical = Control.SIZE_EXPAND_FILL
	txt.max_lines_visible = 6 if w >= 280 else 5
	v.add_child(txt)
	if d.type == "monster":
		var sh := hbox(16)
		sh.add_child(stat("heart", str(int(d.get("hp", 0))), RED))
		sh.add_child(stat("sword", "=Жадн." if d.get("special", "") == "mimic" else str(int(d.get("atk", 0))), TEXT))
		v.add_child(sh)
	ignore_mouse(p)
	p.tooltip_text = Data.card_name(id, up) + "\n" + Data.card_text(id, up, lvl)
	return p


## Размер шрифта названия: длинные названия мельче, чтобы влезали в одну строку.
static func _name_size(text: String, w: int) -> int:
	var base := 24 if w >= 190 else 16
	if w >= 190 and w < 280 and text.length() > 10:
		base = 20 if text.length() <= 13 else 16
	return base


## Камень редкости: серый, синий, фиолетовый, золотой.
static func rarity_gem(rarity: String, scale: int = 3) -> TextureRect:
	var g := icon("rarity/" + rarity, scale)
	g.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	g.tooltip_text = Data.RARITY_NAMES.get(rarity, "")
	return g


## Строка «[значок типа] Ловушка · Обычная» цветом редкости.
static func type_line(type: String, rarity: String, size: int = 16) -> HBoxContainer:
	var h := hbox(4)
	var ic := icon("icons/type_" + type, 2)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ic)
	h.add_child(label("%s · %s" % [Data.TYPE_NAMES.get(type, ""), Data.RARITY_NAMES.get(rarity, "")], size, Data.RARITY_COLORS.get(rarity, DIM), HORIZONTAL_ALIGNMENT_LEFT, false))
	return h


## Компактная карта для руки: стоимость, картинка, название.
static func mini_card(c: Dictionary, w: int, h: int, cost_override: int = -1) -> PanelContainer:
	var up: bool = c.get("up", false) or c.get("temp_up", false)
	var lvl := int(c.get("lvl", 1))
	var d: Dictionary = Data.cdef(c.id, up, lvl)
	var p := framed(card_frame(c.id, true), 10)
	p.custom_minimum_size = Vector2(w, h)
	var v := vbox(2)
	p.add_child(v)
	var cost := cost_override if cost_override >= 0 else int(d.cost)
	var head := hbox(2)
	head.add_child(cost_badge(cost))
	var sp := spacer(0)
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	if lvl > 1:
		head.add_child(level_badge(lvl, 16))
	var gem := rarity_gem(d.rarity, 3)
	gem.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(gem)
	v.add_child(head)
	var ic := card_icon(c.id, 4)
	ic.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(ic)
	var nm := label(Data.card_name(c.id, up), 16, GREEN if up else TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(nm)
	if c.get("temp_up", false):
		p.add_theme_stylebox_override("panel", frame("slot_ok", 6))
	ignore_mouse(p)
	return p


static func relic_view(id: String) -> PanelContainer:
	var r: Dictionary = Data.relics[id]
	var p := framed("panel_light", 12)
	var h := hbox(12)
	p.add_child(h)
	var ic := icon("relics/" + id, 5)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ic)
	var v := vbox(4)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	v.add_child(label(r.name, 24, GOLD))
	v.add_child(label(r.text, 16, TEXT))
	ignore_mouse(p)
	return p


## Откуда реликвия: базовая или из крыла Замка.
static func relic_origin(id: String) -> String:
	var set_id: String = Data.relics[id].get("set", "base")
	if set_id == "base":
		return "Базовая"
	for w in Data.wings:
		if w.id == set_id:
			return "Крыло «%s»" % w.name
	return ""


## Большая карточка реликвии для выбора награды.
static func relic_card(id: String, selected: bool, w: int = 212) -> PanelContainer:
	var r: Dictionary = Data.relics[id]
	var p := framed("card_selected" if selected else "panel_light", 12)
	p.custom_minimum_size = Vector2(w, 0)
	var v := vbox(8)
	p.add_child(v)
	var art := framed("popup" if selected else "panel_dark", 6)
	art.add_child(center(icon("relics/" + id, 7)))
	v.add_child(art)
	v.add_child(label(r.name, 24, GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	var txt := label(r.text, 24, TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	txt.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(txt)
	v.add_child(label(relic_origin(id), 16, DIM, HORIZONTAL_ALIGNMENT_CENTER))
	ignore_mouse(p)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	return p


## Значок уровня карты: «Ур.3».
## Табличка уровня: тёмная пластинка с золотой рамкой и пиксельной цифрой.
## На максимальном уровне — золотая пластинка.
static func level_badge(lvl: int, size: int = 16) -> PanelContainer:
	var maxed := lvl >= Progress.max_level()
	var p := PanelContainer.new()
	var sb := style(Color("#c47b25") if maxed else Color("#18141e"), 0, Color("#ffe08a") if maxed else GOLD, 2, 0)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	sb.shadow_color = Color(0, 0, 0, 0.6)
	sb.shadow_size = 0
	sb.shadow_offset = Vector2(2, 2)
	p.add_theme_stylebox_override("panel", sb)
	var l := Label.new()
	l.text = "УР %d" % lvl
	l.add_theme_font_override("font", pixel_font())
	l.add_theme_font_size_override("font_size", pfs(size))
	l.add_theme_color_override("font_color", Color.WHITE if maxed else GOLD)
	l.add_theme_color_override("font_outline_color", INK)
	l.add_theme_constant_override("outline_size", 4)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


## Полоска прогресса с подписью поверх («12/20»).
static func progress_bar(value: int, total: int, w: int, color: Color, text: String = "", h: int = 26) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(w, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := ColorRect.new()
	bg.color = INK
	full(bg)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(bg)
	var fill := ColorRect.new()
	fill.color = color
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.anchor_bottom = 1.0
	fill.anchor_right = clampf(float(value) / maxf(1.0, float(total)), 0.0, 1.0)
	fill.offset_left = 2
	fill.offset_top = 2
	fill.offset_bottom = -2
	c.add_child(fill)
	var l := label(text if text != "" else "%d/%d" % [value, total], 16, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, false)
	l.add_theme_color_override("font_outline_color", INK)
	l.add_theme_constant_override("outline_size", 4)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	full(l)
	c.add_child(l)
	return c


# ---------------------------------------------------------------- всплывающие окна

## Затемнение + окно по центру. Возвращает {overlay, box, root}.
static func popup(parent: Node, heading: String, close_text: String = "Закрыть") -> Dictionary:
	var ov := ColorRect.new()
	ov.color = Color(0.03, 0.02, 0.05, 0.8)
	full(ov)
	ov.mouse_filter = Control.MOUSE_FILTER_STOP
	ov.z_index = 50   # поверх жетонов героев и факелов коридора
	parent.add_child(ov)
	var m := margin(24)
	full(m)
	ov.add_child(m)
	var cc := CenterContainer.new()
	m.add_child(cc)
	var p := framed("popup", 20)
	p.custom_minimum_size = Vector2(620, 0)
	cc.add_child(p)
	var v := vbox(14)
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
	p.box.add_child(label(text, 24))
	var help: String = Data.keyword_help(text)
	if help != "":
		p.box.add_child(label(help, 16, DIM))


static func card_popup(parent: Node, id: String, up: bool, lvl: int = 1) -> void:
	var p := popup(parent, "")
	p.box.add_child(center(card_view(id, up, 320, lvl)))
	var help: String = Data.keyword_help(Data.card_text(id, up))
	if help != "":
		p.box.add_child(label(help, 16, DIM))
	if not up and Data.cards[id].has("up"):
		p.box.add_child(label("Версия «+»: " + Data.card_text(id, true), 16, GREEN))
