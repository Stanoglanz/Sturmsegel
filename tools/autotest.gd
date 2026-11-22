extends Node
## Automatischer Rundgang mit Bildschirmfotos: godot --path . -- --autotest <ordner>

var main: Node
var out := "user://shots"

func _ready() -> void:
	main = get_parent()
	var a := OS.get_cmdline_user_args()
	if a.size() > 1: out = a[1]
	DirAccess.make_dir_recursive_absolute(out)
	run.call_deferred()

func shot(n: String) -> void:
	await get_tree().create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + "/" + n + ".png")
	print("SHOT ", n)

func run() -> void:
	if "--two" in OS.get_cmdline_user_args():
		Game.new_game(); main.close_overlay(); Game.lvl = 6; Game.heal_all()
		main._start_training("hafen", "saum")
		for i in 60:
			if main.battle.phase == "plan": main.battle.auto_rest()
			await get_tree().create_timer(0.3).timeout
			print("t", i, " phase=", main.battle.phase, " units=", main.battle.units.size(), " cards=", main.battle.enemy_row.get_child_count(), " ov=", main.overlay != null)
			if main.overlay != null: break
		main.battle.stop(); main.close_overlay()
		main.start_battle(["matrose", "feldwebel", "matrose"], {"title": "Feldwebel Brask", "boss": true})
		for i in 6:
			await get_tree().create_timer(0.3).timeout
			print("B", i, " units=", main.battle.units.size(), " cards=", main.battle.enemy_row.get_child_count())
		get_tree().quit(); return
	if "--boss" in OS.get_cmdline_user_args():
		Game.new_game(); main.close_overlay(); Game.lvl = 4; Game.heal_all()
		main.start_battle(["matrose", "feldwebel", "matrose"], {"title": "Feldwebel Brask", "boss": true})
		await shot("b1")
		print("units=", main.battle.units.size(), " cards=", main.battle.enemy_row.get_child_count())
		get_tree().quit(); return
	await shot("01_titel")
	main._start_new()
	await shot("02_dialog")
	while main.mode == "dialog": main._dialog_next(); await get_tree().process_frame
	main.world.input.up = true
	await get_tree().create_timer(2.0).timeout
	await shot("03_segeln")
	main.world.ship.position.y = -30.0
	await shot("04_tiefe")
	main.world.ship.position = Vector3(8, 2, 52)
	main.open_port("hafen")
	await shot("05_hafen")
	main._shop("hafen"); await shot("06_laden")
	main.open_party_menu(func(): pass); await shot("07_gruppe")
	main._wk_menu("tizian", func(): pass); await shot("08_windkunde")
	main._kniff_menu("tiago", func(): pass); await shot("09_kniffe")
	main._start_training("hafen", "saum")
	await shot("10_kampf")
	var b: Node = main.battle
	for i in 90:
		if b.phase == "plan": b.auto_rest()
		await get_tree().create_timer(0.5).timeout
		if i == 4: await shot("11_kampf_lauf")
		if main.overlay != null: break
	await shot("12_ergebnis")
	# Bosskampf
	main.battle.stop(); main.close_overlay()
	Game.lvl = 4; Game.heal_all()
	main.start_battle(["matrose", "feldwebel", "matrose"], {"title": "Feldwebel Brask", "boss": true, "fragments": 1, "equip": "sturmharpune"})
	await shot("13_boss")
	print("units=", b.units.size(), " cards=", b.enemy_row.get_child_count(), " party=", b.party_row.get_child_count())
	for i in 120:
		if b.phase == "plan": b.auto_rest()
		await get_tree().create_timer(0.5).timeout
		if main.overlay != null: break
	await shot("14_boss_ende")
	print("DONE mode=", main.mode, " lvl=", Game.lvl, " gold=", Game.gold)
	get_tree().quit()
