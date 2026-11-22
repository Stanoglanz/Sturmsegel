extends Node3D
## Rundenkampf: Befehle für alle planen, Ablauf nach Tempo, geteilter Schwung.

signal finished(result: String, info: Dictionary)

const MAX_SCHWUNG := 15

var cam: Camera3D
var env: Environment
var stage: Node3D
var units: Array = []
var schwung := 4
var round_no := 0
var phase := "plan"         # plan, run, over
var plan_i := 0
var opt := {}
var shield := false
var taunt_id := ""
var casts := {}             # id -> {el: Anzahl}
var cam_goal_pos := Vector3(9, 8, 21)
var cam_goal_look := Vector3(-1, 4, -3)
var cam_look := Vector3(-1, 4, -3)
var shake := 0.0
var t := 0.0
var pending := {}           # Plan, der noch ein Ziel braucht
var gen := 0                # Kampfnummer, beendet alte Abläufe

# Oberfläche
var ui: CanvasLayer
var enemy_row: HBoxContainer
var party_row: HBoxContainer
var schwung_bar: HBoxContainer
var log_label: Label
var head_label: Label
var menu: VBoxContainer
var stone_row: HBoxContainer
var title_label: Label
var banner: Label

func _ready() -> void:
	_build_scene()
	_build_ui()
	visible = false
	ui.visible = false

# ---------- Szene ----------
func _build_scene() -> void:
	env = Environment.new()
	var sky := Sky.new(); var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color("2a64b0"); sm.sky_horizon_color = Color("cfe2f2"); sm.ground_horizon_color = Color("e8eef4"); sm.ground_bottom_color = Color("ffffff")
	sky.sky_material = sm; env.background_mode = Environment.BG_SKY; env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY; env.ambient_light_energy = 0.9; env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true; env.fog_light_color = Color("e6eef6"); env.fog_density = 0.004
	pass
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-50, 30, 0); sun.light_energy = 1.1; sun.shadow_enabled = true; sun.directional_shadow_max_distance = 80
	add_child(sun)
	var fill := DirectionalLight3D.new(); fill.rotation_degrees = Vector3(-25, 200, 0); fill.light_energy = 0.4; add_child(fill)
	cam = Camera3D.new(); cam.fov = 48; cam.position = cam_goal_pos; add_child(cam); cam.environment = env
	stage = Node3D.new(); add_child(stage)
	var planks := Models.mat(Color("b8885a"), 0.9)
	stage.add_child(Models.mesh(_box(Vector3(30, 1.2, 28)), planks, Vector3(0, -0.6, 0)))
	stage.add_child(Models.mesh(_box(Vector3(31, 5, 29)), Models.mat(Color("8b5a32")), Vector3(0, -3.8, 0)))
	for z in range(-13, 14, 3):
		stage.add_child(Models.mesh(_box(Vector3(30, 0.05, 0.12)), Models.mat(Color("7a5232")), Vector3(0, 0.03, z)))
	for sx in [-1, 1]:
		stage.add_child(Models.mesh(_box(Vector3(0.4, 0.4, 28)), Models.mat(Color("6b4a33")), Vector3(sx * 15, 1.6, 0)))
		for z in range(-13, 14, 3):
			stage.add_child(Models.cyl(0.15, 0.15, 1.6, Color("6b4a33"), Vector3(sx * 15, 0.8, z), 6))
	var mast := Models.kit("mast-ropes"); mast.scale = Vector3.ONE * 3.2; mast.position = Vector3(-11, 0, -9); stage.add_child(mast)
	for i in 3:
		var b := Models.kit("barrel"); b.scale = Vector3.ONE * 1.6; b.position = Vector3(11 + (i % 2) * 2.0, 0, -11 + i * 1.6); stage.add_child(b)
	for sx in [-1, 1]:
		var c := Models.kit("cannon"); c.scale = Vector3.ONE * 2.0; c.position = Vector3(sx * 13.5, 0, 6); c.rotation.y = sx * PI / 2; stage.add_child(c)
	var cr := Models.kit("crate"); cr.scale = Vector3.ONE * 1.8; cr.position = Vector3(12, 0, 10); stage.add_child(cr)
	# Wolken rundherum
	var puff := SphereMesh.new(); puff.radius = 1; puff.height = 1.4; puff.radial_segments = 8; puff.rings = 4
	var pm := StandardMaterial3D.new(); pm.albedo_color = Color.WHITE; pm.emission_enabled = true; pm.emission = Color(0.18, 0.18, 0.24)
	var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.mesh = puff; mm.instance_count = 220
	for i in 220:
		var a := randf() * TAU; var d := 45.0 + randf() * 160.0; var k := 5.0 + randf() * 9.0
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3(k * 1.6, k * 0.7, k)), Vector3(cos(a) * d, -22.0 + randf() * 40.0, sin(a) * d)))
	var mi := MultiMeshInstance3D.new(); mi.multimesh = mm; mi.material_override = pm; add_child(mi)

func _box(s: Vector3) -> BoxMesh:
	var b := BoxMesh.new(); b.size = s; return b

# ---------- Oberfläche ----------
func _build_ui() -> void:
	ui = CanvasLayer.new(); ui.layer = 5; add_child(ui)
	var root := Control.new(); root.set_anchors_preset(Control.PRESET_FULL_RECT); root.theme = UI.build_theme(); root.mouse_filter = Control.MOUSE_FILTER_IGNORE; ui.add_child(root)
	var shade := TextureRect.new(); var gt := GradientTexture2D.new(); var gr := Gradient.new()
	gr.offsets = PackedFloat32Array([0.0, 0.25, 0.5, 0.72, 1.0])
	gr.colors = PackedColorArray([Color(0.05, 0.09, 0.16, 0.75), Color(0.05, 0.09, 0.16, 0.0), Color(0.05, 0.09, 0.16, 0.0), Color(0.05, 0.09, 0.16, 0.85), Color(0.05, 0.09, 0.16, 0.95)])
	gt.gradient = gr; gt.fill_from = Vector2(0, 0); gt.fill_to = Vector2(0, 1); shade.texture = gt; shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.set_anchors_preset(Control.PRESET_FULL_RECT); shade.mouse_filter = Control.MOUSE_FILTER_IGNORE; root.add_child(shade)
	var v := VBoxContainer.new(); v.set_anchors_preset(Control.PRESET_FULL_RECT); v.add_theme_constant_override("separation", 8)
	v.offset_left = 14; v.offset_right = -14; v.offset_top = 10; v.offset_bottom = -10; v.mouse_filter = Control.MOUSE_FILTER_IGNORE; root.add_child(v)
	var head := HBoxContainer.new(); v.add_child(head)
	title_label = UI.label("Kampf", 22, UI.BRASS); head.add_child(title_label)
	head_label = UI.label("", 14, UI.MUTED); head_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL; head_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; head.add_child(head_label)
	enemy_row = HBoxContainer.new(); enemy_row.alignment = BoxContainer.ALIGNMENT_CENTER; enemy_row.add_theme_constant_override("separation", 8); v.add_child(enemy_row)
	var spacer := Control.new(); spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL; spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE; v.add_child(spacer)
	log_label = UI.label("", 16); log_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	log_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8)); log_label.add_theme_constant_override("shadow_offset_y", 1); v.add_child(log_label)
	party_row = HBoxContainer.new(); party_row.alignment = BoxContainer.ALIGNMENT_CENTER; party_row.add_theme_constant_override("separation", 8); v.add_child(party_row)
	var sh := HBoxContainer.new(); sh.alignment = BoxContainer.ALIGNMENT_CENTER; v.add_child(sh)
	sh.add_child(UI.label("SCHWUNG", 12, UI.MUTED))
	schwung_bar = HBoxContainer.new(); schwung_bar.add_theme_constant_override("separation", 3); sh.add_child(schwung_bar)
	stone_row = HBoxContainer.new(); stone_row.alignment = BoxContainer.ALIGNMENT_CENTER; v.add_child(stone_row)
	menu = VBoxContainer.new(); menu.add_theme_constant_override("separation", 6); menu.alignment = BoxContainer.ALIGNMENT_CENTER; v.add_child(menu)
	banner = UI.label("", 40, UI.BRASS); banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.set_anchors_preset(Control.PRESET_CENTER_TOP); banner.offset_top = 150; banner.offset_left = -400; banner.offset_right = 400
	banner.add_theme_color_override("font_outline_color", UI.NIGHT); banner.add_theme_constant_override("outline_size", 10); banner.modulate.a = 0.0
	root.add_child(banner)

# ---------- Start ----------
func start(comp: Array, o: Dictionary) -> void:
	opt = o; gen += 1
	for c in stage.get_children(): pass
	for u in units:
		if is_instance_valid(u.get("model")): u.model.queue_free()
	units = []; casts = {}; schwung = 4; round_no = 0; shield = false; taunt_id = ""
	for id in DB.PARTY_ORDER:
		var p: Dictionary = DB.PARTY[id]; var s := Game.stats(id); var c: Dictionary = Game.party[id]
		var u := {"id": id, "name": p.name, "side": "ally", "hp": c.hp, "max": s.hp, "mp": c.mp, "mmax": s.mp, "atk": s.atk, "def": s.def, "spd": s.spd, "wil": s.wil,
			"el": c.el, "res": s.res, "st": {}, "buff": {}, "plan": {}, "spells": Game.known_spells(id), "kniffe": Game.kniffe[id].duplicate()}
		units.append(u)
	var cnt := {}; var seen := {}
	for ty in comp: cnt[ty] = cnt.get(ty, 0) + 1
	for ty in comp:
		var e: Dictionary = DB.ENEMY[ty]; seen[ty] = seen.get(ty, 0) + 1
		var suf: String = (" " + "ABCD"[seen[ty] - 1]) if cnt[ty] > 1 else ""
		units.append({"id": "%s%d" % [ty, seen[ty]], "type": ty, "name": e.n + suf, "side": "enemy", "hp": e.hp, "max": e.hp, "atk": e.atk, "def": e.def, "spd": e.spd,
			"weak": e.weak, "res": e.res, "moves": e.moves, "boss": e.get("boss", false), "st": {}, "buff": {}})
	var allies := alive("ally", true); var foes := alive("enemy", true)
	for i in allies.size():
		var u: Dictionary = allies[i]; var m := Models.party_model(u.id)
		m.position = Vector3((i - 1) * 5.5, 0, 7.5); m.rotation.y = PI; add_child(m); u.model = m
		if u.hp <= 0: m.rotation.x = -PI / 2
	for i in foes.size():
		var u: Dictionary = foes[i]; var m := Models.enemy_model(u.type)
		var sp := 0.0 if foes.size() == 1 else (i - (foes.size() - 1) / 2.0) * 6.5
		m.position = Vector3(sp, 14, -6.5 - (2.0 if u.boss else 0.0)); add_child(m); u.model = m
		var tw := create_tween(); tw.tween_property(m, "position:y", 0.0, 0.55 + i * 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	title_label.text = opt.get("title", "Kampf")
	visible = true; ui.visible = true; cam.current = true
	cam.position = Vector3(0, 30, 40); cam_reset()
	Sfx.play_music("boss" if opt.get("boss", false) else "battle")
	set_log("[b]%s[/b] stellt sich euch entgegen!" % opt.title if opt.get("boss", false) else opt.get("intro", "Gegner greifen an!"))
	begin_round()

func stop() -> void:
	gen += 1; phase = "over"
	visible = false; ui.visible = false
	for u in units:
		if is_instance_valid(u.get("model")): u.model.queue_free()
	units = []

func alive(side: String, all := false) -> Array:
	var r := []
	for u in units:
		if u.side == side and (all or u.hp > 0): r.append(u)
	return r

func uid(id: String) -> Dictionary:
	for u in units:
		if u.id == id: return u
	return {}

# ---------- Runde ----------
func begin_round() -> void:
	round_no += 1; phase = "plan"; shield = false; taunt_id = ""
	for u in alive("ally"): u.plan = {}
	plan_i = 0
	_skip_unable()
	head_label.text = "Runde %d · Befehle planen" % round_no
	render()

func _skip_unable() -> void:
	var al := alive("ally")
	while plan_i < al.size() and _cannot_act(al[plan_i]):
		al[plan_i].plan = {"type": "none"}; plan_i += 1

func _cannot_act(u: Dictionary) -> bool:
	return u.st.has("schlaf") or u.st.has("erstarrt")

func planner() -> Dictionary:
	var al := alive("ally")
	return al[plan_i] if phase == "plan" and plan_i < al.size() else {}

func reserved_schwung() -> int:
	var s := 0
	for u in alive("ally"):
		if u.plan.get("type", "") == "kniff": s += DB.KNIFF[u.plan.key].c
		if u.plan.get("type", "") == "focus": s -= 0
	return s

func items_reserved(k: String) -> int:
	var n := 0
	for u in alive("ally"):
		if u.plan.get("type", "") == "item" and u.plan.key == k: n += 1
	return n

func set_plan(p: Dictionary) -> void:
	var u := planner(); if u.is_empty(): return
	u.plan = p; pending = {}; plan_i += 1; _skip_unable()
	if plan_i >= alive("ally").size(): run_round()
	else: render()

func back() -> void:
	pending = {}
	if plan_i == 0: render(); return
	var al := alive("ally")
	plan_i -= 1
	while plan_i > 0 and al[plan_i].plan.get("type", "") == "none" and _cannot_act(al[plan_i]): plan_i -= 1
	al[plan_i].plan = {}
	render()

func auto_rest() -> void:
	while phase == "plan" and not planner().is_empty():
		var u := planner(); var tg := _best_target(u.el)
		set_plan({"type": "attack", "target": tg.id, "el": u.el})

func _best_target(el: String) -> Dictionary:
	var best := {}
	for e in alive("enemy"):
		if best.is_empty() or (e.weak == el and _known(e.type, el)) or (e.hp < best.hp and best.weak != el): best = e
	return best

func _known(type: String, el: String) -> bool:
	return Game.flags.get("known_%s_%s" % [type, el], false)

func _know(type: String, el: String) -> void:
	Game.flags["known_%s_%s" % [type, el]] = true

func flee() -> void:
	if opt.get("boss", false) or opt.get("no_flee", false):
		set_log("Vor diesem Gegner gibt es kein Entkommen!"); return
	phase = "over"
	if randf() < 0.75:
		set_log("Ihr entkommt in die Wolken."); _store_party(false)
		await get_tree().create_timer(0.8).timeout
		finished.emit("flee", {})
	else:
		set_log("Die Flucht misslingt!")
		for u in alive("ally"): u.plan = {"type": "none"}
		phase = "run"; await _execute_round()

func run_round() -> void:
	phase = "run"; head_label.text = "Runde %d · Aktionen laufen" % round_no; render()
	await _execute_round()

func _execute_round() -> void:
	var order := []
	for u in units:
		if u.hp > 0: order.append(u)
	for u in order:
		var p: Dictionary = u.get("plan", {})
		var first: bool = p.get("type", "") == "guard" or (p.get("type", "") == "kniff" and DB.KNIFF[p.key].get("first", false))
		var slow: bool = p.get("type", "") == "kniff" and DB.KNIFF[p.key].get("slow", false)
		var spd: float = u.spd * (1.5 if u.buff.has("spd") else 1.0)
		u.ord = (1000.0 if first else 0.0) - (1000.0 if slow else 0.0) + spd + randf() * 4.0
	order.sort_custom(func(a, b): return a.ord > b.ord)
	var g := gen
	for u in order:
		if g != gen: return
		if u.hp <= 0 or _check_end(): continue
		if u.st.has("schlaf"):
			set_log("[b]%s[/b] schläft." % u.name); await _wait(0.6); continue
		if u.st.has("erstarrt"):
			set_log("[b]%s[/b] ist erstarrt." % u.name); u.st.erase("erstarrt"); await _wait(0.6); continue
		if u.st.has("laehmung") and randf() < 0.5:
			set_log("[b]%s[/b] ist gelähmt." % u.name); await _wait(0.6); continue
		if u.side == "ally": await _do_ally(u)
		else: await _do_enemy(u)
		if g != gen: return
		render(); await _wait(0.35)
	if g != gen: return
	if _check_end():
		await _wait(0.5)
		if g != gen: return
		await _end_battle(alive("enemy").is_empty()); return
	# Rundenende: Gift, Regeneration, Puffer
	for u in units:
		if u.hp <= 0: continue
		if u.st.has("gift"):
			var d := maxi(1, int(u.max * 0.08)); u.hp = maxi(1, u.hp - d); _pop(u, "Gift %d" % d, UI.KONTOR)
		if u.buff.has("regen"): _heal(u, int(u.max * 0.12))
		for k in u.buff.keys():
			u.buff[k] -= 1
			if u.buff[k] <= 0: u.buff.erase(k)
		if u.st.has("schwaeche"):
			u.st.schwaeche -= 1
			if u.st.schwaeche <= 0: u.st.erase("schwaeche")
		if u.st.has("stumm") and randf() < 0.35: u.st.erase("stumm")
		if u.st.has("laehmung") and randf() < 0.4: u.st.erase("laehmung")
		if u.st.has("schlaf") and randf() < 0.3: u.st.erase("schlaf")
	schwung = mini(MAX_SCHWUNG, schwung + alive("ally").size())
	cam_reset()
	begin_round()

func _check_end() -> bool:
	return alive("enemy").is_empty() or alive("ally").is_empty()

func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout

# ---------- Aktionen der Gruppe ----------
func _do_ally(u: Dictionary) -> void:
	var p: Dictionary = u.plan
	match p.get("type", ""):
		"attack":
			var tg := _retarget(p.target, "enemy"); if tg.is_empty(): return
			set_log("[b]%s[/b] greift %s an." % [u.name, tg.name])
			await _anim_attack(u, tg); _physical(u, tg, 1.0, p.el)
		"focus":
			focus_on(u.model); _burst(u.model.position + Vector3(0, 2, 0), UI.WIND)
			schwung = mini(MAX_SCHWUNG, schwung + 3); set_log("[b]%s[/b] sammelt sich. +3 Schwung." % u.name); await _wait(0.4)
		"guard":
			set_log("[b]%s[/b] geht in Abwehr." % u.name)
		"kniff": await _do_kniff(u, p)
		"spell": await _do_spell(u, p)
		"item": await _do_item(u, p)

func _do_kniff(u: Dictionary, p: Dictionary) -> void:
	var K: Dictionary = DB.KNIFF[p.key]
	if schwung < K.c:
		set_log("[b]%s[/b] fehlt der Schwung für %s." % [u.name, K.n]); return
	schwung -= K.c; render()
	var el: String = p.get("el", u.el) if K.get("use_el", false) else K.get("el", u.el)
	await _special_intro(u, K.n, el)
	if K.get("group", false):
		set_log("[b]%s![/b] Alle greifen gemeinsam an." % K.n)
		cam_to(Vector3(18, 14, 14), Vector3(0, 2, -4))
		for a in alive("ally"): _burst(a.model.position + Vector3(0, 3, 0), DB.ELEM_COLOR[el])
		await _wait(0.5)
		for tg in alive("enemy"): _burst(tg.model.position + Vector3(0, 3, 0), DB.ELEM_COLOR[el], 70)
		shake = 0.5; await _wait(0.3)
		for tg in alive("enemy"): _deal(u, tg, K.fixed * (1.0 + 0.12 * (Game.lvl - 1)) * randf_range(0.95, 1.05), el)
		return
	if K.get("shield", false):
		shield = true; set_log("[b]%s![/b] Halber Schaden für alle diese Runde." % K.n); return
	if K.get("taunt", false):
		taunt_id = u.id; set_log("[b]%s![/b] %s zieht alle Angriffe auf sich." % [K.n, u.name]); return
	if K.get("scan", false):
		for e in alive("enemy"): _know(e.type, e.weak); _know(e.type, e.res)
		set_log("[b]%s:[/b] Alle Schwächen und Resistenzen sind sichtbar." % K.n); render(); return
	if K.get("rally", false):
		for a in alive("ally"): a.buff["atk"] = 3
		set_log("[b]%s![/b] Angriff der Gruppe steigt." % K.n); return
	if K.has("heal"):
		for a in alive("ally"):
			_heal(a, K.heal)
			if K.get("cure", false): a.st = {}
		return
	if K.has("mp_gain"):
		for a in alive("ally"): a.mp = mini(a.mmax, a.mp + K.mp_gain); _pop(a, "+%d Äther" % K.mp_gain, UI.WIND)
		return
	if K.tg == "enemies":
		set_log("[b]%s![/b]" % K.n); await _anim_cast(u, alive("enemy"), el)
		for tg in alive("enemy"):
			if K.has("fixed"): _deal(u, tg, K.fixed * u.wil, el)
			else: _physical(u, tg, K.mul, el)
			if K.has("st"): _try_status(tg, K.st)
		return
	var tg2 := _retarget(p.get("target", ""), "enemy"); if tg2.is_empty(): return
	if K.get("crit", false): el = tg2.weak; _know(tg2.type, el)
	set_log("[b]%s![/b] %s trifft %s." % [K.n, u.name, tg2.name])
	await _anim_attack(u, tg2); _physical(u, tg2, K.mul, el)

func _do_spell(u: Dictionary, p: Dictionary) -> void:
	var S: Dictionary = DB.SPELL[p.key]
	if u.st.has("stumm"):
		set_log("[b]%s[/b] ist verstummt und kann nicht zaubern." % u.name); return
	if u.mp < S.mp:
		set_log("[b]%s[/b] hat nicht genug Äther." % u.name); return
	u.mp -= S.mp
	if not casts.has(u.id): casts[u.id] = {}
	casts[u.id][S.el] = casts[u.id].get(S.el, 0) + 1
	if S.mp >= 18: await _special_intro(u, S.n, S.el)
	set_log("[b]%s[/b] wirkt %s." % [u.name, S.n])
	var targets := []
	match S.tg:
		"enemies": targets = alive("enemy")
		"allies": targets = alive("ally")
		"enemy": targets = [_retarget(p.get("target", ""), "enemy")]
		_: targets = [uid(p.get("target", ""))]
	targets = targets.filter(func(x): return not x.is_empty())
	await _anim_cast(u, targets, S.el)
	var lv := 1.0 + 0.08 * (Game.lvl - 1)
	for tg in targets:
		if S.has("pow"):
			var d := _deal(u, tg, S.pow * u.wil * lv * randf_range(0.95, 1.05), S.el)
			if S.has("drain") and d > 0: _heal(u, int(d * S.drain))
		if S.has("st"): _try_status(tg, S.st)
		if S.has("heal"): _heal(tg, int(S.heal * u.wil * lv))
		if S.get("cure", false) and tg.hp > 0: tg.st = {}; _pop(tg, "Geheilt", Color("93d48b"))
		if S.has("revive") and tg.hp <= 0:
			tg.hp = int(tg.max * S.revive); _stand_up(tg); _pop(tg, "Wach!", Color("93d48b"))
		if S.has("buff"):
			if S.buff == "all": tg.buff["atk"] = 3; tg.buff["def"] = 3
			else: tg.buff[S.buff] = 3
		if S.get("regen", false): tg.buff["regen"] = 3
	if S.get("shield", false): shield = true; set_log("[b]%s![/b] Halber Schaden für die Gruppe." % S.n)
	render()

func _do_item(u: Dictionary, p: Dictionary) -> void:
	var I: Dictionary = DB.ITEMS[p.key]
	if Game.items.get(p.key, 0) <= 0: return
	var tg := uid(p.target); if tg.is_empty(): return
	Game.items[p.key] -= 1
	set_log("[b]%s[/b] benutzt %s." % [u.name, I.n]); focus_on(u.model, tg.model); await _wait(0.3)
	if I.has("heal") and tg.hp > 0: _heal(tg, I.heal)
	if I.has("mp_gain") and tg.hp > 0: tg.mp = mini(tg.mmax, tg.mp + I.mp_gain); _pop(tg, "+%d Äther" % I.mp_gain, UI.WIND)
	if I.get("cure", false) and tg.hp > 0: tg.st = {}; _pop(tg, "Geheilt", Color("93d48b"))
	if I.has("revive") and tg.hp <= 0: tg.hp = int(tg.max * I.revive); _stand_up(tg); _pop(tg, "Wach!", Color("93d48b"))

func _retarget(id: String, side: String) -> Dictionary:
	var tg := uid(id)
	if not tg.is_empty() and tg.hp > 0: return tg
	var a := alive(side)
	return {} if a.is_empty() else a[randi() % a.size()]

# ---------- Gegner ----------
func _do_enemy(u: Dictionary) -> void:
	var tot := 0
	for m in u.moves: tot += m.w
	var r := randi() % tot; var mv: Dictionary = u.moves[0]
	for m in u.moves:
		r -= m.w
		if r < 0: mv = m; break
	var targets := []
	if mv.get("all", false): targets = alive("ally")
	else:
		var tg := uid(taunt_id) if taunt_id != "" else {}
		if tg.is_empty() or tg.hp <= 0:
			var al := alive("ally"); tg = al[randi() % al.size()]
		targets = [tg]
	set_log("[b]%s[/b]: %s" % [u.name, mv.n])
	if mv.get("all", false): await _anim_cast(u, targets, "")
	else: await _anim_attack(u, targets[0])
	for tg in targets:
		if mv.p > 0:
			var def: float = tg.def * (1.4 if tg.buff.has("def") else 1.0)
			var base: float = u.atk * randf_range(0.9, 1.1) * mv.p - def * 0.5
			if tg.get("plan", {}).get("type", "") == "guard": base *= 0.5
			_deal(u, tg, maxf(1.0, base), "")
		if mv.has("st"): _try_status(tg, mv.st)

# ---------- Schaden ----------
func _elem_mul(tg: Dictionary, el: String) -> float:
	if el == "": return 1.0
	if tg.side == "ally": return 0.5 if tg.get("res", "") == el else 1.0
	_know(tg.type, el)
	if el == tg.weak: return 1.5
	if el == tg.res: return 0.5
	return 1.0

func _physical(u: Dictionary, tg: Dictionary, mul: float, el: String) -> int:
	var def: float = tg.def * (0.5 if tg.st.has("schwaeche") else 1.0)
	var atk: float = u.atk * (1.25 if u.buff.has("atk") else 1.0)
	return _deal(u, tg, maxf(1.0, atk * randf_range(0.9, 1.1) * mul - def * 0.5), el)

func _deal(src: Dictionary, tg: Dictionary, amount: float, el: String) -> int:
	if tg.hp <= 0: return 0
	var m := _elem_mul(tg, el); var d := amount * m
	if tg.side == "ally":
		if shield: d *= 0.5
		if tg.buff.has("def"): d *= 0.75
	var di := maxi(1, int(round(d))); tg.hp = maxi(0, tg.hp - di)
	tg.st.erase("schlaf")
	var tag := ""
	if m > 1.0:
		tag = "Schwäche! "
		if src.get("side", "") == "ally": schwung = mini(MAX_SCHWUNG, schwung + 1)
	elif m < 1.0: tag = "Resistent "
	Sfx.play("hit"); _flash(tg.model)
	_pop(tg, tag + str(di), Color("ffd27a") if m > 1.0 else (UI.MUTED if m < 1.0 else Color.WHITE))
	if tg.hp <= 0:
		tg.st = {}; _knock_out(tg)
	render()
	return di

func _heal(tg: Dictionary, amt: int) -> void:
	if tg.hp <= 0: return
	var h := mini(amt, tg.max - tg.hp); tg.hp += h
	Sfx.play("heal"); _pop(tg, "+%d" % h, Color("93d48b")); _burst(tg.model.position + Vector3(0, 2, 0), Color("93d48b"), 25)
	render()

func _try_status(tg: Dictionary, st: Array) -> void:
	if tg.hp <= 0 or randf() > st[1]: return
	if tg.get("boss", false) and st[0] != "schwaeche" and randf() < 0.6: return
	tg.st[st[0]] = 3 if st[0] == "schwaeche" else 1
	_pop(tg, DB.STATUS_NAME[st[0]], Color("c9a2ff"))

# ---------- Ende ----------
func _store_party(recover: bool) -> void:
	for u in alive("ally", true):
		var c: Dictionary = Game.party[u.id]; c.el = u.el
		c.hp = clampi(u.hp + (int(u.max * 0.25) if recover else 0), 1, u.max)
		c.mp = mini(u.mmax, u.mp + (int(u.mmax * 0.2) if recover else 0))

func _end_battle(win: bool) -> void:
	phase = "over"; render()
	if not win:
		Sfx.play_music(""); Sfx.play("ko")
		cam_to(Vector3(0, 7, 16), Vector3(0, 3, 4))
		finished.emit("lose", {}); return
	Sfx.fanfare(); set_log("[b]Sieg![/b]")
	var my_gen := gen
	await _victory_pose()
	if my_gen != gen: return
	var info := {"xp": 0, "gold": 0, "loot": [], "learned": [], "wk": [], "ups": [], "fragments": 0}
	var training: bool = opt.get("training", false)
	var xp0 := 0; var g := 0
	for e in alive("enemy", true):
		xp0 += DB.ENEMY[e.type].xp; g += DB.ENEMY[e.type].g
	var gold_mul := 1.0
	for id in DB.PARTY_ORDER: gold_mul += Game.stats(id).gold
	info.xp = int(xp0 * (0.5 if training else 1.0)); info.gold = 0 if training else int(g * gold_mul)
	Game.gold += info.gold
	_store_party(true)
	info.ups = Game.gain_xp(info.xp)
	var wk_base := minf(10.0, maxf(1.0, round(xp0 / 14.0))) * (2.0 if training else 1.0)
	for u in alive("ally"):
		var neu: Array = Game.wk_gain(u.id, u.el, wk_base)
		for e in casts.get(u.id, {}): neu.append_array(Game.wk_gain(u.id, e, casts[u.id][e] * 0.4))
		info.wk.append("%s +%s %s" % [u.name, snappedf(wk_base * DB.PARTY[u.id].wk_rate, 0.1), DB.ELEM_NAME[u.el]])
		for k in neu: info.learned.append("%s lernt %s!" % [u.name, DB.SPELL[k].n])
	if not training:
		for e in alive("enemy", true):
			var r := randf()
			if r < 0.2: info.loot.append("trank")
			elif r < 0.27: info.loot.append("kraut")
			elif r < 0.29: info.loot.append("windbeere")
		for k in info.loot: Game.add_item(k)
	if opt.has("fragments"):
		Game.fragments += opt.fragments; info.fragments = opt.fragments
	if opt.has("equip"):
		Game.add_equip(opt.equip); info.equip = opt.equip
	if not info.learned.is_empty() or not info.ups.is_empty(): Sfx.play("levelup")
	finished.emit("win", info)

func _victory_pose() -> void:
	var al := alive("ally")
	cam_to(Vector3(0, 4.2, -1.5), Vector3(0, 2.6, 7.5))
	for u in al:
		var tw := create_tween(); tw.tween_property(u.model, "rotation:y", 0.0, 0.6)
	await _wait(0.5)
	for j in 2:
		for i in al.size():
			var m: Node3D = al[i].model
			var tw := create_tween(); tw.tween_property(m, "position:y", 1.4 + i * 0.2, 0.2).set_ease(Tween.EASE_OUT); tw.tween_property(m, "position:y", 0.0, 0.22).set_ease(Tween.EASE_IN)
			for a in m.get_meta("arms", []): a.rotation.x = -2.8
		await _wait(0.45)
	for u in al: _burst(u.model.position + Vector3(0, 3.5, 0), UI.BRASS)
	await _wait(0.5)

# ---------- Animationen ----------
func cam_to(pos: Vector3, look: Vector3) -> void:
	cam_goal_pos = pos; cam_goal_look = look

func cam_reset() -> void:
	cam_to(Vector3(9, 8, 21), Vector3(-1, 4, -3))

func focus_on(a: Node3D, b: Node3D = null) -> void:
	var ap := a.position; var tp := b.position if b else Vector3.ZERO
	var dir := (ap - tp); dir.y = 0; dir = dir.normalized(); var side := Vector3(-dir.z, 0, dir.x)
	cam_to(ap + dir * 9 + side * 5 + Vector3(0, 5, 0), ap.lerp(tp, 0.5) + Vector3(0, 2.5, 0))

func _anim_attack(u: Dictionary, tg: Dictionary) -> void:
	var a: Node3D = u.model; var b: Node3D = tg.model
	focus_on(a, b); await _wait(0.25)
	var from := a.position; var to := from.lerp(b.position, 0.72)
	var tw := create_tween(); tw.tween_property(a, "position", to, 0.28).set_trans(Tween.TRANS_QUAD); await tw.finished
	var arms: Array = a.get_meta("arms", [])
	if arms.size() > 1:
		var tw2 := create_tween(); tw2.tween_property(arms[1], "rotation:x", -2.2, 0.09); tw2.tween_property(arms[1], "rotation:x", 0.0, 0.09); await tw2.finished
	_burst(b.position + Vector3(0, 2.5, 0), Color("fff0c0"), 24); shake = 0.2
	var tw3 := create_tween(); tw3.tween_property(a, "position", from, 0.3).set_trans(Tween.TRANS_QUAD); await tw3.finished

func _anim_cast(u: Dictionary, targets: Array, el: String) -> void:
	var a: Node3D = u.model
	focus_on(a, targets[0].model if not targets.is_empty() else null)
	var c: Color = DB.ELEM_COLOR.get(el, Color.WHITE)
	_burst(a.position + Vector3(0, 3, 0), c, 30); Sfx.play("cast")
	for arm in a.get_meta("arms", []):
		var tw := create_tween(); tw.tween_property(arm, "rotation:x", -2.6, 0.3); tw.tween_property(arm, "rotation:x", 0.0, 0.3)
	await _wait(0.45)
	for tg in targets: _burst(tg.model.position + Vector3(0, 2.5, 0), c, 60)
	shake = 0.15; await _wait(0.3)

func _special_intro(u: Dictionary, title: String, el: String) -> void:
	var a: Node3D = u.model
	Sfx.play("special")
	banner.text = title; banner.add_theme_color_override("font_color", DB.ELEM_COLOR.get(el, UI.BRASS))
	var bt := create_tween(); bt.tween_property(banner, "modulate:a", 1.0, 0.15); bt.tween_interval(0.8); bt.tween_property(banner, "modulate:a", 0.0, 0.3)
	cam_to(a.position + Vector3(3.2, 2.2, -6.5), a.position + Vector3(0, 2.6, 0))
	_burst(a.position + Vector3(0, 1, 0), DB.ELEM_COLOR.get(el, UI.BRASS), 70, 5.0)
	var tw := create_tween(); tw.tween_property(a, "position:y", 1.2, 0.18); tw.tween_property(a, "position:y", 0.0, 0.18)
	await _wait(0.8)

func _knock_out(tg: Dictionary) -> void:
	var m: Node3D = tg.model; Sfx.play("ko")
	var tw := create_tween()
	if tg.side == "ally": tw.tween_property(m, "rotation:x", -PI / 2, 0.5)
	else:
		tw.set_parallel(true); tw.tween_property(m, "rotation:x", PI / 2, 0.5); tw.tween_property(m, "position:y", -1.5, 0.5); tw.tween_property(m, "scale", Vector3.ONE * 0.01, 0.6)

func _stand_up(tg: Dictionary) -> void:
	var tw := create_tween(); tw.tween_property(tg.model, "rotation:x", 0.0, 0.4)

func _flash(m: Node3D) -> void:
	var tw := create_tween(); tw.tween_property(m, "scale", m.scale * 1.08, 0.06); tw.tween_property(m, "scale", m.scale, 0.1)

func _burst(pos: Vector3, c: Color, n := 40, spread := 3.0) -> void:
	var p := CPUParticles3D.new(); p.one_shot = true; p.amount = n; p.lifetime = 0.9; p.explosiveness = 0.95
	p.direction = Vector3.UP; p.spread = 180; p.initial_velocity_min = spread * 0.5; p.initial_velocity_max = spread * 1.6; p.gravity = Vector3(0, -2, 0)
	var sm := SphereMesh.new(); sm.radius = 0.12; sm.height = 0.24; sm.radial_segments = 4; sm.rings = 2
	var mt := StandardMaterial3D.new(); mt.albedo_color = c; mt.emission_enabled = true; mt.emission = c; mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.material = mt; p.mesh = sm; p.position = pos; add_child(p); p.emitting = true
	get_tree().create_timer(1.5).timeout.connect(p.queue_free)

func _pop(tg: Dictionary, txt: String, c: Color) -> void:
	var l := Label3D.new(); l.text = txt; l.font_size = 64; l.pixel_size = 0.02; l.billboard = BaseMaterial3D.BILLBOARD_ENABLED; l.no_depth_test = true
	l.modulate = c; l.outline_size = 12; l.outline_modulate = Color(0.05, 0.08, 0.15)
	l.position = tg.model.position + Vector3(randf_range(-0.5, 0.5), 5.5, 0); add_child(l)
	var tw := create_tween(); tw.set_parallel(true); tw.tween_property(l, "position:y", l.position.y + 1.5, 1.0); tw.tween_property(l, "modulate:a", 0.0, 1.0).set_delay(0.5)
	tw.chain().tween_callback(l.queue_free)

func _process(dt: float) -> void:
	if not visible: return
	t += dt
	var k := 1.0 - exp(-dt * 2.6)
	cam.position = cam.position.lerp(cam_goal_pos, k); cam_look = cam_look.lerp(cam_goal_look, k)
	cam.look_at(cam_look)
	if shake > 0.0:
		shake -= dt; cam.position += Vector3(randf_range(-0.25, 0.25), randf_range(-0.2, 0.2), 0)
	stage.position.y = sin(t * 0.9) * 0.25
	for u in units:
		var m: Node3D = u.get("model"); if not is_instance_valid(m) or u.hp <= 0: continue
		var body: Node3D = m.get_meta("body", null)
		if m.get_meta("fly", false) and body:
			body.position.y = 3.0 + sin(t * 2.0 + m.get_instance_id()) * 0.5
			for i in m.get_meta("wings", []).size():
				m.get_meta("wings")[i].rotation.z = (1 if i else -1) * sin(t * 8.0) * 0.5
		elif body: body.position.y = sin(t * 2.2 + m.get_instance_id()) * 0.06

# ---------- Darstellung ----------
func set_log(txt: String) -> void:
	log_label.text = txt.replace("[b]", "").replace("[/b]", "")

func render() -> void:
	for row in [enemy_row, party_row, schwung_bar, stone_row, menu]:
		for c in row.get_children():
			row.remove_child(c); c.queue_free()
	var free := schwung - reserved_schwung()
	for e in alive("enemy", true):
		var card := _unit_card(e, false)
		enemy_row.add_child(card)
	var pl := planner()
	for a in alive("ally", true):
		party_row.add_child(_unit_card(a, a == pl))
	for i in MAX_SCHWUNG:
		var dot := Panel.new(); dot.custom_minimum_size = Vector2(14, 14)
		var s := StyleBoxFlat.new(); s.set_corner_radius_all(7); s.set_border_width_all(1); s.border_color = UI.WIND
		s.bg_color = UI.WIND if i < free else (Color(UI.WIND, 0.35) if i < schwung else Color(0, 0, 0, 0))
		dot.add_theme_stylebox_override("panel", s); schwung_bar.add_child(dot)
	schwung_bar.add_child(UI.label("  %d / %d" % [free, MAX_SCHWUNG], 13, UI.MUTED))
	if phase == "plan" and not pl.is_empty(): _render_menu(pl, free)

func _unit_card(u: Dictionary, active: bool) -> PanelContainer:
	var p := PanelContainer.new()
	var s := UI.sb(UI.PANEL, UI.WIND if active else (UI.KONTOR if u.side == "enemy" else UI.LINE), 10, 10)
	if active: s.set_border_width_all(2)
	p.add_theme_stylebox_override("panel", s); p.custom_minimum_size.x = 190
	if u.hp <= 0: p.modulate.a = 0.4
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 2); p.add_child(v)
	var h := HBoxContainer.new(); v.add_child(h)
	var nm := UI.label(u.name, 15); nm.autowrap_mode = TextServer.AUTOWRAP_OFF; nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(nm)
	if u.side == "ally": h.add_child(UI.label(DB.PARTY[u.id].role, 11, UI.MUTED))
	var hb := ProgressBar.new(); hb.max_value = u.max; hb.value = u.hp; hb.show_percentage = false; hb.custom_minimum_size.y = 7
	var fill := StyleBoxFlat.new(); fill.set_corner_radius_all(4); fill.bg_color = Color("93d48b") if u.side == "ally" else UI.KONTOR
	hb.add_theme_stylebox_override("fill", fill); v.add_child(hb)
	if u.side == "ally":
		var mb := ProgressBar.new(); mb.max_value = u.mmax; mb.value = u.mp; mb.show_percentage = false; mb.custom_minimum_size.y = 4
		var mf := StyleBoxFlat.new(); mf.bg_color = Color("6aa8e8"); mf.set_corner_radius_all(3); mb.add_theme_stylebox_override("fill", mf); v.add_child(mb)
		v.add_child(UI.label("%d/%d LP · %d Äther · %s" % [u.hp, u.max, u.mp, DB.ELEM_NAME[u.el]], 12, UI.MUTED))
		if not u.plan.is_empty() and u.plan.get("type", "") != "none": v.add_child(UI.label(_plan_text(u.plan), 12, UI.WIND))
	else:
		v.add_child(UI.label("%d / %d LP" % [u.hp, u.max], 12, UI.MUTED))
		var wk := "?"
		if _known(u.type, u.weak): wk = DB.ELEM_NAME[u.weak]
		v.add_child(UI.label("Schwäche: " + wk, 11, UI.BRASS if wk != "?" else UI.MUTED))
	var st := []
	for k in u.st: st.append(DB.STATUS_NAME[k])
	for k in u.buff: st.append({"atk": "Angriff+", "def": "Abwehr+", "spd": "Tempo+", "regen": "Regeneration"}.get(k, k))
	if not st.is_empty(): v.add_child(UI.label(", ".join(st), 11, Color("c9a2ff")))
	return p

func _plan_text(p: Dictionary) -> String:
	var tg := uid(p.get("target", ""))
	var tn: String = (" auf " + tg.name) if not tg.is_empty() else ""
	match p.type:
		"attack": return "Angriff (%s)%s" % [DB.ELEM_NAME[p.el], tn]
		"kniff": return DB.KNIFF[p.key].n + tn
		"spell": return DB.SPELL[p.key].n + tn
		"item": return DB.ITEMS[p.key].n + tn
		"focus": return "Fokus"
		"guard": return "Abwehr"
	return ""

func _render_menu(u: Dictionary, free: int) -> void:
	stone_row.add_child(UI.label("%s · Befehl %d von %d   Windstein: " % [u.name, plan_i + 1, alive("ally").size()], 14, UI.BRASS))
	for e in DB.ELEMENTS:
		var b := Button.new(); b.text = DB.ELEM_NAME[e]; b.add_theme_font_size_override("font_size", 12)
		var s := UI.sb(DB.ELEM_COLOR[e] if u.el == e else Color(0, 0, 0, 0.3), DB.ELEM_COLOR[e], 999, 8)
		b.add_theme_stylebox_override("normal", s); b.add_theme_stylebox_override("hover", s)
		if u.el == e: b.add_theme_color_override("font_color", UI.NIGHT)
		b.pressed.connect(func(): u.el = e; Game.party[u.id].el = e; Sfx.play("select"); render())
		stone_row.add_child(b)
	var grid := GridContainer.new(); grid.columns = 3; grid.add_theme_constant_override("h_separation", 6); grid.add_theme_constant_override("v_separation", 6)
	var center := CenterContainer.new(); center.add_child(grid); menu.add_child(center)
	if not pending.is_empty():
		_render_targets(u, grid); _bottom_row(); return
	var sub: String = u.get("submenu", "")
	if sub == "kniff":
		for k in u.kniffe:
			var K: Dictionary = DB.KNIFF[k]
			grid.add_child(_act_btn("%s  (%d)" % [K.n, K.c], K.d, free < K.c, func(): _choose_kniff(u, k)))
	elif sub == "spell":
		if u.spells.is_empty(): grid.add_child(UI.label("Noch keine Zauber gelernt.", 14, UI.MUTED))
		for k in u.spells:
			var S: Dictionary = DB.SPELL[k]
			grid.add_child(_act_btn("%s  (%d Äther)" % [S.n, S.mp], DB.ELEM_NAME[S.el] + ": " + S.d, S.mp > u.mp or u.st.has("stumm"), func(): _choose_spell(u, k)))
	elif sub == "item":
		for k in DB.ITEMS:
			var n: int = Game.items.get(k, 0) - items_reserved(k)
			if Game.items.get(k, 0) <= 0 or DB.ITEMS[k].tg == "" or k == "windbeere": continue
			grid.add_child(_act_btn("%s  (%d)" % [DB.ITEMS[k].n, n], DB.ITEMS[k].d, n <= 0, func(): _choose_item(u, k)))
	else:
		grid.add_child(_act_btn("Angriff", "Normaler Angriff im Element " + DB.ELEM_NAME[u.el], false, func(): pending = {"tg": "enemy", "plan": {"type": "attack", "el": u.el}}; _auto_single()))
		grid.add_child(_act_btn("Kniffe", "Spezialtechniken, kosten Schwung", false, func(): u.submenu = "kniff"; render()))
		grid.add_child(_act_btn("Windmagie", "Zauber, kosten eigenen Äther", false, func(): u.submenu = "spell"; render()))
		grid.add_child(_act_btn("Gegenstand", "Tränke und Kräuter", false, func(): u.submenu = "item"; render()))
		grid.add_child(_act_btn("Fokus", "+3 Schwung zusätzlich", false, func(): set_plan({"type": "focus"})))
		grid.add_child(_act_btn("Abwehr", "Zuerst, halber Schaden", false, func(): set_plan({"type": "guard"})))
	_bottom_row()

func _bottom_row() -> void:
	var u := planner()
	var row := HBoxContainer.new(); row.alignment = BoxContainer.ALIGNMENT_CENTER; row.add_theme_constant_override("separation", 8); menu.add_child(row)
	if u.get("submenu", "") != "" or not pending.is_empty() or plan_i > 0:
		row.add_child(UI.button("Zurück", func():
			if not pending.is_empty(): pending = {}; render()
			elif u.get("submenu", "") != "": u.submenu = ""; render()
			else: back()))
	row.add_child(UI.button("Rest automatisch", auto_rest))
	if not opt.get("boss", false): row.add_child(UI.button("Fliehen", flee))

func _act_btn(title: String, desc: String, disabled: bool, cb: Callable) -> Button:
	var b := Button.new(); b.text = title + "\n" + desc; b.disabled = disabled; b.custom_minimum_size = Vector2(230, 54)
	b.add_theme_font_size_override("font_size", 14); b.alignment = HORIZONTAL_ALIGNMENT_LEFT; b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.pressed.connect(func(): Sfx.play("select"); cb.call())
	return b

func _auto_single() -> void:
	if pending.tg == "enemy" and alive("enemy").size() == 1:
		var p: Dictionary = pending.plan; p.target = alive("enemy")[0].id; set_plan(p); return
	render()

func _render_targets(u: Dictionary, grid: GridContainer) -> void:
	var list := []
	match pending.tg:
		"enemy": list = alive("enemy")
		"ally": list = alive("ally")
		"dead": list = alive("ally", true).filter(func(x): return x.hp <= 0)
	for tg in list:
		var info: String = "%d/%d LP" % [tg.hp, tg.max]
		grid.add_child(_act_btn(tg.name, info, false, func():
			var p: Dictionary = pending.plan; p.target = tg.id; u.erase("submenu"); set_plan(p)))
	if list.is_empty(): grid.add_child(UI.label("Kein gültiges Ziel.", 14, UI.MUTED))

func _choose_kniff(u: Dictionary, k: String) -> void:
	var K: Dictionary = DB.KNIFF[k]; var plan := {"type": "kniff", "key": k, "el": u.el}
	u.erase("submenu")
	if K.tg == "enemy": pending = {"tg": "enemy", "plan": plan}; _auto_single()
	else: set_plan(plan)

func _choose_spell(u: Dictionary, k: String) -> void:
	var S: Dictionary = DB.SPELL[k]; var plan := {"type": "spell", "key": k}
	if S.tg in ["enemy", "ally", "dead"]:
		if S.tg == "dead" and alive("ally", true).filter(func(x): return x.hp <= 0).is_empty():
			set_log("Niemand ist bewusstlos."); return
		pending = {"tg": S.tg, "plan": plan}; u.erase("submenu"); _auto_single()
	else: u.erase("submenu"); set_plan(plan)

func _choose_item(u: Dictionary, k: String) -> void:
	var I: Dictionary = DB.ITEMS[k]
	if I.tg == "dead" and alive("ally", true).filter(func(x): return x.hp <= 0).is_empty():
		set_log("Niemand ist bewusstlos."); return
	pending = {"tg": I.tg, "plan": {"type": "item", "key": k}}; u.erase("submenu"); render()
