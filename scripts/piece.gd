class_name Piece
extends Node2D
## 一个棋子 = 一个角色。只负责自己的状态和绘制，规则在 game.gd。

const FONT := preload("res://assets/fonts/NotoSansSC-Subset.otf")
## 棋子图标（原创矢量图）。士兵按阵营区分：[天辉, 夜魇]
const ICONS := {
	"zeus": "res://assets/icons/zeus.svg",
	"crystal_maiden": "res://assets/icons/snow.svg",
	"juggernaut": "res://assets/icons/blade.svg",
	"chaos_knight": "res://assets/icons/knight.svg",
	"axe": "res://assets/icons/axe.svg",
	"pudge": "res://assets/icons/hook.svg",
	"illusion": "res://assets/icons/knight.svg",
	"soldier": ["res://assets/icons/creep_radiant.svg", "res://assets/icons/creep_dire.svg"],
}

var type_id := ""
var def: Dictionary
var team := 0
var team_color := Color.WHITE
var label_name := ""        # 例：天辉·宙斯、夜魇·士兵2
var cell := Vector2i.ZERO
var hp := 1
var max_hp := 1
var defense := 0
var atk_bonus := 0          # 基础攻击额外伤害（装备）
var equipment: Array[String] = []    # 已装备的装备卡 id（最多 6，装上不能卸）
var move := 1
var cards: Array = []
var cooldowns := {}         # 卡牌 id -> 剩余冷却（己方回合数）
var stun := 0               # 剩余眩晕（己方回合数）
var respawn_in := 0         # 英雄阵亡后，还要几个己方回合复活（0 = 不在复活中）
var alive := true
var is_hero := false
var highlight := false      # 本回合正在行动
var cell_size := 48
var _icon: Texture2D

## 头像替换：把图片放到 assets/portraits/<棋子类型>.png 即可覆盖默认图标（像素图自动用最近邻缩放保持清晰）
##   例：zeus.png / crystal_maiden.png / juggernaut.png / chaos_knight.png / axe.png / pudge.png
##       soldier_radiant.png / soldier_dire.png
const PORTRAIT_DIR := "res://assets/portraits/"


func setup(p_type: String, p_team: int, p_color: Color, p_label: String, p_cell_size: int) -> void:
	type_id = p_type
	def = PieceDefs.PIECES[p_type]
	team = p_team
	team_color = p_color
	label_name = p_label
	cell_size = p_cell_size
	max_hp = def["hp"]
	hp = max_hp
	defense = def["defense"]
	move = def["move"]
	cards = def["cards"].duplicate()     # 行动卡：基础攻击 + 已解锁的技能
	is_hero = def["hero"]
	z_index = 1
	var icon_path = ICONS[type_id]
	_icon = load(icon_path[team] if icon_path is Array else icon_path)
	var file: String = {"illusion": "chaos_knight"}.get(type_id, type_id)     # 幻象用混沌骑士的头像
	if type_id == "soldier":
		file = "soldier_radiant" if team == 0 else "soldier_dire"
	var path := PORTRAIT_DIR + file + ".png"
	if ResourceLoader.exists(path):
		_icon = load(path)
		# 32px 的小地图头像用最近邻放大保持像素感；大图（小兵 96px）用平滑缩小
		if _icon.get_width() <= 48:
			texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func cooldown_of(card_id: String) -> int:
	return cooldowns.get(card_id, 0)


## 己方回合结束时调用：冷却、眩晕各减 1
func end_own_turn() -> void:
	for k in cooldowns.keys():
		cooldowns[k] = maxi(0, cooldowns[k] - 1)
	if stun > 0:
		stun -= 1
	queue_redraw()


func flash() -> void:
	modulate = Color(2.2, 2.2, 2.2)
	create_tween().tween_property(self, "modulate", Color.WHITE, 0.3)


## 复活：满血、清眩晕，装备和已解锁技能保留
func revive(p_cell: Vector2i, pos: Vector2) -> void:
	alive = true
	respawn_in = 0
	hp = max_hp
	stun = 0
	cell = p_cell
	position = pos
	show()
	modulate = Color(1, 1, 1, 0)
	create_tween().tween_property(self, "modulate:a", 1.0, 0.4)
	queue_redraw()


func die() -> void:
	alive = false
	highlight = false
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.4)
	tw.tween_callback(hide)


func _draw() -> void:
	var r := cell_size * (0.42 if is_hero else 0.32)

	if highlight:
		draw_circle(Vector2.ZERO, r + 6, Color(0.98, 0.8, 0.08, 0.5))
	draw_circle(Vector2(2, 3), r, Color(0, 0, 0, 0.3))        # 阴影
	if type_id == "illusion":                                  # 幻象：半透明紫色
		self_modulate = Color(0.85, 0.7, 1.0, 0.75)
	draw_circle(Vector2.ZERO, r, team_color)                   # 阵营色外圈
	draw_circle(Vector2.ZERO, r - 3.5, Color("#0f172a"))       # 深色底
	draw_arc(Vector2.ZERO, r, 0, TAU, 48, Color("#fbbf24") if is_hero else Color(1, 1, 1, 0.75), 2.5 if is_hero else 1.5)

	var s := (r - 4) * 1.6
	draw_texture_rect(_icon, Rect2(-s * 0.5, -s * 0.5, s, s), false)

	# 血条（血量少时按格显示，一格 = 1 点血）
	var bw := cell_size * 0.82
	var top := -cell_size * 0.5 + 1
	var ratio := float(hp) / max_hp
	var bar_col := Color("#16a34a") if ratio > 0.5 else (Color("#eab308") if ratio > 0.25 else Color("#dc2626"))
	draw_rect(Rect2(-bw * 0.5, top, bw, 6), Color(0, 0, 0, 0.6))
	if max_hp <= 12:
		var seg := bw / max_hp
		for i in hp:
			draw_rect(Rect2(-bw * 0.5 + i * seg + 1, top + 1, seg - 2, 4), bar_col)
	else:
		draw_rect(Rect2(-bw * 0.5, top, bw * ratio, 6), bar_col)

	# 眩晕标记
	if stun > 0:
		var p := Vector2(r * 0.55, -r * 0.55)
		draw_circle(p, 9, Color("#facc15"))
		var sw := FONT.get_string_size("晕", HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		draw_string(FONT, p + Vector2(-sw * 0.5, 4.5), "晕", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.BLACK)
