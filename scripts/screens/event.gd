extends Control
## Событие: картинка, история и 2–3 варианта с честно показанными последствиями.

const UI := preload("res://scripts/ui/ui.gd")
const RunMenus := preload("res://scripts/ui/run_menus.gd")

const COSTS := {
	"goblin_gambler:play": 10, "mine_collapse:clear": 5, "mirror:break": 8,
	"witch:potion": 12, "ancient_pact:sign": 10,
}

var ev_id := ""
var lay := {}


func _ready() -> void:
	ev_id = Game.pending.get("event", "rat_feast")
	_build()


func _build() -> void:
	for ch in get_children():
		ch.queue_free()
	var e: Dictionary = Data.events[ev_id]
	lay = UI.screen_layout(self, e.name)
	var tb := UI.top_bar()
	lay.root.add_child(tb)
	lay.root.move_child(tb, 0)
	var body: VBoxContainer = lay.body
	var art := UI.panel(Color("#2a1f3a"), 16, 10, UI.ACCENT.darkened(0.3), 2)
	art.custom_minimum_size = Vector2(0, 260)
	var al := UI.label(e.name.substr(0, 1), 140, UI.ACCENT.lightened(0.2), HORIZONTAL_ALIGNMENT_CENTER, false)
	al.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	art.add_child(al)
	body.add_child(art)
	if Game.pending.has("result"):
		body.add_child(UI.label(Game.pending.result, 26, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
		var next := UI.button("Дальше", func(): Game.node_done(), 28, 84)
		UI.tint_button(next, UI.ACCENT)
		lay.footer.add_child(next)
		return
	body.add_child(UI.label(e.text, 24))
	for o in e.options:
		var key: String = ev_id + ":" + o.id
		var p := UI.panel(UI.PANEL2, 12, 10)
		var v := UI.vbox(6)
		p.add_child(v)
		var b := UI.button(o.text, func(): _choose(o.id), 26, 70)
		b.disabled = not _possible(key)
		v.add_child(b)
		v.add_child(UI.label(o.effect, 18, UI.DIM))
		body.add_child(p)


func _possible(key: String) -> bool:
	if COSTS.has(key) and int(Game.run.treasury) <= int(COSTS[key]):
		return false
	if key == "witch:trade" and Game.run.deck.size() < 3:
		return false
	if key == "witch:potion" and Game.upgradable_cards().is_empty():
		return false
	return true


func _choose(option: String) -> void:
	Sfx.play("click")
	if ev_id == "mirror" and option == "copy":
		RunMenus.pick_cards(self, "Скопировать карту", 1, Callable(), _on_copy)
		return
	if ev_id == "witch" and option == "trade":
		RunMenus.pick_cards(self, "Отдать 2 карты", 2, Callable(), _on_trade)
		return
	_set_result(Game.resolve_event(ev_id, option))


func _on_copy(chosen: Array) -> void:
	if chosen.is_empty():
		return
	var c = chosen[0]
	Game.add_card(c.id, c.up)
	_set_result("Отражение становится настоящим: ещё одна карта «%s»." % Data.card_name(c.id, c.up))


func _on_trade(chosen: Array) -> void:
	if chosen.size() < 2:
		return
	for c in chosen:
		Game.remove_deck_card(int(c.uid))
	var rare := []
	for id in Game.card_pool(false):
		if Data.cards[id].rarity == "rare":
			rare.append(id)
	var got = Game.rpick(rare)
	if got != null:
		Game.add_card(got)
	_set_result("Ведьма забирает карты и протягивает новую: «%s»." % Data.card_name(str(got)))


func _set_result(text: String) -> void:
	Game.pending["result"] = text
	Game.save_run()
	if int(Game.run.treasury) <= 0:
		Game.node_done()
		return
	_build()
