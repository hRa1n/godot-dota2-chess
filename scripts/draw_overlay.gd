class_name DrawOverlay
extends Control
## 抽卡演出（每个己方回合开始时播放），翻牌式抽卡：
##   1. 屏幕变暗，5 张卡背面朝上从下方飞到中间排开
##   2. 玩家点其中 picks 张（默认 2 张）：点一张翻一张，技能卡金光（解锁）/ 装备卡绿光 / 弃掉灰光
##   3. 选够后，没选的牌也翻开给你看（变暗，标「放回牌库」）
##   4. 点击任意处 / 空格：选中的牌飞向左右栏，没选的落回牌库，关闭
## 空格：发牌中 = 跳过动画；选牌中 = 随机替你选完；展示中 = 继续
## 结算由 resolver 回调交给 game.gd：resolver.call(第几张) -> {kind, caption}

signal finished(picked: Array)

const FONT := preload("res://assets/fonts/NotoSansSC-Subset.otf")
const CARD := Vector2(176, 271)
const GAP := 26.0
const GLOW := {
	"skill": Color("#fbbf24"),
	"equip": Color("#4ade80"),
	"burn": Color("#9ca3af"),
	"unpicked": Color("#64748b"),
}

var sfx: Sfx = null             # 由 game.gd 传进来
var _entries: Array = []        # [{view, target, kind, caption, revealed, picked}]
var _state := "idle"            # idle / dealing / picking / revealed / leaving
var _picks_left := 0
var _picked: Array = []
var _resolver: Callable
var _tween: Tween
var _angle := 0.0
var _title := ""
var _title_color := Color.WHITE
var _hint_alpha := 0.0
var _hover := -1


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func is_playing() -> bool:
	return visible


## offers: 每张牌的 CardView info；picks: 要选几张；resolver: 选中第 i 张时调用，返回 {kind, caption}
func play(offers: Array, picks: int, resolver: Callable, title: String, color: Color) -> void:
	_clear()
	if offers.is_empty():
		finished.emit([])
		return
	_title = title
	_title_color = color
	_hint_alpha = 0.0
	_resolver = resolver
	_picks_left = mini(picks, offers.size())
	_picked = []
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.2)

	var n := offers.size()
	var vs := _area()
	var total := n * CARD.x + (n - 1) * GAP
	var x0 := vs.x * 0.5 - total * 0.5
	var y := vs.y * 0.5 - CARD.y * 0.5 - 10
	var deck := Vector2(vs.x * 0.5 - CARD.x * 0.5, vs.y + 40)
	for i in n:
		var v := CardView.new()
		var info: Dictionary = offers[i].duplicate()
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
		_entries.append({"view": v, "target": Vector2(x0 + i * (CARD.x + GAP), y),
			"kind": "", "caption": "", "revealed": false, "picked": false})

	_state = "dealing"
	_tween = create_tween()
	for e in _entries:
		_tween.tween_callback(_snd.bind("card"))
		_tween.tween_property(e["view"], "position", e["target"], 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_tween.parallel().tween_property(e["view"], "rotation", 0.0, 0.32)
		_tween.tween_interval(0.05)
	_tween.tween_callback(_start_picking)


# ---------------- 交互 ----------------

## 空格 / 回车
func advance() -> void:
	match _state:
		"dealing":
			_finish_dealing()
		"picking":
			_auto_pick()
		"revealed":
			_leave()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and _state == "picking":
		var h := _card_at(event.position)
		if h != _hover:
			_hover = h
			_update_hover()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		match _state:
			"dealing":
				_finish_dealing()
			"picking":
				var i := _card_at(event.position)
				if i >= 0 and not _entries[i]["revealed"]:
					_pick(i)
			"revealed":
				_leave()      # 展示阶段：点哪里都继续


func _card_at(pos: Vector2) -> int:
	for i in _entries.size():
		var v: CardView = _entries[i]["view"]
		if Rect2(v.position, CARD).has_point(pos):
			return i
	return -1


func _update_hover() -> void:
	for i in _entries.size():
		var e: Dictionary = _entries[i]
		var v: CardView = e["view"]
		var up: bool = i == _hover and not e["revealed"]
		v.position.y = e["target"].y - (16.0 if up else 0.0)
	queue_redraw()


func _finish_dealing() -> void:
	if _tween:
		_tween.kill()
	for e in _entries:
		e["view"].position = e["target"]
		e["view"].rotation = 0.0
	_start_picking()


func _start_picking() -> void:
	_state = "picking"
	if _picks_left >= _entries.size():     # 牌不够挑：全部直接翻开
		_auto_pick()


func _auto_pick() -> void:
	var rest := []
	for i in _entries.size():
		if not _entries[i]["revealed"]:
			rest.append(i)
	rest.shuffle()
	while _picks_left > 0 and not rest.is_empty():
		_pick(rest.pop_back())


func _pick(i: int) -> void:
	if _picks_left <= 0:
		return
	var e: Dictionary = _entries[i]
	var res: Dictionary = _resolver.call(i)
	e["kind"] = res.get("kind", "equip")
	e["caption"] = res.get("caption", "")
	e["picked"] = true
	_picked.append(i)
	_picks_left -= 1
	_flip(i, false)
	_snd({"skill": "unlock", "equip": "equip"}.get(e["kind"], ""))
	if _picks_left == 0:
		_state = "revealing"
		var tw := create_tween()
		tw.tween_interval(0.45)
		tw.tween_callback(_reveal_unpicked)


## 没选的牌也翻开（变暗）
func _reveal_unpicked() -> void:
	for i in _entries.size():
		var e: Dictionary = _entries[i]
		if not e["revealed"]:
			e["kind"] = "unpicked"
			e["caption"] = "放回牌库"
			_flip(i, true)
	_hover = -1
	_update_hover()
	_state = "revealed"
	create_tween().tween_property(self, "_hint_alpha", 1.0, 0.3)


func _flip(i: int, dim: bool) -> void:
	var e: Dictionary = _entries[i]
	var v: CardView = e["view"]
	v.position.y = e["target"].y
	var tw := create_tween()
	tw.tween_property(v, "scale:x", 0.0, 0.12).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		v.face_down = false
		e["revealed"] = true
		if dim:
			v.modulate = Color(0.55, 0.55, 0.6, 1.0)
		v.queue_redraw()
		_snd("flip"))
	if dim:
		tw.tween_property(v, "scale:x", 1.0, 0.14)
	else:
		tw.tween_property(v, "scale", Vector2(1.12, 1.12), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(v, "scale", Vector2.ONE, 0.12)


func _leave() -> void:
	_state = "leaving"
	var vs := _area()
	var tw := create_tween().set_parallel()
	for e in _entries:
		var v: CardView = e["view"]
		var dest: Vector2
		match e["kind"]:
			"skill":
				dest = Vector2(60, vs.y * 0.55)                 # 左侧：英雄行动卡
			"equip":
				dest = Vector2(vs.x - CARD.x * 0.6, 60)         # 右侧：装备手牌
			_:
				dest = Vector2(vs.x * 0.5 - CARD.x * 0.5, vs.y + 60)   # 弃掉 / 放回牌库：往下落
		tw.tween_property(v, "position", dest, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(v, "scale", Vector2(0.3, 0.3), 0.4)
		tw.tween_property(v, "modulate:a", 0.0, 0.4).set_delay(0.15)
	tw.tween_property(self, "modulate:a", 0.0, 0.3).set_delay(0.25)
	var picked := _picked.duplicate()
	tw.chain().tween_callback(func():
		_clear()
		visible = false
		finished.emit(picked))


func _clear() -> void:
	if _tween:
		_tween.kill()
	for e in _entries:
		e["view"].queue_free()
	_entries.clear()
	_state = "idle"
	_hover = -1


func _snd(name: String) -> void:
	if sfx:
		sfx.play(name)


# ---------------- 绘制 ----------------

func _process(delta: float) -> void:
	if visible:
		_angle += delta * 0.5
		queue_redraw()


## 第一回合时界面可能还没布局好，统一用视口大小
func _area() -> Vector2:
	return get_viewport_rect().size


func _draw() -> void:
	var vs := _area()
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0.01, 0.02, 0.05, 0.8))
	_center_text(_title, Vector2(vs.x * 0.5, vs.y * 0.5 - CARD.y * 0.5 - 76), 32, _title_color.lightened(0.4))
	if _state in ["dealing", "picking"]:
		_center_text("翻开 %d 张（点卡牌）" % _picks_left, Vector2(vs.x * 0.5, vs.y * 0.5 - CARD.y * 0.5 - 36), 20, Color("#fde68a"))

	for i in _entries.size():
		var e: Dictionary = _entries[i]
		var v: CardView = e["view"]
		var c: Vector2 = v.position + CARD * 0.5
		if not e["revealed"]:
			if i == _hover:      # 悬停的背面卡：金色描边光
				draw_circle(c, CARD.x * 0.75, Color(1.0, 0.85, 0.3, 0.12))
			continue
		var col: Color = GLOW.get(e["kind"], Color.WHITE)
		if e["picked"]:
			var rays := 14
			for k in rays:
				var a := _angle + TAU * k / rays
				draw_colored_polygon(PackedVector2Array([c,
					c + Vector2.from_angle(a - 0.07) * 230, c + Vector2.from_angle(a + 0.07) * 230]),
					Color(col.r, col.g, col.b, 0.13))
			for k in 5:
				draw_circle(c, 130 - k * 20, Color(col.r, col.g, col.b, 0.05 + k * 0.025))
		_center_text(e["caption"], c + Vector2(0, CARD.y * 0.5 + 30), 18 if e["picked"] else 15, col.lightened(0.3))

	if _hint_alpha > 0.0:
		var a := _hint_alpha * (0.6 + 0.4 * sin(_angle * 8.0))
		_center_text("点击任意处 / 空格 继续", Vector2(vs.x * 0.5, vs.y - 60), 18, Color(1, 1, 1, a))
	elif _state == "picking":
		_center_text("空格 = 随机帮你选", Vector2(vs.x * 0.5, vs.y - 60), 15, Color(1, 1, 1, 0.6))


func _center_text(t: String, c: Vector2, fs: int, col: Color) -> void:
	var tw := FONT.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pos := Vector2(c.x - tw * 0.5, c.y)
	draw_string_outline(FONT, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color(0, 0, 0, 0.8 * col.a))
	draw_string(FONT, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
