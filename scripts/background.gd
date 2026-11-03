extends Control
## 战场背景（屏幕空间，不随摄像机移动），两套主题：
##   team = 0 天辉：晴空、太阳、远山、绿色树林、草地、花与光点
##   team = 1 夜魇：血色天空、红月、黑色山脊、枯树、熔岩裂缝、余烬、紫雾
## 回合切换时由 game.gd 交叉淡入淡出。全部用代码画，固定随机种子，窗口变化时重画。

@export var team := 0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	if size.x < 200 or size.y < 200:  # 还没布局好（初始尺寸很小）时不画，避免多边形退化
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261103 + team
	if team == 0:
		_draw_radiant(rng)
	else:
		_draw_dire(rng)
	# 四周暗角，让中间的棋盘更突出
	var w := size.x
	var h := size.y
	_hgrad(0, 140, Color(0, 0, 0, 0.4), Color(0, 0, 0, 0))
	_hgrad(w - 140, w, Color(0, 0, 0, 0), Color(0, 0, 0, 0.4))
	_vgrad(h - 80, h, Color(0, 0, 0, 0), Color(0, 0, 0, 0.35))


# ======================= 天辉 =======================

func _draw_radiant(rng: RandomNumberGenerator) -> void:
	var w := size.x
	var h := size.y
	var horizon := h * 0.34

	# 天空
	_vgrad(0, horizon, Color("#5fb3e6"), Color("#cdeaf2"))
	# 太阳
	var sun := Vector2(w * 0.8, h * 0.13)
	for i in 6:
		draw_circle(sun, 70 - i * 9, Color(1.0, 0.95, 0.7, 0.07 + i * 0.03))
	draw_circle(sun, 26, Color("#fff4c2"))
	# 云
	for i in 7:
		var c := Vector2(rng.randf() * w, rng.randf_range(0.04, 0.22) * h)
		var s := rng.randf_range(20, 36)
		for j in 4:
			draw_circle(c + Vector2((j - 1.5) * s * 0.8, sin(j * 1.7) * s * 0.25), s * rng.randf_range(0.6, 0.9), Color(1, 1, 1, 0.85))

	# 远山（两层）
	_ridge(horizon + 10, 70, Color("#7fb6a0"), rng, 9)
	_ridge(horizon + 40, 55, Color("#5d9a6c"), rng, 13)

	# 草地
	_vgrad(horizon + 40, h, Color("#5aa04a"), Color("#2d6b30"))
	for i in 260:
		var g := Vector2(rng.randf() * w, rng.randf_range(horizon + 50, h))
		var c := Color("#78c060") if rng.randf() < 0.5 else Color("#4f9a45")
		draw_line(g, g + Vector2(rng.randf_range(-3, 3), -rng.randf_range(5, 11)), c, 1.6)

	# 小路
	var path := PackedVector2Array()
	for i in 30:
		var t := i / 29.0
		path.append(Vector2(w * (0.1 + t * 0.85) + sin(t * 7.0) * 30, lerpf(h * 0.98, horizon + 60, t)))
	draw_polyline(path, Color("#cdb486"), 16.0)
	draw_polyline(path, Color("#e2cfa3"), 8.0)

	# 树林（按 y 排序，远的先画）
	var trees := []
	for i in 46:
		trees.append(Vector2(rng.randf() * w, rng.randf_range(horizon + 45, h * 1.02)))
	trees.sort_custom(func(a, b): return a.y < b.y)
	for t in trees:
		var depth := inverse_lerp(horizon, h, t.y)
		_pine(t, lerpf(16, 40, depth), rng)

	# 花与光点
	for i in 80:
		var f := Vector2(rng.randf() * w, rng.randf_range(horizon + 60, h))
		var fc: Color = [Color("#fde68a"), Color("#f9a8d4"), Color("#ffffff"), Color("#c4b5fd")][rng.randi() % 4]
		draw_circle(f, rng.randf_range(1.4, 2.6), fc)
	for i in 50:
		var l := Vector2(rng.randf() * w, rng.randf_range(horizon, h))
		draw_circle(l, rng.randf_range(4, 8), Color(1.0, 0.97, 0.65, 0.12))
		draw_circle(l, 1.4, Color(1.0, 0.98, 0.8, 0.8))


# ======================= 夜魇 =======================

func _draw_dire(rng: RandomNumberGenerator) -> void:
	var w := size.x
	var h := size.y
	var horizon := h * 0.36

	# 天空
	_vgrad(0, horizon, Color("#14060c"), Color("#5a1620"))
	# 红月
	var moon := Vector2(w * 0.2, h * 0.14)
	for i in 6:
		draw_circle(moon, 80 - i * 10, Color(0.9, 0.15, 0.1, 0.05 + i * 0.025))
	draw_circle(moon, 30, Color("#c2412d"))
	draw_circle(moon + Vector2(8, -6), 24, Color("#d9573f"))
	# 星点
	for i in 60:
		draw_circle(Vector2(rng.randf() * w, rng.randf() * horizon * 0.9), rng.randf_range(0.6, 1.4), Color(1, 0.8, 0.8, rng.randf_range(0.2, 0.6)))

	# 黑色山脊（两层）
	_ridge(horizon + 10, 95, Color("#2a0d14"), rng, 8, true)
	_ridge(horizon + 45, 70, Color("#1a070c"), rng, 12, true)

	# 焦土
	_vgrad(horizon + 45, h, Color("#3a1418"), Color("#1a080b"))
	# 熔岩裂缝
	for i in 22:
		var p := Vector2(rng.randf() * w, rng.randf_range(horizon + 60, h))
		var pts := PackedVector2Array([p])
		for j in rng.randi_range(3, 7):
			p += Vector2(rng.randf_range(-45, 45), rng.randf_range(-14, 14))
			pts.append(p)
		draw_polyline(pts, Color(1.0, 0.3, 0.08, 0.35), 4.0)
		draw_polyline(pts, Color(1.0, 0.65, 0.25, 0.6), 1.2)

	# 枯树
	var trees := []
	for i in 40:
		trees.append(Vector2(rng.randf() * w, rng.randf_range(horizon + 40, h * 1.02)))
	trees.sort_custom(func(a, b): return a.y < b.y)
	for t in trees:
		var depth := inverse_lerp(horizon, h, t.y)
		_dead_tree(t, lerpf(18, 46, depth), rng)

	# 紫雾
	for i in 12:
		var c := Vector2(rng.randf() * w, rng.randf_range(horizon, h))
		draw_circle(c, rng.randf_range(60, 120), Color(0.45, 0.15, 0.55, 0.06))

	# 余烬
	for i in 140:
		var e := Vector2(rng.randf() * w, rng.randf() * h)
		draw_circle(e, rng.randf_range(0.8, 2.4), Color(1.0, rng.randf_range(0.35, 0.7), 0.15, rng.randf_range(0.35, 0.85)))


# ======================= 绘制小工具 =======================

func _vgrad(y0: float, y1: float, c0: Color, c1: Color) -> void:
	var w := size.x
	draw_polygon(PackedVector2Array([Vector2(0, y0), Vector2(w, y0), Vector2(w, y1), Vector2(0, y1)]),
		PackedColorArray([c0, c0, c1, c1]))


func _hgrad(x0: float, x1: float, c0: Color, c1: Color) -> void:
	var h := size.y
	draw_polygon(PackedVector2Array([Vector2(x0, 0), Vector2(x1, 0), Vector2(x1, h), Vector2(x0, h)]),
		PackedColorArray([c0, c1, c1, c0]))


## 山脊：从 base_y 往上起伏，填充到屏幕底部
func _ridge(base_y: float, amp: float, col: Color, rng: RandomNumberGenerator, peaks: int, sharp := false) -> void:
	var w := size.x
	var pts := PackedVector2Array([Vector2(0, size.y)])
	var n := peaks * 2
	for i in n + 1:
		var x := w * i / n
		var up := (i % 2 == 0) == sharp
		var y := base_y - (amp * rng.randf_range(0.5, 1.0) if up else amp * rng.randf_range(0.0, 0.35))
		pts.append(Vector2(x, minf(y, size.y - 2)))
	pts.append(Vector2(w, size.y))
	draw_colored_polygon(pts, col)


## 天辉松树：影子 + 树干 + 三层树冠
func _pine(base: Vector2, s: float, rng: RandomNumberGenerator) -> void:
	draw_circle(base + Vector2(4, 2), s * 0.45, Color(0, 0, 0, 0.18))
	draw_rect(Rect2(base.x - s * 0.08, base.y - s * 0.35, s * 0.16, s * 0.35), Color("#5b3a1e"))
	var shade := rng.randf_range(-0.08, 0.08)
	for i in 3:
		var tw := s * (0.62 - i * 0.14)
		var ty := base.y - s * 0.3 - i * s * 0.32
		var col := Color("#2f7d32").lightened(shade + i * 0.07)
		draw_colored_polygon(PackedVector2Array([
			Vector2(base.x - tw, ty), Vector2(base.x + tw, ty), Vector2(base.x, ty - s * 0.55)]), col)


## 夜魇枯树：弯曲树干 + 分叉枝
func _dead_tree(base: Vector2, s: float, rng: RandomNumberGenerator) -> void:
	var col := Color("#0d0507")
	var tip := base + Vector2(rng.randf_range(-6, 6), -s)
	draw_line(base, tip, col, maxf(2.0, s * 0.09))
	for i in rng.randi_range(2, 4):
		var t := rng.randf_range(0.35, 0.9)
		var p := base.lerp(tip, t)
		var dir := Vector2(rng.randf_range(-1, 1), -rng.randf_range(0.3, 1)).normalized()
		var q := p + dir * s * rng.randf_range(0.25, 0.5)
		draw_line(p, q, col, maxf(1.4, s * 0.05))
		draw_line(q, q + Vector2(dir.x * 5, -6), col, 1.2)
