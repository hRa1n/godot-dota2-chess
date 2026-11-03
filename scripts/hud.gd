class_name Hud
extends CanvasLayer
## 界面层：左列 = 回合 / 提示 / 棋子信息 / 行动卡；右列 = 装备手牌 / 战斗日志 / 结束回合；中间是棋盘。
## 全部用代码搭建，只负责显示和发信号，不含规则。

signal card_pressed(card_id: String)
signal hand_card_pressed(uid: int)
signal end_turn_pressed
signal restart_pressed

const MAX_LOG := 60

var turn_label: Label
var hint_label: Label
var info_label: Label
var capture_label: Label
var log_label: RichTextLabel
var cards_flow: HFlowContainer
var hand_root: Control
var hand_label: Label
var _hand_cards: Array = []
## 两侧栏宽度；卡牌两列排
const SIDE_W := 318.0
const CARD_GAP := 10.0
const CARD_SIZE := Vector2(154, 237)
const LOG_H := 170.0
const END_H := 56.0
var end_btn: Button
var win_panel: PanelContainer
var win_label: Label
var _log_lines: PackedStringArray = []


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# ================= 左列：回合、提示、棋子信息、行动卡 =================
	var left := VBoxContainer.new()
	left.position = Vector2(12, 8)
	left.custom_minimum_size = Vector2(SIDE_W, 0)
	left.add_theme_constant_override("separation", 8)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(left)
	turn_label = _label(24)
	left.add_child(turn_label)
	hint_label = _label(14)
	hint_label.add_theme_color_override("font_color", Color("#fde68a"))
	hint_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	hint_label.custom_minimum_size = Vector2(SIDE_W, 0)
	left.add_child(hint_label)
	var info_panel := _panel()
	left.add_child(info_panel)
	info_label = _label(14)
	info_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	info_label.custom_minimum_size = Vector2(SIDE_W - 24, 0)
	info_panel.add_child(info_label)
	var action_title := _label(14)
	action_title.text = "行动卡"
	action_title.add_theme_color_override("font_color", Color("#fcd34d"))
	left.add_child(action_title)
	cards_flow = HFlowContainer.new()
	cards_flow.custom_minimum_size = Vector2(SIDE_W, 0)
	cards_flow.add_theme_constant_override("h_separation", CARD_GAP)
	cards_flow.add_theme_constant_override("v_separation", CARD_GAP)
	cards_flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(cards_flow)

	# 顶部居中：能量圈状态
	capture_label = _label(16)
	capture_label.anchor_left = 0.5
	capture_label.anchor_right = 0.5
	capture_label.offset_left = -300
	capture_label.offset_right = 300
	capture_label.offset_top = 12
	capture_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(capture_label)

	# ================= 右列：装备手牌、战斗日志、结束回合 =================
	hand_label = _label(14)
	hand_label.add_theme_color_override("font_color", Color("#86efac"))
	hand_label.anchor_left = 1.0
	hand_label.anchor_right = 1.0
	hand_label.offset_left = -SIDE_W - 12
	hand_label.offset_right = -12
	hand_label.offset_top = 12
	root.add_child(hand_label)
	hand_root = Control.new()
	hand_root.anchor_left = 1.0
	hand_root.anchor_right = 1.0
	hand_root.anchor_bottom = 1.0
	hand_root.offset_left = -SIDE_W - 12
	hand_root.offset_right = -12
	hand_root.offset_top = 40
	hand_root.offset_bottom = -LOG_H - END_H - 24
	hand_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hand_root.resized.connect(_layout_hand)
	root.add_child(hand_root)

	var log_panel := _panel()
	log_panel.anchor_left = 1.0
	log_panel.anchor_right = 1.0
	log_panel.anchor_top = 1.0
	log_panel.anchor_bottom = 1.0
	log_panel.offset_left = -SIDE_W - 12
	log_panel.offset_right = -12
	log_panel.offset_top = -LOG_H - END_H - 16
	log_panel.offset_bottom = -END_H - 16
	root.add_child(log_panel)
	log_label = RichTextLabel.new()
	log_label.bbcode_enabled = true
	log_label.scroll_following = true
	log_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	log_label.add_theme_font_size_override("normal_font_size", 12)
	log_label.add_theme_font_size_override("bold_font_size", 12)
	log_panel.add_child(log_label)

	end_btn = Button.new()
	end_btn.text = "结束回合（空格）"
	end_btn.focus_mode = Control.FOCUS_NONE
	end_btn.anchor_left = 1.0
	end_btn.anchor_right = 1.0
	end_btn.anchor_top = 1.0
	end_btn.anchor_bottom = 1.0
	end_btn.offset_left = -SIDE_W - 12
	end_btn.offset_right = -12
	end_btn.offset_top = -END_H - 8
	end_btn.offset_bottom = -8
	end_btn.add_theme_font_size_override("font_size", 20)
	_style_button(end_btn, Color("#047857"))
	end_btn.pressed.connect(end_turn_pressed.emit)
	root.add_child(end_btn)

	# 胜利面板
	win_panel = _panel(Color(0, 0, 0, 0.85))
	win_panel.set_anchors_preset(Control.PRESET_CENTER)
	win_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	win_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	win_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	win_panel.visible = false
	root.add_child(win_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	win_panel.add_child(vb)
	win_label = _label(40)
	win_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(win_label)
	var again := Button.new()
	again.text = "重新开始"
	again.focus_mode = Control.FOCUS_NONE
	again.custom_minimum_size = Vector2(220, 52)
	again.add_theme_font_size_override("font_size", 20)
	_style_button(again, Color("#047857"))
	again.pressed.connect(restart_pressed.emit)
	vb.add_child(again)


# ---------- 对外接口 ----------

func set_turn(round_no: int, team_name: String, team_color: Color) -> void:
	turn_label.text = "第 %d 回合 · %s行动" % [round_no, team_name]
	turn_label.add_theme_color_override("font_color", team_color.lightened(0.35))


func set_capture(text: String, color: Color) -> void:
	capture_label.text = text
	capture_label.add_theme_color_override("font_color", color.lightened(0.4))


func set_hint(text: String) -> void:
	hint_label.text = text


func set_info(text: String) -> void:
	info_label.text = text


func add_log(text: String) -> void:
	_log_lines.append(text)
	if _log_lines.size() > MAX_LOG:
		_log_lines.remove_at(0)
	log_label.text = "\n".join(_log_lines)


## cards: 见 CardView.info 的字段说明
func set_cards(cards: Array) -> void:
	for c in cards_flow.get_children():
		cards_flow.remove_child(c)
		c.queue_free()
	for c in cards:
		var v := CardView.new()
		v.setup(c, CARD_SIZE)
		v.clicked.connect(func(info): card_pressed.emit(info["id"]))
		cards_flow.add_child(v)


## 装备手牌：两列排，放不下时上下叠起来；悬停的那张会上浮并放到最前面
func set_hand(cards: Array, header: String) -> void:
	hand_label.text = header
	for c in hand_root.get_children():
		hand_root.remove_child(c)
		c.queue_free()
	_hand_cards.clear()
	for c in cards:
		var v := CardView.new()
		v.setup(c, CARD_SIZE)
		v.raise_on_hover = true
		v.clicked.connect(func(info): hand_card_pressed.emit(info["uid"]))
		hand_root.add_child(v)
		_hand_cards.append(v)
	_layout_hand()


func _layout_hand() -> void:
	var n := _hand_cards.size()
	if n == 0:
		return
	var rows := int(ceil(n / 2.0))
	var h := CARD_SIZE.y
	var avail := hand_root.size.y
	var step := h + CARD_GAP
	if rows > 1 and step * (rows - 1) + h > avail:
		step = maxf(40.0, (avail - h) / (rows - 1))
	for i in n:
		var v: CardView = _hand_cards[i]
		v.base_y = (i / 2) * step
		v.position = Vector2((i % 2) * (CARD_SIZE.x + CARD_GAP), v.base_y)


func show_winner(text: String, color: Color) -> void:
	win_label.text = text
	win_label.add_theme_color_override("font_color", color.lightened(0.3))
	win_panel.visible = true
	end_btn.disabled = true


# ---------- 样式 ----------

func _label(size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color("#e5edf5"))
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _panel(bg := Color(0.04, 0.07, 0.12, 0.8)) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(12)
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _style_button(b: Button, base: Color, selecting := false) -> void:
	var states := {
		"normal": base,
		"hover": base.lightened(0.15),
		"pressed": base.darkened(0.15),
		"disabled": Color(0.25, 0.27, 0.3, 0.9),
	}
	for s in states:
		var sb := StyleBoxFlat.new()
		sb.bg_color = states[s]
		sb.set_corner_radius_all(8)
		sb.set_content_margin_all(8)
		if selecting and s != "disabled":
			sb.set_border_width_all(3)
			sb.border_color = Color("#facc15")
		b.add_theme_stylebox_override(s, sb)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(0.7, 0.72, 0.75))
