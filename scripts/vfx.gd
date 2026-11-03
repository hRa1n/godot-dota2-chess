class_name Vfx
extends Node2D
## 技能特效：全部用代码画，播完自动删除。坐标都是棋盘本地坐标。
##   bolt    闪电：p0 → p1 的锯齿线（每帧重新抖动）
##   beam    光束：p0 → p1 的粗直线
##   orb     飞弹：发光球从 p0 飞到 p1，带拖尾
##   ring    冲击波：以 p1 为中心扩散的圆环
##   burst   爆裂：从 p1 往外射的光线
##   slash   斩击：p1 上划过的几道刀光
##   x       斩杀：p1 上的巨大红叉
##   spin    旋风：绕 p1 旋转的弧
##   snow    雪花：以 p1 为中心、radius 内飘落的雪片
##   cloud   毒雾 / 烟雾：p1 周围鼓起的半透明圆
##   chain   钩链：从 p0 伸到 p1 再收回
##   portal  传送门：p1 上张开再合上的椭圆
##   rise    上升粒子：从 p1 往上飘的十字 / 星点（治疗、装备）

var kind := ""
var p0 := Vector2.ZERO
var p1 := Vector2.ZERO
var color := Color.WHITE
var radius := 40.0
var duration := 0.4
var _t := 0.0
var _seed := 0


static func make(p_kind: String, from: Vector2, to: Vector2, p_color: Color, p_radius := 40.0, p_duration := 0.4) -> Vfx:
	var v := Vfx.new()
	v.kind = p_kind
	v.p0 = from
	v.p1 = to
	v.color = p_color
	v.radius = p_radius
	v.duration = p_duration
	return v


func _ready() -> void:
	z_index = 20
	_seed = randi()


func _process(delta: float) -> void:
	_t += delta
	if _t >= duration:
		queue_free()
	else:
		queue_redraw()


func _draw() -> void:
	var k := clampf(_t / duration, 0.0, 1.0)
	var fade := 1.0 - k
	var rng := RandomNumberGenerator.new()
	match kind:
		"bolt":
			rng.seed = _seed + int(_t * 40.0)
			var pts := PackedVector2Array([p0])
			var segs := 9
			var dir := p1 - p0
			var nrm := dir.orthogonal().normalized()
			for i in range(1, segs):
				pts.append(p0 + dir * (float(i) / segs) + nrm * rng.randf_range(-14, 14))
			pts.append(p1)
			draw_polyline(pts, _a(color, 0.45 * fade), 16.0)
			draw_polyline(pts, _a(color.lightened(0.5), fade), 6.0)
			draw_polyline(pts, _a(Color.WHITE, fade), 2.5)
			draw_circle(p1, 22.0 * (1.0 + k), _a(color, 0.45 * fade))

		"beam":
			draw_line(p0, p1, _a(color, 0.4 * fade), 18.0)
			draw_line(p0, p1, _a(color.lightened(0.6), 0.9 * fade), 4.0)

		"orb":
			var e := ease(k, 0.6)
			var pos := p0.lerp(p1, e)
			for i in 6:
				var tp := p0.lerp(p1, maxf(0.0, e - i * 0.05))
				draw_circle(tp, 9.0 - i * 1.2, _a(color, 0.25 * (1.0 - i / 6.0)))
			draw_circle(pos, 20.0, _a(color, 0.4))
			draw_circle(pos, 11.0, _a(color.lightened(0.5), 0.95))
			draw_circle(pos, 5.0, Color.WHITE)

		"ring":
			var r := radius * ease(k, 0.4)
			draw_circle(p1, r, _a(color, 0.22 * fade))
			draw_arc(p1, r, 0, TAU, 64, _a(color.lightened(0.3), fade), 9.0 * fade + 2.0)

		"burst":
			rng.seed = _seed
			for i in 12:
				var a := TAU * i / 12 + rng.randf_range(-0.2, 0.2)
				var l := radius * ease(k, 0.3) * rng.randf_range(0.6, 1.0)
				draw_line(p1 + Vector2.from_angle(a) * l * 0.3, p1 + Vector2.from_angle(a) * l, _a(color, fade), 5.0)
			draw_circle(p1, radius * 0.4 * (1.0 - k), _a(color.lightened(0.4), 0.6 * fade))

		"slash":
			for i in 3:
				var kk := clampf(k * 2.0 - i * 0.25, 0.0, 1.0)
				if kk <= 0.0:
					continue
				var a := -0.8 + i * 0.5
				var d := Vector2.from_angle(a) * radius
				var o := Vector2(0, (i - 1) * 8)
				draw_line(p1 - d + o, p1 - d + o + d * 2.0 * kk, _a(color, 0.6 * fade), 12.0)
				draw_line(p1 - d + o, p1 - d + o + d * 2.0 * kk, _a(Color.WHITE, fade), 4.5)

		"x":
			var s := radius * (0.6 + 0.4 * ease(k, 0.3))
			for d in [Vector2(1, 1), Vector2(1, -1)]:
				draw_line(p1 - d * s, p1 + d * s, _a(color, 0.4 * fade), 16.0)
				draw_line(p1 - d * s, p1 + d * s, _a(color.lightened(0.4), fade), 6.0)

		"spin":
			for i in 3:
				var a0 := _t * 14.0 + TAU * i / 3
				draw_arc(p1, radius, a0, a0 + 1.6, 16, _a(color, fade), 9.0)
				draw_arc(p1, radius * 0.7, -a0, -a0 + 1.0, 12, _a(color.lightened(0.4), 0.6 * fade), 3.0)

		"snow":
			rng.seed = _seed
			draw_circle(p1, radius, _a(color, 0.2 * fade))
			for i in 40:
				var base := p1 + Vector2(rng.randf_range(-radius, radius), rng.randf_range(-radius, radius))
				if base.distance_to(p1) > radius:
					continue
				var fall := Vector2(sin(_t * 4.0 + i) * 6.0, (_t * 60.0 + i * 7.0) - 20.0)
				var c := base + fall
				var sz := rng.randf_range(3.0, 6.0)
				draw_line(c - Vector2(sz, 0), c + Vector2(sz, 0), _a(Color.WHITE, fade), 2.5)
				draw_line(c - Vector2(0, sz), c + Vector2(0, sz), _a(Color.WHITE, fade), 2.5)

		"cloud":
			rng.seed = _seed
			for i in 9:
				var off := Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * radius * 0.7
				var r := radius * 0.45 * (0.6 + 0.6 * sin(k * PI)) * rng.randf_range(0.7, 1.1)
				draw_circle(p1 + off, r, _a(color, 0.32 * fade))

		"chain":
			var out := minf(k * 2.0, 2.0 - k * 2.0)       # 0 → 1 → 0
			var tip := p0.lerp(p1, out)
			var n := int(p0.distance_to(tip) / 10.0)
			for i in n:
				var c := p0.lerp(tip, float(i) / maxf(1.0, n))
				draw_arc(c, 4.0, 0, TAU, 8, Color("#d6d3d1"), 2.0)
			draw_circle(tip, 6.0, Color("#e7e5e4"))

		"portal":
			var open := sin(k * PI)
			draw_set_transform(p1, 0.0, Vector2(0.6, 1.0))
			draw_circle(Vector2.ZERO, radius * open, _a(color.darkened(0.5), 0.8))
			draw_arc(Vector2.ZERO, radius * open, 0, TAU, 40, _a(color.lightened(0.3), 1.0), 4.0)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

		"rise":
			rng.seed = _seed
			for i in 10:
				var x := rng.randf_range(-radius * 0.6, radius * 0.6)
				var y := -k * radius * rng.randf_range(0.8, 1.6) + rng.randf_range(-6, 6)
				var c := p1 + Vector2(x, y)
				var sz := rng.randf_range(3.0, 5.0)
				draw_line(c - Vector2(sz, 0), c + Vector2(sz, 0), _a(color, fade), 2.5)
				draw_line(c - Vector2(0, sz), c + Vector2(0, sz), _a(color, fade), 2.5)


static func _a(c: Color, alpha: float) -> Color:
	return Color(c.r, c.g, c.b, c.a * clampf(alpha, 0.0, 1.0))
