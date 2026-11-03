class_name Board
extends Node2D
## 20x20 棋盘：负责格子坐标换算、绘制、悬停/选中。
## 后续的棋子、地形、技能范围都基于这里的坐标 API。

signal cell_hovered(cell: Vector2i)
signal cell_clicked(cell: Vector2i)

const COLS := 20
const ROWS := 20
const NO_CELL := Vector2i(-1, -1)

@export var cell_size: int = 48
## 棋盘外围留给行列编号的边距（像素）
@export var label_margin: int = 28

const COLOR_LIGHT := Color("#4b5a46")
const COLOR_DARK := Color("#3e4b3a")
const COLOR_GRID := Color("#2b3429")
const COLOR_BORDER := Color("#c9a85a")
const COLOR_HOVER := Color(1, 1, 1, 0.16)
const COLOR_SELECT_FILL := Color(0.95, 0.79, 0.30, 0.28)
const COLOR_SELECT_LINE := Color("#f2c94c")
const COLOR_LABEL := Color("#9aa596")

var hovered: Vector2i = NO_CELL
var selected: Vector2i = NO_CELL


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
		selected = NO_CELL if cell == selected else cell
		queue_redraw()
		cell_clicked.emit(cell)
		get_viewport().set_input_as_handled()


# ---------- 绘制 ----------

func _draw() -> void:
	var size_px := board_size_px()

	# 格子（棋盘交错色）
	for y in ROWS:
		for x in COLS:
			var c := Vector2i(x, y)
			draw_rect(cell_rect(c), COLOR_LIGHT if (x + y) % 2 == 0 else COLOR_DARK)

	# 网格线
	for i in range(1, COLS):
		var px := i * cell_size
		draw_line(Vector2(px, 0), Vector2(px, size_px.y), COLOR_GRID, 1.0)
	for i in range(1, ROWS):
		var py := i * cell_size
		draw_line(Vector2(0, py), Vector2(size_px.x, py), COLOR_GRID, 1.0)

	# 悬停 / 选中
	if hovered != NO_CELL:
		draw_rect(cell_rect(hovered), COLOR_HOVER)
	if selected != NO_CELL:
		var r := cell_rect(selected)
		draw_rect(r, COLOR_SELECT_FILL)
		draw_rect(r.grow(-1.5), COLOR_SELECT_LINE, false, 3.0)

	# 外框
	draw_rect(Rect2(Vector2.ZERO, size_px), COLOR_BORDER, false, 3.0)

	# 行列编号（0~19）
	var font := ThemeDB.fallback_font
	var fs := 14
	for x in COLS:
		var t := str(x)
		var w := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var cx := x * cell_size + cell_size * 0.5 - w * 0.5
		draw_string(font, Vector2(cx, -9), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, COLOR_LABEL)
		draw_string(font, Vector2(cx, size_px.y + 20), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, COLOR_LABEL)
	for y in ROWS:
		var t := str(y)
		var w := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var cy := y * cell_size + cell_size * 0.5 + fs * 0.35
		draw_string(font, Vector2(-8 - w, cy), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, COLOR_LABEL)
		draw_string(font, Vector2(size_px.x + 8, cy), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, COLOR_LABEL)
