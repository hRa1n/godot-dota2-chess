class_name CardView
extends Control
## 一张卡牌（炉石风格）：金色边框、卡面插画、名字横幅、描述框、三颗宝石。
##   左下橙宝石 = 伤害   右下青宝石 = 范围（没有就不画）
##   卡身颜色：攻击卡棕、技能卡蓝、装备卡绿
## 只负责显示和点击，规则在 game.gd。

signal clicked(info: Dictionary)

const FONT := preload("res://assets/fonts/NotoSansSC-Subset.otf")
const ART_DIR := "res://assets/icons/"
## 基准卡尺寸 170x262，实际显示放大到 CARD_SIZE
const BASE_W := 170.0
const CARD_SIZE := Vector2(232, 358)
const GOLD := Color("#d4af37")

## {id, uid, name, kind, type_line, card_text, desc, art, damage, range_text, status, enabled, selecting}
var info: Dictionary = {}
var raise_on_hover := false     # 手牌：悬停时上浮
var base_y := 0.0
var _hover := false
var _art: Texture2D


func setup(c: Dictionary, card_size := CARD_SIZE) -> void:
	info = c
	custom_minimum_size = card_size
	size = card_size
	var path: String = ART_DIR + c.get("art", "sword") + ".svg"
	_art = load(path) if ResourceLoader.exists(path) else load(ART_DIR + "sword.svg")
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = c["desc"]
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if c["enabled"] else Control.CURSOR_ARROW
	modulate = Color.WHITE if c["enabled"] else Color(0.6, 0.6, 0.66)
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER:
		_hover = true
		if raise_on_hover:
			position.y = base_y - size.y * 0.12
			z_index = 10
		queue_redraw()
	elif what == NOTIFICATION_MOUSE_EXIT:
		_hover = false
		if raise_on_hover:
			position.y = base_y
			z_index = 0
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		if info.get("enabled", false):
			clicked.emit(info)


func _draw() -> void:
	if info.is_empty():
		return
	var ci := get_canvas_item()
	var w := size.x
	var h := size.y
	var k := w / BASE_W            # 所有尺寸按基准卡（170 宽）等比放大，字体同步放大保持清晰
	var base: Color = {"attack": Color("#7a4510"), "skill": Color("#1e3a8a"), "equip": Color("#14532d")}[info["kind"]]

	# 选中 / 悬停光晕
	if info["selecting"]:
		_sb(Color(0.98, 0.8, 0.1, 0.6), int(18 * k)).draw(ci, Rect2(-6 * k, -6 * k, w + 12 * k, h + 12 * k))
	elif _hover and info["enabled"]:
		_sb(Color(1, 1, 1, 0.28), int(17 * k)).draw(ci, Rect2(-4 * k, -4 * k, w + 8 * k, h + 8 * k))

	# 边框 + 卡身
	_sb(GOLD, int(14 * k)).draw(ci, Rect2(0, 0, w, h))
	_sb(base, int(11 * k), 1, base.lightened(0.35)).draw(ci, Rect2(4 * k, 4 * k, w - 8 * k, h - 8 * k))

	# 插画（椭圆窗）
	var art := Rect2(14 * k, 26 * k, w - 28 * k, 96 * k)
	_sb(base.darkened(0.6), int(48 * k), int(3 * k), GOLD).draw(ci, art)
	var s := 86.0 * k
	draw_texture_rect(_art, Rect2(art.get_center() - Vector2(s, s) * 0.5, Vector2(s, s)), false)

	# 名字横幅
	var banner := Rect2(8 * k, 110 * k, w - 16 * k, 28 * k)
	_sb(base.darkened(0.35), int(6 * k), int(2 * k), GOLD).draw(ci, banner)
	_text(info["name"], banner.get_center(), int(17 * k), Color.WHITE, true)

	# 类型
	_text(info.get("type_line", ""), Vector2(w * 0.5, 150 * k), int(12 * k), GOLD.lightened(0.25))

	# 描述框
	var box := Rect2(12 * k, 160 * k, w - 24 * k, 66 * k)
	_sb(Color("#f3e9d2"), int(6 * k)).draw(ci, box)
	var txt: String = info["card_text"]
	var fs := int((13 if txt.length() <= 20 else 11) * k)
	var lines := 3 if txt.length() <= 20 else 4
	draw_multiline_string(FONT, Vector2(box.position.x + 5 * k, box.position.y + 4 * k + FONT.get_ascent(fs)), txt,
		HORIZONTAL_ALIGNMENT_CENTER, box.size.x - 10 * k, fs, lines, Color("#3b2a14"))

	# 宝石
	var dmg: String = info["damage"]
	if dmg != "":
		_gem(Vector2(20 * k, h - 18 * k), 17 * k, Color("#d97706"), dmg, int((17 if dmg.length() <= 2 else 11) * k))
	var rng: String = info["range_text"]
	if rng != "":
		_gem(Vector2(w - 20 * k, h - 18 * k), 17 * k, Color("#0e7490"), rng, int((11 if rng.length() <= 5 else 9) * k))

	# 状态（冷却中 / 已出牌 …）
	if info["status"] != "可用":
		var st: String = info["status"]
		var sfs := int(11 * k)
		var tw := FONT.get_string_size(st, HORIZONTAL_ALIGNMENT_LEFT, -1, sfs).x + 14 * k
		var pill := Rect2(w * 0.5 - tw * 0.5, h - 27 * k, tw, 19 * k)
		_sb(Color(0, 0, 0, 0.8), int(9 * k)).draw(ci, pill)
		_text(st, pill.get_center(), sfs, Color("#fde68a"))


func _gem(c: Vector2, r: float, col: Color, t: String, fs: int) -> void:
	draw_circle(c, r * 1.15, GOLD)
	draw_circle(c, r, col)
	draw_arc(c, r * 0.8, deg_to_rad(200), deg_to_rad(290), 12, Color(1, 1, 1, 0.45), r * 0.12)
	_text(t, c, fs, Color.WHITE, true)


func _text(t: String, center: Vector2, fs: int, col: Color, outline := false) -> void:
	var tw := FONT.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pos := Vector2(center.x - tw * 0.5, center.y + (FONT.get_ascent(fs) - FONT.get_descent(fs)) * 0.5)
	if outline:
		draw_string_outline(FONT, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, maxi(4, fs / 4), Color(0, 0, 0, 0.75))
	draw_string(FONT, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _sb(bg: Color, radius: int, border := 0, border_col := Color.TRANSPARENT) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.anti_aliasing = true
	if border > 0:
		sb.set_border_width_all(border)
		sb.border_color = border_col
	return sb
