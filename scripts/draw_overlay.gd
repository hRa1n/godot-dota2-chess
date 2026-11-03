class_name DrawOverlay
extends Control
## 抽卡演出（每个己方回合开始时播放）：
##   1. 屏幕变暗，卡牌背面朝上从屏幕下方飞到中间排开
##   2. 逐张翻面，背后放射光芒：技能卡 = 金蓝光（解锁技能），装备卡 = 绿光，弃掉的牌 = 灰
##   3. 全部翻开后提示「点击 / 空格继续」；动画途中点击 = 直接翻开全部
##   4. 继续后：技能卡飞向左侧（英雄行动卡），装备卡飞向右侧手牌，然后关闭
## 只负责表现；抽牌结果在播放前已经结算好。

signal finished

const FONT := preload("res://assets/fonts/NotoSansSC-Subset.otf")
const CARD := Vector2(200, 308)
const GLOW := {
	"skill": Color("#fbbf24"),
	"equip": Color("#4ade80"),
	"burn": Color("#9ca3af"),
}

var _entries: Array = []        # [{view, kind, target, caption, revealed}]
var _state := "idle"            # idle / dealing / revealed / leaving
var _tween: Tween
var _angle := 0.0
var _title := ""
var _title_color := Color.WHITE
var _hint_alpha := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func is_playing() -> bool:
	return visible


## results: [{info: CardView 的 info, kind: skill/equip/burn, caption: 卡下面的说明}]
func play(results: Array, title: String, color: Color) -> void:
	_clear()
	if results.is_empty():
		return
	_title = title
	_title_color = color
	_hint_alpha = 0.0
	# 第一回合时界面可能还没布局好，直接用视口大小
	position = Vector2.ZERO
	size = get_viewport_rect().size
	visible = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.2)

	var n := results.size()
	var spacing := CARD.x + 70
	var center := size * 0.5
	var deck := Vector2(center.x - CARD.x * 0.5, size.y + 40)
	for i in n:
		var r: Dictionary = results[i]
		var v := CardView.new()
		var info: Dictionary = r["info"].duplicate()
		info["status"] = "可用"
		info["enabled"] = true
		info["selecting"] = false
		v.setup(info, CARD)
		v.face_down = true
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.pivot_offset = CARD * 0.5
		v.position = deck
		v.rotation = randf_range(-0.3, 0.3)
		add_child(v)
		var target := Vector2(center.x - spacing * (n - 1) * 0.5 + spacing * i - CARD.x * 0.5, center.y - CARD.y * 0.5 - 10)
		_entries.append({"view": v, "kind": r["kind"], "target": target, "caption": r["caption"], "revealed": false})

	_state = "dealing"
	_tween = create_tween()
	# 发牌：依次飞到中间
	for e in _entries:
		_tween.tween_property(e["view"], "position", e["target"], 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_tween.parallel().tween_property(e["view"], "rotation", 0.0, 0.38)
		_tween.tween_interval(0.08)
	_tween.tween_interval(0.25)
	# 翻牌：逐张
	for i in _entries.size():
		var v: CardView = _entries[i]["view"]
		_tween.tween_property(v, "scale:x", 0.0, 0.13).set_ease(Tween.EASE_IN)
		_tween.tween_callback(_reveal.bind(i))
		_tween.tween_property(v, "scale", Vector2(1.12, 1.12), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_tween.tween_property(v, "scale", Vector2.ONE, 0.12)
		_tween.tween_interval(0.22)
	_tween.tween_callback(_on_all_revealed)


## 点击 / 空格：动画中 = 直接全部翻开；全部翻开后 = 收牌关闭
func advance() -> void:
	match _state:
		"dealing":
			if _tween:
				_tween.kill()
			for i in _entries.size():
				var v: CardView = _entries[i]["view"]
				v.position = _entries[i]["target"]
				v.rotation = 0.0
				v.scale = Vector2.ONE
				_reveal(i)
			_on_all_revealed()
		"revealed":
			_leave()


func _reveal(i: int) -> void:
	var e: Dictionary = _entries[i]
	if e["revealed"]:
		return
	e["revealed"] = true
	var v: CardView = e["view"]
	v.face_down = false
	v.scale.x = maxf(v.scale.x, 0.01)
	v.queue_redraw()


func _on_all_revealed() -> void:
	_state = "revealed"
	create_tween().tween_property(self, "_hint_alpha", 1.0, 0.3)


func _leave() -> void:
	_state = "leaving"
	var tw := create_tween().set_parallel()
	for e in _entries:
		var v: CardView = e["view"]
		var dest: Vector2
		match e["kind"]:
			"skill":
				dest = Vector2(60, size.y * 0.55)                  # 左侧：英雄行动卡
			"equip":
				dest = Vector2(size.x - CARD.x * 0.6, 60)          # 右侧：装备手牌
			_:
				dest = Vector2(v.position.x, size.y + 60)          # 弃掉：往下掉
		tw.tween_property(v, "position", dest, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(v, "scale", Vector2(0.3, 0.3), 0.4)
		tw.tween_property(v, "modulate:a", 0.0, 0.4).set_delay(0.15)
	tw.tween_property(self, "modulate:a", 0.0, 0.3).set_delay(0.25)
	tw.chain().tween_callback(func():
		_clear()
		visible = false
		finished.emit())


func _clear() -> void:
	if _tween:
		_tween.kill()
	for e in _entries:
		e["view"].queue_free()
	_entries.clear()
	_state = "idle"


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		advance()


func _process(delta: float) -> void:
	if visible:
		_angle += delta * 0.5
		queue_redraw()


func _draw() -> void:
	# 背景压暗
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.02, 0.05, 0.78))

	# 标题
	_center_text(_title, Vector2(size.x * 0.5, size.y * 0.5 - CARD.y * 0.5 - 70), 34, _title_color.lightened(0.4))

	# 翻开的卡背后：旋转光芒 + 光晕
	for e in _entries:
		if not e["revealed"]:
			continue
		var v: CardView = e["view"]
		var c: Vector2 = v.position + CARD * 0.5
		var col: Color = GLOW.get(e["kind"], Color.WHITE)
		var rays := 14
		for k in rays:
			var a := _angle + TAU * k / rays
			var p1 := c + Vector2.from_angle(a - 0.07) * 260
			var p2 := c + Vector2.from_angle(a + 0.07) * 260
			draw_colored_polygon(PackedVector2Array([c, p1, p2]), Color(col.r, col.g, col.b, 0.13))
		for k in 5:
			draw_circle(c, 150 - k * 22, Color(col.r, col.g, col.b, 0.05 + k * 0.025))
		# 卡下方的说明
		_center_text(e["caption"], c + Vector2(0, CARD.y * 0.5 + 34), 20, col.lightened(0.3))

	# 继续提示
	if _hint_alpha > 0.0:
		var a := _hint_alpha * (0.6 + 0.4 * sin(_angle * 8.0))
		_center_text("点击任意处 / 空格 继续", Vector2(size.x * 0.5, size.y - 60), 18, Color(1, 1, 1, a))


func _center_text(t: String, c: Vector2, fs: int, col: Color) -> void:
	var tw := FONT.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pos := Vector2(c.x - tw * 0.5, c.y)
	draw_string_outline(FONT, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color(0, 0, 0, 0.8 * col.a))
	draw_string(FONT, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
