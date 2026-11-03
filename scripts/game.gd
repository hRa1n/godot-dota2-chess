extends Node2D
## 游戏主控：回合流程、棋子行动、卡牌结算、泉水、胜负。
##
## 回合规则：
##   - 双方轮流行动，每回合只能操作【一个】己方棋子
##   - 这个棋子本回合可以：移动一次（可选）+ 使用一张自己的卡牌（可选），顺序不限
##   - 一旦移动或出牌，本回合就锁定为这个棋子
##   - 移动和出牌都用完后自动结束回合，也可以随时点「结束回合」
## 泉水：每方回合开始时，己方泉水范围内的己方棋子回血，敌方棋子受到伤害
## 胜负：消灭对方全部英雄获胜

const FloatText := preload("res://scripts/float_text.gd")

enum Team { BLUE, RED }
const TEAM_NAME := ["蓝方", "红方"]
const TEAM_SHORT := ["蓝", "红"]
const TEAM_COLOR := [Color("#2563eb"), Color("#dc2626")]
const FOUNTAIN_CELLS := [Vector2i(0, 20), Vector2i(20, 0)]
const FOUNTAIN_RADIUS := 2      # 切比雪夫距离：泉水周围 5x5（贴角时 3x3）
const FOUNTAIN_HEAL := 10
const FOUNTAIN_DAMAGE := 20

## 蓝方开局布置（红方按棋盘中心对称）
const LAYOUT := [
	["zeus", Vector2i(2, 18)],
	["chaos_knight", Vector2i(4, 16)],
	["soldier", Vector2i(6, 18)],
	["soldier", Vector2i(2, 14)],
	["soldier", Vector2i(6, 14)],
	["soldier", Vector2i(8, 16)],
]

const OVERLAY_MOVE := Color(0.13, 0.65, 0.3, 0.38)
const OVERLAY_RANGE := Color(0.95, 0.35, 0.2, 0.14)
const OVERLAY_TARGET := Color(0.9, 0.12, 0.08, 0.5)

const DIRS := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]

@onready var board: Board = $Board
@onready var pieces_root: Node2D = $Pieces
@onready var fx_root: Node2D = $FX
@onready var hud: Hud = $HUD

var pieces: Array[Piece] = []
var current_team := Team.BLUE
var round_no := 1
var selected: Piece = null      # 当前选中（可以是敌方，用来查看信息）
var active: Piece = null        # 本回合已锁定的行动棋子
var has_moved := false
var has_used_card := false
var pending_card := ""          # 正在选目标的卡牌 id
var move_cells := {}            # 可移动格
var range_cells := {}           # 射程范围
var target_cells := {}          # 可选目标格
var game_over := false
var busy := false               # 播放动画时不接受操作


func _ready() -> void:
	randomize()
	board.fountains = {FOUNTAIN_CELLS[0]: TEAM_COLOR[0], FOUNTAIN_CELLS[1]: TEAM_COLOR[1]}
	board.fountain_radius = FOUNTAIN_RADIUS
	board.cell_clicked.connect(_on_cell_clicked)
	hud.card_pressed.connect(_on_card_pressed)
	hud.end_turn_pressed.connect(end_turn)
	hud.restart_pressed.connect(func(): get_tree().reload_current_scene())
	_spawn_all()
	_start_turn()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if pending_card != "":
			_cancel_targeting()
		else:
			_select(null)


# ================= 布置 =================

func _spawn_all() -> void:
	for team in [Team.BLUE, Team.RED]:
		var soldier_no := 0
		for entry in LAYOUT:
			var type_id: String = entry[0]
			var cell: Vector2i = entry[1]
			if team == Team.RED:
				cell = Vector2i(Board.COLS - 1 - cell.x, Board.ROWS - 1 - cell.y)
			var name_cn: String = PieceDefs.PIECES[type_id]["name"]
			if type_id == "soldier":
				soldier_no += 1
				name_cn += str(soldier_no)
			var p := Piece.new()
			p.setup(type_id, team, TEAM_COLOR[team], "%s·%s" % [TEAM_SHORT[team], name_cn], board.cell_size)
			p.cell = cell
			p.position = board.cell_center(cell)
			pieces_root.add_child(p)
			pieces.append(p)


# ================= 查询 =================

func piece_at(cell: Vector2i) -> Piece:
	for p in pieces:
		if p.alive and p.cell == cell:
			return p
	return null


func is_blocked(cell: Vector2i) -> bool:
	return not board.is_in_bounds(cell) or FOUNTAIN_CELLS.has(cell) or piece_at(cell) != null


static func manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


static func chebyshev(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


func enemies_of(p: Piece) -> Array[Piece]:
	var out: Array[Piece] = []
	for e in pieces:
		if e.alive and e.team != p.team:
			out.append(e)
	return out


## 上下左右走，不能穿过棋子和泉水
func reachable_cells(p: Piece) -> Dictionary:
	var result := {}
	var dist := {p.cell: 0}
	var frontier: Array[Vector2i] = [p.cell]
	while not frontier.is_empty():
		var c: Vector2i = frontier.pop_front()
		if dist[c] >= p.move:
			continue
		for d in DIRS:
			var n: Vector2i = c + d
			if dist.has(n) or is_blocked(n):
				continue
			dist[n] = dist[c] + 1
			result[n] = true
			frontier.append(n)
	return result


func can_control(p: Piece) -> bool:
	return p != null and p.alive and not game_over and p.team == current_team \
		and p.stun == 0 and (active == null or active == p)


func card_usable(p: Piece, card_id: String) -> bool:
	return can_control(p) and not has_used_card and p.cooldown_of(card_id) == 0


# ================= 回合 =================

func _start_turn() -> void:
	active = null
	has_moved = false
	has_used_card = false
	pending_card = ""
	_log("[b]—— 第 %d 回合 · [color=%s]%s[/color] ——[/b]" % [
		round_no, TEAM_COLOR[current_team].to_html(false), TEAM_NAME[current_team]])
	_fountain_tick(current_team)
	if _check_win():
		return
	_select(null)

	var can_act := false
	for p in pieces:
		if p.alive and p.team == current_team and p.stun == 0:
			can_act = true
	if not can_act:
		_log("%s 没有可行动的棋子，自动跳过" % TEAM_NAME[current_team])
		_end_turn_later(1.0)


func end_turn() -> void:
	if game_over or busy:
		return
	for p in pieces:
		if p.alive and p.team == current_team:
			p.end_own_turn()
	if active:
		active.highlight = false
		active.queue_redraw()
	current_team = Team.RED if current_team == Team.BLUE else Team.BLUE
	if current_team == Team.BLUE:
		round_no += 1
	_start_turn()


func _end_turn_later(delay: float) -> void:
	var team := current_team
	var r := round_no
	await get_tree().create_timer(delay).timeout
	if not game_over and team == current_team and r == round_no:
		end_turn()


func _lock_active(p: Piece) -> void:
	if active == null:
		active = p
		p.highlight = true
		p.queue_redraw()


func _after_action() -> void:
	_refresh_view()
	if _check_win():
		return
	if has_moved and has_used_card:
		_end_turn_later(0.7)


# ================= 泉水 =================

func _fountain_tick(team: int) -> void:
	var f: Vector2i = FOUNTAIN_CELLS[team]
	for p in pieces.duplicate():
		if not p.alive or chebyshev(p.cell, f) > FOUNTAIN_RADIUS:
			continue
		if p.team == team:
			if p.hp < p.max_hp:
				_heal(p, FOUNTAIN_HEAL)
				_log("泉水为 %s 回复生命" % p.label_name)
		else:
			_log("泉水攻击 %s" % p.label_name)
			_damage(p, FOUNTAIN_DAMAGE)


# ================= 输入 =================

func _on_cell_clicked(cell: Vector2i) -> void:
	if game_over or busy:
		return

	# 选目标中
	if pending_card != "":
		if target_cells.has(cell):
			_resolve_card(selected, pending_card, cell)
		else:
			_cancel_targeting()
		return

	# 移动
	if move_cells.has(cell) and can_control(selected) and not has_moved:
		_move(selected, cell)
		return

	# 选棋子
	var p := piece_at(cell)
	if p and p.team == current_team and active and p != active:
		_log("本回合已经选择了 %s 行动" % active.label_name)
	_select(p)


func _select(p: Piece) -> void:
	selected = p
	pending_card = ""
	target_cells.clear()
	range_cells.clear()
	move_cells.clear()
	if can_control(p) and not has_moved:
		move_cells = reachable_cells(p)
	_refresh_view()


func _on_card_pressed(card_id: String) -> void:
	if game_over or busy or not card_usable(selected, card_id):
		return
	if pending_card == card_id:
		_cancel_targeting()
		return
	var card: Dictionary = PieceDefs.CARDS[card_id]
	if card["target"] == "none":
		_resolve_card(selected, card_id, selected.cell)
		return

	pending_card = card_id
	move_cells.clear()
	range_cells.clear()
	target_cells.clear()
	var rng: int = card["range"]
	for dy in range(-rng, rng + 1):
		for dx in range(-rng, rng + 1):
			var c := selected.cell + Vector2i(dx, dy)
			if absi(dx) + absi(dy) <= rng and board.is_in_bounds(c) and c != selected.cell:
				range_cells[c] = true
	for e in enemies_of(selected):
		if manhattan(selected.cell, e.cell) > rng:
			continue
		if card["effect"] == "rift" and _free_cell_next_to(e, selected) == Board.NO_CELL:
			continue
		target_cells[e.cell] = true
	if target_cells.is_empty():
		_log("【%s】射程内没有可选目标" % card["name"])
	_refresh_view()


func _cancel_targeting() -> void:
	pending_card = ""
	target_cells.clear()
	range_cells.clear()
	if can_control(selected) and not has_moved:
		move_cells = reachable_cells(selected)
	_refresh_view()


# ================= 行动 =================

func _move(p: Piece, cell: Vector2i) -> void:
	_lock_active(p)
	has_moved = true
	move_cells.clear()
	_log("%s 移动到 (%d, %d)" % [p.label_name, cell.x, cell.y])
	p.cell = cell
	busy = true
	_refresh_view()
	var tw := create_tween()
	tw.tween_property(p, "position", board.cell_center(cell), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tw.finished
	busy = false
	_after_action()


func _resolve_card(p: Piece, card_id: String, target_cell: Vector2i) -> void:
	var card: Dictionary = PieceDefs.CARDS[card_id]
	_lock_active(p)
	has_used_card = true
	pending_card = ""
	target_cells.clear()
	range_cells.clear()
	move_cells.clear()
	if card["cooldown"] > 0:
		p.cooldowns[card_id] = card["cooldown"]
	var target := piece_at(target_cell)
	_log("%s 使用【%s】" % [p.label_name, card["name"]])

	match card["effect"]:
		"damage":
			_damage(target, card["damage"])

		"crit_attack":
			var dmg: int = card["damage"]
			if randf() < card["crit_chance"]:
				dmg *= 2
				_log("暴击！")
			_damage(target, dmg)

		"chain":
			var hit: Array[Piece] = [target]
			var last := target
			_damage(target, card["damage"])
			for i in card["jumps"]:
				var next: Piece = null
				var best := 999
				for e in enemies_of(p):
					if hit.has(e):
						continue
					var d := manhattan(last.cell, e.cell)
					if d <= card["jump_range"] and d < best:
						best = d
						next = e
				if next == null:
					break
				hit.append(next)
				_damage(next, card["jump_damage"])
				last = next

		"global_heroes":
			for e in enemies_of(p):
				if e.is_hero:
					_damage(e, card["damage"])

		"chaos_bolt":
			var dmg := randi_range(card["min"], card["max"])
			var stun := randi_range(card["stun_min"], card["stun_max"])
			_damage(target, dmg)
			if target.alive:
				target.stun = maxi(target.stun, stun)
				target.queue_redraw()
				_log("%s 被眩晕 %d 回合" % [target.label_name, stun])

		"rift":
			var dest := _free_cell_next_to(target, p)
			_log("%s 传送到 (%d, %d)" % [p.label_name, dest.x, dest.y])
			p.cell = dest
			busy = true
			var tw := create_tween()
			tw.tween_property(p, "modulate:a", 0.0, 0.12)
			tw.tween_callback(func(): p.position = board.cell_center(dest))
			tw.tween_property(p, "modulate:a", 1.0, 0.12)
			await tw.finished
			busy = false
			_damage(target, card["damage"])

	p.queue_redraw()
	_after_action()


## target 周围离 from 最近的空格（裂隙突袭落点）
func _free_cell_next_to(target: Piece, from: Piece) -> Vector2i:
	var best := Board.NO_CELL
	var best_d := 999
	for d in DIRS:
		var c: Vector2i = target.cell + d
		if c == from.cell:
			return c
		if is_blocked(c):
			continue
		var dd := manhattan(c, from.cell)
		if dd < best_d:
			best_d = dd
			best = c
	return best


func _damage(target: Piece, amount: int) -> void:
	if target == null or not target.alive:
		return
	target.hp = maxi(0, target.hp - amount)
	target.flash()
	target.queue_redraw()
	_float(target.position, "-%d" % amount, Color("#ff5a4f"))
	_log("  %s 受到 %d 点伤害（剩余 %d）" % [target.label_name, amount, target.hp])
	if target.hp == 0:
		target.die()
		_log("  [color=#f87171]%s 阵亡[/color]" % target.label_name)


func _heal(target: Piece, amount: int) -> void:
	var real := mini(amount, target.max_hp - target.hp)
	target.hp += real
	target.queue_redraw()
	_float(target.position, "+%d" % real, Color("#4ade80"))


func _float(pos: Vector2, text: String, color: Color) -> void:
	var f := FloatText.new()
	f.text = text
	f.color = color
	f.position = pos + Vector2(0, -board.cell_size * 0.35)
	fx_root.add_child(f)


func _check_win() -> bool:
	if game_over:
		return true
	var heroes_alive := [0, 0]
	for p in pieces:
		if p.alive and p.is_hero:
			heroes_alive[p.team] += 1
	for team in [Team.BLUE, Team.RED]:
		if heroes_alive[team] == 0:
			var winner := Team.RED if team == Team.BLUE else Team.BLUE
			game_over = true
			_log("[b]%s 获胜！[/b]" % TEAM_NAME[winner])
			_refresh_view()
			hud.show_winner("%s 获胜！" % TEAM_NAME[winner], TEAM_COLOR[winner])
			return true
	return false


# ================= 界面同步 =================

func _refresh_view() -> void:
	var o := {}
	for c in move_cells:
		o[c] = OVERLAY_MOVE
	for c in range_cells:
		o[c] = OVERLAY_RANGE
	for c in target_cells:
		o[c] = OVERLAY_TARGET
	board.set_overlays(o)
	board.selected = selected.cell if selected and selected.alive else Board.NO_CELL
	board.queue_redraw()

	hud.set_turn(round_no, TEAM_NAME[current_team], TEAM_COLOR[current_team])
	hud.set_hint(_hint_text())
	hud.set_info(_info_text(selected))

	var list := []
	if selected and selected.alive:
		for id in selected.cards:
			var card: Dictionary = PieceDefs.CARDS[id]
			var cd := selected.cooldown_of(id)
			var status := "可用"
			if cd > 0:
				status = "冷却中（剩 %d 回合）" % cd
			elif selected.team != current_team:
				status = "敌方卡牌"
			elif selected.stun > 0:
				status = "眩晕中"
			elif has_used_card and active == selected:
				status = "本回合已出牌"
			elif not can_control(selected):
				status = "本回合不可用"
			list.append({
				"id": id, "name": card["name"], "kind": card["kind"],
				"summary": card["summary"], "desc": card["desc"], "status": status,
				"enabled": card_usable(selected, id), "selecting": pending_card == id,
			})
	hud.set_cards(list)


func _hint_text() -> String:
	if game_over:
		return "游戏结束"
	if pending_card != "":
		return "点击红色高亮的敌人作为目标（再点一次卡牌或按 Esc 取消）"
	if selected == null:
		if active:
			return "本回合行动棋子：%s" % active.label_name
		return "点击一个己方棋子开始行动"
	if selected.team != current_team:
		return "这是敌方棋子"
	if selected.stun > 0:
		return "该棋子被眩晕，本回合不能行动"
	if not can_control(selected):
		return "本回合只能操作 %s" % active.label_name
	var parts := []
	if not has_moved:
		parts.append("点绿色格子移动")
	if not has_used_card:
		parts.append("点下方卡牌出牌")
	return "，".join(parts) if parts.size() > 0 else "行动完成"


func _info_text(p: Piece) -> String:
	if p == null or not p.alive:
		return "未选择棋子\n\n蓝方泉水在左下，红方泉水在右上。\n泉水范围内：己方每回合 +%d 生命，敌方每回合受到 %d 伤害。\n\n胜利条件：消灭对方全部英雄。" % [FOUNTAIN_HEAL, FOUNTAIN_DAMAGE]
	var role := "英雄" if p.is_hero else "士兵"
	var state := "正常" if p.stun == 0 else "眩晕（剩 %d 回合）" % p.stun
	return "%s（%s）\n生命 %d / %d\n移动 %d 格\n状态：%s\n位置：(%d, %d)" % [
		p.label_name, role, p.hp, p.max_hp, p.move, state, p.cell.x, p.cell.y]


func _log(text: String) -> void:
	hud.add_log(text)
