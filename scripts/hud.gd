# Interface : HUD de combat, menu (perso et arme), augments, shop, arbre, pause, game over, victoire. Tout est construit en code.
extends CanvasLayer

signal weapon_picked(id: String)
signal augment_picked(index: int)
signal shop_buy(index: int)
signal tree_pick(id: String)
signal continue_pressed
signal resume_pressed
signal retry_pressed
signal menu_pressed

const INK := Color("e8eef2")
const DIM := Color("8794a0")
const HOT := Color("ff5a36")
const COOL := Color("3fd0c9")
const WARN := Color("ffc23d")
const PINK := Color("ff4fa3")
const PANEL := Color(0.04, 0.055, 0.08, 0.9)
const RANK_COLORS := { "D": DIM, "C": INK, "B": COOL, "A": WARN, "S": HOT, "SS": HOT, "SSS": PINK }

var display_font: SystemFont
var mono_font: SystemFont
var body_font: SystemFont
var hud: Control
var screens := {}
var lbl := {}
var bars := {}
var feed: VBoxContainer
var cross: Control
var hitmark_t := 0.0
var vignette: ColorRect
var vig_t := 0.0
var banner_t := 0.0
var boss_box: VBoxContainer
var weapon_box: GridContainer
var aug_box: GridContainer
var shop_box: GridContainer
var tree_box: HBoxContainer
var glitch_rect: ColorRect
var surge_rect: ColorRect
var glitch_t := 0.0

func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	display_font = SystemFont.new()
	display_font.font_names = PackedStringArray(["Chakra Petch", "Bahnschrift", "Segoe UI", "Roboto", "DejaVu Sans", "sans-serif"])
	display_font.font_weight = 700
	body_font = SystemFont.new()
	body_font.font_names = display_font.font_names
	body_font.font_weight = 400
	mono_font = SystemFont.new()
	mono_font.font_names = PackedStringArray(["JetBrains Mono", "Consolas", "Menlo", "DejaVu Sans Mono", "monospace"])
	_build_hud()
	_build_menu()
	_build_augments()
	_build_shop()
	_build_tree()
	_build_pause()
	_build_over()
	_build_victory()

# ---------- Aides de construction ----------
func _label(text: String, size: int, color := INK, mono := false, body := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", mono_font if mono else (body_font if body else display_font))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _caps(text: String) -> Label:
	return _label(text.to_upper(), 12, DIM, true)

func _bar(color: Color, w := 220.0, h := 8.0) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(w, h)
	b.max_value = 100.0
	b.value = 100.0
	var bg := StyleBoxFlat.new(); bg.bg_color = Color(1, 1, 1, 0.08)
	var fg := StyleBoxFlat.new(); fg.bg_color = color
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fg)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b

func _corner(preset: int, align_right: bool) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(v)
	v.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE, 20)
	v.grow_horizontal = Control.GROW_DIRECTION_BEGIN if align_right else Control.GROW_DIRECTION_END
	v.grow_vertical = Control.GROW_DIRECTION_BEGIN if preset in [Control.PRESET_BOTTOM_LEFT, Control.PRESET_BOTTOM_RIGHT] else Control.GROW_DIRECTION_END
	if align_right:
		v.alignment = BoxContainer.ALIGNMENT_BEGIN
	return v

func _right(l: Label) -> Label:
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.size_flags_horizontal = Control.SIZE_SHRINK_END
	return l

func _panel_style(border := Color(1, 0.35, 0.21, 0.4)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = PANEL
	s.border_color = border
	s.set_border_width_all(1)
	s.set_content_margin_all(32)
	return s

func _screen(name: String, width := 560.0) -> VBoxContainer:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.025, 0.035, 0.78)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style())
	panel.custom_minimum_size = Vector2(width, 0)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	panel.add_child(v)
	root.visible = false
	screens[name] = root
	return v

func _title(a: String, b: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	h.add_child(_label(a.to_upper(), 60, INK))
	h.add_child(_label(b.to_upper(), 60, HOT))
	return h

func _button(text: String, primary := true) -> Button:
	var b := Button.new()
	b.text = text.to_upper()
	b.add_theme_font_override("font", display_font)
	b.add_theme_font_size_override("font_size", 20)
	b.custom_minimum_size = Vector2(0, 52)
	var n := StyleBoxFlat.new(); n.bg_color = HOT if primary else Color(1, 1, 1, 0.04)
	n.border_color = Color(1, 1, 1, 0.25); n.set_border_width_all(0 if primary else 1)
	var hv := n.duplicate(); hv.bg_color = HOT.lightened(0.15) if primary else Color(1, 0.35, 0.21, 0.15)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", hv)
	b.add_theme_stylebox_override("pressed", hv)
	b.add_theme_stylebox_override("focus", hv)
	var fc := Color("07090d") if primary else INK
	b.add_theme_color_override("font_color", fc)
	b.add_theme_color_override("font_hover_color", fc)
	b.add_theme_color_override("font_pressed_color", fc)
	b.add_theme_color_override("font_focus_color", fc)
	return b

func _card(key: String, tag: String, tag_color: Color, name: String, desc: String, stats := [], highlight := false, footer := "", dim := false, height := 0.0) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(264, height if height > 0.0 else (250.0 if stats.size() > 0 else 200.0))
	if dim:
		b.modulate = Color(1, 1, 1, 0.4)
	var n := StyleBoxFlat.new(); n.bg_color = Color(1, 1, 1, 0.04)
	n.border_color = Color(1, 0.35, 0.21, 0.6) if highlight else Color(1, 1, 1, 0.12); n.set_border_width_all(1)
	var hv := n.duplicate(); hv.border_color = HOT; hv.bg_color = Color(1, 0.35, 0.21, 0.1)
	for s in ["normal", "focus"]: b.add_theme_stylebox_override(s, n)
	for s in ["hover", "pressed"]: b.add_theme_stylebox_override(s, hv)
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]: m.add_theme_constant_override("margin_" + side, 18)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(v)
	var top := HBoxContainer.new(); top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := _label(tag.to_upper(), 12, tag_color, true); t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(t); top.add_child(_label(key, 12, DIM, true))
	v.add_child(top)
	var nm := _label(name, 21, INK)
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.custom_minimum_size = Vector2(228, 0)
	v.add_child(nm)
	var d := _label(desc, 15, DIM, false, true)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(228, 0)
	v.add_child(d)
	for st in stats:
		var row := HBoxContainer.new(); row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var k := _label(st[0], 12, DIM, true); k.custom_minimum_size = Vector2(80, 0)
		row.add_child(k); row.add_child(_label(st[1], 12, INK, true))
		v.add_child(row)
	if footer != "":
		var sp := Control.new(); sp.size_flags_vertical = Control.SIZE_EXPAND_FILL; sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(sp)
		v.add_child(_label(footer, 18, WARN))
	return b

# ---------- HUD de combat ----------
func _build_hud() -> void:
	hud = Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud)
	vignette = ColorRect.new()
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = "shader_type canvas_item; uniform vec4 tint : source_color = vec4(1.0, 0.16, 0.08, 1.0); uniform float strength = 0.0;\nvoid fragment() { float d = distance(UV, vec2(0.5)); COLOR = vec4(tint.rgb, smoothstep(0.35, 0.75, d) * strength); }"
	var sm := ShaderMaterial.new(); sm.shader = sh
	vignette.material = sm
	hud.add_child(vignette)
	surge_rect = ColorRect.new()
	surge_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	surge_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ssh := Shader.new()
	ssh.code = """shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
void fragment() {
	float d = distance(UV, vec2(0.5));
	vec2 off = (UV - 0.5) * 0.006;
	vec3 c = vec3(texture(screen_tex, SCREEN_UV + off).r, texture(screen_tex, SCREEN_UV).g, texture(screen_tex, SCREEN_UV - off).b);
	float edge = smoothstep(0.3, 0.8, d);
	c = mix(c, vec3(0.25, 0.85, 0.8), edge * 0.22);
	COLOR = vec4(c, 1.0);
}"""
	var ssm := ShaderMaterial.new(); ssm.shader = ssh
	surge_rect.material = ssm
	surge_rect.visible = false
	hud.add_child(surge_rect)
	glitch_rect = ColorRect.new()
	glitch_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	glitch_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gsh := Shader.new()
	gsh.code = """shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float strength = 0.0;
float h(float x) { return fract(sin(x * 91.7) * 43758.5); }
void fragment() {
	float t = floor(TIME * 18.0);
	float band = floor(SCREEN_UV.y * 24.0);
	float r = h(band + t);
	float shift = (r > 0.7 ? (h(band * 3.1 + t) - 0.5) * 0.08 : 0.0) * strength;
	vec2 uv = SCREEN_UV + vec2(shift, 0.0);
	vec3 c = vec3(texture(screen_tex, uv + vec2(0.006 * strength, 0.0)).r, texture(screen_tex, uv).g, texture(screen_tex, uv - vec2(0.006 * strength, 0.0)).b);
	float scan = 0.85 + 0.15 * sin(SCREEN_UV.y * 900.0);
	c *= mix(1.0, scan, strength);
	c = mix(c, vec3(0.65, 1.0, 0.0) * h(band + t * 1.3), step(0.94, r) * 0.35 * strength);
	COLOR = vec4(c, 1.0);
}"""
	var gsm := ShaderMaterial.new(); gsm.shader = gsh
	glitch_rect.material = gsm
	glitch_rect.visible = false
	hud.add_child(glitch_rect)
	lbl.glitch = _label("SIGNAL BROUILLÉ", 16, Color("a6ff00"), true)
	lbl.glitch.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	lbl.glitch.position.y += 70
	lbl.glitch.grow_horizontal = Control.GROW_DIRECTION_BOTH
	lbl.glitch.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.glitch.visible = false
	hud.add_child(lbl.glitch)

	cross = Control.new()
	cross.set_anchors_preset(Control.PRESET_FULL_RECT)
	cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cross.draw.connect(_draw_cross)
	hud.add_child(cross)

	# bannière, aide chargeur, barre de rechargement
	var mid := VBoxContainer.new()
	mid.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	mid.position.y = 150
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hud.add_child(mid)
	lbl.banner = _label("", 64, INK); lbl.banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.banner_sub = _label("", 14, DIM, true); lbl.banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(lbl.banner); mid.add_child(lbl.banner_sub)
	mid.modulate.a = 0.0
	lbl.banner_box = mid

	lbl.maghint = _label("TIRE SUR LE CHARGEUR", 13, WARN, true)
	lbl.maghint.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	lbl.maghint.position.y -= 60
	lbl.maghint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	lbl.maghint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.add_child(lbl.maghint)
	bars.reload = _bar(WARN, 64, 3)
	bars.reload.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	bars.reload.position += Vector2(-32, 26)
	hud.add_child(bars.reload)

	# boss
	boss_box = VBoxContainer.new()
	boss_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	boss_box.position.y = 22
	boss_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.boss = _label("", 13, HOT, true); lbl.boss.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bars.boss = _bar(HOT, 520, 10)
	boss_box.add_child(lbl.boss); boss_box.add_child(bars.boss)
	boss_box.visible = false
	hud.add_child(boss_box)

	var tl := _corner(Control.PRESET_TOP_LEFT, false)
	lbl.zone = _label("ZONE 1", 12, HOT, true); tl.add_child(lbl.zone)
	tl.add_child(_caps("Round"))
	lbl.wave = _label("1", 38, INK); tl.add_child(lbl.wave)
	lbl.remain = _caps("0 ennemis"); tl.add_child(lbl.remain)

	var tr := _corner(Control.PRESET_TOP_RIGHT, true)
	tr.add_child(_right(_caps("Score")))
	lbl.score = _right(_label("0", 38, INK)); tr.add_child(lbl.score)
	tr.add_child(_right(_caps("Style")))
	lbl.rank = _right(_label("D", 80, DIM)); tr.add_child(lbl.rank)
	bars.style = _bar(WARN, 160, 4); bars.style.size_flags_horizontal = Control.SIZE_SHRINK_END; tr.add_child(bars.style)
	lbl.chain = _right(_label(" ", 14, INK, true)); tr.add_child(lbl.chain)
	feed = VBoxContainer.new(); feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	feed.size_flags_horizontal = Control.SIZE_SHRINK_END
	tr.add_child(feed)

	var bl := _corner(Control.PRESET_BOTTOM_LEFT, false)
	bl.add_child(_caps("Santé"))
	lbl.hp = _label("100", 22, INK); bl.add_child(lbl.hp)
	bars.hp = _bar(COOL); bl.add_child(bars.hp)
	bl.add_child(_caps("Roulade"))
	bars.roll = _bar(WARN); bl.add_child(bars.roll)
	var eco := HBoxContainer.new(); eco.add_theme_constant_override("separation", 18); eco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.credits = _label("¤ 0", 20, WARN); eco.add_child(lbl.credits)
	lbl.level = _label("NIV. 1", 20, INK); eco.add_child(lbl.level)
	bl.add_child(eco)
	bars.xp = _bar(Color("b25cff"), 220, 4); bl.add_child(bars.xp)

	# compétence au centre, en bas
	var sk := VBoxContainer.new()
	sk.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(sk)
	sk.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 26)
	sk.grow_horizontal = Control.GROW_DIRECTION_BOTH
	sk.grow_vertical = Control.GROW_DIRECTION_BEGIN
	lbl.skill = _label("SURCHARGE", 12, DIM, true); lbl.skill.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sk.add_child(lbl.skill)
	bars.skill = _bar(COOL, 320, 6); sk.add_child(bars.skill)

	var br := _corner(Control.PRESET_BOTTOM_RIGHT, true)
	lbl.wname = _right(_caps("Fusil")); br.add_child(lbl.wname)
	lbl.ammo = _right(_label("30", 38, INK)); br.add_child(lbl.ammo)
	lbl.reserve = _right(_caps(" ")); br.add_child(lbl.reserve)
	lbl.mute = _right(_caps(" ")); br.add_child(lbl.mute)
	hud.visible = false

func _draw_cross() -> void:
	var c := cross.size / 2.0
	for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		cross.draw_line(c + d * 4.0, c + d * 11.0, INK, 2.0)
	if hitmark_t > 0.0:
		for d in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			cross.draw_line(c + d * 9.0, c + d * 15.0, HOT, 2.0)

func _process(delta: float) -> void:
	if hitmark_t > 0.0:
		hitmark_t -= delta
		cross.queue_redraw()
	if vig_t > 0.0:
		vig_t -= delta
		if vig_t <= 0.0:
			(vignette.material as ShaderMaterial).set_shader_parameter("strength", 0.0)
	if glitch_t > 0.0:
		glitch_t -= delta
		var gm := glitch_rect.material as ShaderMaterial
		gm.set_shader_parameter("strength", clampf(glitch_t / 0.6, 0.0, 1.0))
		lbl.glitch.modulate.a = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.03)
		if glitch_t <= 0.0:
			glitch_rect.visible = false
			lbl.glitch.visible = false
	if banner_t > 0.0:
		banner_t -= delta
		lbl.banner_box.modulate.a = clampf(banner_t / 0.3, 0.0, 1.0)

func hitmark() -> void:
	hitmark_t = 0.08
	cross.queue_redraw()

func flash(color: Color, strength: float) -> void:
	var m := vignette.material as ShaderMaterial
	m.set_shader_parameter("tint", color)
	m.set_shader_parameter("strength", strength)
	vig_t = 0.25

func banner(title: String, sub := "") -> void:
	lbl.banner.text = title.to_upper()
	lbl.banner_sub.text = sub.to_upper()
	lbl.banner_box.modulate.a = 1.0
	banner_t = 2.2

func add_feed(text: String, big: bool) -> void:
	var l := _right(_label(text, 16 if big else 14, HOT if big else WARN, true))
	feed.add_child(l)
	feed.move_child(l, 0)
	while feed.get_child_count() > 5:
		var old := feed.get_child(feed.get_child_count() - 1)
		feed.remove_child(old)
		old.queue_free()
	var tw := l.create_tween()
	tw.tween_interval(1.3)
	tw.tween_property(l, "modulate:a", 0.0, 0.5)
	tw.tween_callback(l.queue_free)

func rank_pop() -> void:
	lbl.rank.pivot_offset = lbl.rank.size * Vector2(1, 0.5)
	var tw: Tween = lbl.rank.create_tween()
	tw.tween_property(lbl.rank, "scale", Vector2.ONE * 1.18, 0.07)
	tw.tween_property(lbl.rank, "scale", Vector2.ONE, 0.1)

func glitch(t: float) -> void:
	glitch_t = maxf(glitch_t, t)
	glitch_rect.visible = true
	lbl.glitch.visible = true

func set_surge(on: bool) -> void:
	surge_rect.visible = on

func _scramble(t: String) -> String:
	# HUD brouillé par un hacker : les chiffres deviennent illisibles
	if glitch_t <= 0.0:
		return t
	var out := ""
	var junk := "#%&@$?!01"
	for ch in t:
		out += junk[randi() % junk.length()] if randf() < 0.6 and ch != " " else ch
	return out

func show_boss(name: String) -> void:
	lbl.boss.text = name.to_upper()
	boss_box.visible = true

func update_hud(d: Dictionary) -> void:
	lbl.hp.text = _scramble(str(d.hp))
	bars.hp.value = d.hp_pct
	(bars.hp.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = HOT if d.hp_pct < 35 else COOL
	bars.roll.value = d.roll_pct
	lbl.score.text = _scramble(str(d.score))
	if lbl.rank.text != d.rank:
		lbl.rank.text = d.rank
		lbl.rank.add_theme_color_override("font_color", RANK_COLORS.get(d.rank, INK))
	bars.style.value = d.style_pct
	lbl.chain.text = d.chain
	lbl.zone.text = d.zone.to_upper()
	lbl.wave.text = _scramble(d.wave)
	lbl.remain.text = _scramble(d.remain.to_upper())
	lbl.wname.text = d.wname.to_upper()
	lbl.ammo.text = _scramble(d.ammo)
	lbl.reserve.text = d.reserve.to_upper()
	bars.reload.visible = d.reload_pct >= 0.0
	bars.reload.value = maxf(d.reload_pct, 0.0)
	lbl.maghint.visible = d.mag_flying
	boss_box.visible = d.boss_pct >= 0.0
	bars.boss.value = maxf(d.boss_pct, 0.0)
	lbl.credits.text = _scramble("¤ %d" % d.credits)
	lbl.level.text = "NIV. %d" % d.level + ("  +%d PT" % d.points if d.points > 0 else "")
	bars.xp.value = d.xp_pct
	bars.skill.value = d.skill_pct
	lbl.skill.text = d.skill_txt
	lbl.skill.add_theme_color_override("font_color", COOL if d.skill_ready else DIM)

func set_mute(m: bool) -> void:
	lbl.mute.text = "MUSIQUE COUPÉE (M)" if m else " "

# ---------- Écrans ----------
func _build_menu() -> void:
	var v := _screen("menu", 900)
	v.add_child(_caps("Zone 1 · Ville néon"))
	v.add_child(_title("Horde", "Breaker"))
	var p := _label("10 rounds dans la ville néon : un mini-boss au round 5, le boss de zone au round 10, un shop après les rounds 3, 6 et 9. Enchaîne les kills aériens, les wall runs et les tirs de chargeur : ton combo fait monter le score et charge ta compétence.", 16, DIM, false, true)
	p.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(p)
	var ch := HBoxContainer.new(); ch.add_theme_constant_override("separation", 18)
	lbl.char_name = _label("KADE", 26, INK)
	ch.add_child(lbl.char_name)
	var cv := VBoxContainer.new(); cv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.char_title = _label("", 12, HOT, true); cv.add_child(lbl.char_title)
	lbl.char_skill = _label("", 14, INK, false, true); lbl.char_skill.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cv.add_child(lbl.char_skill)
	ch.add_child(cv)
	v.add_child(ch)
	v.add_child(_caps("Choisis ton arme pour le run"))
	weapon_box = GridContainer.new(); weapon_box.columns = 3
	weapon_box.add_theme_constant_override("h_separation", 12)
	v.add_child(weapon_box)
	var keys := GridContainer.new(); keys.columns = 4
	keys.add_theme_constant_override("h_separation", 18)
	for row in [["ZQSD / WASD", "Se déplacer"], ["Souris", "Viser, clic gauche pour tirer"], ["Espace", "Sauter, double saut, wall jump"],
			["Shift", "Roulade invincible"], ["C", "Glissade en courant"], ["Contre un mur", "Saute et avance : wall run"],
			["R", "Recharger, tire sur le chargeur en vol"], ["E · clic droit", "Compétence quand la jauge est pleine"], ["P · Échap", "Pause · M musique"],
			["Manette", "A saut, LB roulade, B glissade, X recharger, Y compétence, RT tirer"]]:
		keys.add_child(_label(row[0], 12, WARN, true))
		keys.add_child(_label(row[1], 12, INK, true))
	v.add_child(keys)
	lbl.best = _label("", 12, DIM, true)
	v.add_child(lbl.best)

func show_menu(character: Dictionary, weapons: Dictionary, chosen: String, best: int, best_wave: int) -> void:
	lbl.char_name.text = character.name.to_upper()
	lbl.char_title.text = (character.title + " · compétence : " + character.skill).to_upper()
	lbl.char_skill.text = character.blurb + " " + character.skill + " : " + character.skill_desc
	for c in weapon_box.get_children():
		c.queue_free()
	var i := 1
	for id in character.weapons:
		var w: Dictionary = weapons[id]
		var last: bool = id == chosen
		var b := _card(str(i), "Dernière arme jouée" if last else "Arme", WARN, w.name, w.blurb, w.stats, last, "", false, 230.0)
		b.pressed.connect(func(): weapon_picked.emit(id))
		weapon_box.add_child(b)
		i += 1
	lbl.best.text = ("Meilleur score : %d · meilleur round : %d / 10" % [best, best_wave]) if best > 0 else ""
	show_screen("menu")

func _build_augments() -> void:
	var v := _screen("augment", 900)
	lbl.aug_title = _caps("Vague nettoyée"); v.add_child(lbl.aug_title)
	v.add_child(_title("Choisis un", "augment"))
	aug_box = GridContainer.new(); aug_box.columns = 3
	aug_box.add_theme_constant_override("h_separation", 12)
	v.add_child(aug_box)
	lbl.aug_owned = _label("", 12, DIM, true)
	lbl.aug_owned.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(lbl.aug_owned)

func show_augments(choices: Array, taken: Dictionary, title: String, weapon_name: String, owned: String) -> void:
	for c in aug_box.get_children():
		c.queue_free()
	for i in choices.size():
		var a: Dictionary = choices[i]
		var lvl: int = taken.get(a.id, 0)
		var tag: String = (weapon_name if a.has("weapon") else a.tag) + (" · niv. %d" % (lvl + 1) if lvl > 0 else "")
		var b := _card(str(i + 1), tag, HOT if a.has("weapon") else WARN, a.name, a.desc)
		var idx := i
		b.pressed.connect(func(): augment_picked.emit(idx))
		aug_box.add_child(b)
	lbl.aug_title.text = title.to_upper()
	lbl.aug_owned.text = owned
	show_screen("augment")

func _build_shop() -> void:
	var v := _screen("shop", 900)
	lbl.shop_sub = _caps(""); v.add_child(lbl.shop_sub)
	var top := HBoxContainer.new()
	var t := _title("Marché", "noir"); t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(t)
	var money := VBoxContainer.new()
	lbl.shop_credits = _right(_label("¤ 0", 36, WARN)); money.add_child(lbl.shop_credits)
	lbl.shop_hp = _right(_caps("")); money.add_child(lbl.shop_hp)
	top.add_child(money)
	v.add_child(top)
	shop_box = GridContainer.new(); shop_box.columns = 3
	shop_box.add_theme_constant_override("h_separation", 12)
	shop_box.add_theme_constant_override("v_separation", 12)
	v.add_child(shop_box)
	var b := _button("Continuer (Entrée)")
	b.pressed.connect(func(): continue_pressed.emit())
	v.add_child(b)

func show_shop(offers: Array, credits: int, hp: int, max_hp: int, sub: String) -> void:
	for c in shop_box.get_children():
		c.queue_free()
	for i in offers.size():
		var o: Dictionary = offers[i]
		var sold: bool = o.get("sold", false)
		var footer := "VENDU" if sold else "¤ %d" % o.price
		var b := _card(str(i + 1), o.tag, HOT if o.kind in ["aug", "upgrade"] else (COOL if o.kind == "heal" else WARN), o.name, o.desc, [], false, footer, sold or credits < o.price, 190.0)
		var idx := i
		b.pressed.connect(func(): shop_buy.emit(idx))
		shop_box.add_child(b)
	lbl.shop_credits.text = "¤ %d" % credits
	lbl.shop_hp.text = "SANTÉ %d / %d" % [hp, max_hp]
	lbl.shop_sub.text = sub.to_upper()
	show_screen("shop")

func _build_tree() -> void:
	var v := _screen("tree", 900)
	lbl.tree_sub = _caps(""); v.add_child(lbl.tree_sub)
	v.add_child(_title("Arbre de", "compétences"))
	lbl.tree_points = _label("", 16, WARN, true); v.add_child(lbl.tree_points)
	tree_box = HBoxContainer.new()
	tree_box.add_theme_constant_override("separation", 12)
	v.add_child(tree_box)
	var b := _button("Garder mes points (Entrée)", false)
	b.pressed.connect(func(): continue_pressed.emit())
	v.add_child(b)

func show_tree(character: Dictionary, branches: Array, owned: Dictionary, points: int, level: int) -> void:
	for c in tree_box.get_children():
		c.queue_free()
	for br in branches:
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 8)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(_label(br.branch.to_upper(), 14, HOT, true))
		var prev_owned := true
		for n in br.nodes:
			var have: bool = owned.has(n.id)
			var open: bool = not have and prev_owned
			var tag := "Acquis" if have else ("Version améliorée" if n.get("ult", false) else ("Disponible" if open else "Verrouillé"))
			var b := _card("", tag, COOL if have else (WARN if open else DIM), n.name, n.desc, [], have, "", not have and not open, 132.0)
			var id: String = n.id
			b.pressed.connect(func(): tree_pick.emit(id))
			col.add_child(b)
			prev_owned = have
		tree_box.add_child(col)
	lbl.tree_points.text = "%d POINT%s À PLACER" % [points, "S" if points > 1 else ""]
	lbl.tree_sub.text = ("%s · niveau %d" % [character.name, level]).to_upper()
	show_screen("tree")

func _build_victory() -> void:
	var v := _screen("victory", 620)
	lbl.v_sub = _caps("Boss de zone vaincu"); v.add_child(lbl.v_sub)
	v.add_child(_title("Zone", "nettoyée"))
	var g := GridContainer.new(); g.columns = 5
	g.add_theme_constant_override("h_separation", 26)
	for k in [["v_kills", "Kills"], ["v_rank", "Style max"], ["v_level", "Niveau"], ["v_credits", "Crédits"], ["v_score", "Score"]]:
		var c := VBoxContainer.new()
		c.add_child(_caps(k[1]))
		lbl[k[0]] = _label("0", 22, INK)
		c.add_child(lbl[k[0]])
		g.add_child(c)
	v.add_child(g)
	var note := _label("La zone 2, la fonderie, arrive bientôt.", 15, DIM, false, true)
	v.add_child(note)
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 12)
	var r := _button("Rejouer"); r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.pressed.connect(func(): retry_pressed.emit())
	var m := _button("Menu", false); m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.pressed.connect(func(): menu_pressed.emit())
	h.add_child(r); h.add_child(m)
	v.add_child(h)

func show_victory(zone_name: String, kills: int, rank: String, score: int, level: int, credits: int) -> void:
	lbl.v_sub.text = ("Boss de zone vaincu · " + zone_name).to_upper()
	lbl.v_kills.text = str(kills)
	lbl.v_rank.text = rank
	lbl.v_level.text = str(level)
	lbl.v_credits.text = str(credits)
	lbl.v_score.text = str(score)
	show_screen("victory")

func _build_pause() -> void:
	var v := _screen("pause", 420)
	v.add_child(_title("Pause", ""))
	var b := _button("Reprendre")
	b.pressed.connect(func(): resume_pressed.emit())
	v.add_child(b)

func _build_over() -> void:
	var v := _screen("over", 560)
	v.add_child(_caps("Tu es tombé"))
	v.add_child(_title("Game", "Over"))
	var g := GridContainer.new()
	g.columns = 5
	g.add_theme_constant_override("h_separation", 28)
	for k in [["o_wave", "Round"], ["o_kills", "Kills"], ["o_rank", "Style max"], ["o_level", "Niveau"], ["o_score", "Score"]]:
		var c := VBoxContainer.new()
		c.add_child(_caps(k[1]))
		lbl[k[0]] = _label("0", 22, INK)
		c.add_child(lbl[k[0]])
		g.add_child(c)
	v.add_child(g)
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 12)
	var r := _button("Rejouer"); r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.pressed.connect(func(): retry_pressed.emit())
	var m := _button("Changer d'arme", false); m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.pressed.connect(func(): menu_pressed.emit())
	h.add_child(r); h.add_child(m)
	v.add_child(h)

func show_over(wave: int, kills: int, rank: String, score: int, level: int) -> void:
	lbl.o_wave.text = "%d / 10" % wave
	lbl.o_level.text = str(level)
	lbl.o_kills.text = str(kills)
	lbl.o_rank.text = rank
	lbl.o_score.text = str(score)
	show_screen("over")

func show_screen(name: String) -> void:
	for k in screens:
		screens[k].visible = k == name
	hud.visible = name in ["none", "pause"]
