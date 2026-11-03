extends Node2D
## 飘字：伤害 / 治疗数字，上浮后淡出并自动删除。

const FONT := preload("res://assets/fonts/NotoSansSC-Subset.otf")

var text := ""
var color := Color.WHITE
var font_size := 20


func _ready() -> void:
	z_index = 10
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "position:y", position.y - 34, 0.9).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 0.0, 0.9).set_delay(0.35)
	tw.chain().tween_callback(queue_free)


func _draw() -> void:
	var w := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var pos := Vector2(-w * 0.5, 0)
	draw_string_outline(FONT, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 5, Color(0, 0, 0, 0.85))
	draw_string(FONT, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
