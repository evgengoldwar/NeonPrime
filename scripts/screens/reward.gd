extends Control
## Награда после боя: шапка с поверженными героями и золотом, затем выбор.
## Сначала (после босса) 1 реликвия из 3, потом 1 карта из 3.
## Выбор — касанием по карточке, подтверждение — одной кнопкой внизу.

const UI := preload("res://scripts/ui/ui.gd")
const RunMenus := preload("res://scripts/ui/run_menus.gd")
const CARD_W := 212

var _sel_relic := ""
var _sel_card := ""


func _ready() -> void:
	_build()


func _build() -> void:
	for ch in get_children():
		ch.queue_free()
	var r: Dictionary = Game.pending
	var choosing_relic: bool = not r.get("relics", []).is_empty() and not r.get("relic_taken", false)
	var lay := UI.screen_layout(self, "Награда")
	var tb := UI.top_bar()
	lay.root.add_child(tb)
	lay.root.move_child(tb, 0)
	var body: VBoxContainer = lay.body
	body.add_child(_header(r))
	if r.get("relic", "") != "":
		body.add_child(_section("Получена реликвия"))
		body.add_child(UI.relic_view(r.relic))
	if choosing_relic:
		_relic_choice(body, lay.footer, r.relics)
	else:
		_card_choice(body, lay.footer, r.get("cards", []))


## Шапка: спрайты поверженных героев, их имена и золото в Казну.
func _header(r: Dictionary) -> Control:
	var p := UI.framed("popup", 14)
	var v := UI.vbox(8)
	p.add_child(v)
	var killed: Array = r.get("killed", [])
	if not killed.is_empty():
		var row := UI.hbox(12)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		var names := []
		for k in killed:
			var spr := UI.hero_icon(k.id, 6)
			spr.modulate = Color(1, 1, 1, 0.9)
			row.add_child(spr)
			names.append(k.name)
		v.add_child(row)
		var title := "Повержен: " if killed.size() == 1 else "Повержены: "
		v.add_child(UI.label(title + ", ".join(names), 24, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	var gold := int(r.get("gold", 0))
	v.add_child(UI.center(UI.stat("coin", "%+d в Казну" % gold, UI.GOLD if gold >= 0 else UI.RED, 32)))
	return p


func _section(text: String) -> Control:
	var l := UI.label(text, 32, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	l.add_theme_font_override("font", UI.pixel_font())
	l.add_theme_font_size_override("font_size", 24)
	return l


# ---------------------------------------------------------------- реликвии

func _relic_choice(body: VBoxContainer, footer: VBoxContainer, relics: Array) -> void:
	body.add_child(_section("Выбери 1 реликвию из %d" % relics.size()))
	var row := UI.hbox(8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for id in relics:
		var card := UI.relic_card(id, id == _sel_relic, CARD_W)
		card.gui_input.connect(_relic_input.bind(id))
		row.add_child(card)
	body.add_child(row)
	body.add_child(UI.label("Коснись реликвии, чтобы выбрать", 16, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	var take := UI.button("Выбери реликвию" if _sel_relic == "" else "Забрать «%s»" % Data.relics[_sel_relic].name, _take_relic, 28, 84)
	take.disabled = _sel_relic == ""
	UI.tint_button(take, UI.GOLD)
	footer.add_child(take)


func _relic_input(ev: InputEvent, id: String) -> void:
	if ev is InputEventMouseButton and ev.pressed:
		_sel_relic = id
		Sfx.play("click")
		_build()


func _take_relic() -> void:
	if _sel_relic == "":
		return
	Game.add_relic(_sel_relic)
	Game.pending["relic_taken"] = true
	Game.save_run()
	Sfx.play("coin")
	Game.main.toast("Реликвия: " + Data.relics[_sel_relic].name)
	_build()


# ---------------------------------------------------------------- карты

func _card_choice(body: VBoxContainer, footer: VBoxContainer, cards: Array) -> void:
	if Game.pending.get("card_taken", false) or cards.is_empty():
		_done()
		return
	body.add_child(_section("Выбери 1 карту в колоду"))
	var row := UI.hbox(8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for id in cards:
		var cv := UI.card_view(id, false, CARD_W, Game.card_level(id))
		if id == _sel_card:
			cv.add_theme_stylebox_override("panel", UI.frame("card_selected", 10))
		cv.mouse_filter = Control.MOUSE_FILTER_STOP
		cv.gui_input.connect(_card_input.bind(id))
		row.add_child(cv)
	body.add_child(row)
	body.add_child(UI.label("Коснись карты, чтобы выбрать", 16, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	var take := UI.button("Выбери карту" if _sel_card == "" else "Взять «%s»" % Data.card_name(_sel_card), _take_card, 28, 84)
	take.disabled = _sel_card == ""
	UI.tint_button(take, UI.GREEN)
	footer.add_child(take)
	var row2 := UI.hbox(8)
	if Game.can_reroll():
		row2.add_child(UI.button("Перебросить", _reroll, 24, 64))
	row2.add_child(UI.button("Колода %d" % Game.run.deck.size(), func(): RunMenus.deck(self), 24, 64))
	row2.add_child(UI.button("Пропустить +30", _skip, 24, 64))
	footer.add_child(row2)


func _card_input(ev: InputEvent, id: String) -> void:
	if ev is InputEventMouseButton and ev.pressed:
		_sel_card = id
		Sfx.play("click")
		_build()


func _take_card() -> void:
	if _sel_card == "":
		return
	Game.add_card(_sel_card)
	Sfx.play("place")
	Game.main.toast("В колоду: " + Data.card_name(_sel_card))
	_done()


func _skip() -> void:
	Game.add_gold(30)
	Sfx.play("coin")
	_done()


func _reroll() -> void:
	_sel_card = ""
	Game.reroll_reward()
	_build()


func _done() -> void:
	Game.node_done()
