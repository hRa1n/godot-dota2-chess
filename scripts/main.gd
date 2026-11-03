extends Node2D
## 主场景：把棋盘事件显示到左上角信息栏。

@onready var board: Board = $Board
@onready var info: Label = $HUD/InfoLabel

const HELP := "Wheel/Pinch: zoom   Right-drag / WASD: pan   F: fit"


func _ready() -> void:
	board.cell_hovered.connect(func(_c): _refresh())
	board.cell_clicked.connect(func(_c): _refresh())
	_refresh()


func _fmt(c: Vector2i) -> String:
	return "-" if c == Board.NO_CELL else "(%d, %d)" % [c.x, c.y]


func _refresh() -> void:
	info.text = "Board %dx%d   Hover %s   Selected %s\n%s" % [
		Board.COLS, Board.ROWS, _fmt(board.hovered), _fmt(board.selected), HELP]
