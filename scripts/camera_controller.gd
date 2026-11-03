extends Camera2D
## 棋盘摄像机：开局自动适配整张棋盘；滚轮缩放（以鼠标为中心）；
## 右键 / 中键拖动平移；方向键 / WASD 平移；F 键重新适配。

@export var board_path: NodePath
@export var min_zoom := 0.25
@export var max_zoom := 3.0
@export var zoom_step := 1.12
@export var key_pan_speed := 900.0
## 屏幕四周留给界面的像素：左侧卡牌栏、右侧日志、上方回合信息
@export var hud_left := 384.0
@export var hud_right := 330.0
@export var hud_top := 80.0
@export var hud_bottom := 278.0

var _board: Board
var _dragging := false


func _ready() -> void:
	_board = get_node(board_path) as Board
	get_viewport().size_changed.connect(fit_to_board)
	fit_to_board.call_deferred()


func fit_to_board() -> void:
	var rect := _board.full_rect()
	rect.position += _board.global_position
	var vs := get_viewport_rect().size
	# 窗口太窄时不预留左右（界面会盖住一点棋盘，但棋盘不会被压得太小）
	var lr := Vector2(hud_left, hud_right) if vs.x > 1000 else Vector2.ZERO
	var avail := Vector2(vs.x - lr.x - lr.y, vs.y - hud_top - hud_bottom)
	var z := minf(avail.x / rect.size.x, avail.y / rect.size.y) * 0.97
	z = clampf(z, min_zoom, max_zoom)
	zoom = Vector2(z, z)
	# 棋盘放在四周界面围出来的区域正中
	position = rect.get_center() - Vector2(lr.x - lr.y, hud_top - hud_bottom) * 0.5 / z


func _zoom_at(screen_pos: Vector2, factor: float) -> void:
	var old_z := zoom.x
	var new_z := clampf(old_z * factor, min_zoom, max_zoom)
	if is_equal_approx(old_z, new_z):
		return
	var offset := screen_pos - get_viewport_rect().size * 0.5
	var world_under_mouse := position + offset / old_z
	zoom = Vector2(new_z, new_z)
	position = world_under_mouse - offset / new_z


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if event.pressed:
					_zoom_at(event.position, zoom_step)
			MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed:
					_zoom_at(event.position, 1.0 / zoom_step)
			MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE:
				_dragging = event.pressed
	elif event is InputEventMouseMotion and _dragging:
		position -= event.relative / zoom.x
	elif event is InputEventMagnifyGesture:  # 触控板双指缩放
		_zoom_at(event.position, event.factor)
	elif event is InputEventPanGesture:  # 触控板双指滑动
		position += event.delta * 12.0 / zoom.x
	elif event is InputEventKey and event.pressed and event.keycode == KEY_F:
		fit_to_board()


func _process(delta: float) -> void:
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A): dir.x -= 1
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D): dir.x += 1
	if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W): dir.y -= 1
	if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S): dir.y += 1
	if dir != Vector2.ZERO:
		position += dir.normalized() * key_pan_speed * delta / zoom.x
