class_name ApBar
extends Control
## 屏幕正下方的行动点条（参考《神界：原罪 2》）：
##   移动点 1 个、行动点 1 个；可用时点亮，用掉后变灰。装备不消耗点数。

const FONT := preload("res://assets/fonts/NotoSansSC-Subset.otf")
const ICON_MOVE := preload("res://assets/icons/boots.svg")
const ICON_ACTION := preload("res://assets/icons/sword.svg")
const GOLD := Color("#d4af37")

var move_left := true
var action_left := true
var who := ""
var team_color := Color.WHITE


func set_state(p_move: bool, p_action: bool, p_who: String, p_color: Color) -> void:
	move_left = p_move
	action_left = p_action
	who = p_who
	team_color = p_color
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	# 底板
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.05, 0.09, 0.85)
	sb.set_corner_radius_all(int(h * 0.5))
	sb.set_border_width_all(2)
	sb.border_color = GOLD.darkened(0.2)
	sb.anti_aliasing = true
	sb.draw(get_canvas_item(), Rect2(Vector2.ZERO, size))

	# 左边：当前行动棋子
	_text(who, Vector2(18, h * 0.5), 14, team_color.lightened(0.45), HORIZONTAL_ALIGNMENT_LEFT)

	# 两颗点：移动、行动
	var r := h * 0.34
	var cx := w * 0.5 + 10
	_pip(Vector2(cx - 62, h * 0.5), r, move_left, Color("#22c55e"), ICON_MOVE, "移动")
	_pip(Vector2(cx + 34, h * 0.5), r, action_left, Color("#f59e0b"), ICON_ACTION, "行动")

	# 右边：说明
	_text("装备不消耗点数", Vector2(w - 18, h * 0.5), 12, Color("#86efac"), HORIZONTAL_ALIGNMENT_RIGHT)


func _pip(c: Vector2, r: float, lit: bool, col: Color, icon: Texture2D, label: String) -> void:
	if lit:
		draw_circle(c, r + 6, Color(col.r, col.g, col.b, 0.25))      # 光晕
	draw_circle(c, r + 2.5, GOLD if lit else Color(0.35, 0.35, 0.38))
	draw_circle(c, r, col.darkened(0.25) if lit else Color(0.16, 0.17, 0.2))
	var s := r * 1.25
	draw_texture_rect(icon, Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)), false,
		Color.WHITE if lit else Color(1, 1, 1, 0.3))
	_text(label, c + Vector2(r + 10, 0), 13, Color.WHITE if lit else Color(0.6, 0.62, 0.66), HORIZONTAL_ALIGNMENT_LEFT)


func _text(t: String, anchor: Vector2, fs: int, col: Color, align: int) -> void:
	var tw := FONT.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var x := anchor.x if align == HORIZONTAL_ALIGNMENT_LEFT else (anchor.x - tw if align == HORIZONTAL_ALIGNMENT_RIGHT else anchor.x - tw * 0.5)
	var y := anchor.y + (FONT.get_ascent(fs) - FONT.get_descent(fs)) * 0.5
	draw_string_outline(FONT, Vector2(x, y), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.7))
	draw_string(FONT, Vector2(x, y), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
