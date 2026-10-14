extends Control
## Замок: крылья (новые Хозяева и карты) и улучшения за Души.

const UI := preload("res://scripts/ui/ui.gd")

var embedded := false   # встроен во вкладку главного меню


func _ready() -> void:
	_build()


func _build() -> void:
	for ch in get_children():
		ch.queue_free()
	var lay := UI.screen_layout(self, "Замок")
	var body: VBoxContainer = lay.body
	body.add_child(UI.center(UI.stat("soul", str(int(Game.meta.souls)), UI.SOUL, 40)))
	body.add_child(UI.label("Крылья", 28, UI.GOLD))
	for w in Data.wings:
		body.add_child(_wing_row(w))
	body.add_child(UI.label("Улучшения", 28, UI.GOLD))
	body.add_child(UI.label("Удобство и разнообразие, а не прямая сила.", 18, UI.DIM))
	for u in Data.upgrades:
		body.add_child(_upgrade_row(u))
	if not embedded:
		lay.footer.add_child(UI.button("Назад", func(): Game.main.goto("menu"), 24, 70))


func _wing_row(w: Dictionary) -> Control:
	var open: bool = Game.wing_unlocked(w.id)
	var p := UI.framed("popup" if open else "panel", 14)
	var outer := UI.hbox(14)
	p.add_child(outer)
	var spr := UI.icon("masters/" + str(w.master), 7)
	spr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if not open:
		spr.modulate = Color(0, 0, 0, 0.8)
	outer.add_child(spr)
	var v := UI.vbox(6)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.add_child(v)
	var h := UI.hbox()
	v.add_child(h)
	var nm := UI.label("Крыло «%s»" % w.name, 26, UI.GOLD if open else UI.TEXT)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(nm)
	if open:
		h.add_child(UI.label("Открыто", 22, UI.GREEN, HORIZONTAL_ALIGNMENT_RIGHT, false))
	v.add_child(UI.label("Хозяин: %s · %s" % [Data.masters[w.master].name, w.theme], 20, UI.DIM))
	var rel := []
	for r in Data.relic_list:
		if r.set == w.id:
			rel.append(r.name)
	v.add_child(UI.label("Реликвии: " + ", ".join(rel), 18, UI.DIM))
	var bh := UI.hbox()
	v.add_child(bh)
	bh.add_child(UI.button("Карты крыла", func(): _show_cards(w), 20, 60))
	if not open:
		var b := UI.button("Открыть: %d Душ" % int(w.cost), func(): _buy_wing(w), 16, 60)
		b.disabled = int(Game.meta.souls) < int(w.cost)
		UI.tint_button(b, UI.SOUL)
		bh.add_child(b)
	return p


func _upgrade_row(u: Dictionary) -> Control:
	var lvl: int = Game.upgrade_level(u.id)
	var costs: Array = u.costs
	var p := UI.framed("panel", 12)
	var h := UI.hbox()
	p.add_child(h)
	var v := UI.vbox(4)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	var lvl_text := ""
	if costs.size() > 1:
		lvl_text = "  (%d/%d)" % [lvl, costs.size()]
	v.add_child(UI.label(u.name + lvl_text, 24, UI.GOLD if lvl > 0 else UI.TEXT))
	v.add_child(UI.label(u.text, 18, UI.DIM))
	if lvl < costs.size():
		var cost := int(costs[lvl])
		var b := UI.button("%d Душ" % cost, func(): _buy_upgrade(u.id, cost), 20, 60)
		b.custom_minimum_size = Vector2(150, 60)
		b.size_flags_horizontal = Control.SIZE_SHRINK_END
		b.disabled = int(Game.meta.souls) < cost
		h.add_child(b)
	else:
		h.add_child(UI.label("Куплено", 20, UI.GREEN, HORIZONTAL_ALIGNMENT_RIGHT, false))
	return p


func _show_cards(w: Dictionary) -> void:
	var p := UI.popup(self, "Карты крыла «%s»" % w.name)
	var grid := GridContainer.new()
	grid.columns = 3
	for c in Data.card_list:
		if c.set == w.id:
			grid.add_child(UI.card_view(c.id, false, 180))
	var sc := UI.scroll()
	sc.custom_minimum_size = Vector2(0, 760)
	sc.add_child(grid)
	p.box.add_child(sc)


func _buy_wing(w: Dictionary) -> void:
	if int(Game.meta.souls) < int(w.cost):
		return
	Game.meta.souls = int(Game.meta.souls) - int(w.cost)
	Game.meta.wings.append(w.id)
	Progress.on_wing(w.id, true)
	Game.save_meta()
	Game.main.toast("Открыто крыло «%s» и Хозяин %s" % [w.name, Data.masters[w.master].name])
	_build()


func _buy_upgrade(id: String, cost: int) -> void:
	if int(Game.meta.souls) < cost:
		return
	Game.meta.souls = int(Game.meta.souls) - cost
	Game.meta.upgrades[id] = Game.upgrade_level(id) + 1
	Game.save_meta()
	_build()
