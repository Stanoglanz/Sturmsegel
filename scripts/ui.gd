class_name UI
## Oberfläche: Nachtblau und Messing, wie Instrumente an Deck.

const NIGHT := Color("13203a")
const PANEL := Color(0.06, 0.1, 0.18, 0.9)
const PANEL_SOLID := Color("16243f")
const LINE := Color(0.96, 0.93, 0.86, 0.18)
const PAPER := Color("f4ecdc")
const MUTED := Color("aeb9cb")
const BRASS := Color("e3a948")
const WIND := Color("7fe0d2")
const KONTOR := Color("d9605a")

static var theme: Theme

static func sb(bg: Color, border := LINE, radius := 12, pad := 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg; s.border_color = border; s.set_border_width_all(1); s.set_corner_radius_all(radius)
	s.content_margin_left = pad; s.content_margin_right = pad; s.content_margin_top = pad * 0.7; s.content_margin_bottom = pad * 0.7
	return s

static func build_theme() -> Theme:
	if theme: return theme
	theme = Theme.new()
	theme.default_font_size = 17
	theme.set_color("font_color", "Label", PAPER)
	theme.set_stylebox("panel", "PanelContainer", sb(PANEL))
	theme.set_stylebox("panel", "Panel", sb(PANEL))
	var bn := sb(Color(0.1, 0.16, 0.27, 0.95), LINE, 10, 14)
	var bh := sb(Color(0.16, 0.24, 0.38, 0.98), BRASS, 10, 14)
	var bp := sb(Color(0.2, 0.3, 0.45, 1.0), BRASS, 10, 14)
	var bd := sb(Color(0.08, 0.12, 0.2, 0.6), LINE, 10, 14)
	var bf := sb(Color(0.16, 0.24, 0.38, 0.98), WIND, 10, 14); bf.set_border_width_all(2)
	theme.set_stylebox("normal", "Button", bn); theme.set_stylebox("hover", "Button", bh)
	theme.set_stylebox("pressed", "Button", bp); theme.set_stylebox("disabled", "Button", bd); theme.set_stylebox("focus", "Button", bf)
	theme.set_color("font_color", "Button", PAPER); theme.set_color("font_disabled_color", "Button", Color(PAPER, 0.4))
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_stylebox("normal", "LineEdit", bn)
	var pb := StyleBoxFlat.new(); pb.bg_color = Color(1, 1, 1, 0.1); pb.set_corner_radius_all(4)
	var pf := StyleBoxFlat.new(); pf.bg_color = Color("93d48b"); pf.set_corner_radius_all(4)
	theme.set_stylebox("background", "ProgressBar", pb); theme.set_stylebox("fill", "ProgressBar", pf)
	theme.set_color("default_color", "RichTextLabel", PAPER)
	return theme

static func label(text: String, size := 17, color := PAPER) -> Label:
	var l := Label.new(); l.text = text
	l.add_theme_font_size_override("font_size", size); l.add_theme_color_override("font_color", color)
	if text.length() > 40: l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

static func rich(text: String, size := 16) -> RichTextLabel:
	var r := RichTextLabel.new(); r.bbcode_enabled = true; r.fit_content = true; r.scroll_active = false
	r.add_theme_font_size_override("normal_font_size", size); r.add_theme_font_size_override("bold_font_size", size)
	r.text = text
	return r

static func button(text: String, cb: Callable, min_w := 0) -> Button:
	var b := Button.new(); b.text = text; b.focus_mode = Control.FOCUS_ALL
	if min_w > 0: b.custom_minimum_size.x = min_w
	b.pressed.connect(func(): Sfx.play("select"); cb.call())
	return b

static func primary(b: Button) -> Button:
	var s := sb(BRASS, BRASS.darkened(0.2), 10, 16)
	var h := sb(BRASS.lightened(0.15), BRASS, 10, 16)
	b.add_theme_stylebox_override("normal", s); b.add_theme_stylebox_override("hover", h); b.add_theme_stylebox_override("pressed", s)
	var f := sb(BRASS, WIND, 10, 16); f.set_border_width_all(3); b.add_theme_stylebox_override("focus", f)
	b.add_theme_color_override("font_color", NIGHT); b.add_theme_color_override("font_hover_color", NIGHT); b.add_theme_color_override("font_focus_color", NIGHT)
	return b

static func panel(pad := 14) -> PanelContainer:
	var p := PanelContainer.new(); p.add_theme_stylebox_override("panel", sb(PANEL, LINE, 12, pad))
	return p

static func card(width := 560) -> Array:
	## Gibt [Hintergrund, VBox] zurück: zentrierte Karte mit Abdunklung
	var bg := ColorRect.new(); bg.color = Color(0.04, 0.07, 0.13, 0.62); bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	var cc := CenterContainer.new(); cc.set_anchors_preset(Control.PRESET_FULL_RECT); bg.add_child(cc)
	var p := PanelContainer.new(); p.add_theme_stylebox_override("panel", sb(PANEL_SOLID, LINE, 14, 24))
	p.custom_minimum_size.x = width; cc.add_child(p)
	var sc := ScrollContainer.new(); sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size = Vector2(width - 48, 0); p.add_child(sc)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 10); v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)
	bg.set_meta("scroll", sc); bg.set_meta("panel", p)
	return [bg, v]

static func fit_card(bg: Control) -> void:
	## Begrenzt die Kartenhöhe auf den Bildschirm
	var sc: ScrollContainer = bg.get_meta("scroll"); var p: PanelContainer = bg.get_meta("panel")
	var vp := bg.get_viewport_rect().size
	p.custom_minimum_size.x = minf(p.custom_minimum_size.x, vp.x - 24)
	sc.custom_minimum_size.x = p.custom_minimum_size.x - 48
	var content_h := (sc.get_child(0) as Control).get_combined_minimum_size().y
	sc.custom_minimum_size.y = minf(content_h, vp.y - 90)

static func eyebrow(text: String) -> Label:
	var l := label(text.to_upper(), 12, WIND); return l

static func hsep() -> HSeparator:
	var s := HSeparator.new(); var st := StyleBoxLine.new(); st.color = LINE; s.add_theme_stylebox_override("separator", st)
	return s
