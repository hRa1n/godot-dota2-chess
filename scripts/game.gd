extends Node2D
## 游戏主控：回合流程、牌库/手牌、棋子行动、卡牌结算、泉水、能量圈、胜负。
##
## 回合规则：
##   - 每方回合开始：泉水结算 → 能量圈结算 → 从本方牌库抽 2 张资源卡
##       抽到技能卡：对应英雄永久解锁这个技能（加入它的行动卡，不进手牌）
##       抽到装备卡：进手牌（上限 8）
##   - 每回合只能操作【一个】己方棋子：移动一次（可选）+ 一个行动（可选），顺序不限
##       行动 = 用该棋子的一张行动卡（基础攻击 / 已解锁的技能，技能有冷却），或从手牌给它用一张装备
##   - 一旦移动或行动，本回合就锁定为这个棋子；两样都用完后自动结束回合
## 牌库：本方 3 个英雄的技能卡各 1 张 + 每种装备各 2 张；抽空后把弃牌洗回牌库
## 装备：只有英雄能装，每个英雄最多 6 件，装上后不能卸下（治疗药膏是消耗品，任何棋子都能用）
## 复活：英雄阵亡后，过 2 个己方回合，在己方泉水周围复活（从泉水正上方开始顺时针找空格）
## 阵营：天辉在下，夜魇在上
## 泉水：每方回合开始时，己方泉水周围 5x5 内的己方棋子 +2 血，并随机打范围内一个敌人 5 血
## 能量圈：地图正中。棋子站上去后，连续 2 个己方回合开始时仍站在上面 → 获胜
## 另外：对方棋子全部阵亡也直接获胜
## 坐标：内部 Vector2i(列, 行) 从 0 开始；界面和日志显示为「行-列」，从 1 开始

const FloatText := preload("res://scripts/float_text.gd")

enum Team { BLUE, RED }
const TEAM_NAME := ["天辉", "夜魇"]
const TEAM_SHORT := ["天辉", "夜魇"]
const TEAM_COLOR := [Color("#16a34a"), Color("#b91c1c")]
## 泉水位置：天辉在下边中间（11-6），夜魇在上边中间（1-6）
const FOUNTAIN_CELLS := [Vector2i(5, 10), Vector2i(5, 0)]
const FOUNTAIN_RADIUS := 2      # 周围 5x5（贴边时只有棋盘内的部分）
const FOUNTAIN_HEAL := 2
const FOUNTAIN_DAMAGE := 5
## 能量圈：正中（6-6）
const ENERGY_CELL := Vector2i(5, 5)
const CAPTURE_TURNS := 2
## 抽牌
const DRAW_PER_TURN := 2
const HAND_LIMIT := 8
const MAX_EQUIP := 6
const RESPAWN_TURNS := 2

## 开局布置：[天辉, 夜魇]，坐标为内部 Vector2i(列, 行)
const LAYOUTS := [
	[   # 天辉（下）：水晶室女、宙斯、剑圣 + 4 小兵
		["crystal_maiden", Vector2i(3, 9)],
		["zeus", Vector2i(5, 9)],
		["juggernaut", Vector2i(7, 9)],
		["soldier", Vector2i(2, 8)],
		["soldier", Vector2i(4, 8)],
		["soldier", Vector2i(6, 8)],
		["soldier", Vector2i(8, 8)],
	],
	[   # 夜魇（上）：斧王、混沌骑士、屠夫 + 4 小兵
		["axe", Vector2i(3, 1)],
		["chaos_knight", Vector2i(5, 1)],
		["pudge", Vector2i(7, 1)],
		["soldier", Vector2i(2, 2)],
		["soldier", Vector2i(4, 2)],
		["soldier", Vector2i(6, 2)],
		["soldier", Vector2i(8, 2)],
	],
]

const OVERLAY_MOVE := Color(0.13, 0.65, 0.3, 0.38)
const OVERLAY_RANGE := Color(0.95, 0.35, 0.2, 0.14)
const OVERLAY_TARGET := Color(0.9, 0.12, 0.08, 0.5)

const DIRS := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
const DIRS8 := [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 0),
	Vector2i(1, 0), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)]

@onready var board: Board = $Board
@onready var pieces_root: Node2D = $Pieces
@onready var fx_root: Node2D = $FX
@onready var hud: Hud = $HUD
@onready var backgrounds: Array[Control] = [$BackgroundLayer/RadiantBG, $BackgroundLayer/DireBG]
var _bg_tween: Tween

var pieces: Array[Piece] = []
var current_team := Team.BLUE
var round_no := 1
var selected: Piece = null      # 当前选中（可以是敌方，用来查看信息）
var active: Piece = null        # 本回合已锁定的行动棋子
var has_moved := false
var has_used_card := false
var pending_card := ""          # 正在选目标的卡牌 id
var pending_hand_uid := -1      # 正在选目标的手牌（-1 = 基础攻击卡，不在手牌里）
var move_cells := {}            # 可移动格
var range_cells := {}           # 射程范围
var target_cells := {}          # 可选目标格
var capture_piece: Piece = null # 正在占领能量圈的棋子
var capture_count := 0
var game_over := false
var busy := false               # 播放动画时不接受操作

## 牌：每方一个牌库、一个弃牌堆、一手牌。手牌元素 = {uid, id}
var decks := [[], []]
var discards := [[], []]
var hands := [[], []]
var _uid := 0
var _name_counters := {}


func _ready() -> void:
	randomize()
	board.fountains = {FOUNTAIN_CELLS[0]: TEAM_COLOR[0], FOUNTAIN_CELLS[1]: TEAM_COLOR[1]}
	board.fountain_radius = FOUNTAIN_RADIUS
	board.energy_cell = ENERGY_CELL
	board.cell_clicked.connect(_on_cell_clicked)
	hud.card_pressed.connect(_on_card_pressed)
	hud.hand_card_pressed.connect(_on_hand_card_pressed)
	hud.end_turn_pressed.connect(end_turn)
	hud.restart_pressed.connect(func(): get_tree().reload_current_scene())
	_spawn_all()
	_build_decks()
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
		for entry in LAYOUTS[team]:
			_spawn(entry[0], team, entry[1])


func _spawn(type_id: String, team: int, cell: Vector2i) -> Piece:
	var def: Dictionary = PieceDefs.PIECES[type_id]
	var name_cn: String = def["name"]
	if not def["hero"]:     # 士兵、幻象按阵营编号
		var key := "%d_%s" % [team, type_id]
		_name_counters[key] = _name_counters.get(key, 0) + 1
		name_cn += str(_name_counters[key])
	var p := Piece.new()
	p.setup(type_id, team, TEAM_COLOR[team], "%s·%s" % [TEAM_SHORT[team], name_cn], board.cell_size)
	p.cell = cell
	p.position = board.cell_center(cell)
	pieces_root.add_child(p)
	pieces.append(p)
	return p


# ================= 牌库 / 手牌 =================

func _build_decks() -> void:
	for team in [Team.BLUE, Team.RED]:
		var heroes := []
		for entry in LAYOUTS[team]:
			if PieceDefs.PIECES[entry[0]]["hero"]:
				heroes.append(entry[0])
		decks[team] = PieceDefs.build_deck(heroes)
		decks[team].shuffle()
		discards[team] = []
		hands[team] = []


## 抽到技能卡：给本方对应英雄解锁；英雄已阵亡则进弃牌堆
func _unlock_skill(team: int, card_id: String) -> String:
	var card: Dictionary = PieceDefs.CARDS[card_id]
	var hero_name: String = PieceDefs.PIECES[card["owner"]]["name"]
	for p in pieces:
		if p.team == team and p.type_id == card["owner"] and (p.alive or p.respawn_in > 0):
			if not p.cards.has(card_id):
				p.cards.append(card_id)
				_float(p.position, "解锁 " + card["name"], Color("#93c5fd"))
				return "%s解锁【%s】" % [hero_name, card["name"]]
	discards[team].append(card_id)
	return "【%s】（已解锁过，弃掉）" % card["name"]


## 直接给英雄解锁技能（测试 / 调试用）
func unlock(p: Piece, card_id: String) -> void:
	if not p.cards.has(card_id):
		p.cards.append(card_id)


## 直接往手牌里加一张（测试 / 调试用）
func give_card(team: int, card_id: String) -> int:
	_uid += 1
	hands[team].append({"uid": _uid, "id": card_id})
	return _uid


func _hand_entry(team: int, uid: int) -> Dictionary:
	for e in hands[team]:
		if e["uid"] == uid:
			return e
	return {}


func _draw_cards(team: int, n: int) -> void:
	var got := []
	for i in n:
		if decks[team].is_empty():
			if discards[team].is_empty():
				_log("%s 牌库和弃牌堆都空了，无牌可抽" % TEAM_NAME[team])
				break
			decks[team] = discards[team]
			discards[team] = []
			decks[team].shuffle()
			_log("%s 弃牌堆洗回牌库" % TEAM_NAME[team])
		var id: String = decks[team].pop_back()
		var card: Dictionary = PieceDefs.CARDS[id]
		var card_name: String = card["name"]
		if card["kind"] == "skill":
			got.append(_unlock_skill(team, id))
			continue
		if hands[team].size() >= HAND_LIMIT:
			discards[team].append(id)
			_log("手牌已满，【%s】被弃掉" % card_name)
		else:
			give_card(team, id)
			got.append("【%s】" % card_name)
	if not got.is_empty():
		_log("%s 抽牌：%s（手牌 %d/%d）" % [TEAM_NAME[team], "、".join(got), hands[team].size(), HAND_LIMIT])


# ================= 查询 =================

func piece_at(cell: Vector2i) -> Piece:
	for p in pieces:
		if p.alive and p.cell == cell:
			return p
	return null


func is_blocked(cell: Vector2i) -> bool:
	return not board.is_in_bounds(cell) or FOUNTAIN_CELLS.has(cell) or piece_at(cell) != null


## 显示用坐标：「行-列」，从 1 开始
static func fmt(c: Vector2i) -> String:
	return "%d-%d" % [c.y + 1, c.x + 1]


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


func allies_of(p: Piece) -> Array[Piece]:
	var out: Array[Piece] = []
	for a in pieces:
		if a.alive and a.team == p.team:
			out.append(a)
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


## 这个棋子有没有资格用这张牌（不看本回合状态）
func piece_can_use(p: Piece, card_id: String) -> bool:
	if p == null:
		return false
	var card: Dictionary = PieceDefs.CARDS[card_id]
	if card["kind"] == "equip":
		if card.get("consumable", false):
			return true     # 消耗品：任何棋子都能用
		return p.is_hero and p.equipment.size() < MAX_EQUIP
	return p.cards.has(card_id)     # 基础攻击 / 已解锁的技能


func card_usable(p: Piece, card_id: String) -> bool:
	return can_control(p) and not has_used_card and p.cooldown_of(card_id) == 0 and piece_can_use(p, card_id)


# ================= 回合 =================

func _start_turn() -> void:
	active = null
	has_moved = false
	has_used_card = false
	pending_card = ""
	pending_hand_uid = -1
	_log("[b]—— 第 %d 回合 · [color=%s]%s[/color] ——[/b]" % [
		round_no, TEAM_COLOR[current_team].to_html(false), TEAM_NAME[current_team]])
	_switch_background(current_team)
	_respawn_tick(current_team)
	_fountain_tick(current_team)
	if _check_win():
		return
	if _capture_tick(current_team):
		return
	_draw_cards(current_team, DRAW_PER_TURN)
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
	if active and active.alive and not has_moved and can_control(active):
		move_cells = reachable_cells(active)
	_refresh_view()
	if _check_win():
		return
	if has_moved and has_used_card:
		_end_turn_later(0.7)


## 回合切换：当前阵营的背景淡入，另一边淡出
func _switch_background(team: int) -> void:
	if _bg_tween:
		_bg_tween.kill()
	_bg_tween = create_tween().set_parallel()
	for i in backgrounds.size():
		_bg_tween.tween_property(backgrounds[i], "modulate:a", 1.0 if i == team else 0.0, 0.6)


# ================= 复活 =================

func _respawn_tick(team: int) -> void:
	for p in pieces:
		if p.alive or p.team != team or p.respawn_in <= 0:
			continue
		p.respawn_in -= 1
		if p.respawn_in > 0:
			_log("%s %d 回合后复活" % [p.label_name, p.respawn_in])
			continue
		var c := respawn_cell(team)
		if c == Board.NO_CELL:
			p.respawn_in = 1
			_log("%s 泉水周围没有空位，下回合再复活" % p.label_name)
			continue
		p.revive(c, board.cell_center(c))
		_log("[color=#93c5fd]%s 在 %s 复活[/color]" % [p.label_name, fmt(c)])


## 泉水周围的复活点：从正上方开始顺时针，先找第一圈，满了再往外一圈
func respawn_cell(team: int) -> Vector2i:
	var f: Vector2i = FOUNTAIN_CELLS[team]
	for r in range(1, 4):
		for off in _clockwise_ring(r):
			var c: Vector2i = f + off
			if not is_blocked(c):
				return c
	return Board.NO_CELL


static func _clockwise_ring(r: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for x in range(0, r + 1):              # 上边：正上方 → 右上角
		out.append(Vector2i(x, -r))
	for y in range(-r + 1, r + 1):         # 右边：往下
		out.append(Vector2i(r, y))
	for x in range(r - 1, -r - 1, -1):     # 下边：往左
		out.append(Vector2i(x, r))
	for y in range(r - 1, -r - 1, -1):     # 左边：往上
		out.append(Vector2i(-r, y))
	for x in range(-r + 1, 0):             # 上边：左上角 → 正上方
		out.append(Vector2i(x, -r))
	return out


# ================= 泉水 =================

func _fountain_tick(team: int) -> void:
	var f: Vector2i = FOUNTAIN_CELLS[team]
	var enemies_in_range: Array[Piece] = []
	for p in pieces:
		if not p.alive or chebyshev(p.cell, f) > FOUNTAIN_RADIUS:
			continue
		if p.team == team:
			if p.hp < p.max_hp:
				_heal(p, FOUNTAIN_HEAL)
				_log("泉水为 %s 回复 %d 血" % [p.label_name, FOUNTAIN_HEAL])
		else:
			enemies_in_range.append(p)
	if not enemies_in_range.is_empty():
		var victim: Piece = enemies_in_range.pick_random()
		_log("泉水攻击 %s" % victim.label_name)
		_damage(victim, FOUNTAIN_DAMAGE)


# ================= 能量圈 =================

## 己方回合开始时结算占领；返回 true 表示已分出胜负
func _capture_tick(team: int) -> bool:
	var p := piece_at(ENERGY_CELL)
	# 占领者离开或阵亡 → 清零
	if capture_piece and (not capture_piece.alive or capture_piece != p):
		capture_piece = null
		capture_count = 0
	if p == null or p.team != team:
		_refresh_capture()
		return false
	if capture_piece != p:
		capture_piece = p
		capture_count = 0
	capture_count += 1
	_log("[color=#c084fc]%s 占领能量圈 %d/%d[/color]" % [p.label_name, capture_count, CAPTURE_TURNS])
	_refresh_capture()
	if capture_count >= CAPTURE_TURNS:
		_declare_win(team, "占领能量圈 %d 回合" % CAPTURE_TURNS)
		return true
	return false


func _refresh_capture() -> void:
	var p := piece_at(ENERGY_CELL)
	if capture_piece and capture_piece == p:
		board.energy_owner_color = TEAM_COLOR[p.team]
		board.energy_progress = float(capture_count) / CAPTURE_TURNS
		hud.set_capture("能量圈：%s 已占领 %d/%d 回合" % [p.label_name, capture_count, CAPTURE_TURNS], TEAM_COLOR[p.team])
	elif p:
		board.energy_owner_color = TEAM_COLOR[p.team]
		board.energy_progress = 0.0
		hud.set_capture("能量圈：%s 站在上面（下个己方回合开始计 1/%d）" % [p.label_name, CAPTURE_TURNS], TEAM_COLOR[p.team])
	else:
		board.energy_progress = 0.0
		hud.set_capture("能量圈：无人占领（站上去，连续 %d 个己方回合开始时仍在 → 获胜）" % CAPTURE_TURNS, Color("#c084fc"))
	board.queue_redraw()


# ================= 输入 =================

func _on_cell_clicked(cell: Vector2i) -> void:
	if game_over or busy:
		return

	# 选目标中
	if pending_card != "":
		if target_cells.has(cell):
			_resolve_card(selected, pending_card, cell, pending_hand_uid)
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
	pending_hand_uid = -1
	target_cells.clear()
	range_cells.clear()
	move_cells.clear()
	if can_control(p) and not has_moved:
		move_cells = reachable_cells(p)
	_refresh_view()


## 点了左侧的基础攻击卡
func _on_card_pressed(card_id: String) -> void:
	_begin_card(card_id, -1)


## 点了手牌
func _on_hand_card_pressed(uid: int) -> void:
	var entry := _hand_entry(current_team, uid)
	if entry.is_empty():
		return
	_begin_card(entry["id"], uid)


func _begin_card(card_id: String, hand_uid: int) -> void:
	if game_over or busy:
		return
	if selected == null or selected.team != current_team:
		_log("先点一个己方棋子，再出牌")
		return
	if not card_usable(selected, card_id):
		return
	if pending_card == card_id and pending_hand_uid == hand_uid:
		_cancel_targeting()
		return
	var card: Dictionary = PieceDefs.CARDS[card_id]
	if card["target"] == "none":
		_resolve_card(selected, card_id, selected.cell, hand_uid)
		return

	pending_card = card_id
	pending_hand_uid = hand_uid
	move_cells.clear()
	range_cells = _range_cells(selected, card)
	target_cells = _target_cells(selected, card)
	if target_cells.is_empty():
		_log("【%s】范围内没有可选目标" % card["name"])
	_refresh_view()


func _range_cells(p: Piece, card: Dictionary) -> Dictionary:
	var out := {}
	var rng: int = card["range"]
	var area: String = card.get("area", "square")
	if area == "line":
		for d in DIRS:
			for i in range(1, rng + 1):
				var c: Vector2i = p.cell + d * i
				if board.is_in_bounds(c):
					out[c] = true
		return out
	for dy in range(-rng, rng + 1):
		for dx in range(-rng, rng + 1):
			var c := p.cell + Vector2i(dx, dy)
			var inside := area == "square" or absi(dx) + absi(dy) <= rng
			if inside and board.is_in_bounds(c) and c != p.cell:
				out[c] = true
	return out


func _target_cells(p: Piece, card: Dictionary) -> Dictionary:
	var out := {}
	var rng: int = card["range"]
	var area: String = card.get("area", "square")
	if area == "line":
		# 每个方向上第一个棋子；是敌人才能钩
		for d in DIRS:
			for i in range(1, rng + 1):
				var c: Vector2i = p.cell + d * i
				if not board.is_in_bounds(c) or FOUNTAIN_CELLS.has(c):
					break
				var hit := piece_at(c)
				if hit:
					if hit.team != p.team and i > 1:
						out[c] = true
					break
		return out
	for e in enemies_of(p):
		var d := chebyshev(p.cell, e.cell) if area == "square" else manhattan(p.cell, e.cell)
		if d > rng:
			continue
		if card["effect"] in ["rift", "omnislash"] and _free_cell_next_to(e, p) == Board.NO_CELL:
			continue
		out[e.cell] = true
	return out


func _cancel_targeting() -> void:
	pending_card = ""
	pending_hand_uid = -1
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
	_log("%s 移动到 %s" % [p.label_name, fmt(cell)])
	p.cell = cell
	busy = true
	_refresh_view()
	var tw := create_tween()
	tw.tween_property(p, "position", board.cell_center(cell), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tw.finished
	busy = false
	_after_action()


func _resolve_card(p: Piece, card_id: String, target_cell: Vector2i, hand_uid := -1) -> void:
	var card: Dictionary = PieceDefs.CARDS[card_id]
	_lock_active(p)
	has_used_card = true
	pending_card = ""
	pending_hand_uid = -1
	target_cells.clear()
	range_cells.clear()
	move_cells.clear()
	# 手牌用掉 → 进弃牌堆
	if hand_uid >= 0:
		var entry := _hand_entry(p.team, hand_uid)
		if not entry.is_empty():
			hands[p.team].erase(entry)
			discards[p.team].append(card_id)
	if card.get("cooldown", 0) > 0:
		# 己方回合结束时 -1；+1 是为了让“冷却 N”= 接下来 N 个己方回合不能用
		p.cooldowns[card_id] = card["cooldown"] + 1
	var target := piece_at(target_cell)
	var physical: bool = card.get("damage_type", "magic") == "physical"
	_log("%s 使用【%s】" % [p.label_name, card["name"]])

	match card["effect"]:
		"damage":
			var dmg: int = card["damage"]
			if card["kind"] == "attack":
				dmg += p.atk_bonus
			_damage(target, dmg, physical)

		"chain":
			var hit: Array[Piece] = [target]
			var last := target
			_damage(target, card["damage"], physical)
			for i in card["jumps"]:
				var next: Piece = null
				var best := 999
				for e in enemies_of(p):
					if hit.has(e):
						continue
					var d := chebyshev(last.cell, e.cell)
					if d <= card["jump_range"] and d < best:
						best = d
						next = e
				if next == null:
					break
				hit.append(next)
				_damage(next, card["jump_damage"], physical)
				last = next

		"global_enemies":
			for e in enemies_of(p):
				_damage(e, card["damage"], physical)

		"aoe_at_target":
			for e in enemies_of(p):
				if chebyshev(e.cell, target_cell) <= card["radius"]:
					_damage(e, card["damage"], physical)

		"aoe_self":
			for e in enemies_of(p):
				if chebyshev(e.cell, p.cell) <= card["radius"]:
					_damage(e, card["damage"], physical)

		"damage_stun":
			_damage(target, card["damage"], physical)
			_stun(target, card["stun"])

		"heal_area":
			for a in allies_of(p):
				if chebyshev(a.cell, p.cell) <= card["radius"] and a.hp < a.max_hp:
					_heal(a, card["heal"])
					_log("  %s 回复 %d 血" % [a.label_name, card["heal"]])

		"chaos_bolt":
			_damage(target, randi_range(card["min"], card["max"]), physical)
			_stun(target, randi_range(card["stun_min"], card["stun_max"]))

		"rift":
			await _teleport(p, _free_cell_next_to(target, p))
			_damage(target, card["damage"], physical)

		"omnislash":
			await _teleport(p, _free_cell_next_to(target, p))
			for i in card["hits"]:
				var near: Array[Piece] = []
				for e in enemies_of(p):
					if chebyshev(e.cell, p.cell) <= 1:
						near.append(e)
				if near.is_empty():
					break
				_damage(near.pick_random(), card["damage"], physical)

		"summon":
			var made := 0
			for d in DIRS8:
				if made >= card["count"]:
					break
				var c: Vector2i = p.cell + d
				if is_blocked(c):
					continue
				var s := _spawn(card["summon"], p.team, c)
				s.modulate.a = 0.0
				create_tween().tween_property(s, "modulate:a", 1.0, 0.3)
				_log("  召唤 %s 于 %s" % [s.label_name, fmt(c)])
				made += 1
			if made == 0:
				_log("  身边没有空格，召唤失败")

		"berserkers_call":
			for e in enemies_of(p):
				if chebyshev(e.cell, p.cell) <= card["radius"]:
					_stun(e, card["stun"])
			p.defense += card["defense"]
			_log("  %s 防御 +%d（现在 %d）" % [p.label_name, card["defense"], p.defense])

		"cull":
			if target.hp <= card["threshold"]:
				_log("  斩杀！")
				_damage(target, target.hp, false)
			else:
				_damage(target, card["damage"], physical)

		"hook":
			var dir := Vector2i(signi(target.cell.x - p.cell.x), signi(target.cell.y - p.cell.y))
			var dest := p.cell + dir
			_log("  %s 被钩到 %s" % [target.label_name, fmt(dest)])
			target.cell = dest
			busy = true
			var tw := create_tween()
			tw.tween_property(target, "position", board.cell_center(dest), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			await tw.finished
			busy = false
			_damage(target, card["damage"], physical)

		"rot":
			for e in enemies_of(p):
				if chebyshev(e.cell, p.cell) <= card["radius"]:
					_damage(e, card["damage"], physical)
			_log("  腐烂反噬自身")
			_damage(p, card["self_damage"], false)

		"dismember":
			_damage(target, card["damage"], physical)
			if p.alive and p.hp < p.max_hp:
				_heal(p, card["heal"])

		"equip":
			_apply_equipment(p, card)

	p.queue_redraw()
	_after_action()


func _apply_equipment(p: Piece, card: Dictionary) -> void:
	var st: Dictionary = card["stats"]
	var parts := []
	if st.has("defense"):
		p.defense += st["defense"]
		parts.append("防御 +%d" % st["defense"])
	if st.has("atk"):
		p.atk_bonus += st["atk"]
		parts.append("攻击 +%d" % st["atk"])
	if st.has("move"):
		p.move += st["move"]
		parts.append("移动 +%d" % st["move"])
	if st.has("max_hp"):
		p.max_hp += st["max_hp"]
		parts.append("血量上限 +%d" % st["max_hp"])
	if st.has("heal") and p.hp < p.max_hp:
		_heal(p, st["heal"])
		parts.append("回复 %d" % st["heal"])
	if not card.get("consumable", false):
		p.equipment.append(card["name"])
	_log("  %s %s" % [p.label_name, "，".join(parts)])


func _stun(target: Piece, turns: int) -> void:
	if target == null or not target.alive:
		return
	target.stun = maxi(target.stun, turns)
	target.queue_redraw()
	_log("  %s 被眩晕 %d 回合" % [target.label_name, turns])


func _teleport(p: Piece, dest: Vector2i) -> void:
	_log("  %s 闪现到 %s" % [p.label_name, fmt(dest)])
	p.cell = dest
	busy = true
	var tw := create_tween()
	tw.tween_property(p, "modulate:a", 0.0, 0.12)
	tw.tween_callback(func(): p.position = board.cell_center(dest))
	tw.tween_property(p, "modulate:a", 1.0, 0.12)
	await tw.finished
	busy = false


## target 周围离 from 最近的空格（传送落点）
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


## physical = true 时扣除防御（至少 1 点）
func _damage(target: Piece, amount: int, physical := false) -> void:
	if target == null or not target.alive:
		return
	if physical:
		amount = maxi(1, amount - target.defense)
	target.hp = maxi(0, target.hp - amount)
	target.flash()
	target.queue_redraw()
	_float(target.position, "-%d" % amount, Color("#ff5a4f"))
	_log("  %s 受到 %d 点伤害（剩余 %d）" % [target.label_name, amount, target.hp])
	if target.hp == 0:
		target.die()
		_log("  [color=#f87171]%s 阵亡[/color]" % target.label_name)
		if target.is_hero:
			target.respawn_in = RESPAWN_TURNS
			_log("  %s 将在 %d 个己方回合后于泉水复活" % [target.label_name, RESPAWN_TURNS])
		if target == capture_piece:
			capture_piece = null
			capture_count = 0
			_refresh_capture()


func _heal(target: Piece, amount: int) -> void:
	var real := mini(amount, target.max_hp - target.hp)
	if real <= 0:
		return
	target.hp += real
	target.queue_redraw()
	_float(target.position, "+%d" % real, Color("#4ade80"))


func _float(pos: Vector2, text: String, color: Color) -> void:
	var f := FloatText.new()
	f.text = text
	f.color = color
	f.position = pos + Vector2(0, -board.cell_size * 0.35)
	fx_root.add_child(f)


## 对方棋子全部阵亡 → 获胜
func _check_win() -> bool:
	if game_over:
		return true
	var alive := [0, 0]
	for p in pieces:
		if p.alive or p.respawn_in > 0:     # 等待复活的英雄也算
			alive[p.team] += 1
	for team in [Team.BLUE, Team.RED]:
		if alive[team] == 0:
			_declare_win(Team.RED if team == Team.BLUE else Team.BLUE, "消灭对方全部棋子")
			return true
	return false


func _declare_win(winner: int, reason: String) -> void:
	game_over = true
	_log("[b]%s 获胜！（%s）[/b]" % [TEAM_NAME[winner], reason])
	_refresh_view()
	hud.show_winner("%s 获胜！\n%s" % [TEAM_NAME[winner], reason], TEAM_COLOR[winner])


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
	_refresh_capture()

	hud.set_turn(round_no, TEAM_NAME[current_team], TEAM_COLOR[current_team])
	hud.set_hint(_hint_text())
	hud.set_info(_info_text(selected))

	# 左侧：选中棋子的行动卡（基础攻击 + 已解锁技能）
	var big := []
	if selected and selected.alive:
		for id in selected.cards:
			big.append(_card_info(id, -1))
	hud.set_cards(big)

	# 底部：本方手牌
	var hand := []
	for e in hands[current_team]:
		hand.append(_card_info(e["id"], e["uid"]))
	hud.set_hand(hand, "%s手牌 %d/%d · 牌库 %d · 弃牌 %d" % [
		TEAM_NAME[current_team], hands[current_team].size(), HAND_LIMIT,
		decks[current_team].size(), discards[current_team].size()])


func _card_info(id: String, uid: int) -> Dictionary:
	var card: Dictionary = PieceDefs.CARDS[id]
	var p := selected
	var status := "可用"
	var cd := p.cooldown_of(id) if p else 0
	if p == null or not p.alive:
		status = "先选棋子"
	elif p.team != current_team:
		status = "敌方棋子"
	elif p.stun > 0:
		status = "眩晕中"
	elif card["kind"] == "equip" and not card.get("consumable", false) and not p.is_hero:
		status = "只有英雄能装备"
	elif card["kind"] == "equip" and not card.get("consumable", false) and p.equipment.size() >= MAX_EQUIP:
		status = "装备已满 %d/%d" % [MAX_EQUIP, MAX_EQUIP]
	elif has_used_card:
		status = "本回合已行动"
	elif cd > 0:
		status = "冷却中 剩%d回合" % cd
	elif not can_control(p):
		status = "本回合不可用"

	# 宝石上的数字：伤害 / 范围
	var dmg := ""
	if card.has("min"):
		dmg = "%d~%d" % [card["min"], card["max"]]
	elif card.has("damage"):
		var d: int = card["damage"]
		if card["kind"] == "attack" and p:
			d += p.atk_bonus
		dmg = str(d)
	var rng := ""
	if card["target"] == "none":
		if card["effect"] == "global_enemies":
			rng = "全场"
		elif card.has("radius"):
			rng = "%dx%d" % [card["radius"] * 2 + 1, card["radius"] * 2 + 1]
	elif card.get("area", "square") == "line":
		rng = "直线%d" % card["range"]
	else:
		rng = "%dx%d" % [card["range"] * 2 + 1, card["range"] * 2 + 1]

	var type_line: String = {"attack": "攻击卡", "skill": "技能卡", "equip": "装备卡"}[card["kind"]]
	if card.has("owner"):
		type_line += " · " + PieceDefs.PIECES[card["owner"]]["name"]
	if card.get("consumable", false):
		type_line = "消耗品"

	return {
		"id": id, "uid": uid, "name": card["name"], "kind": card["kind"],
		"type_line": type_line, "card_text": card.get("card_text", ""), "desc": card["desc"],
		"art": card.get("art", "sword"), "damage": dmg, "range_text": rng,
		"cooldown": card.get("cooldown", 0),
		"status": status, "enabled": p != null and card_usable(p, id),
		"selecting": pending_card == id and pending_hand_uid == uid,
	}


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
		parts.append("用一张行动卡（左侧）或装备（下方）")
	return "，".join(parts) if parts.size() > 0 else "行动完成"


func _info_text(p: Piece) -> String:
	if p == null or not p.alive:
		return ("未选择棋子\n\n坐标格式：行-列\n泉水：天辉 %s（下），夜魇 %s（上）。每个己方回合开始，周围 5x5 内己方棋子 +%d 血，并随机攻击范围内一个敌人 %d 血。\n\n每回合开始抽 %d 张资源卡：技能卡直接解锁给对应英雄（变成它的行动卡），装备卡进手牌。英雄最多 6 件装备，装上不能卸。英雄阵亡 2 个己方回合后在泉水旁复活。\n\n胜利：站上中央能量圈 %s，连续 %d 个己方回合开始时仍在上面；或消灭对方全部棋子。") % [
			fmt(FOUNTAIN_CELLS[0]), fmt(FOUNTAIN_CELLS[1]), FOUNTAIN_HEAL, FOUNTAIN_DAMAGE, DRAW_PER_TURN, fmt(ENERGY_CELL), CAPTURE_TURNS]
	var role := "英雄" if p.is_hero else ("召唤物" if p.type_id == "illusion" else "士兵")
	var state := "正常" if p.stun == 0 else "眩晕（剩 %d 回合）" % p.stun
	var eq := "（只有英雄能装备）"
	if p.is_hero:
		eq = "%d/%d  %s" % [p.equipment.size(), MAX_EQUIP, "无" if p.equipment.is_empty() else "、".join(p.equipment)]
	return "%s（%s）  %s\n血量 %d / %d    防御 %d\n移动速度 %d    攻击加成 +%d\n装备：%s\n状态：%s" % [
		p.label_name, role, fmt(p.cell), p.hp, p.max_hp, p.defense, p.move, p.atk_bonus, eq, state]


func _log(text: String) -> void:
	hud.add_log(text)
