extends Node3D
## Die Weite: Segeln, Inseln, Wolkenmeer, Sturmwall, Begegnungen.

signal encounter(pool: String)
signal interact_changed(text: String)
signal toast(text: String)

const CLOUD_Y := -60.0

var ship: Node3D
var cam: Camera3D
var sun: DirectionalLight3D
var env: Environment
var speed := 0.0
var active := false
var interact_cb: Callable
var _interact_text := ""
var enc_meter := 0.0
var enc_next := 1.0
var enc_grace := 4.0
var wall_warn := 0.0
var t := 0.0
var input := {"up": false, "down": false, "left": false, "right": false, "rise": false, "sink": false}
var islands := {}
var flocks := []
var storm: Node3D

## Orte im Saumland (Kapitel 1). r = Radius der Insel
const ISLANDS := {
	"hafen": {"n": "Möwenruh", "x": 0, "z": 0, "r": 26, "h": 40, "top": "8cbf68", "rock": "8a6a52", "kind": "port"},
	"glocke": {"n": "Glockenfels", "x": 230, "z": -170, "r": 20, "h": 46, "top": "a3b07a", "rock": "9a8a78", "kind": "disc"},
	"anker": {"n": "Ankerfels", "x": -160, "z": 90, "r": 22, "h": 44, "top": "9ab86a", "rock": "7a6a5a", "kind": "frachter"},
	"turm": {"n": "Gläserner Turm", "x": 300, "z": 150, "r": 22, "h": 48, "top": "b8c8a8", "rock": "8a8aa0", "kind": "turm"},
	"raben": {"n": "Rabenklippe", "x": -230, "z": -235, "r": 24, "h": 56, "top": "6f7d5a", "rock": "5b5560", "kind": "klippe"},
	"moos": {"n": "Moosinsel", "x": 120, "z": -330, "r": 14, "h": 30, "top": "7fae5a", "rock": "8a6a52", "kind": "deko"},
	"zwilling": {"n": "Zwillingsfelsen", "x": -320, "z": -40, "r": 12, "h": 34, "top": "8cbf68", "rock": "8a7a6a", "kind": "deko"},
}
const WALL_R := 520.0
const CENTER := Vector2(0, -60)

func _ready() -> void:
	_build_env()
	_build_islands()
	_build_clouds()
	_build_storm_wall()
	_build_flocks()
	ship = Node3D.new(); add_child(ship)
	var sm := Models.kit("ship-pirate-medium"); sm.rotation.y = PI; ship.add_child(sm)
	sm.scale = Vector3.ONE * 1.1
	ship.set_meta("model", sm)
	cam = Camera3D.new(); cam.fov = 62; cam.far = 3000; add_child(cam); cam.environment = env
	place_ship()

func place_ship() -> void:
	ship.position = Vector3(Game.ship.x, Game.ship.y, Game.ship.z); ship.rotation.y = Game.ship.h
	cam.position = ship.position + Vector3(-sin(Game.ship.h) * 26, 12, -cos(Game.ship.h) * 26)

func _build_env() -> void:
	env = Environment.new()
	var sky := Sky.new(); var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color("1f5aa6"); sm.sky_horizon_color = Color("bcd8f0"); sm.ground_horizon_color = Color("e8eef4"); sm.ground_bottom_color = Color("f4f4f8")
	sm.sun_angle_max = 20; sm.sun_curve = 0.1
	sky.sky_material = sm; env.background_mode = Environment.BG_SKY; env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY; env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true; env.fog_light_color = Color("e6eef6"); env.fog_density = 0.0016; env.fog_sky_affect = 0.0
	pass
	sun = DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-48, -35, 0); sun.light_energy = 1.15
	sun.light_color = Color("fff0d6"); sun.shadow_enabled = true; sun.directional_shadow_max_distance = 160
	add_child(sun)

func _build_islands() -> void:
	for k in ISLANDS:
		var I: Dictionary = ISLANDS[k]
		var g := Models.island(I.r, I.h, Color(I.top), Color(I.rock), false)
		g.position = Vector3(I.x, 0, I.z); add_child(g)
		g.set_meta("base_y", 0.0); g.set_meta("phase", randf() * 6.0)
		islands[k] = g
		var lb := Label3D.new(); lb.text = I.n; lb.font_size = 96; lb.pixel_size = 0.06; lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lb.outline_size = 18; lb.outline_modulate = Color(0.07, 0.12, 0.22, 0.85); lb.position = Vector3(0, 26, 0); lb.no_depth_test = false
		g.add_child(lb)
		match I.kind:
			"port": _deco_port(g, I.r)
			"frachter": _deco_frachter(g, I.r)
			"turm": _deco_turm(g)
			"klippe": _deco_klippe(g, I.r)
			"disc":
				var arch := Models.kit("castle-gate"); arch.scale = Vector3.ONE * 2.2; arch.position = Vector3(0, 2.4, 0); g.add_child(arch)
	# kleine Deko-Inseln in der Ferne
	var rng := RandomNumberGenerator.new(); rng.seed = 7
	for i in 14:
		var a := rng.randf() * TAU; var d := 180.0 + rng.randf() * 300.0
		var r := 5.0 + rng.randf() * 8.0
		var g := Models.island(r, r * 1.6, Color("8cbf68"), Color("8a6a52"), false, 2)
		g.position = Vector3(CENTER.x + cos(a) * d, -10.0 + rng.randf() * 40.0, CENTER.y + sin(a) * d)
		g.set_meta("base_y", g.position.y); g.set_meta("phase", rng.randf() * 6.0)
		add_child(g); islands["deko%d" % i] = g

func _deco_port(g: Node3D, r: float) -> void:
	var houses := [Vector3(-8, 2.4, -6), Vector3(-2, 2.4, -10), Vector3(6, 2.4, -7), Vector3(-10, 2.4, 4)]
	for i in houses.size():
		var h := Models.kit("structure" if i % 2 == 0 else "tower-watch"); h.scale = Vector3.ONE * 2.6; h.position = houses[i]; h.rotation.y = i * 1.3
		g.add_child(h)
	var tw := Models.kit("tower-complete-large"); tw.scale = Vector3.ONE * 1.6; tw.position = Vector3(12, 2.4, -4); g.add_child(tw)
	for i in 4:
		var dk := Models.kit("structure-platform-dock"); dk.scale = Vector3.ONE * 2.2; dk.position = Vector3(-2 + i * 5.4, 1.4, r - 1); g.add_child(dk)
	var fl := Models.kit("flag-high"); fl.scale = Vector3.ONE * 3; fl.position = Vector3(12, 18, -4); g.add_child(fl)
	for i in 3:
		var b := Models.kit("barrel"); b.scale = Vector3.ONE * 1.6; b.position = Vector3(2 + i * 1.8, 2.4, r - 6); g.add_child(b)

func _deco_frachter(g: Node3D, r: float) -> void:
	var s := Models.kit("ship-large"); s.scale = Vector3.ONE * 2.2; s.position = Vector3(r + 16, -2, 0); s.rotation.y = 0.2; g.add_child(s)
	for i in 3:
		var c := Models.kit("crate"); c.scale = Vector3.ONE * 2.0; c.position = Vector3(-4 + i * 2.6, 2.4, 6); g.add_child(c)
	var dk := Models.kit("structure-platform-dock"); dk.scale = Vector3.ONE * 2.5; dk.position = Vector3(r + 2, 1.4, 0); g.add_child(dk)

func _deco_turm(g: Node3D) -> void:
	var glass := Models.mat(Color(0.65, 0.95, 0.95), 0.1, 0.2, Color(0.1, 0.35, 0.35))
	var c := CylinderMesh.new(); c.top_radius = 3.0; c.bottom_radius = 6.0; c.height = 46; c.radial_segments = 6
	var tw := Models.mesh(c, glass, Vector3(0, 25, 0)); g.add_child(tw)
	var p := PrismMesh.new(); p.size = Vector3(7, 9, 7)
	g.add_child(Models.mesh(p, glass, Vector3(0, 52, 0)))
	for i in 6:
		var a := i / 6.0 * TAU
		var cr := Models.mesh(p, glass, Vector3(cos(a) * 12, 4, sin(a) * 12)); cr.scale = Vector3(0.4, 0.8, 0.4); g.add_child(cr)

func _deco_klippe(g: Node3D, r: float) -> void:
	for i in 5:
		var rk := Models.kit(["rocks-a", "rocks-b", "rocks-c"][i % 3]); rk.scale = Vector3.ONE * (3.0 + i); rk.position = Vector3(cos(i * 1.3) * r * 0.5, 2.4, sin(i * 1.3) * r * 0.5); g.add_child(rk)
	var tw := Models.kit("tower-watch"); tw.scale = Vector3.ONE * 3.0; tw.position = Vector3(0, 2.4, 0); g.add_child(tw)

func _build_clouds() -> void:
	var sea := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(9000, 9000); sea.mesh = pm
	sea.material_override = Models.mat(Color("f3eef0"), 1.0); sea.position.y = CLOUD_Y - 4; add_child(sea)
	var puff := SphereMesh.new(); puff.radius = 1.0; puff.height = 1.4; puff.radial_segments = 8; puff.rings = 4
	var pmat := StandardMaterial3D.new(); pmat.albedo_color = Color(1, 1, 1); pmat.roughness = 1.0
	pmat.emission_enabled = true; pmat.emission = Color(0.16, 0.16, 0.22)
	var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.mesh = puff
	var n := 900; mm.instance_count = n
	var rng := RandomNumberGenerator.new(); rng.seed = 3
	for i in n:
		var k := 8.0 + rng.randf() * 18.0
		var b := Basis(Vector3.UP, rng.randf() * 6.0).scaled(Vector3(k * 1.7, k * 0.65, k * 1.3))
		mm.set_instance_transform(i, Transform3D(b, Vector3(CENTER.x + (rng.randf() - 0.5) * 1700, CLOUD_Y + rng.randf() * 9, CENTER.y + (rng.randf() - 0.5) * 1700)))
	var mi := MultiMeshInstance3D.new(); mi.multimesh = mm; mi.material_override = pmat; mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	# hohe Wolken
	var mm2 := MultiMesh.new(); mm2.transform_format = MultiMesh.TRANSFORM_3D; mm2.mesh = puff; mm2.instance_count = 160
	for i in 160:
		var grp := i / 5
		var gx := CENTER.x + sin(grp * 12.9898) * 900.0; var gz := CENTER.y + cos(grp * 78.233) * 900.0
		var k := 5.0 + rng.randf() * 8.0
		var b := Basis.IDENTITY.scaled(Vector3(k * 1.6, k * 0.7, k))
		mm2.set_instance_transform(i, Transform3D(b, Vector3(gx + (i % 5) * 9.0, 60 + float(grp % 7) * 9.0, gz + rng.randf() * 8.0)))
	var mi2 := MultiMeshInstance3D.new(); mi2.multimesh = mm2; mi2.material_override = pmat; mi2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi2)

func _build_storm_wall() -> void:
	storm = Node3D.new(); add_child(storm); storm.position = Vector3(CENTER.x, 0, CENTER.y)
	var c := CylinderMesh.new(); c.top_radius = WALL_R + 40; c.bottom_radius = WALL_R + 40; c.height = 260; c.radial_segments = 48; c.cap_top = false; c.cap_bottom = false
	var m := StandardMaterial3D.new(); m.albedo_color = Color(0.25, 0.27, 0.36, 0.72); m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED; m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var mi := MeshInstance3D.new(); mi.mesh = c; mi.material_override = m; mi.position.y = 40; storm.add_child(mi)
	var puff := SphereMesh.new(); puff.radius = 1; puff.height = 1.6; puff.radial_segments = 8; puff.rings = 4
	var pm := StandardMaterial3D.new(); pm.albedo_color = Color(0.36, 0.38, 0.48)
	var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.mesh = puff; mm.instance_count = 260
	for i in 260:
		var a := i / 260.0 * TAU; var k := 16.0 + fmod(i * 7.3, 14.0)
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3(k * 1.5, k, k * 1.5)), Vector3(cos(a) * (WALL_R + 30), -40.0 + fmod(i * 37.0, 200.0), sin(a) * (WALL_R + 30))))
	var mi2 := MultiMeshInstance3D.new(); mi2.multimesh = mm; mi2.material_override = pm; storm.add_child(mi2)

func _build_flocks() -> void:
	var wing := Models.box(Vector3(2.2, 0.06, 0.8), Color("f4f0e8")).mesh
	for c in [Vector3(0, 32, 0), Vector3(230, 40, -170), Vector3(-230, 38, -235), Vector3(300, 30, 150)]:
		var g := Node3D.new(); add_child(g)
		var birds := []
		for i in 6:
			var b := Node3D.new()
			for sx in [-1, 1]:
				var w := Node3D.new(); var wm := MeshInstance3D.new(); wm.mesh = wing; wm.material_override = Models.mat(Color("f4f0e8")); wm.position.x = sx * 1.1
				w.add_child(wm); b.add_child(w)
			b.position = Vector3(randf_range(-6, 6), randf_range(-2, 2), randf_range(-6, 6)); g.add_child(b); birds.append(b)
		flocks.append({"g": g, "c": c, "birds": birds, "a": randf() * 6.0, "r": 40.0 + randf() * 25.0})

func fwd() -> Vector3:
	return Vector3(sin(ship.rotation.y), 0, cos(ship.rotation.y))

func _process(dt: float) -> void:
	t += dt
	for k in islands:
		var g: Node3D = islands[k]
		g.position.y = g.get_meta("base_y") + sin(t * 0.5 + g.get_meta("phase")) * 0.5
	for f in flocks:
		f.a += dt * 0.2
		f.g.position = f.c + Vector3(cos(f.a) * f.r, sin(f.a * 2.0) * 3.0, sin(f.a) * f.r); f.g.rotation.y = -f.a
		for b in f.birds:
			var w := sin(t * 9.0 + b.position.x) * 0.6
			b.get_child(0).rotation.z = w; b.get_child(1).rotation.z = -w
	storm.rotation.y += dt * 0.01
	var model: Node3D = ship.get_meta("model")
	model.position.y = sin(t * 1.4) * 0.35
	if not active:
		speed = maxf(0.0, speed - 6.0 * dt)
		_follow_cam(dt)
		return
	var turn := (1.0 if input.left else 0.0) - (1.0 if input.right else 0.0)
	ship.rotation.y += turn * 1.4 * dt
	model.rotation.z = lerpf(model.rotation.z, -turn * 0.12, dt * 3.0)
	if input.up: speed = minf(20.0, speed + 9.0 * dt)
	elif input.down: speed = maxf(0.0, speed - 14.0 * dt)
	else: speed = maxf(0.0, speed - 1.5 * dt)
	var climb := (1.0 if input.rise else 0.0) - (1.0 if input.sink else 0.0)
	ship.position.y = clampf(ship.position.y + climb * 11.0 * dt, -44.0, 28.0)
	model.rotation.x = lerpf(model.rotation.x, -climb * 0.1, dt * 3.0)
	var f := fwd()
	ship.position += f * speed * dt
	# Inseln umfahren
	for k in islands:
		if k.begins_with("deko"): continue
		var I: Dictionary = ISLANDS[k]; var c := Vector2(I.x, I.z); var p := Vector2(ship.position.x, ship.position.z)
		var d := p.distance_to(c); var m: float = I.r + 6.0
		if d < m and ship.position.y > -I.h:
			var q := c + (p - c).normalized() * m; ship.position.x = q.x; ship.position.z = q.y; speed *= 0.9
	# Sturmwall
	var p2 := Vector2(ship.position.x, ship.position.z) - CENTER
	if p2.length() > WALL_R:
		var q2 := CENTER + p2.normalized() * WALL_R; ship.position.x = q2.x; ship.position.z = q2.y; speed *= 0.5
		if wall_warn <= 0.0:
			wall_warn = 6.0; toast.emit("Der Sturmwall ist zu stark für die Möwe. Ohne einen stärkeren Kiel kommt ihr hier nicht durch.")
	wall_warn = maxf(0.0, wall_warn - dt)
	Game.ship = {"x": ship.position.x, "z": ship.position.z, "h": ship.rotation.y, "y": ship.position.y}
	# Interaktionen
	var it := _find_interaction()
	if it.text != _interact_text:
		_interact_text = it.text; interact_cb = it.cb; interact_changed.emit(_interact_text)
	# Zufallskämpfe
	enc_grace = maxf(0.0, enc_grace - dt)
	var rate: float = {"Häufig": 1.0 / 230.0, "Normal": 1.0 / 420.0, "Selten": 1.0 / 800.0, "Aus": 0.0}.get(Game.enc_rate, 0.0)
	var near_port := Vector2(ship.position.x, ship.position.z).length() < 110.0
	if enc_grace <= 0.0 and not near_port and _interact_text == "":
		enc_meter += speed * dt * rate * (1.7 if ship.position.y < -20 else 1.0)
		if enc_meter >= enc_next:
			enc_meter = 0.0; enc_next = randf_range(0.6, 1.4); enc_grace = 3.0
			encounter.emit("saum_tief" if ship.position.y < -20 else "saum")
	# Nebel in der Tiefe
	var deep := clampf((-ship.position.y - 10.0) / 30.0, 0.0, 1.0)
	env.fog_density = lerpf(0.0016, 0.006, deep)
	_follow_cam(dt)

func _follow_cam(dt: float) -> void:
	var f := fwd()
	var target := ship.position + Vector3(-f.x * 26, 11, -f.z * 26)
	cam.position = cam.position.lerp(target, 1.0 - exp(-dt * 3.5))
	cam.look_at(ship.position + f * 10 + Vector3(0, 3, 0))
	sun.position = ship.position

func _find_interaction() -> Dictionary:
	var p := Vector2(ship.position.x, ship.position.z)
	for k in ISLANDS:
		var I: Dictionary = ISLANDS[k]
		if p.distance_to(Vector2(I.x, I.z)) < I.r + 30.0 and absf(ship.position.y) < 30.0:
			match I.kind:
				"port": return {"text": "In %s anlegen" % I.n, "cb": func(): get_parent().open_port("hafen")}
				"frachter": return {"text": "Den Kontor-Frachter entern", "cb": func(): get_parent().enter_dungeon("frachter")}
				"turm": return {"text": "Den Gläsernen Turm betreten", "cb": func(): get_parent().enter_dungeon("turm")}
				"klippe": return {"text": "Die Höhlen der Rabenklippe erkunden", "cb": func(): get_parent().enter_dungeon("klippe")}
				"disc":
					if not Game.disc.has(k): return {"text": "Die Insel %s erkunden" % I.n, "cb": func(): get_parent().discover(k)}
	return {"text": "", "cb": Callable()}

func interact() -> void:
	if _interact_text != "" and interact_cb.is_valid(): interact_cb.call()
