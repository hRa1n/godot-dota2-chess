class_name Piece
extends Node2D
## 一个棋子 = 一个角色。只负责自己的状态和绘制，规则在 game.gd。

const FONT := preload("res://assets/fonts/NotoSansSC-Subset.otf")

var type_id := ""
var def: Dictionary
var team := 0
var team_color := Color.WHITE
var label_name := ""        # 例：蓝·宙斯、红·士兵2
var cell := Vector2i.ZERO
var hp := 1
var max_hp := 1
var move := 1
var cards: Array = []
var cooldowns := {}         # 卡牌 id -> 剩余冷却（己方回合数）
var stun := 0               # 剩余眩晕（己方回合数）
var alive := true
var is_hero := false
var highlight := false      # 本回合正在行动
var cell_size := 48


func setup(p_type: String, p_team: int, p_color: Color, p_label: String, p_cell_size: int) -> void:
	type_id = p_type
	def = PieceDefs.PIECES[p_type]
	team = p_team
	team_color = p_color
	label_name = p_label
	cell_size = p_cell_size
	max_hp = def["hp"]
	hp = max_hp
	move = def["move"]
	cards = def["cards"]
	is_hero = def["hero"]
	z_index = 1


func cooldown_of(card_id: String) -> int:
	return cooldowns.get(card_id, 0)


## 己方回合结束时调用：冷却、眩晕各减 1
func end_own_turn() -> void:
	for k in cooldowns.keys():
		cooldowns[k] = maxi(0, cooldowns[k] - 1)
	if stun > 0:
		stun -= 1
	queue_redraw()


func flash() -> void:
	modulate = Color(2.2, 2.2, 2.2)
	create_tween().tween_property(self, "modulate", Color.WHITE, 0.3)


func die() -> void:
	alive = false
	highlight = false
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.4)
	tw.tween_callback(hide)


func _draw() -> void:
	var r := cell_size * (0.42 if is_hero else 0.32)

	if highlight:
		draw_circle(Vector2.ZERO, r + 6, Color(0.98, 0.8, 0.08, 0.45))
	draw_circle(Vector2(2, 3), r, Color(0, 0, 0, 0.25))       # 阴影
	draw_circle(Vector2.ZERO, r, team_color)
	draw_arc(Vector2.ZERO, r, 0, TAU, 40, Color.WHITE, 2.5 if is_hero else 1.5)

	var short: String = def["short"]
	var fs := 22 if is_hero else 15
	var w := FONT.get_string_size(short, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var baseline := (FONT.get_ascent(fs) - FONT.get_descent(fs)) * 0.5
	draw_string(FONT, Vector2(-w * 0.5, baseline), short, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)

	# 血条
	var bw := cell_size * 0.82
	var top := -cell_size * 0.5 + 1
	var ratio := float(hp) / max_hp
	var bar_col := Color("#16a34a") if ratio > 0.5 else (Color("#eab308") if ratio > 0.25 else Color("#dc2626"))
	draw_rect(Rect2(-bw * 0.5, top, bw, 5), Color(0, 0, 0, 0.55))
	draw_rect(Rect2(-bw * 0.5, top, bw * ratio, 5), bar_col)

	# 眩晕标记
	if stun > 0:
		var p := Vector2(r * 0.55, -r * 0.55)
		draw_circle(p, 9, Color("#facc15"))
		var sw := FONT.get_string_size("晕", HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		draw_string(FONT, p + Vector2(-sw * 0.5, 4.5), "晕", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.BLACK)
