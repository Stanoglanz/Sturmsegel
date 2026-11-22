extends Node
## Spielstand: Gruppe, Vorrat, Windkunde, Fortschritt. Speichern in user://.

signal changed

const SAVE_PATH := "user://sturmsegel_spielstand.json"

var gold := 150
var fame := 0
var lvl := 1
var xp := 0
var chapter := 1
var party := {}          # id -> {hp, mp, el, weapon, armor, amulet}
var items := {}          # id -> Anzahl
var equip_bag := {}      # id -> Anzahl (nicht angelegt)
var wk := {}             # id -> {element -> Wind-EP}
var kniffe := {}         # id -> [freigeschaltete Kniffe]
var fragments := 0       # Kniff-Fragmente
var flags := {}          # Story- und Weltflags
var chests := {}         # "dungeon:index" -> true
var disc := {}           # Entdeckungen
var enc_rate := "Normal"
var ship := {"x": 8.0, "z": 52.0, "h": PI, "y": 2.0}
var last_port := "hafen"

func new_game() -> void:
	gold = 150; fame = 0; lvl = 1; xp = 0; chapter = 1; fragments = 0
	items = {"trank": 4, "kraut": 2, "feder": 1, "tee": 1}
	equip_bag = {}
	flags = {}; chests = {}; disc = {}
	ship = {"x": 8.0, "z": 52.0, "h": PI, "y": 2.0}
	last_port = "hafen"
	wk = {}; kniffe = {}; party = {}
	for id in DB.PARTY_ORDER:
		var p: Dictionary = DB.PARTY[id]
		wk[id] = {}
		for e in DB.ELEMENTS:
			wk[id][e] = DB.WK_START.get(id, {}).get(e, 0)
		kniffe[id] = [p.kniffe[0]]
		party[id] = {"hp": 0, "mp": 0, "el": "blitz" if id == "tizian" else ("frost" if id == "tiago" else "schatten"),
			"weapon": p.start_weapon, "armor": "", "amulet": ""}
	for id in DB.PARTY_ORDER:
		var s := stats(id)
		party[id].hp = s.hp; party[id].mp = s.mp
	changed.emit()

## Werte einer Figur inklusive Stufe, Windkunde und Ausrüstung
func stats(id: String, l: int = -1) -> Dictionary:
	if l < 0: l = lvl
	var p: Dictionary = DB.PARTY[id]
	var k := l - 1
	var s := {
		"hp": int(round(p.hp * (1.0 + 0.15 * k))),
		"mp": int(round(p.mp * (1.0 + 0.1 * k))) + int(floor(wk_sum(id) / 8.0)),
		"atk": p.atk + 3 * k, "def": p.def + 2 * k, "spd": p.spd + int(k / 2), "wil": p.wil, "res": "", "gold": 0.0,
	}
	var c: Dictionary = party.get(id, {})
	for slot in ["weapon", "armor", "amulet"]:
		var e: String = c.get(slot, "")
		if e == "" or not DB.EQUIP.has(e): continue
		var q: Dictionary = DB.EQUIP[e]
		s.atk += q.get("atk", 0); s.def += q.get("def", 0); s.spd += q.get("spd", 0)
		s.wil += q.get("wil", 0.0); s.gold += q.get("gold", 0.0)
		if q.has("res"): s.res = q.res
	return s

func wk_sum(id: String) -> float:
	var t := 0.0
	for e in DB.ELEMENTS: t += float(wk.get(id, {}).get(e, 0))
	return t

func known_spells(id: String) -> Array:
	var r := []
	for e in DB.ELEMENTS:
		for pair in DB.WK[e]:
			if float(wk[id][e]) >= pair[1]: r.append(pair[0])
	return r

## Gibt neu gelernte Zauber zurück
func wk_gain(id: String, el: String, amt: float) -> Array:
	var before := known_spells(id)
	var rate: float = DB.PARTY[id].wk_rate
	wk[id][el] = snappedf(float(wk[id][el]) + amt * rate, 0.1)
	var after := known_spells(id)
	var neu := []
	for k in after:
		if not before.has(k): neu.append(k)
	return neu

func wk_next(id: String, el: String) -> Array:
	for pair in DB.WK[el]:
		if float(wk[id][el]) < pair[1]: return pair
	return []

func gain_xp(amount: int) -> Array:
	xp += amount
	var ups := []
	while xp >= DB.xp_need(lvl):
		xp -= DB.xp_need(lvl)
		var before := {}
		for id in DB.PARTY_ORDER: before[id] = stats(id)
		lvl += 1
		for id in DB.PARTY_ORDER:
			var s := stats(id)
			party[id].hp = mini(s.hp, party[id].hp + s.hp - before[id].hp)
			party[id].mp = mini(s.mp, party[id].mp + s.mp - before[id].mp)
		ups.append(lvl)
	changed.emit()
	return ups

func heal_all() -> void:
	for id in DB.PARTY_ORDER:
		var s := stats(id)
		party[id].hp = s.hp; party[id].mp = s.mp
	changed.emit()

func add_item(k: String, n: int = 1) -> void:
	items[k] = items.get(k, 0) + n
	changed.emit()

func add_equip(k: String, n: int = 1) -> void:
	equip_bag[k] = equip_bag.get(k, 0) + n
	changed.emit()

func equip(id: String, k: String) -> void:
	var q: Dictionary = DB.EQUIP[k]
	var slot: String = q.slot
	var old: String = party[id].get(slot, "")
	if old != "": add_equip(old)
	equip_bag[k] = equip_bag.get(k, 0) - 1
	if equip_bag[k] <= 0: equip_bag.erase(k)
	party[id][slot] = k
	var s := stats(id)
	party[id].hp = mini(party[id].hp, s.hp); party[id].mp = mini(party[id].mp, s.mp)
	changed.emit()

func unequip(id: String, slot: String) -> void:
	var old: String = party[id].get(slot, "")
	if old == "" or slot == "weapon": return
	add_equip(old); party[id][slot] = ""
	changed.emit()

func can_unlock_kniff(id: String) -> String:
	for k in DB.PARTY[id].kniffe:
		if not kniffe[id].has(k): return k
	return ""

func unlock_kniff(id: String) -> bool:
	var k := can_unlock_kniff(id)
	if k == "": return false
	var cost: int = DB.KNIFF[k].fr
	if fragments < cost: return false
	fragments -= cost; kniffe[id].append(k); changed.emit()
	return true

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func save() -> void:
	var d := {"v": 1, "gold": gold, "fame": fame, "lvl": lvl, "xp": xp, "chapter": chapter, "party": party, "items": items,
		"equip_bag": equip_bag, "wk": wk, "kniffe": kniffe, "fragments": fragments, "flags": flags, "chests": chests,
		"disc": disc, "enc_rate": enc_rate, "ship": ship, "last_port": last_port}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f: f.store_string(JSON.stringify(d))

func load_game() -> bool:
	if not has_save(): return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not f: return false
	var d = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY: return false
	new_game()
	gold = int(d.gold); fame = int(d.fame); lvl = int(d.lvl); xp = int(d.xp); chapter = int(d.get("chapter", 1))
	party = d.party; items = d.items; equip_bag = d.get("equip_bag", {}); wk = d.wk; kniffe = d.kniffe
	fragments = int(d.get("fragments", 0)); flags = d.get("flags", {}); chests = d.get("chests", {}); disc = d.get("disc", {})
	enc_rate = d.get("enc_rate", "Normal"); ship = d.ship; last_port = d.get("last_port", "hafen")
	# JSON liefert Zahlen als float, Anzahlen wieder als int
	for k in items.keys(): items[k] = int(items[k])
	for k in equip_bag.keys(): equip_bag[k] = int(equip_bag[k])
	for id in party.keys():
		party[id].hp = int(party[id].hp); party[id].mp = int(party[id].mp)
	changed.emit()
	return true
