class_name EquipSlot
extends Control
## 装备栏里的一格：有装备时显示图标 + 名字 + 效果，悬停看完整说明；没有装备时是空槽。

const FONT := preload("res://assets/fonts/NotoSansSC-Subset.otf")
const ART_DIR := "res://assets/icons/"
const GOLD := Color("#d4af37")

var item := {}      # {name, art, text, desc}；空字典 = 空槽
var _icon: Texture2D


func setup(p_item: Dictionary, slot_size: Vector2) -> void:
	item = p_item
	custom_minimum_size = slot_size
	size = slot_size
	mouse_filter = Control.MOUSE_FILTER_PASS
	tooltip_text = p_item.get("desc", "")
	if not p_item.is_empty():
		_icon = load(ART_DIR + p_item.get("art", "sword") + ".svg")
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(6)
	sb.anti_aliasing = true
	if item.is_empty():
		sb.bg_color = Color(0, 0, 0, 0.35)
		sb.set_border_width_all(1)
		sb.border_color = Color(1, 1, 1, 0.15)
		sb.draw(get_canvas_item(), r)
		return
	sb.bg_color = Color("#14532d").darkened(0.35)
	sb.set_border_width_all(2)
	sb.border_color = GOLD
	sb.draw(get_canvas_item(), r)
	var s := 26.0
	draw_texture_rect(_icon, Rect2(4, (size.y - s) * 0.5, s, s), false)
	var x := s + 7
	var w := size.x - x - 2
	draw_string(FONT, Vector2(x, 21), item["name"], HORIZONTAL_ALIGNMENT_LEFT, w, 12, Color.WHITE)
	draw_string(FONT, Vector2(x, 39), item.get("text", ""), HORIZONTAL_ALIGNMENT_LEFT, w, 10, Color("#bbf7d0"))
