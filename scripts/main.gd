extends Node
## Spielablauf: Titel, Segeln, Hafen, Kampf, Menüs, Dialoge.

var world: Node3D
var battle: Node3D
var ui: CanvasLayer
var root: Control
var hud: Control
var hud_info: Label
var hud_place: Label
var interact_btn: Button
var toast_label: Label
var touch: Control
var overlay: Control          # aktuelle Karte (Hafen, Menü, Dialog)
var mode := "title"           # title, sail, port, battle, dialog, menu
var touch_state := {}
var _toast_t := 0.0
var _dialog_queue: Array = []
var _dialog_done: Callable
var _last_comp: Array = []
var _last_opt := {}

const KEYS := {
	"up": [KEY_W, KEY_UP], "down": [KEY_S, KEY_DOWN], "left": [KEY_A, KEY_LEFT], "right": [KEY_D, KEY_RIGHT],
	"rise": [KEY_SPACE, KEY_R], "sink": [KEY_SHIFT, KEY_F],
}

const PORT_NAMES := {"hafen": "Möwenruh"}

func _ready() -> void:
	world = preload("res://scripts/world.gd").new(); add_child(world)
	world.encounter.connect(_on_encounter)
	world.interact_changed.connect(_on_interact_changed)
	world.toast.connect(show_toast)
	battle = preload("res://scripts/battle.gd").new(); add_child(battle)
	battle.finished.connect(_on_battle_finished)
	_build_ui()
	get_tree().root.size_changed.connect(_fit_screen); _fit_screen()
	show_title()
	if "--autotest" in OS.get_cmdline_user_args():
		add_child(load("res://tools/autotest.gd").new())

# ---------- Oberfläche ----------
func _fit_screen() -> void:
	## Hochformat am Handy: kleinere Grundfläche, damit die Oberfläche lesbar bleibt
	var w := get_tree().root
	var sz := Vector2(w.size)
	var portrait := sz.x < sz.y
	w.content_scale_size = Vector2i(700, 1100) if portrait else Vector2i(1280, 720)
	if interact_btn:
		interact_btn.offset_top = -300.0 if portrait else -150.0
		interact_btn.offset_bottom = interact_btn.offset_top + 50.0

func _build_ui() -> void:
	ui = CanvasLayer.new(); ui.layer = 10; add_child(ui)
	root = Control.new(); root.set_anchors_preset(Control.PRESET_FULL_RECT); root.theme = UI.build_theme()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE; ui.add_child(root)
	hud = Control.new(); hud.set_anchors_preset(Control.PRESET_FULL_RECT); hud.mouse_filter = Control.MOUSE_FILTER_IGNORE; root.add_child(hud)
	var top := UI.panel(10); top.position = Vector2(12, 10); hud.add_child(top)
	var tv := VBoxContainer.new(); tv.add_theme_constant_override("separation", 2); top.add_child(tv)
	hud_place = UI.label("Saumland", 14, UI.WIND); tv.add_child(hud_place)
	hud_info = UI.label("", 15); hud_info.autowrap_mode = TextServer.AUTOWRAP_OFF; tv.add_child(hud_info)
	var menu_row := HBoxContainer.new(); menu_row.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	menu_row.offset_left = -330; menu_row.offset_right = -12; menu_row.offset_top = 10; menu_row.alignment = BoxContainer.ALIGNMENT_END; hud.add_child(menu_row)
	menu_row.add_child(UI.button("Gruppe", func(): open_party_menu()))
	menu_row.add_child(UI.button("Optionen", func(): open_options()))
	interact_btn = UI.primary(UI.button("", func(): world.interact()))
	interact_btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM); interact_btn.offset_top = -150; interact_btn.offset_bottom = -100
	interact_btn.offset_left = -200; interact_btn.offset_right = 200; interact_btn.visible = false; hud.add_child(interact_btn)
	_build_touch()
	toast_label = UI.label("", 16); toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.set_anchors_preset(Control.PRESET_CENTER_TOP); toast_label.offset_top = 80; toast_label.offset_left = -360; toast_label.offset_right = 360
	toast_label.add_theme_color_override("font_outline_color", UI.NIGHT); toast_label.add_theme_constant_override("outline_size", 8)
	toast_label.modulate.a = 0.0; toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE; root.add_child(toast_label)
	Game.changed.connect(_refresh_hud)

func _build_touch() -> void:
	touch = Control.new(); touch.set_anchors_preset(Control.PRESET_FULL_RECT); touch.mouse_filter = Control.MOUSE_FILTER_IGNORE; hud.add_child(touch)
	var pad := GridContainer.new(); pad.columns = 3; pad.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	pad.offset_left = 16; pad.offset_top = -200; pad.offset_bottom = -16; pad.add_theme_constant_override("h_separation", 6); pad.add_theme_constant_override("v_separation", 6)
	touch.add_child(pad)
	for cell in [["", ""], ["^", "up"], ["", ""], ["<", "left"], ["v", "down"], [">", "right"]]:
		if cell[1] == "":
			var sp := Control.new(); sp.custom_minimum_size = Vector2(62, 62); sp.mouse_filter = Control.MOUSE_FILTER_IGNORE; pad.add_child(sp)
		else: pad.add_child(_hold_btn(cell[0], cell[1]))
	var alt := VBoxContainer.new(); alt.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	alt.offset_left = -96; alt.offset_right = -16; alt.offset_top = -150; alt.offset_bottom = -16; alt.add_theme_constant_override("separation", 6)
	touch.add_child(alt)
	alt.add_child(_hold_btn("Hoch", "rise")); alt.add_child(_hold_btn("Tief", "sink"))

func _hold_btn(text: String, key: String) -> Button:
	var b := Button.new(); b.text = text; b.custom_minimum_size = Vector2(62, 62); b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 20); b.modulate.a = 0.75
	b.button_down.connect(func(): touch_state[key] = true)
	b.button_up.connect(func(): touch_state[key] = false)
	return b

func _refresh_hud() -> void:
	if not hud_info: return
	var lead: Dictionary = Game.party.get("tizian", {})
	var s := Game.stats("tizian") if not lead.is_empty() else {"hp": 0}
	hud_info.text = "Stufe %d   ·   %d Gold   ·   Tizian %d/%d LP" % [Game.lvl, Game.gold, lead.get("hp", 0), s.hp]

func show_toast(text: String) -> void:
	toast_label.text = text; _toast_t = 4.0
	var tw := create_tween(); tw.tween_property(toast_label, "modulate:a", 1.0, 0.25)

func _process(dt: float) -> void:
	if _toast_t > 0.0:
		_toast_t -= dt
		if _toast_t <= 0.0:
			var tw := create_tween(); tw.tween_property(toast_label, "modulate:a", 0.0, 0.5)
	if mode == "sail":
		for k in KEYS:
			var on: bool = touch_state.get(k, false)
			for code in KEYS[k]: on = on or Input.is_physical_key_pressed(code)
			world.input[k] = on
		hud_place.text = _place_name()

func _place_name() -> String:
	var y: float = world.ship.position.y
	if y < -20.0: return "SAUMLAND · TIEFE WOLKEN"
	if y > 18.0: return "SAUMLAND · HOHER WIND"
	return "SAUMLAND"

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		if mode == "sail":
			if e.keycode in [KEY_E, KEY_ENTER]: world.interact()
			elif e.keycode in [KEY_TAB, KEY_M]: open_party_menu()
		elif mode == "dialog" and e.keycode in [KEY_E, KEY_ENTER, KEY_SPACE]:
			_dialog_next()

func _on_interact_changed(text: String) -> void:
	interact_btn.text = text + "   [E]" if text != "" else ""
	interact_btn.visible = text != "" and mode == "sail"

func _set_mode(m: String) -> void:
	mode = m
	world.active = m == "sail"
	world.visible = m != "battle"
	hud.visible = m == "sail"
	if m != "sail":
		for k in world.input: world.input[k] = false
		touch_state.clear()
	interact_btn.visible = m == "sail" and interact_btn.text != ""
	if m == "sail":
		world.cam.current = true
		Sfx.play_music("sail")
	_refresh_hud()

func close_overlay() -> void:
	if overlay and is_instance_valid(overlay): overlay.queue_free()
	overlay = null

func _show_card(width := 560) -> VBoxContainer:
	close_overlay()
	var c := UI.card(width); overlay = c[0]; root.add_child(overlay)
	_fit_later.call_deferred(overlay)
	return c[1]

func _fit_later(bg: Control) -> void:
	if is_instance_valid(bg):
		await get_tree().process_frame
		if is_instance_valid(bg): UI.fit_card(bg)

# ---------- Titel ----------
func show_title() -> void:
	_set_mode("title")
	Sfx.play_music("title")
	world.active = false
	var v := _show_card(520)
	v.add_child(UI.eyebrow("Ein Abenteuer über dem Wolkenmeer"))
	var t := UI.label("Sturmsegel", 44, UI.BRASS); v.add_child(t)
	v.add_child(UI.label("Tizian, Tiago und Valeria segeln mit der Möwe durch das Saumland. Ein Handelskontor greift nach den alten Windherzen, und hinter dem Sturmwall wartet der Rest der Welt.", 16, UI.MUTED))
	v.add_child(UI.hsep())
	var b := UI.primary(UI.button("Neues Spiel", func(): _start_new()))
	v.add_child(b)
	var c := UI.button("Weiterspielen", func(): _continue())
	c.disabled = not Game.has_save(); v.add_child(c)
	v.add_child(UI.label("Steuerung: WASD oder Pfeile zum Segeln, Leertaste hoch, Umschalt tief, E für Aktionen, Tab für die Gruppe. Am Handy die Knöpfe am Rand.", 13, UI.MUTED))
	b.grab_focus.call_deferred()

func _start_new() -> void:
	Game.new_game()
	world.place_ship()
	close_overlay()
	_set_mode("dialog")
	dialog([
		["Erzähler", "Möwenruh, am Rand des Saumlands. Die Möwe liegt im Hafen, die Segel noch feucht vom Morgennebel."],
		["Tiago", "Der Kessel hält, solange niemand drauf tritt. Tizian, du trittst drauf."],
		["Tizian", "Einmal! Das war einmal. Valeria, was sagen deine Karten?"],
		["Valeria", "Dass das Kontor einen Frachter beim Ankerfels liegen hat. Und dass im Gläsernen Turm wieder Licht brennt. Seit hundert Jahren war da niemand."],
		["Tizian", "Dann fangen wir mit dem Frachter an. Wer zuerst da ist, bekommt die Fracht."],
		["Hinweis", "Kämpfe stärken die Windkunde eures gewählten Windsteins. Neue Zauber kommen langsam. Im Hafen könnt ihr gefahrlos üben."],
	], func(): _set_mode("sail"); show_toast("Segelt zum Ankerfels im Westen. Der Kompass ist die Sonne."))

func _continue() -> void:
	if not Game.load_game(): show_toast("Kein Spielstand gefunden."); return
	world.place_ship()
	close_overlay()
	_set_mode("sail")
	show_toast("Willkommen zurück an Deck.")

# ---------- Dialoge ----------
func dialog(lines: Array, done: Callable = Callable()) -> void:
	_dialog_queue = lines.duplicate(); _dialog_done = done
	_set_mode("dialog")
	_dialog_next()

func _dialog_next() -> void:
	if _dialog_queue.is_empty():
		close_overlay()
		var cb := _dialog_done; _dialog_done = Callable()
		if cb.is_valid(): cb.call()
		else: _set_mode("sail")
		return
	var line: Array = _dialog_queue.pop_front()
	close_overlay()
	var bg := Control.new(); bg.set_anchors_preset(Control.PRESET_FULL_RECT); bg.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay = bg; root.add_child(bg)
	bg.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed: _dialog_next())
	var p := UI.panel(18); p.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	p.offset_left = -440; p.offset_right = 440; p.offset_top = -190; p.offset_bottom = -24; bg.add_child(p)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 6); p.add_child(v)
	var who: String = line[0]
	var col: Color = UI.WIND
	if DB.PARTY.has(who.to_lower()): col = DB.PARTY[who.to_lower()].color.lightened(0.4)
	if who == "Hinweis": col = UI.BRASS
	v.add_child(UI.label(who, 15, col))
	v.add_child(UI.label(line[1], 18))
	var more := UI.label("weiter", 12, UI.MUTED); more.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; v.add_child(more)
	await get_tree().process_frame
	if is_instance_valid(p):
		var w := minf(880.0, root.size.x - 24.0); p.offset_left = -w / 2; p.offset_right = w / 2

# ---------- Hafen ----------
func open_port(id: String) -> void:
	Game.last_port = id
	Game.save()
	_set_mode("port")
	Sfx.play_music("port")
	_port_main(id)

func _port_main(id: String) -> void:
	var v := _show_card(560)
	v.add_child(UI.eyebrow("Hafen"))
	v.add_child(UI.label(PORT_NAMES.get(id, id), 30, UI.BRASS))
	v.add_child(UI.label("Der Hafenmeister winkt euch an den Steg. Das Spiel wurde gespeichert.", 15, UI.MUTED))
	v.add_child(UI.hsep())
	v.add_child(UI.button("Gasthaus: ausruhen (10 Gold)", func(): _rest(id)))
	v.add_child(UI.button("Händlerin Ilse: Vorräte und Ausrüstung", func(): _shop(id)))
	v.add_child(UI.button("Übungsplatz: Training für die Windkunde", func(): _training(id)))
	v.add_child(UI.button("Gruppe, Windsteine und Kniffe", func(): open_party_menu(func(): _port_main(id))))
	v.add_child(UI.button("Mit Leuten reden", func(): _port_talk(id)))
	var leave := UI.primary(UI.button("Ablegen", func(): close_overlay(); _set_mode("sail")))
	v.add_child(leave); leave.grab_focus.call_deferred()

func _rest(id: String) -> void:
	if Game.gold < 10: show_toast("Nicht genug Gold."); return
	Game.gold -= 10; Game.heal_all(); Game.save(); Sfx.play("heal")
	show_toast("Alle sind ausgeruht. LP und Äther voll.")
	_port_main(id)

func _port_talk(id: String) -> void:
	var lines := [["Hafenmeister Brun", "Der Kontor-Frachter beim Ankerfels holt sich Fracht, die ihm nicht gehört. Feldwebel Brask führt da das Wort."]]
	if Game.flags.get("frachter_done", false):
		lines = [["Hafenmeister Brun", "Ihr habt Brask zurückgeschickt? Dann redet man in Möwenruh noch lange von euch."],
			["Valeria", "Im Gläsernen Turm brennt immer noch Licht. Östlich von hier."]]
	lines.append(["Fischerin Mara", "Unter den Wolken ist es dunkel und voller Krabben. Wer tief fliegt, findet Ärger. Manchmal auch Schätze."])
	dialog(lines, func(): _set_mode("port"); _port_main(id))

func _shop(id: String) -> void:
	var v := _show_card(620)
	v.add_child(UI.eyebrow("Händlerin Ilse"))
	v.add_child(UI.label("Ihr habt %d Gold." % Game.gold, 18, UI.BRASS))
	var S: Dictionary = DB.PRICES_SHOP.get(id, {"items": [], "equip": []})
	v.add_child(UI.label("Vorräte", 15, UI.WIND))
	for k in S.items:
		var it: Dictionary = DB.ITEMS[k]
		var b := UI.button("%s  ·  %d Gold  ·  im Beutel %d\n%s" % [it.n, it.price, Game.items.get(k, 0), it.d], func(): _buy(id, k, it.price, false))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT; b.disabled = Game.gold < it.price; v.add_child(b)
	v.add_child(UI.label("Ausrüstung", 15, UI.WIND))
	for k in S.equip:
		var q: Dictionary = DB.EQUIP[k]
		var b := UI.button("%s  ·  %d Gold  ·  %s\n%s" % [q.n, q.price, _who(q), q.d], func(): _buy(id, k, q.price, true))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT; b.disabled = Game.gold < q.price; v.add_child(b)
	v.add_child(UI.primary(UI.button("Zurück", func(): _port_main(id))))

func _who(q: Dictionary) -> String:
	if q.who == "alle": return "für alle"
	return "für " + DB.PARTY[q.who].name

func _buy(id: String, k: String, price: int, eq: bool) -> void:
	if Game.gold < price: return
	Game.gold -= price
	if eq: Game.add_equip(k)
	else: Game.add_item(k)
	Sfx.play("chest")
	show_toast("Gekauft: " + (DB.EQUIP[k].n if eq else DB.ITEMS[k].n))
	_shop(id)

func _training(id: String) -> void:
	var v := _show_card(560)
	v.add_child(UI.eyebrow("Übungsplatz"))
	v.add_child(UI.label("Meisterin Okka", 26, UI.BRASS))
	v.add_child(UI.label("Hier kämpft ihr gegen Übungsgegner. Es gibt kein Gold und nur halbe Erfahrung, dafür doppelte Windkunde für den angelegten Windstein. Niederlagen kosten nichts. Wer vor einem Bosskampf trainiert, kennt seine Zauber.", 15, UI.MUTED))
	v.add_child(UI.hsep())
	v.add_child(UI.button("Leichtes Training (Quallen und Möwen)", func(): _start_training(id, "saum")))
	var deep := UI.button("Schweres Training (Krabben und Raben)", func(): _start_training(id, "saum_tief"))
	deep.disabled = Game.lvl < 3
	if deep.disabled: deep.text += "  ·  ab Stufe 3"
	v.add_child(deep)
	v.add_child(UI.primary(UI.button("Zurück", func(): _port_main(id))))

func _start_training(id: String, pool: String) -> void:
	var comp: Array = DB.POOLS[pool].pick_random()
	start_battle(comp, {"title": "Übungskampf", "training": true, "intro": "Meisterin Okka gibt das Zeichen.", "return_port": id})

# ---------- Kampf ----------
func _on_encounter(pool: String) -> void:
	if mode != "sail": return
	Sfx.play("enc")
	var comp: Array = DB.POOLS[pool].pick_random()
	start_battle(comp, {"title": "Begegnung" if pool == "saum" else "Aus der Tiefe"})

func start_battle(comp: Array, o: Dictionary) -> void:
	_last_comp = comp; _last_opt = o
	close_overlay()
	_set_mode("battle")
	battle.start(comp, o)

func _on_battle_finished(result: String, info: Dictionary) -> void:
	var training: bool = _last_opt.get("training", false)
	match result:
		"win": _win_card(info)
		"flee":
			battle.stop(); show_toast("Ihr seid entkommen.")
			_after_battle()
		"lose":
			await get_tree().create_timer(1.2).timeout
			var v := _show_card(480)
			v.add_child(UI.eyebrow("Niederlage"))
			v.add_child(UI.label("Die Möwe treibt im Wind", 26, UI.KONTOR))
			if training:
				v.add_child(UI.label("Meisterin Okka hilft euch auf. Im Training kostet eine Niederlage nichts.", 15, UI.MUTED))
				v.add_child(UI.primary(UI.button("Weiter", func(): battle.stop(); Game.heal_all(); _after_battle())))
			else:
				v.add_child(UI.label("Ihr könnt den Kampf neu beginnen oder im letzten Hafen aufwachen. Dort verliert ihr die Hälfte eures Golds.", 15, UI.MUTED))
				v.add_child(UI.primary(UI.button("Kampf wiederholen", func(): _retry())))
				v.add_child(UI.button("Im Hafen aufwachen", func(): _wake_in_port()))

func _retry() -> void:
	if not Game.load_game(): Game.heal_all()
	battle.stop()
	start_battle(_last_comp, _last_opt)

func _wake_in_port() -> void:
	battle.stop()
	Game.gold = int(Game.gold / 2.0); Game.heal_all()
	Game.ship = {"x": 8.0, "z": 52.0, "h": PI, "y": 2.0}
	world.place_ship()
	open_port(Game.last_port)

func _win_card(info: Dictionary) -> void:
	var v := _show_card(520)
	v.add_child(UI.eyebrow("Sieg"))
	v.add_child(UI.label("+%d Erfahrung   +%d Gold" % [info.xp, info.gold], 22, UI.BRASS))
	for l in info.ups: v.add_child(UI.label("Die Gruppe erreicht Stufe %d!" % l, 17, Color("93d48b")))
	for l in info.learned: v.add_child(UI.label(l, 18, UI.WIND))
	for l in info.wk: v.add_child(UI.label(l, 14, UI.MUTED))
	if not info.loot.is_empty():
		var names := []
		for k in info.loot: names.append(DB.ITEMS[k].n)
		v.add_child(UI.label("Beute: " + ", ".join(names), 15))
	if info.get("fragments", 0) > 0: v.add_child(UI.label("+%d Kniff-Fragment" % info.fragments, 15, UI.BRASS))
	if info.has("equip"): v.add_child(UI.label("Erhalten: " + DB.EQUIP[info.equip].n, 17, UI.BRASS))
	var b := UI.primary(UI.button("Weiter", func(): battle.stop(); _after_battle()))
	v.add_child(b); b.grab_focus.call_deferred()

func _after_battle() -> void:
	close_overlay()
	var port: String = _last_opt.get("return_port", "")
	var then: Callable = _last_opt.get("then", Callable())
	if then.is_valid(): then.call(); return
	if port != "":
		_set_mode("port"); Sfx.play_music("port"); _training(port)
	else: _set_mode("sail")

# ---------- Orte ----------
func discover(k: String) -> void:
	Game.disc[k] = true
	Sfx.play("chest")
	match k:
		"glocke":
			Game.add_item("windbeere")
			dialog([["Erzähler", "Auf dem Glockenfels hängt eine alte Sturmglocke, grün vom Wetter. Darunter liegt ein Beutel mit einer Windbeere."],
				["Valeria", "Die Glocke haben die ersten Segler gegossen, um einander im Nebel zu finden. Das trage ich in die Karte ein."],
				["Hinweis", "Entdeckung eingetragen. Eine Windbeere gibt +2 Wind-EP in jedem Element."]])
		_: dialog([["Erzähler", "Ihr tragt die Insel in Valerias Karte ein."]])
	Game.fame += 5

func enter_dungeon(id: String) -> void:
	match id:
		"frachter":
			if Game.flags.get("frachter_done", false):
				show_toast("Der Frachter ist leer. Nur noch Taue und Möwen."); return
			dialog([["Erzähler", "Der Kontor-Frachter hängt schwer im Wind. Wachen auf dem Oberdeck, Kanonen offen."],
				["Tiago", "Wir gehen über die Ankerkette. Leise. Also ohne Tizian."],
				["Hinweis", "Die Gänge des Frachters kommen in der nächsten Version. Jetzt geht es direkt zum Kampf gegen Feldwebel Brask."]],
				func(): start_battle(["matrose", "feldwebel", "matrose"], {"title": "Feldwebel Brask", "boss": true, "no_flee": true, "fragments": 1, "equip": "sturmharpune",
					"then": func(): _after_frachter()}))
		"turm": show_toast("Die Tür des Gläsernen Turms ist versiegelt. Der Weg hinein kommt in der nächsten Version.")
		"klippe": show_toast("Fallwinde drücken die Möwe von den Höhlen weg. Die Rabenklippe kommt in der nächsten Version.")

func _after_frachter() -> void:
	Game.flags["frachter_done"] = true; Game.fame += 20; Game.save()
	dialog([["Feldwebel Brask", "Das Kontor vergisst nicht. Ihr segelt auf geliehener Zeit."],
		["Tizian", "Dann zahlen wir sie zurück, mit Zinsen."],
		["Valeria", "In seiner Kajüte lag eine Karte. Der Gläserne Turm ist rot eingekreist."],
		["Hinweis", "Tizian hat die Sturmharpune erhalten. Legt sie im Gruppenmenü an."]])

# ---------- Gruppe ----------
func open_party_menu(back: Callable = Callable()) -> void:
	var prev := mode
	if mode == "sail": _set_mode("menu")
	var ret := back if back.is_valid() else func(): close_overlay(); _set_mode("sail" if prev in ["sail", "menu"] else prev)
	_party_overview(ret)

func _party_overview(ret: Callable) -> void:
	var v := _show_card(680)
	v.add_child(UI.eyebrow("Die Gruppe der Möwe"))
	v.add_child(UI.label("Stufe %d  ·  %d / %d EP  ·  %d Gold  ·  %d Kniff-Fragmente" % [Game.lvl, Game.xp, DB.xp_need(Game.lvl), Game.gold, Game.fragments], 15, UI.MUTED))
	for id in DB.PARTY_ORDER:
		var p: Dictionary = DB.PARTY[id]; var c: Dictionary = Game.party[id]; var s := Game.stats(id)
		var row := UI.panel(10); v.add_child(row)
		var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 10); row.add_child(h)
		var info := VBoxContainer.new(); info.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(info)
		info.add_child(UI.label(p.name, 19, p.color.lightened(0.45)))
		info.add_child(UI.label("LP %d/%d  ·  Äther %d/%d  ·  Angriff %d  ·  Schutz %d  ·  Tempo %d" % [c.hp, s.hp, c.mp, s.mp, s.atk, s.def, s.spd], 13, UI.MUTED))
		info.add_child(UI.label("Windstein: %s  ·  Waffe: %s" % [DB.ELEM_NAME[c.el], DB.EQUIP[c.weapon].n], 13, DB.ELEM_COLOR[c.el]))
		var bx := VBoxContainer.new(); h.add_child(bx)
		bx.add_child(UI.button("Windkunde", func(): _wk_menu(id, ret)))
		bx.add_child(UI.button("Ausrüstung", func(): _equip_menu(id, ret)))
		bx.add_child(UI.button("Kniffe", func(): _kniff_menu(id, ret)))
	var row2 := HBoxContainer.new(); v.add_child(row2)
	row2.add_child(UI.button("Beutel", func(): _bag_menu(ret)))
	var b := UI.primary(UI.button("Zurück", ret)); b.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row2.add_child(b)
	b.grab_focus.call_deferred()

func _wk_menu(id: String, ret: Callable) -> void:
	var v := _show_card(640)
	var c: Dictionary = Game.party[id]
	v.add_child(UI.eyebrow("Windkunde"))
	v.add_child(UI.label(DB.PARTY[id].name, 24, UI.BRASS))
	v.add_child(UI.label("Der angelegte Windstein bestimmt das Element der Angriffe und welche Windkunde nach jedem Kampf wächst. Zauber werden selbst zu Übung: jeder Zauber gibt ein wenig Wind-EP in seinem Element.", 14, UI.MUTED))
	for e in DB.ELEMENTS:
		var cur := float(Game.wk[id][e]); var nx := Game.wk_next(id, e)
		var line := HBoxContainer.new(); line.add_theme_constant_override("separation", 8); v.add_child(line)
		var b := UI.button(("• " if c.el == e else "") + DB.ELEM_NAME[e], func(): c.el = e; Game.changed.emit(); _wk_menu(id, ret), 130)
		b.add_theme_color_override("font_color", DB.ELEM_COLOR[e]); line.add_child(b)
		var col := VBoxContainer.new(); col.size_flags_horizontal = Control.SIZE_EXPAND_FILL; line.add_child(col)
		var pb := ProgressBar.new(); pb.show_percentage = false; pb.custom_minimum_size.y = 10
		var prev := 0.0
		for pair in DB.WK[e]:
			if cur >= pair[1]: prev = pair[1]
		pb.min_value = prev; pb.max_value = nx[1] if not nx.is_empty() else prev + 1; pb.value = cur if not nx.is_empty() else pb.max_value
		var fill := StyleBoxFlat.new(); fill.bg_color = DB.ELEM_COLOR[e]; fill.set_corner_radius_all(4); pb.add_theme_stylebox_override("fill", fill)
		col.add_child(pb)
		var known := []
		for pair in DB.WK[e]:
			if cur >= pair[1]: known.append(DB.SPELL[pair[0]].n)
		var txt := "%s Wind-EP" % snappedf(cur, 0.1)
		if not nx.is_empty(): txt += "  ·  nächster Zauber bei %d: %s" % [nx[1], "???" if cur < nx[1] * 0.5 else DB.SPELL[nx[0]].n]
		if not known.is_empty(): txt += "\nBekannt: " + ", ".join(known)
		col.add_child(UI.label(txt, 13, UI.MUTED))
	v.add_child(UI.primary(UI.button("Zurück", func(): _party_overview(ret))))

func _equip_menu(id: String, ret: Callable) -> void:
	var v := _show_card(600)
	var c: Dictionary = Game.party[id]
	v.add_child(UI.eyebrow("Ausrüstung"))
	v.add_child(UI.label(DB.PARTY[id].name, 24, UI.BRASS))
	for slot in ["weapon", "armor", "amulet"]:
		var cur: String = c.get(slot, "")
		var sname: String = {"weapon": "Waffe", "armor": "Rüstung", "amulet": "Schmuck"}[slot]
		v.add_child(UI.label("%s: %s" % [sname, DB.EQUIP[cur].n if cur != "" else "nichts"], 16, UI.WIND))
		if cur != "": v.add_child(UI.label(DB.EQUIP[cur].d, 13, UI.MUTED))
		for k in Game.equip_bag:
			var q: Dictionary = DB.EQUIP[k]
			if q.slot != slot or not (q.who == "alle" or q.who == id): continue
			var b := UI.button("Anlegen: %s (%dx)  ·  %s" % [q.n, Game.equip_bag[k], q.d], func(): Game.equip(id, k); Sfx.play("chest"); _equip_menu(id, ret))
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT; v.add_child(b)
		if cur != "" and slot != "weapon":
			v.add_child(UI.button("Ablegen", func(): Game.unequip(id, slot); _equip_menu(id, ret)))
	v.add_child(UI.primary(UI.button("Zurück", func(): _party_overview(ret))))

func _kniff_menu(id: String, ret: Callable) -> void:
	var v := _show_card(600)
	v.add_child(UI.eyebrow("Kniffe"))
	v.add_child(UI.label(DB.PARTY[id].name, 24, UI.BRASS))
	v.add_child(UI.label("Kniffe kosten im Kampf Schwung. Neue Kniffe lernt man nur mit Kniff-Fragmenten, die Bosse und seltene Truhen hergeben. Ihr habt %d." % Game.fragments, 14, UI.MUTED))
	for k in DB.PARTY[id].kniffe:
		var K: Dictionary = DB.KNIFF[k]
		var has: bool = Game.kniffe[id].has(k)
		if has: v.add_child(UI.label("• %s  ·  %d Schwung  ·  %s" % [K.n, K.c, K.d], 15))
		else: v.add_child(UI.label("%s  ·  %d Fragment(e)" % [K.n if k == Game.can_unlock_kniff(id) else "???", K.fr], 15, UI.MUTED))
	var nx := Game.can_unlock_kniff(id)
	if nx != "":
		var b := UI.primary(UI.button("%s lernen (%d Fragmente)" % [DB.KNIFF[nx].n, DB.KNIFF[nx].fr], func():
			if Game.unlock_kniff(id): Sfx.play("levelup"); show_toast("%s lernt %s!" % [DB.PARTY[id].name, DB.KNIFF[nx].n])
			_kniff_menu(id, ret)))
		b.disabled = Game.fragments < DB.KNIFF[nx].fr; v.add_child(b)
	v.add_child(UI.button("Zurück", func(): _party_overview(ret)))

func _bag_menu(ret: Callable) -> void:
	var v := _show_card(600)
	v.add_child(UI.eyebrow("Beutel"))
	var any := false
	for k in Game.items:
		if Game.items[k] <= 0: continue
		any = true
		var it: Dictionary = DB.ITEMS[k]
		v.add_child(UI.label("%s x%d  ·  %s" % [it.n, Game.items[k], it.d], 15))
		if it.tg == "dead": continue
		var h := HBoxContainer.new(); v.add_child(h)
		for id in DB.PARTY_ORDER:
			h.add_child(UI.button(DB.PARTY[id].name, func(): _use_item(k, id); _bag_menu(ret)))
	if not any: v.add_child(UI.label("Der Beutel ist leer.", 15, UI.MUTED))
	v.add_child(UI.primary(UI.button("Zurück", func(): _party_overview(ret))))

func _use_item(k: String, id: String) -> void:
	if Game.items.get(k, 0) <= 0: return
	var it: Dictionary = DB.ITEMS[k]; var c: Dictionary = Game.party[id]; var s := Game.stats(id)
	if it.has("heal"): c.hp = mini(s.hp, c.hp + it.heal)
	if it.has("mp_gain"): c.mp = mini(s.mp, c.mp + it.mp_gain)
	if it.has("wk_all"):
		var neu := []
		for e in DB.ELEMENTS: neu.append_array(Game.wk_gain(id, e, it.wk_all / DB.PARTY[id].wk_rate))
		for n in neu: show_toast("%s lernt %s!" % [DB.PARTY[id].name, DB.SPELL[n].n])
	Game.items[k] -= 1
	if Game.items[k] <= 0: Game.items.erase(k)
	Sfx.play("heal"); Game.changed.emit()

# ---------- Optionen ----------
func open_options() -> void:
	var prev := mode
	_set_mode("menu")
	var v := _show_card(460)
	v.add_child(UI.eyebrow("Optionen"))
	v.add_child(UI.button("Musik: " + ("an" if Sfx.music_on else "aus"), func(): Sfx.toggle_music(); _set_mode(prev); open_options()))
	v.add_child(UI.label("Begegnungen", 15, UI.WIND))
	var h := HBoxContainer.new(); v.add_child(h)
	for r in ["Häufig", "Normal", "Selten", "Aus"]:
		var b := UI.button(("• " if Game.enc_rate == r else "") + r, func(): Game.enc_rate = r; _set_mode(prev); open_options())
		h.add_child(b)
	v.add_child(UI.button("Speichern", func(): Game.save(); show_toast("Gespeichert.")))
	v.add_child(UI.button("Zum Titel", func(): Game.save(); show_title()))
	v.add_child(UI.primary(UI.button("Weiter segeln", func(): close_overlay(); _set_mode("sail"))))
