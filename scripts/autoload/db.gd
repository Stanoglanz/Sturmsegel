extends Node
## Spieldaten: Figuren, Zauber, Kniffe, Ausrüstung, Gegner, Orte.
## Alle Namen sind eigene Schöpfungen für Sturmsegel.

const ELEMENTS := ["glut", "frost", "blitz", "gruen", "licht", "schatten"]
const ELEM_NAME := {"glut": "Glut", "frost": "Frost", "blitz": "Blitz", "gruen": "Grün", "licht": "Licht", "schatten": "Schatten"}
const ELEM_COLOR := {"glut": Color("ff7040"), "frost": Color("80c8ff"), "blitz": Color("ffe060"), "gruen": Color("70e070"), "licht": Color("fffbe8"), "schatten": Color("b080ff")}

const STATUS_NAME := {"gift": "Gift", "schlaf": "Schlaf", "laehmung": "Lähmung", "erstarrt": "Erstarrt", "schwaeche": "Geschwächt", "stumm": "Verstummt"}

## Grundwerte der Figuren (Stufe 1)
const PARTY := {
	"tizian": {"name": "Tizian", "role": "Kapitän", "hp": 140, "mp": 18, "spd": 16, "atk": 18, "def": 10, "wil": 1.0, "wk_rate": 1.0,
		"kniffe": ["boenschnitt", "sturmschritt", "kapitaensruf", "windklinge", "sturmruf", "himmelsbrecher"], "start_weapon": "harpune", "color": Color("2f5f9e")},
	"tiago": {"name": "Tiago", "role": "Mechaniker", "hp": 190, "mp": 10, "spd": 9, "atk": 23, "def": 15, "wil": 0.85, "wk_rate": 0.8,
		"kniffe": ["ankerwurf", "schildmauer", "notreparatur", "kesseldruck", "eisenwall", "dampfhammer"], "start_weapon": "hammer", "color": Color("c77a35")},
	"valeria": {"name": "Valeria Luana", "role": "Kartografin", "hp": 110, "mp": 30, "spd": 13, "atk": 13, "def": 8, "wil": 1.25, "wk_rate": 1.3,
		"kniffe": ["kartenblick", "tintensturm", "sternpeilung", "kompassnadel", "atlasflut", "himmelskarte"], "start_weapon": "windgewehr", "color": Color("5b3f86")},
}
const PARTY_ORDER := ["tizian", "tiago", "valeria"]

## Windkunde: sechs Zauber je Element, Schwellen in Wind-EP. Die letzten sind sehr teuer.
const WK := {
	"glut": [["funke", 3], ["feuersbrunst", 14], ["glutsaeule", 32], ["flammenwall", 55], ["sonnensturz", 85], ["urfeuer", 130]],
	"frost": [["reif", 3], ["frostsiegel", 12], ["eisdorn", 30], ["frostpanzer", 52], ["weissersturm", 82], ["ewiges_eis", 125]],
	"blitz": [["funkenschlag", 3], ["kettenblitz", 16], ["donnerkeil", 34], ["wetterleuchten", 56], ["himmelszorn", 88], ["sturmgericht", 130]],
	"gruen": [["lindern", 3], ["linderwind", 16], ["quellkraft", 32], ["wachstum", 50], ["lebensbrise", 80], ["weltenbaum", 125]],
	"licht": [["klarheit", 3], ["weckruf", 12], ["schutzglanz", 28], ["segen", 48], ["morgenstrahl", 78], ["zweites_leben", 120]],
	"schatten": [["schwaechen", 3], ["schlafsporen", 12], ["schattenbiss", 30], ["verstummen", 50], ["nachtfall", 82], ["leerer_himmel", 128]],
}
const WK_START := {
	"tizian": {"blitz": 3, "glut": 3},
	"tiago": {"frost": 3},
	"valeria": {"schatten": 12, "gruen": 3, "licht": 3},
}

## tg: enemy, enemies, ally, allies, dead, self
const SPELL := {
	"funke": {"n": "Funke", "el": "glut", "mp": 3, "tg": "enemy", "pow": 30, "d": "Glut-Schaden an einem Gegner"},
	"feuersbrunst": {"n": "Feuersbrunst", "el": "glut", "mp": 8, "tg": "enemies", "pow": 30, "d": "Glut-Schaden an allen Gegnern"},
	"glutsaeule": {"n": "Glutsäule", "el": "glut", "mp": 9, "tg": "enemy", "pow": 72, "d": "Starker Glut-Schaden"},
	"flammenwall": {"n": "Flammenwall", "el": "glut", "mp": 10, "tg": "allies", "buff": "atk", "d": "Angriff der Gruppe +25 % für 3 Runden"},
	"sonnensturz": {"n": "Sonnensturz", "el": "glut", "mp": 20, "tg": "enemies", "pow": 70, "d": "Schwerer Glut-Schaden an allen"},
	"urfeuer": {"n": "Urfeuer", "el": "glut", "mp": 30, "tg": "enemies", "pow": 115, "d": "Verheerendes Glut-Feuer an allen"},
	"reif": {"n": "Reif", "el": "frost", "mp": 3, "tg": "enemy", "pow": 30, "d": "Frost-Schaden an einem Gegner"},
	"frostsiegel": {"n": "Frostsiegel", "el": "frost", "mp": 6, "tg": "enemy", "pow": 20, "st": ["erstarrt", 0.6], "d": "Frost, 60 % Erstarren"},
	"eisdorn": {"n": "Eisdorn", "el": "frost", "mp": 9, "tg": "enemy", "pow": 66, "st": ["erstarrt", 0.25], "d": "Starker Frost, 25 % Erstarren"},
	"frostpanzer": {"n": "Frostpanzer", "el": "frost", "mp": 10, "tg": "allies", "buff": "def", "d": "Abwehr der Gruppe +40 % für 3 Runden"},
	"weissersturm": {"n": "Weißer Sturm", "el": "frost", "mp": 20, "tg": "enemies", "pow": 62, "st": ["erstarrt", 0.2], "d": "Schwerer Frost an allen"},
	"ewiges_eis": {"n": "Ewiges Eis", "el": "frost", "mp": 30, "tg": "enemies", "pow": 105, "st": ["erstarrt", 0.35], "d": "Frost an allen, 35 % Erstarren"},
	"funkenschlag": {"n": "Funkenschlag", "el": "blitz", "mp": 4, "tg": "enemy", "pow": 34, "st": ["laehmung", 0.3], "d": "Blitz, 30 % Lähmung"},
	"kettenblitz": {"n": "Kettenblitz", "el": "blitz", "mp": 9, "tg": "enemies", "pow": 30, "st": ["laehmung", 0.2], "d": "Blitz an allen"},
	"donnerkeil": {"n": "Donnerkeil", "el": "blitz", "mp": 11, "tg": "enemy", "pow": 78, "st": ["laehmung", 0.35], "d": "Sehr starker Blitz"},
	"wetterleuchten": {"n": "Wetterleuchten", "el": "blitz", "mp": 10, "tg": "allies", "buff": "spd", "d": "Tempo der Gruppe +50 % für 3 Runden"},
	"himmelszorn": {"n": "Himmelszorn", "el": "blitz", "mp": 22, "tg": "enemies", "pow": 66, "st": ["laehmung", 0.35], "d": "Schwerer Blitz an allen"},
	"sturmgericht": {"n": "Sturmgericht", "el": "blitz", "mp": 30, "tg": "enemy", "pow": 190, "d": "Gewaltiger Blitz auf ein Ziel"},
	"lindern": {"n": "Lindern", "el": "gruen", "mp": 4, "tg": "ally", "heal": 60, "d": "Heilt eine Figur um 60"},
	"linderwind": {"n": "Linderwind", "el": "gruen", "mp": 9, "tg": "allies", "heal": 40, "d": "Heilt die Gruppe um 40"},
	"quellkraft": {"n": "Quellkraft", "el": "gruen", "mp": 8, "tg": "ally", "heal": 160, "d": "Heilt eine Figur um 160"},
	"wachstum": {"n": "Wachstum", "el": "gruen", "mp": 12, "tg": "allies", "regen": true, "d": "Gruppe heilt 3 Runden lang jede Runde"},
	"lebensbrise": {"n": "Lebensbrise", "el": "gruen", "mp": 18, "tg": "allies", "heal": 110, "cure": true, "d": "Heilt alle um 110 und alle Zustände"},
	"weltenbaum": {"n": "Weltenbaum", "el": "gruen", "mp": 32, "tg": "allies", "heal": 999, "cure": true, "d": "Heilt die Gruppe vollständig"},
	"klarheit": {"n": "Klarheit", "el": "licht", "mp": 3, "tg": "ally", "cure": true, "d": "Heilt alle Zustände einer Figur"},
	"weckruf": {"n": "Weckruf", "el": "licht", "mp": 8, "tg": "dead", "revive": 0.5, "d": "Holt eine bewusstlose Figur zurück"},
	"schutzglanz": {"n": "Schutzglanz", "el": "licht", "mp": 10, "tg": "allies", "shield": true, "d": "Gruppe nimmt diese Runde halben Schaden"},
	"segen": {"n": "Segen", "el": "licht", "mp": 12, "tg": "allies", "buff": "all", "d": "Angriff und Abwehr +20 % für 3 Runden"},
	"morgenstrahl": {"n": "Morgenstrahl", "el": "licht", "mp": 18, "tg": "enemies", "pow": 66, "d": "Schweres Licht an allen"},
	"zweites_leben": {"n": "Zweites Leben", "el": "licht", "mp": 30, "tg": "dead", "revive": 1.0, "d": "Holt eine Figur mit vollen LP zurück"},
	"schwaechen": {"n": "Schwächen", "el": "schatten", "mp": 4, "tg": "enemy", "st": ["schwaeche", 1.0], "d": "Halbiert die Abwehr des Ziels"},
	"schlafsporen": {"n": "Schlafsporen", "el": "schatten", "mp": 5, "tg": "enemies", "st": ["schlaf", 0.5], "d": "50 % Schlaf bei allen"},
	"schattenbiss": {"n": "Schattenbiss", "el": "schatten", "mp": 9, "tg": "enemy", "pow": 64, "drain": 0.5, "d": "Starker Schatten, heilt dich"},
	"verstummen": {"n": "Verstummen", "el": "schatten", "mp": 8, "tg": "enemy", "st": ["stumm", 0.8], "d": "80 % Verstummen: keine Zauber"},
	"nachtfall": {"n": "Nachtfall", "el": "schatten", "mp": 20, "tg": "enemies", "pow": 58, "st": ["schwaeche", 0.6], "d": "Schatten an allen, 60 % Schwäche"},
	"leerer_himmel": {"n": "Leerer Himmel", "el": "schatten", "mp": 32, "tg": "enemies", "pow": 120, "d": "Schatten, der alles verschluckt"},
}

## Kniffe kosten Schwung. Sie werden mit Kniff-Fragmenten freigeschaltet (fr = Kosten).
const KNIFF := {
	"boenschnitt": {"n": "Böenschnitt", "c": 4, "tg": "enemy", "mul": 2.2, "use_el": true, "fr": 0, "d": "Starker Hieb im Element des Windsteins"},
	"sturmschritt": {"n": "Sturmschritt", "c": 7, "tg": "enemies", "mul": 1.5, "use_el": true, "fr": 2, "d": "Trifft alle Gegner"},
	"kapitaensruf": {"n": "Kapitänsruf", "c": 5, "tg": "allies", "gain": 0, "rally": true, "fr": 3, "d": "Gruppe +25 % Angriff, 3 Runden"},
	"windklinge": {"n": "Windklinge", "c": 8, "tg": "enemy", "mul": 3.4, "use_el": true, "fr": 4, "d": "Sehr starker Hieb"},
	"sturmruf": {"n": "Sturmruf", "c": 12, "tg": "enemies", "fixed": 95, "group": true, "fr": 5, "d": "Gruppen-Kniff: alle drei greifen an"},
	"himmelsbrecher": {"n": "Himmelsbrecher", "c": 15, "tg": "enemy", "mul": 6.0, "use_el": true, "fr": 8, "d": "Tizians stärkster Kniff"},
	"ankerwurf": {"n": "Ankerwurf", "c": 5, "tg": "enemy", "mul": 2.9, "slow": true, "fr": 0, "d": "Sehr stark, Tiago handelt zuletzt"},
	"schildmauer": {"n": "Schildmauer", "c": 4, "tg": "none", "first": true, "shield": true, "fr": 2, "d": "Zuerst: halber Schaden für alle"},
	"notreparatur": {"n": "Notreparatur", "c": 6, "tg": "allies", "heal": 70, "fr": 3, "d": "Heilt die Gruppe um 70"},
	"kesseldruck": {"n": "Kesseldruck", "c": 8, "tg": "enemies", "mul": 1.8, "fr": 4, "d": "Dampfstoß gegen alle"},
	"eisenwall": {"n": "Eisenwall", "c": 9, "tg": "none", "first": true, "taunt": true, "fr": 5, "d": "Zuerst: Tiago zieht alle Angriffe auf sich"},
	"dampfhammer": {"n": "Dampfhammer", "c": 13, "tg": "enemy", "mul": 5.5, "slow": true, "fr": 8, "d": "Tiagos stärkster Kniff"},
	"kartenblick": {"n": "Kartenblick", "c": 2, "tg": "none", "first": true, "scan": true, "fr": 0, "d": "Zuerst: zeigt alle Schwächen"},
	"tintensturm": {"n": "Tintensturm", "c": 6, "tg": "enemies", "fixed": 36, "el": "schatten", "st": ["schwaeche", 0.7], "fr": 2, "d": "Schatten an alle, 70 % Schwäche"},
	"sternpeilung": {"n": "Sternpeilung", "c": 5, "tg": "allies", "mp_gain": 12, "fr": 3, "d": "Alle erhalten 12 Äther"},
	"kompassnadel": {"n": "Kompassnadel", "c": 7, "tg": "enemy", "mul": 2.0, "crit": true, "fr": 4, "d": "Trifft immer die Schwäche"},
	"atlasflut": {"n": "Atlasflut", "c": 10, "tg": "enemies", "fixed": 80, "el": "licht", "fr": 5, "d": "Licht an alle"},
	"himmelskarte": {"n": "Himmelskarte", "c": 14, "tg": "allies", "heal": 999, "cure": true, "fr": 8, "d": "Heilt alle vollständig"},
}

## Gegenstände
const ITEMS := {
	"trank": {"n": "Heiltrank", "tg": "ally", "heal": 80, "price": 30, "d": "+80 LP"},
	"grosstrank": {"n": "Großer Heiltrank", "tg": "ally", "heal": 250, "price": 120, "d": "+250 LP"},
	"kraut": {"n": "Ätherkraut", "tg": "ally", "mp_gain": 15, "price": 60, "d": "+15 Äther"},
	"feder": {"n": "Weckfeder", "tg": "dead", "revive": 0.5, "price": 150, "d": "Holt eine Figur zurück"},
	"tee": {"n": "Klartee", "tg": "ally", "cure": true, "price": 40, "d": "Heilt alle Zustände"},
	"windbeere": {"n": "Windbeere", "tg": "ally", "wk_all": 2, "price": 0, "d": "Selten: +2 Wind-EP in jedem Element (außerhalb des Kampfes)"},
}

## Ausrüstung: slot weapon/armor/amulet, who: Figur oder "alle"
const EQUIP := {
	"harpune": {"n": "Harpune", "slot": "weapon", "who": "tizian", "atk": 0, "price": 0, "d": "Tizians alte Harpune"},
	"sturmharpune": {"n": "Sturmharpune", "slot": "weapon", "who": "tizian", "atk": 9, "price": 0, "d": "Fängt den Wind in der Spitze"},
	"seglersaebel": {"n": "Seglersäbel", "slot": "weapon", "who": "tizian", "atk": 5, "price": 300, "d": "Leicht und schnell"},
	"hammer": {"n": "Werkhammer", "slot": "weapon", "who": "tiago", "atk": 0, "price": 0, "d": "Repariert alles, zerschlägt alles"},
	"kesselhammer": {"n": "Kesselhammer", "slot": "weapon", "who": "tiago", "atk": 7, "price": 360, "d": "Schwer und dampfend"},
	"windgewehr": {"n": "Windgewehr", "slot": "weapon", "who": "valeria", "atk": 0, "price": 0, "d": "Schießt verdichtete Luft"},
	"astrolabgewehr": {"n": "Astrolab-Gewehr", "slot": "weapon", "who": "valeria", "atk": 6, "wil": 0.1, "price": 0, "d": "Zielt nach den Sternen"},
	"lederweste": {"n": "Lederweste", "slot": "armor", "who": "alle", "def": 3, "price": 120, "d": "Einfacher Schutz"},
	"segeltuchmantel": {"n": "Segeltuchmantel", "slot": "armor", "who": "alle", "def": 6, "price": 340, "d": "Gewachstes Segeltuch"},
	"kontorpanzer": {"n": "Kontorpanzer", "slot": "armor", "who": "alle", "def": 10, "price": 0, "d": "Erbeutet vom Kontor"},
	"glaskette": {"n": "Glaskette", "slot": "amulet", "who": "alle", "res": "licht", "price": 0, "d": "Halbiert Licht-Schaden"},
	"kompassamulett": {"n": "Kompass der Strömung", "slot": "amulet", "who": "alle", "spd": 4, "price": 0, "d": "+4 Tempo"},
	"glueckstaler": {"n": "Glückstaler", "slot": "amulet", "who": "alle", "gold": 0.25, "price": 400, "d": "+25 % Gold nach Kämpfen"},
}

## Gegner
const ENEMY := {
	"qualle": {"n": "Wolkenqualle", "hp": 58, "spd": 8, "atk": 12, "def": 4, "weak": "glut", "res": "frost", "xp": 14, "g": 12, "model": "qualle", "moves": [{"n": "Nesselfaden", "p": 1.0, "st": ["gift", 0.25], "w": 1}]},
	"moewe": {"n": "Sturmmöwe", "hp": 42, "spd": 20, "atk": 11, "def": 3, "weak": "frost", "res": "blitz", "xp": 10, "g": 8, "model": "vogel", "tint": Color("f2f2f2"), "moves": [{"n": "Picken", "p": 1.0, "w": 3}, {"n": "Sturzflug", "p": 1.45, "w": 1}]},
	"soldat": {"n": "Kontor-Soldat", "hp": 120, "spd": 11, "atk": 19, "def": 9, "weak": "blitz", "res": "frost", "xp": 30, "g": 40, "model": "mensch", "tint": Color("5a606b"), "moves": [{"n": "Säbelhieb", "p": 1.0, "w": 3}, {"n": "Kolbenstoß", "p": 1.35, "w": 1}]},
	"falke": {"n": "Signalfalke", "hp": 75, "spd": 19, "atk": 12, "def": 5, "weak": "frost", "res": "blitz", "xp": 18, "g": 20, "model": "vogel", "tint": Color("8a6a4a"), "moves": [{"n": "Krallen", "p": 1.0, "w": 3}, {"n": "Schrillschrei", "p": 0.0, "st": ["schlaf", 0.4], "w": 1}]},
	"matrose": {"n": "Kontor-Matrose", "hp": 90, "spd": 14, "atk": 16, "def": 6, "weak": "schatten", "res": "gruen", "xp": 22, "g": 30, "model": "mensch", "tint": Color("7a8494"), "moves": [{"n": "Entermesser", "p": 1.0, "w": 3}, {"n": "Pfefferwurf", "p": 0.3, "st": ["laehmung", 0.3], "w": 1}]},
	"feldwebel": {"n": "Feldwebel Brask", "hp": 420, "spd": 10, "atk": 24, "def": 12, "weak": "glut", "res": "schatten", "xp": 160, "g": 200, "boss": true, "model": "mensch", "tint": Color("40454e"), "scale": 1.35, "moves": [{"n": "Dampfkeule", "p": 1.1, "w": 2}, {"n": "Kesselstoß", "p": 0.7, "all": true, "w": 1}, {"n": "Befehl: Feuer!", "p": 0.5, "all": true, "w": 1}]},
	"motte": {"n": "Giftmotte", "hp": 66, "spd": 15, "atk": 10, "def": 4, "weak": "glut", "res": "gruen", "xp": 15, "g": 15, "model": "falter", "tint": Color("8a7a4a"), "moves": [{"n": "Flügelstaub", "p": 1.0, "st": ["gift", 0.45], "w": 1}]},
	"splitter": {"n": "Splittergeist", "hp": 120, "spd": 17, "atk": 24, "def": 10, "weak": "schatten", "res": "licht", "xp": 50, "g": 40, "model": "kristall", "moves": [{"n": "Glassplitter", "p": 1.0, "w": 3}, {"n": "Spiegelblitz", "p": 0.5, "all": true, "w": 1}]},
	"spiegel": {"n": "Spiegelkäfer", "hp": 160, "spd": 10, "atk": 26, "def": 22, "weak": "schatten", "res": "glut", "xp": 62, "g": 55, "model": "kaefer", "tint": Color("bfd8ee"), "moves": [{"n": "Panzerstoß", "p": 1.0, "w": 3}, {"n": "Blendschild", "p": 0.4, "st": ["laehmung", 0.35], "w": 1}]},
	"lichtwisp": {"n": "Lichtirrlicht", "hp": 70, "spd": 22, "atk": 18, "def": 6, "weak": "schatten", "res": "licht", "xp": 40, "g": 30, "model": "kristall", "tint": Color("fff2b0"), "moves": [{"n": "Blendung", "p": 0.6, "st": ["stumm", 0.3], "w": 1}, {"n": "Lichtnadel", "p": 1.0, "w": 2}]},
	"glaswaechter": {"n": "Gläserner Wächter", "hp": 1100, "spd": 12, "atk": 32, "def": 18, "weak": "schatten", "res": "licht", "xp": 520, "g": 0, "boss": true, "model": "golem", "tint": Color("9feeee"), "scale": 1.6, "moves": [{"n": "Splitterregen", "p": 0.75, "all": true, "w": 2}, {"n": "Lichtlanze", "p": 1.7, "w": 2}, {"n": "Blendlicht", "p": 0.4, "st": ["laehmung", 0.5], "w": 1}]},
	"klippenkrabbe": {"n": "Klippenkrabbe", "hp": 140, "spd": 9, "atk": 22, "def": 18, "weak": "blitz", "res": "frost", "xp": 45, "g": 35, "model": "kaefer", "tint": Color("c4553f"), "moves": [{"n": "Scherengriff", "p": 1.0, "w": 3}, {"n": "Panzerschwung", "p": 0.6, "all": true, "w": 1}]},
	"rabe": {"n": "Klippenrabe", "hp": 85, "spd": 21, "atk": 19, "def": 6, "weak": "licht", "res": "schatten", "xp": 38, "g": 28, "model": "vogel", "tint": Color("2a2a32"), "moves": [{"n": "Hacken", "p": 1.0, "w": 3}, {"n": "Unglücksruf", "p": 0.0, "st": ["schwaeche", 0.5], "w": 1}]},
	"dorn": {"n": "Hollis Dorn", "hp": 1500, "spd": 18, "atk": 36, "def": 16, "weak": "licht", "res": "schatten", "xp": 800, "g": 600, "boss": true, "model": "mensch", "tint": Color("24242b"), "scale": 1.2, "moves": [{"n": "Doppelschuss", "p": 1.3, "w": 3}, {"n": "Rauchbombe", "p": 0.4, "all": true, "st": ["schlaf", 0.3], "w": 1}, {"n": "Kopfgeldjagd", "p": 2.0, "w": 1}]},
}

## Zufallskämpfe je Gebiet
const POOLS := {
	"saum": [["qualle", "qualle"], ["moewe", "moewe", "moewe"], ["qualle", "moewe"], ["qualle", "qualle", "moewe"], ["motte", "moewe"]],
	"saum_tief": [["klippenkrabbe"], ["rabe", "rabe"], ["motte", "motte", "qualle"]],
	"frachter": [["matrose", "matrose"], ["soldat"], ["matrose", "falke"], ["soldat", "matrose"]],
	"turm": [["splitter", "splitter"], ["spiegel"], ["splitter", "lichtwisp"], ["lichtwisp", "lichtwisp", "splitter"]],
	"klippe": [["rabe", "rabe"], ["klippenkrabbe", "rabe"], ["klippenkrabbe", "klippenkrabbe"]],
}

const PRICES_SHOP := {
	"hafen": {"items": ["trank", "kraut", "tee", "feder"], "equip": ["lederweste", "seglersaebel"]},
}

const XP_BASE := 70.0

static func xp_need(lvl: int) -> int:
	return int(round(XP_BASE * pow(lvl, 1.6)))
