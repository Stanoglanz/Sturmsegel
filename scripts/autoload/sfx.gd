extends Node
## Eigene Musik und Klänge, zur Laufzeit synthetisiert (keine fremden Aufnahmen).

const RATE := 16000

var music_on := true
var _music: AudioStreamPlayer
var _players: Array[AudioStreamPlayer] = []
var _cache := {}
var _current := ""

## Melodien: Werte = MIDI-Note, -1 = halten, 0 = Pause. Alles eigene Kompositionen.
const TRACKS := {
	"sail": {"dt": 0.2, "lead": "tri", "vol": 0.22, "bar": 6,
		"mel": [74,-1,76,78,-1,81, 79,-1,78,76,-1,74, 76,-1,78,74,-1,71, 73,-1,-1,-1,-1,0,
				74,-1,76,78,-1,81, 83,-1,81,79,-1,78, 76,-1,79,78,-1,76, 74,-1,-1,-1,-1,0,
				78,-1,79,81,-1,-1, 83,-1,81,79,-1,78, 79,-1,78,76,-1,74, 76,-1,-1,-1,-1,0,
				78,-1,79,81,-1,83, 86,-1,83,81,-1,79, 78,-1,76,73,-1,76, 74,-1,-1,-1,-1,0],
		"roots": [50,55,52,57,50,55,57,50,54,55,52,57,54,55,57,50], "bass": [1,0,0,2,0,0], "kick": [0], "snare": [3]},
	"port": {"dt": 0.27, "lead": "tri", "vol": 0.18, "bar": 6,
		"mel": [74,-1,-1,78,-1,76, 74,-1,-1,71,-1,-1, 72,-1,74,76,-1,74, 71,-1,-1,-1,-1,0,
				69,-1,-1,74,-1,76, 78,-1,-1,79,-1,78, 76,-1,74,73,-1,76, 74,-1,-1,-1,-1,0],
		"roots": [50,55,48,55,45,50,45,50], "bass": [1,0,0,2,0,0], "kick": [], "snare": []},
	"battle": {"dt": 0.18, "lead": "sq", "vol": 0.11, "bar": 8,
		"mel": [69,-1,72,-1,76,-1,74,72, 71,-1,-1,72,74,-1,71,-1, 69,-1,72,-1,77,-1,76,74, 76,-1,-1,-1,0,0,0,0,
				72,-1,74,-1,76,-1,79,77, 76,-1,74,-1,72,-1,71,-1, 72,-1,71,69,68,-1,71,-1, 69,-1,-1,-1,0,0,0,0],
		"roots": [45,41,43,40,45,41,40,45], "bass": [1,1,2,1,1,2,1,2], "kick": [0,3,5], "snare": [2,6]},
	"boss": {"dt": 0.2, "lead": "saw", "vol": 0.08, "bar": 8,
		"mel": [66,-1,69,-1,73,-1,71,69, 68,-1,-1,69,71,-1,68,-1, 66,-1,69,-1,74,-1,73,71, 73,-1,-1,-1,0,0,0,0,
				69,-1,71,-1,73,-1,76,74, 73,-1,71,-1,69,-1,68,-1, 69,-1,68,66,65,-1,68,-1, 66,-1,-1,-1,0,0,0,0],
		"roots": [42,43,40,41,42,43,41,37], "bass": [1,2,1,2,1,2,1,2], "kick": [0,2,3,5,6], "snare": [4]},
	"dungeon": {"dt": 0.3, "lead": "tri", "vol": 0.17, "bar": 12,
		"mel": [74,-1,-1,73,-1,-1,74,-1,77,-1,-1,-1, 76,-1,-1,74,-1,-1,72,-1,69,-1,-1,-1,
				70,-1,-1,69,-1,-1,70,-1,74,-1,-1,-1, 73,-1,-1,-1,-1,-1,0,0,0,0,0,0],
		"roots": [38,34,36,33], "bass": [1,0,0,0,0,0,2,0,0,0,0,0], "kick": [0], "snare": []},
	"title": {"dt": 0.24, "lead": "tri", "vol": 0.2, "bar": 8,
		"mel": [62,-1,69,-1,74,-1,-1,76, 78,-1,-1,-1,76,-1,74,-1, 71,-1,-1,74,-1,-1,73,-1, 69,-1,-1,-1,-1,-1,0,0,
				62,-1,69,-1,74,-1,-1,78, 81,-1,-1,-1,79,-1,78,-1, 76,-1,-1,78,-1,-1,73,-1, 74,-1,-1,-1,-1,-1,0,0],
		"roots": [50,47,43,45,50,47,43,50], "bass": [1,0,0,0,2,0,0,0], "kick": [], "snare": []},
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_music = AudioStreamPlayer.new(); _music.volume_db = -6.0; add_child(_music)
	for i in 6:
		var p := AudioStreamPlayer.new(); add_child(p); _players.append(p)

func _hz(m: float) -> float:
	return 440.0 * pow(2.0, (m - 69.0) / 12.0)

func _osc(kind: String, ph: float) -> float:
	var x := fmod(ph, 1.0)
	match kind:
		"sq": return 1.0 if x < 0.5 else -1.0
		"saw": return 2.0 * x - 1.0
		"sin": return sin(ph * TAU)
		_: return 4.0 * absf(x - 0.5) - 1.0

func _note(buf: PackedFloat32Array, start: int, m: float, dur: float, kind: String, vol: float, slide := 0.0) -> void:
	var n := int(dur * RATE)
	var f0 := _hz(m); var f1 := _hz(m + slide)
	var ph := 0.0
	var a := int(0.01 * RATE)
	for i in n:
		var idx := start + i
		if idx >= buf.size(): idx -= buf.size()
		var t := float(i) / n
		var env := minf(1.0, float(i) / a) * (1.0 - t) ** 1.5
		ph += lerpf(f0, f1, t) / RATE
		buf[idx] += _osc(kind, ph) * vol * env

func _noise(buf: PackedFloat32Array, start: int, dur: float, vol: float, lp := 0.5) -> void:
	var n := int(dur * RATE); var y := 0.0
	for i in n:
		var idx := start + i
		if idx >= buf.size(): idx -= buf.size()
		y = lerpf(y, randf() * 2.0 - 1.0, lp)
		buf[idx] += y * vol * (1.0 - float(i) / n) ** 2

func _kick(buf: PackedFloat32Array, start: int, vol: float) -> void:
	var n := int(0.18 * RATE); var ph := 0.0
	for i in n:
		var idx := start + i
		if idx >= buf.size(): idx -= buf.size()
		var t := float(i) / n
		ph += lerpf(130.0, 40.0, t) / RATE
		buf[idx] += sin(ph * TAU) * vol * (1.0 - t)

func _to_wav(buf: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var bytes := PackedByteArray(); bytes.resize(buf.size() * 2)
	for i in buf.size():
		var v := int(clampf(buf[i], -1.0, 1.0) * 32000.0)
		bytes.encode_s16(i * 2, v)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS; w.mix_rate = RATE; w.stereo = false; w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD; w.loop_begin = 0; w.loop_end = buf.size()
	return w

func _render_track(name: String) -> AudioStreamWAV:
	var T: Dictionary = TRACKS[name]
	var mel: Array = T.mel
	var steps := mel.size()
	var dt: float = T.dt
	var buf := PackedFloat32Array(); buf.resize(int(steps * dt * RATE))
	for i in steps:
		var t0 := int(i * dt * RATE)
		var m: int = mel[i]
		if m > 0:
			var n := 1
			while mel[(i + n) % steps] == -1 and n < 12: n += 1
			_note(buf, t0, m, n * dt * 0.95, T.lead, T.vol)
			_note(buf, t0, m + 12, n * dt * 0.6, "sin", T.vol * 0.25)
		var b := i % int(T.bar)
		var roots: Array = T.roots
		var root: int = roots[int(i / T.bar) % roots.size()]
		var bp: int = T.bass[b]
		if bp > 0:
			_note(buf, t0, root + (12 if bp == 2 else 0), dt * (1.6 if bp == 1 else 0.9), "tri", 0.2)
		if b == 0:
			for iv in [12, 19, 24]:
				_note(buf, t0, root + iv, dt * T.bar * 0.95, "sin", 0.035)
		if T.kick.has(b): _kick(buf, t0, 0.5)
		if T.snare.has(b): _noise(buf, t0, 0.12, 0.15, 0.7)
	return _to_wav(buf, true)

func play_music(name: String) -> void:
	if name == _current: return
	_current = name
	if not music_on or name == "":
		_music.stop(); return
	if not _cache.has(name): _cache[name] = _render_track(name)
	_music.stream = _cache[name]; _music.play()

func toggle_music() -> bool:
	music_on = not music_on
	var c := _current; _current = ""
	if music_on: play_music(c)
	else: _music.stop(); _current = c
	return music_on

func _sfx_stream(k: String) -> AudioStreamWAV:
	if _cache.has("sfx_" + k): return _cache["sfx_" + k]
	var buf := PackedFloat32Array(); buf.resize(int(1.2 * RATE))
	match k:
		"hit": _noise(buf, 0, 0.18, 0.6, 0.3); _note(buf, 0, 48, 0.12, "sq", 0.15, -12)
		"cast": _note(buf, 0, 72, 0.45, "sin", 0.3, 12); _note(buf, int(0.08 * RATE), 79, 0.4, "sin", 0.18, 12)
		"heal":
			for i in 4: _note(buf, int(i * 0.06 * RATE), [76, 81, 85, 88][i], 0.3, "sin", 0.22)
		"select": _note(buf, 0, 84, 0.05, "sq", 0.12)
		"enc": _noise(buf, 0, 0.9, 0.5, 0.15); _note(buf, 0, 76, 0.8, "saw", 0.12, -24)
		"special":
			_noise(buf, 0, 0.6, 0.3, 0.8)
			for i in 5: _note(buf, int(i * 0.05 * RATE), [67, 71, 74, 79, 83][i], 0.5, "sq", 0.1)
		"cannon": _noise(buf, 0, 0.5, 0.8, 0.12); _kick(buf, 0, 0.7)
		"chest":
			for i in 4: _note(buf, int(i * 0.12 * RATE), [74, 78, 81, 86][i], 0.6, "tri", 0.22)
		"fanfare":
			buf.resize(int(2.4 * RATE))
			var seq := [[69,1],[74,1],[78,1],[81,3],[79,1],[78,1],[79,1],[83,4],[0,1],[81,1],[83,1],[86,6]]
			var t := 0.0
			for s in seq:
				if s[0] > 0:
					_note(buf, int(t * RATE), s[0], s[1] * 0.13 * 0.95, "sq", 0.16)
					_note(buf, int(t * RATE), s[0] - 12, s[1] * 0.13 * 0.95, "tri", 0.12)
				t += s[1] * 0.13
		"levelup":
			for i in 5: _note(buf, int(i * 0.07 * RATE), [74, 78, 81, 86, 90][i], 0.35, "tri", 0.22)
		"ko": _note(buf, 0, 55, 0.5, "tri", 0.25, -12)
		"door": _noise(buf, 0, 1.0, 0.4, 0.05); _note(buf, 0, 43, 1.0, "tri", 0.2, -5)
		"drip": _note(buf, 0, 92 + randf() * 6, 0.18, "sin", 0.12, -7)
	var w := _to_wav(buf, false)
	_cache["sfx_" + k] = w
	return w

func play(k: String) -> void:
	for p in _players:
		if not p.playing:
			p.stream = _sfx_stream(k); p.play(); return
	_players[0].stream = _sfx_stream(k); _players[0].play()

func fanfare() -> void:
	_music.stop(); _current = ""
	play("fanfare")
