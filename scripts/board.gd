class_name Board
extends Node2D
## 21x21 棋盘：负责格子坐标换算、绘制（格子、泉水、能量圈、高亮）、把点击/悬停转成格子坐标。
## 棋盘本身不管游戏规则，规则在 game.gd 里。

signal cell_hovered(cell: Vector2i)
signal cell_clicked(cell: Vector2i)

const COLS := 21
const ROWS := 21
const NO_CELL := Vector2i(-1, -1)
const FONT := preload("res://assets/fonts/NotoSansSC-Subset.otf")

@export var cell_size: int = 48
## 棋盘外围留给行列编号的边距（像素）
@export var label_margin: int = 28

const COLOR_WHITE := Color("#f3f7fc")
const COLOR_BLUE := Color("#b7d4f0")
const COLOR_GRID := Color("#8fb2d4")
const COLOR_BORDER := Color("#2f5d8a")
const COLOR_HOVER := Color(0.1, 0.25, 0.5, 0.18)
const COLOR_SELECT_LINE := Color("#f59e0b")
const COLOR_LABEL := Color("#9fb3c8")

var hovered: Vector2i = NO_CELL
var selected: Vector2i = NO_CELL
## 泉水：格子 -> 阵营颜色
var fountains: Dictionary = {}
var fountain_radius := 2
## 能量圈
var energy_cell: Vector2i = NO_CELL
var energy_progress := 0.0
var energy_owner_color := Color.WHITE
## 规则层传进来的高亮：格子 -> 颜色
var overlays: Dictionary = {}


# ---------- 坐标 API ----------

func board_size_px() -> Vector2:
	return Vector2(COLS, ROWS) * cell_size


## 棋盘连同编号边距在内的矩形（本地坐标），给摄像机做适配用
func full_rect() -> Rect2:
	var m := Vector2(label_margin, label_margin)
	return Rect2(-m, board_size_px() + m * 2)


func is_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < COLS and cell.y < ROWS


func cell_to_local(cell: Vector2i) -> Vector2:
	return Vector2(cell) * cell_size


func cell_center(cell: Vector2i) -> Vector2:
	return cell_to_local(cell) + Vector2.ONE * cell_size * 0.5


func local_to_cell(pos: Vector2) -> Vector2i:
	var cell := Vector2i(floori(pos.x / cell_size), floori(pos.y / cell_size))
	return cell if is_in_bounds(cell) else NO_CELL


func cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(cell_to_local(cell), Vector2.ONE * cell_size)


func set_overlays(o: Dictionary) -> void:
	overlays = o
	queue_redraw()


# ---------- 输入 ----------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var cell := local_to_cell(get_local_mouse_position())
		if cell != hovered:
			hovered = cell
			queue_redraw()
			cell_hovered.emit(cell)
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		var cell := local_to_cell(get_local_mouse_position())
		if cell == NO_CELL:
			return
		cell_clicked.emit(cell)
		get_viewport().set_input_as_handled()


# ---------- 绘制 ----------

func _draw() -> void:
	var size_px := board_size_px()

	# 格子：蓝白交错
	for y in ROWS:
		for x in COLS:
			draw_rect(cell_rect(Vector2i(x, y)), COLOR_WHITE if (x + y) % 2 == 0 else COLOR_BLUE)

	# 泉水范围（淡色）
	for f in fountains:
		var tint: Color = fountains[f]
		tint.a = 0.16
		for dy in range(-fountain_radius, fountain_radius + 1):
			for dx in range(-fountain_radius, fountain_radius + 1):
				var c: Vector2i = f + Vector2i(dx, dy)
				if is_in_bounds(c):
					draw_rect(cell_rect(c), tint)

	# 能量圈底色
	if energy_cell != NO_CELL:
		draw_rect(cell_rect(energy_cell), Color(0.66, 0.33, 0.97, 0.35))

	# 规则层高亮（可移动、射程、目标）
	for c in overlays:
		draw_rect(cell_rect(c), overlays[c])

	# 网格线
	for i in range(1, COLS):
		var px := i * cell_size
		draw_line(Vector2(px, 0), Vector2(px, size_px.y), COLOR_GRID, 1.0)
	for i in range(1, ROWS):
		var py := i * cell_size
		draw_line(Vector2(0, py), Vector2(size_px.x, py), COLOR_GRID, 1.0)

	# 泉水本体
	for f in fountains:
		var col: Color = fountains[f]
		var center := cell_center(f)
		var r := cell_size * 0.44
		draw_circle(center, r, col.darkened(0.15))
		draw_arc(center, r, 0, TAU, 40, Color.WHITE, 3.0)
		draw_arc(center, r * 0.7, 0, TAU, 32, Color(1, 1, 1, 0.5), 1.5)
		_draw_centered_text("泉", center, 20, Color.WHITE)

	# 能量圈本体：紫色光环 + 占领进度
	if energy_cell != NO_CELL:
		var ec := cell_center(energy_cell)
		var er := cell_size * 0.47
		draw_arc(ec, er, 0, TAU, 48, Color("#a855f7"), 3.0)
		draw_arc(ec, er * 0.62, 0, TAU, 36, Color(0.75, 0.52, 0.99, 0.7), 1.5)
		for i in 4:
			var a := TAU * i / 4.0 + PI / 4.0
			draw_circle(ec + Vector2.from_angle(a) * er, 3.0, Color("#e9d5ff"))
		if energy_progress > 0.0:
			draw_arc(ec, er + 4, -PI / 2, -PI / 2 + TAU * energy_progress, 48, energy_owner_color, 5.0)

	# 悬停 / 选中
	if hovered != NO_CELL:
		draw_rect(cell_rect(hovered), COLOR_HOVER)
	if selected != NO_CELL:
		draw_rect(cell_rect(selected).grow(-1.5), COLOR_SELECT_LINE, false, 3.0)

	# 外框
	draw_rect(Rect2(Vector2.ZERO, size_px), COLOR_BORDER, false, 3.0)

	var fs := 14
	# 行列编号：显示从 1 开始（内部坐标从 0 开始）
	for x in COLS:
		var cx := x * cell_size + cell_size * 0.5
		_draw_centered_text(str(x + 1), Vector2(cx, -14), fs, COLOR_LABEL)
		_draw_centered_text(str(x + 1), Vector2(cx, size_px.y + 14), fs, COLOR_LABEL)
	for y in ROWS:
		var cy := y * cell_size + cell_size * 0.5
		_draw_centered_text(str(y + 1), Vector2(-14, cy), fs, COLOR_LABEL)
		_draw_centered_text(str(y + 1), Vector2(size_px.x + 14, cy), fs, COLOR_LABEL)


func _draw_centered_text(t: String, center: Vector2, fs: int, col: Color) -> void:
	var w := FONT.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var baseline := center.y + (FONT.get_ascent(fs) - FONT.get_descent(fs)) * 0.5
	draw_string(FONT, Vector2(center.x - w * 0.5, baseline), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
