class_name Models
## Modelle: freie Kenney-Modelle (CC0) plus eigene Low-Poly-Figuren aus Grundformen.

const KIT := "res://assets/models/pirate/"

static var _mats := {}

static func mat(c: Color, rough := 0.85, metal := 0.0, emissive := Color.BLACK) -> StandardMaterial3D:
	var key := "%s|%s|%s|%s" % [c.to_html(), rough, metal, emissive.to_html()]
	if _mats.has(key): return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c; m.roughness = rough; m.metallic = metal
	if emissive != Color.BLACK:
		m.emission_enabled = true; m.emission = emissive
	_mats[key] = m
	return m

static func kit(name: String) -> Node3D:
	var res = load(KIT + name + ".glb")
	if res == null:
		push_warning("Modell fehlt: " + name)
		return Node3D.new()
	return res.instantiate()

static func mesh(m: Mesh, material: Material, pos := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); mi.mesh = m; mi.material_override = material; mi.position = pos
	return mi

static func box(size: Vector3, c: Color, pos := Vector3.ZERO) -> MeshInstance3D:
	var b := BoxMesh.new(); b.size = size
	return mesh(b, mat(c), pos)

static func sphere(r: float, c: Color, pos := Vector3.ZERO, emissive := Color.BLACK) -> MeshInstance3D:
	var s := SphereMesh.new(); s.radius = r; s.height = r * 2.0; s.radial_segments = 16; s.rings = 10
	return mesh(s, mat(c, 0.8, 0.0, emissive), pos)

static func cyl(top: float, bottom: float, h: float, c: Color, pos := Vector3.ZERO, segs := 10) -> MeshInstance3D:
	var s := CylinderMesh.new(); s.top_radius = top; s.bottom_radius = bottom; s.height = h; s.radial_segments = segs
	return mesh(s, mat(c), pos)

static func cone(r: float, h: float, c: Color, pos := Vector3.ZERO, segs := 8) -> MeshInstance3D:
	return cyl(0.0, r, h, c, pos, segs)

## Humanoide Figur. Gibt Node3D mit meta "arms", "legs", "body" zurück.
static func humanoid(o: Dictionary) -> Node3D:
	var g := Node3D.new(); var body := Node3D.new(); g.add_child(body)
	var bulk: float = o.get("bulk", 1.0)
	var skin: Color = o.get("skin", Color("f0c8a0"))
	var coat: Color = o.get("coat", Color.GRAY)
	var pants: Color = o.get("pants", Color("3a3a48"))
	var hair: Color = o.get("hair", Color("3a2a20"))
	var acc: Color = o.get("accent", Color("e3a948"))
	var legs := []
	for sx in [-1, 1]:
		var l := Node3D.new(); l.position = Vector3(sx * 0.36, 1.95, 0)
		l.add_child(cyl(0.27, 0.32, 1.9, pants, Vector3(0, -0.95, 0)))
		l.add_child(box(Vector3(0.5, 0.38, 0.78), Color("3a2a20"), Vector3(0, -1.85, 0.1)))
		body.add_child(l); legs.append(l)
	body.add_child(cyl(0.74 * bulk, 0.62 * bulk, 2.0, coat, Vector3(0, 3, 0)))
	if o.get("long_coat", false): body.add_child(cyl(0.7, 1.05, 1.4, coat, Vector3(0, 1.7, 0)))
	body.add_child(cyl(0.66 * bulk, 0.66 * bulk, 0.2, acc, Vector3(0, 2.1, 0)))
	if o.has("scarf"):
		var t := TorusMesh.new(); t.inner_radius = 0.38; t.outer_radius = 0.62
		var sc := mesh(t, mat(o.scarf), Vector3(0, 3.95, 0)); body.add_child(sc)
	var arms := []
	for sx in [-1, 1]:
		var a := Node3D.new(); a.position = Vector3(sx * 0.95 * bulk, 3.85, 0); a.rotation.z = sx * 0.12
		a.add_child(cyl(0.18, 0.22, 1.7, coat, Vector3(0, -0.85, 0)))
		a.add_child(sphere(0.22, skin, Vector3(0, -1.8, 0)))
		body.add_child(a); arms.append(a)
	var head := Node3D.new(); head.position = Vector3(0, 4.65, 0); body.add_child(head)
	head.add_child(sphere(0.64, skin))
	for sx in [-1, 1]: head.add_child(sphere(0.09, Color("1a1a24"), Vector3(sx * 0.22, 0.06, 0.57)))
	var hc := SphereMesh.new(); hc.radius = 0.7; hc.height = 1.0; hc.is_hemisphere = true
	var hm := mesh(hc, mat(hair), Vector3(0, 0.1, -0.05)); head.add_child(hm)
	match o.get("style", ""):
		"spiky":
			for i in 6:
				var s := cone(0.2, 0.8, hair, Vector3((i - 2.5) * 0.2, 0.55, -0.25)); s.rotation = Vector3(-0.9, 0, (i - 2.5) * 0.18); head.add_child(s)
			var gg := TorusMesh.new(); gg.inner_radius = 0.6; gg.outer_radius = 0.72
			var gm := mesh(gg, mat(acc), Vector3(0, 0.32, 0)); gm.rotation.x = 0.35; head.add_child(gm)
		"long":
			head.add_child(box(Vector3(1.1, 1.7, 0.4), hair, Vector3(0, -0.55, -0.42)))
		"bandana":
			head.add_child(cyl(0.68, 0.7, 0.3, acc, Vector3(0, 0.35, 0), 12))
			head.add_child(box(Vector3(0.8, 0.45, 0.3), hair, Vector3(0, -0.45, 0.45)))
	if o.has("weapon"):
		var w: Node3D = weapon(o.weapon); w.position = Vector3(0, -1.75, 0); arms[1].add_child(w)
	g.scale = Vector3.ONE * o.get("scale", 1.0)
	g.set_meta("arms", arms); g.set_meta("legs", legs); g.set_meta("body", body); g.set_meta("head", head)
	return g

static func weapon(kind: String) -> Node3D:
	var w := Node3D.new()
	match kind:
		"harpune":
			var s := cyl(0.07, 0.07, 3.2, Color("6b4a33"), Vector3(0, 0, 0.9)); s.rotation.x = PI / 2; w.add_child(s)
			var t := cone(0.18, 0.6, Color("c9c9c9"), Vector3(0, 0, 2.6)); t.rotation.x = PI / 2; w.add_child(t)
		"hammer":
			var s := cyl(0.08, 0.08, 2.2, Color("6b4a33"), Vector3(0, 0, 0.6)); s.rotation.x = PI / 2; w.add_child(s)
			w.add_child(box(Vector3(0.9, 0.6, 0.6), Color("5a5f66"), Vector3(0, 0, 1.7)))
		"gewehr":
			w.add_child(box(Vector3(0.18, 0.22, 2.4), Color("4a3a2a"), Vector3(0, 0, 0.7)))
			var b := cyl(0.06, 0.06, 1.4, Color("c9a24a"), Vector3(0, 0.1, 1.6)); b.rotation.x = PI / 2; w.add_child(b)
		"saebel":
			var s := box(Vector3(0.08, 0.2, 1.8), Color("d8dde2"), Vector3(0, 0, 0.9)); w.add_child(s)
	return w

static func party_model(id: String) -> Node3D:
	match id:
		"tizian": return humanoid({"coat": Color("2f5f9e"), "pants": Color("3b3226"), "hair": Color("5a3418"), "accent": Color("e3a948"), "scarf": Color("c4553f"), "style": "spiky", "weapon": "harpune"})
		"tiago": return humanoid({"coat": Color("c77a35"), "pants": Color("4a4f5a"), "hair": Color("2b2420"), "accent": Color("7a2e2e"), "style": "bandana", "bulk": 1.35, "scale": 1.15, "skin": Color("c89670"), "weapon": "hammer"})
		_: return humanoid({"coat": Color("5b3f86"), "pants": Color("2e2a3a"), "hair": Color("1c1a24"), "accent": Color("d9b26a"), "long_coat": true, "style": "long", "skin": Color("e8b892"), "weapon": "gewehr"})

static func enemy_model(type: String) -> Node3D:
	var e: Dictionary = DB.ENEMY[type]
	var tint: Color = e.get("tint", Color.WHITE)
	var g: Node3D
	match e.get("model", ""):
		"mensch":
			g = humanoid({"coat": tint, "pants": Color("2c2f35"), "hair": Color("3a2a20"), "accent": Color("b8322b"), "style": "bandana", "weapon": "saebel", "bulk": 1.2 if e.get("boss", false) else 1.0})
		"vogel":
			g = Node3D.new(); var body := Node3D.new(); g.add_child(body); body.position.y = 3
			var b := sphere(0.8, tint); b.scale = Vector3(0.8, 0.8, 1.4); body.add_child(b)
			body.add_child(sphere(0.45, tint, Vector3(0, 0.4, 1.0)))
			var beak := cone(0.15, 0.6, Color("e3a948"), Vector3(0, 0.35, 1.55)); beak.rotation.x = PI / 2; body.add_child(beak)
			var wings := []
			for sx in [-1, 1]:
				var wp := Node3D.new(); wp.position = Vector3(sx * 0.5, 0.2, 0)
				wp.add_child(box(Vector3(2.4, 0.08, 0.9), tint.darkened(0.15), Vector3(sx * 1.2, 0, 0)))
				body.add_child(wp); wings.append(wp)
			g.set_meta("wings", wings); g.set_meta("fly", true); g.set_meta("body", body)
		"qualle":
			g = Node3D.new(); var body := Node3D.new(); g.add_child(body); body.position.y = 3
			var dm := SphereMesh.new(); dm.radius = 1.4; dm.height = 1.6; dm.is_hemisphere = true
			var mt := mat(Color("d8a8e8"), 0.4, 0.0, Color("4a2a5a")); mt = mt.duplicate(); mt.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; mt.albedo_color.a = 0.8
			body.add_child(mesh(dm, mt))
			for i in 6:
				var a := i / 6.0 * TAU
				body.add_child(cyl(0.06, 0.03, 2.2, Color("e8c8f0"), Vector3(cos(a) * 0.8, -1.1, sin(a) * 0.8)))
			g.set_meta("fly", true); g.set_meta("body", body)
		"falter":
			g = Node3D.new(); var body := Node3D.new(); g.add_child(body); body.position.y = 3
			body.add_child(cyl(0.2, 0.3, 1.6, Color("4a3a2a")))
			var wings := []
			for sx in [-1, 1]:
				var wp := Node3D.new(); wp.add_child(box(Vector3(1.8, 0.05, 1.4), tint, Vector3(sx * 0.9, 0, 0))); body.add_child(wp); wings.append(wp)
			g.set_meta("wings", wings); g.set_meta("fly", true); g.set_meta("body", body)
		"kristall":
			g = Node3D.new(); var body := Node3D.new(); g.add_child(body); body.position.y = 3
			var cm := mat(tint if tint != Color.WHITE else Color("aef4f4"), 0.2, 0.0, Color("2a8a8a"))
			var c := PrismMesh.new(); c.size = Vector3(1.4, 2.4, 1.4)
			var top := mesh(c, cm); body.add_child(top)
			var bot := mesh(c, cm, Vector3(0, -1.8, 0)); bot.rotation.z = PI; body.add_child(bot)
			for i in 5:
				var a := i / 5.0 * TAU
				var sh := mesh(c, cm, Vector3(cos(a) * 1.8, sin(i) * 0.5, sin(a) * 1.8)); sh.scale = Vector3.ONE * 0.3; body.add_child(sh)
			body.add_child(sphere(0.2, Color("ff5a7a"), Vector3(0, 0, 0.75), Color("ff5a7a")))
			g.set_meta("fly", true); g.set_meta("body", body)
		"kaefer":
			g = Node3D.new(); var body := Node3D.new(); g.add_child(body)
			var sm := SphereMesh.new(); sm.radius = 1.5; sm.height = 1.8; sm.is_hemisphere = true
			body.add_child(mesh(sm, mat(tint, 0.3, 0.5), Vector3(0, 0.6, 0)))
			body.add_child(sphere(0.55, tint.darkened(0.4), Vector3(0, 0.9, 1.4)))
			for sx in [-1, 1]:
				for k in 3:
					var l := cyl(0.07, 0.07, 1.4, Color("2a2a2a"), Vector3(sx * 1.3, 0.4, -0.7 + k * 0.7)); l.rotation.z = sx * 1.0; body.add_child(l)
			g.set_meta("body", body)
		"golem":
			g = Node3D.new(); var body := Node3D.new(); g.add_child(body)
			var gm := mat(tint, 0.25, 0.1, tint.darkened(0.7))
			var tor := SphereMesh.new(); tor.radius = 1.8; tor.height = 3.6; tor.radial_segments = 8; tor.rings = 4
			var t := mesh(tor, gm, Vector3(0, 4, 0)); t.scale = Vector3(1.2, 1.1, 0.9); body.add_child(t)
			var hd := SphereMesh.new(); hd.radius = 0.8; hd.height = 1.6; hd.radial_segments = 6; hd.rings = 3
			body.add_child(mesh(hd, gm, Vector3(0, 6.3, 0)))
			var arms := []
			for sx in [-1, 1]:
				var a := Node3D.new(); a.position = Vector3(sx * 2.3, 5, 0)
				a.add_child(mesh(_box(Vector3(0.9, 3.0, 0.9)), gm, Vector3(0, -1.5, 0)))
				a.add_child(mesh(hd, gm, Vector3(0, -3.2, 0)))
				body.add_child(a); arms.append(a)
			for sx in [-1, 1]: body.add_child(mesh(_box(Vector3(1, 2.4, 1)), gm, Vector3(sx * 0.9, 1.2, 0)))
			body.add_child(sphere(0.22, Color("ff6a6a"), Vector3(0, 6.4, 0.75), Color("ff6a6a")))
			g.set_meta("arms", arms); g.set_meta("body", body)
		_:
			g = humanoid({"coat": Color.GRAY})
	g.scale *= e.get("scale", 1.0)
	return g

static func _box(s: Vector3) -> BoxMesh:
	var b := BoxMesh.new(); b.size = s; return b

## Schwebende Insel aus Grundformen, dekoriert mit Kit-Modellen
static func island(r: float, h: float, top: Color, rock: Color, palm := false, trees := -1) -> Node3D:
	var g := Node3D.new()
	var cm := CylinderMesh.new(); cm.top_radius = r; cm.bottom_radius = r * 0.08; cm.height = h; cm.radial_segments = 12; cm.rings = 4
	var rk := mesh(cm, mat(rock, 0.95), Vector3(0, -h / 2.0, 0)); g.add_child(rk)
	var tp := CylinderMesh.new(); tp.top_radius = r * 1.03; tp.bottom_radius = r * 0.97; tp.height = 2.4; tp.radial_segments = 12
	g.add_child(mesh(tp, mat(top, 0.95), Vector3(0, 1.2, 0)))
	var n := trees if trees >= 0 else int(r / 3.0)
	var rng := RandomNumberGenerator.new(); rng.seed = int(r * 1000 + h)
	for i in n:
		var a := rng.randf() * TAU; var d := rng.randf() * r * 0.78
		var tr: Node3D
		if palm:
			tr = kit(["palm-straight", "palm-bend", "palm-detailed-straight", "palm-detailed-bend"][i % 4]); tr.scale = Vector3.ONE * (4.0 + rng.randf() * 2.0)
		else:
			tr = Node3D.new()
			tr.add_child(cyl(0.35, 0.5, 2.2, Color("6b4a33"), Vector3(0, 1.1, 0), 6))
			tr.add_child(cone(1.9, 3.2, Color("4f8a4a"), Vector3(0, 3.0, 0), 7))
			tr.add_child(cone(1.4, 2.6, Color("5f9a52"), Vector3(0, 4.6, 0), 7))
			tr.scale = Vector3.ONE * (0.8 + rng.randf() * 0.6)
		tr.position = Vector3(cos(a) * d, 2.4, sin(a) * d); tr.rotation.y = rng.randf() * TAU
		g.add_child(tr)
	return g
