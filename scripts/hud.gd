class_name Hud
extends CanvasLayer
## 界面层：回合信息、棋子信息、卡牌栏、结束回合按钮、战斗日志、胜利面板。
## 全部用代码搭建，只负责显示和发信号，不含规则。

signal card_pressed(card_id: String)
signal end_turn_pressed
signal restart_pressed

const COLOR_ATTACK := Color("#b45309")
const COLOR_SKILL := Color("#4338ca")
const MAX_LOG := 60

var turn_label: Label
var hint_label: Label
var info_label: Label
var log_label: RichTextLabel
var card_bar: HBoxContainer
var end_btn: Button
var win_panel: PanelContainer
var win_label: Label
var _log_lines: PackedStringArray = []


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# 左上：回合 + 提示
	turn_label = _label(24)
	turn_label.position = Vector2(16, 8)
	root.add_child(turn_label)
	hint_label = _label(15)
	hint_label.position = Vector2(16, 44)
	hint_label.add_theme_color_override("font_color", Color("#fde68a"))
	root.add_child(hint_label)

	# 左侧：棋子信息
	var info_panel := _panel()
	info_panel.position = Vector2(12, 84)
	info_panel.custom_minimum_size = Vector2(250, 0)
	root.add_child(info_panel)
	info_label = _label(15)
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_label.custom_minimum_size = Vector2(230, 0)
	info_panel.add_child(info_label)

	# 右侧：战斗日志
	var log_panel := _panel()
	log_panel.anchor_left = 1.0
	log_panel.anchor_right = 1.0
	log_panel.offset_left = -312
	log_panel.offset_right = -12
	log_panel.offset_top = 12
	log_panel.offset_bottom = 420
	root.add_child(log_panel)
	log_label = RichTextLabel.new()
	log_label.bbcode_enabled = true
	log_label.scroll_following = true
	log_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	log_label.add_theme_font_size_override("normal_font_size", 13)
	log_label.add_theme_font_size_override("bold_font_size", 13)
	log_panel.add_child(log_label)

	# 底部：卡牌栏
	card_bar = HBoxContainer.new()
	card_bar.anchor_top = 1.0
	card_bar.anchor_bottom = 1.0
	card_bar.anchor_right = 1.0
	card_bar.offset_left = 12
	card_bar.offset_right = -170
	card_bar.offset_top = -122
	card_bar.offset_bottom = -14
	card_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	card_bar.add_theme_constant_override("separation", 10)
	card_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(card_bar)

	# 右下：结束回合
	end_btn = Button.new()
	end_btn.text = "结束回合"
	end_btn.focus_mode = Control.FOCUS_NONE
	end_btn.anchor_left = 1.0
	end_btn.anchor_right = 1.0
	end_btn.anchor_top = 1.0
	end_btn.anchor_bottom = 1.0
	end_btn.offset_left = -156
	end_btn.offset_right = -14
	end_btn.offset_top = -96
	end_btn.offset_bottom = -36
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


func set_hint(text: String) -> void:
	hint_label.text = text


func set_info(text: String) -> void:
	info_label.text = text


func add_log(text: String) -> void:
	_log_lines.append(text)
	if _log_lines.size() > MAX_LOG:
		_log_lines.remove_at(0)
	log_label.text = "\n".join(_log_lines)


## cards: [{id, name, kind, summary, desc, status, enabled, selecting}]
func set_cards(cards: Array) -> void:
	for c in card_bar.get_children():
		c.queue_free()
	for c in cards:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(168, 104)
		b.clip_text = false
		var tag := "【攻击】" if c["kind"] == "attack" else "【技能】"
		b.text = "%s%s\n%s\n%s" % [tag, c["name"], c["summary"], c["status"]]
		b.tooltip_text = c["desc"]
		b.disabled = not c["enabled"]
		b.add_theme_font_size_override("font_size", 14)
		_style_button(b, COLOR_ATTACK if c["kind"] == "attack" else COLOR_SKILL, c["selecting"])
		b.pressed.connect(card_pressed.emit.bind(c["id"]))
		card_bar.add_child(b)


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
