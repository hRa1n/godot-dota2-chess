extends SceneTree
## 规则自动测试（无界面运行）：
##   godot --headless -s res://tests/test_rules.gd
## 注意：测试里的坐标是内部坐标 Vector2i(列, 行)，从 0 开始；界面显示为「行-列」且 +1。

var fails := 0
var game


func check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS  ", msg)
	else:
		fails += 1
		print("  FAIL  ", msg)


func find(label: String) -> Piece:
	for p in game.pieces:
		if p.label_name == label:
			return p
	return null


func place(p: Piece, cell: Vector2i) -> void:
	p.cell = cell
	p.position = game.board.cell_center(cell)


func wait(sec: float) -> void:
	await create_timer(sec).timeout


func new_game() -> void:
	if game:
		game.queue_free()
		await process_frame
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame


## 回到同一方的下一个回合
func next_own_turn() -> void:
	game.end_turn()
	game.end_turn()


## 给 team 一张手牌，让 p 打出（有目标就点目标）
func play(p: Piece, card_id: String, target := Vector2i(-1, -1)) -> void:
	var uid: int = game.give_card(p.team, card_id)
	game._select(p)
	game._on_hand_card_pressed(uid)
	if target != Vector2i(-1, -1):
		game._on_cell_clicked(target)
	await wait(0.6)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await new_game()

	print("[布置与属性]")
	check(Board.COLS == 11 and Board.ROWS == 11, "地图 11x11")
	check(game.pieces.size() == 14, "双方各 7 个棋子")
	for name in ["天辉·宙斯", "天辉·水晶室女", "天辉·剑圣", "夜魇·混沌骑士", "夜魇·斧王", "夜魇·屠夫"]:
		check(find(name) != null, "有 %s" % name)
	var counts := [0, 0]
	for p in game.pieces:
		if p.type_id == "soldier":
			counts[p.team] += 1
	check(counts == [4, 4], "双方各 4 个小兵")
	var all_ok := true
	for p in game.pieces:
		if p.max_hp != 5 or p.defense != 0 or p.move != 5 or p.cards != ["basic_attack"]:
			all_ok = false
	check(all_ok, "所有棋子 血量5 / 防御0 / 移动5，基础攻击卡")
	for hero in PieceDefs.HERO_SKILLS:
		check(PieceDefs.HERO_SKILLS[hero].size() == 3, "%s 有 3 张技能卡" % hero)
	check(game.fmt(Vector2i(5, 0)) == "1-6", "坐标显示为 行-列")

	print("[抽牌]")
	check(game.hands[0].size() == 2, "天辉第一回合开始抽 2 张")
	check(game.decks[0].size() == 3 * 3 * 2 + 5 * 2 - 2, "天辉牌库 28 张，抽完剩 26")
	var deck_ok := true
	for id in game.decks[0] + game.hands[0].map(func(e): return e["id"]):
		var c: Dictionary = PieceDefs.CARDS[id]
		if c.has("owner") and not c["owner"] in ["zeus", "crystal_maiden", "juggernaut"]:
			deck_ok = false
	check(deck_ok, "天辉牌库只有本方英雄的技能 + 装备")
	game.end_turn()
	check(game.hands[1].size() == 2, "夜魇回合开始抽 2 张")
	game.hands[1].clear()
	for i in 7:
		game.give_card(1, "item_salve")
	var disc: int = game.discards[1].size()
	game.end_turn()
	game.end_turn()
	check(game.hands[1].size() == game.HAND_LIMIT and game.discards[1].size() == disc + 1, "手牌上限 8 张，多抽的被弃掉")

	print("[基础攻击 + 移动]")
	await new_game()
	var zeus := find("天辉·宙斯")
	place(zeus, Vector2i(0, 4))
	game._on_cell_clicked(zeus.cell)
	check(game.move_cells.has(Vector2i(5, 4)) and not game.move_cells.has(Vector2i(6, 4)), "移动 5 格")
	var r_s1 := find("夜魇·士兵1")
	place(zeus, Vector2i(3, 4))
	place(r_s1, Vector2i(4, 5))
	game._select(zeus)
	game._on_card_pressed("basic_attack")
	check(game.target_cells.has(Vector2i(4, 5)) and game.range_cells.size() == 8, "3x3 范围，斜角可打")
	game._on_cell_clicked(Vector2i(4, 5))
	check(r_s1.hp == 3, "物理伤害 2，剩 %d" % r_s1.hp)
	await wait(0.8)

	print("[专属技能]")
	await new_game()
	zeus = find("天辉·宙斯")
	check(not game.piece_can_use(zeus, "cm_nova"), "宙斯不能用水晶室女的技能")
	check(game.piece_can_use(zeus, "item_mail"), "任何棋子都能用装备")
	var uid: int = game.give_card(0, "cm_nova")
	game._select(zeus)
	game._on_hand_card_pressed(uid)
	check(game.pending_card == "" and not game.has_used_card, "点别人的专属技能没有反应")

	print("[宙斯]")
	var e1 := find("夜魇·士兵1")
	var e2 := find("夜魇·士兵2")
	place(zeus, Vector2i(0, 5))
	place(e1, Vector2i(5, 5))
	await play(zeus, "zeus_bolt", e1.cell)
	check(e1.hp == 2, "雷击 11x11 内 3 点魔法伤害")
	check(game.discards[0].has("zeus_bolt") and game._hand_entry(0, game._uid).is_empty(), "用掉的手牌进入弃牌堆")
	await next_own_turn()
	e1.hp = 5
	place(e1, Vector2i(2, 5))
	place(e2, Vector2i(3, 6))
	await play(zeus, "zeus_chain", e1.cell)
	check(e1.hp == 3 and e2.hp == 4, "连锁闪电：目标 2，弹射 1")
	await next_own_turn()
	var before := []
	for e in game.enemies_of(zeus):
		before.append(e.hp)
	await play(zeus, "zeus_wrath")
	var all_hit := true
	var i := 0
	for e in game.enemies_of(zeus):
		all_hit = all_hit and e.hp == before[i] - 1
		i += 1
	check(all_hit, "天罚：全场敌人各 1 点")

	print("[水晶室女]")
	await new_game()
	var cm := find("天辉·水晶室女")
	e1 = find("夜魇·士兵1")
	e2 = find("夜魇·士兵2")
	place(cm, Vector2i(2, 5))
	place(e1, Vector2i(4, 5))
	place(e2, Vector2i(5, 6))
	await play(cm, "cm_nova", e1.cell)
	check(e1.hp == 4 and e2.hp == 4, "冰霜新星：目标周围 3x3 各 1 点")
	await next_own_turn()
	await play(cm, "cm_frostbite", e1.cell)
	check(e1.hp == 3 and e1.stun == 1, "冰封禁制：1 点 + 冻结 1 回合")
	await next_own_turn()
	await play(cm, "cm_field")
	check(e1.hp == 1 and e2.hp == 2, "极寒领域：7x7 内各 2 点")

	print("[剑圣]")
	await new_game()
	var jugg := find("天辉·剑圣")
	e1 = find("夜魇·士兵1")
	e2 = find("夜魇·士兵2")
	place(jugg, Vector2i(5, 4))      # 不站能量圈，免得测试中途获胜
	place(e1, Vector2i(6, 5))
	place(e2, Vector2i(4, 3))
	await play(jugg, "jugg_fury")
	check(e1.hp == 3 and e2.hp == 3, "剑刃风暴：3x3 各 2 点")
	await next_own_turn()
	jugg.hp = 2
	var cm2 := find("天辉·水晶室女")
	place(cm2, Vector2i(5, 6))
	cm2.hp = 1
	await play(jugg, "jugg_ward")
	check(jugg.hp == 4 and cm2.hp == 3, "治疗守卫：5x5 内友军 +2")
	await next_own_turn()
	e1.hp = 5
	e2.hp = 5
	place(jugg, Vector2i(1, 5))
	place(e1, Vector2i(4, 5))
	place(e2, Vector2i(9, 9))
	await play(jugg, "jugg_omni", e1.cell)
	check(game.chebyshev(jugg.cell, e1.cell) == 1 and e1.hp == 2, "无敌斩：闪到身边连斩 3 次")

	print("[混沌骑士]")
	await new_game()
	game.end_turn()     # 轮到夜魇
	var ck := find("夜魇·混沌骑士")
	var b1 := find("天辉·士兵1")
	place(ck, Vector2i(5, 3))
	place(b1, Vector2i(5, 6))
	await play(ck, "ck_bolt", b1.cell)
	check(b1.hp >= 2 and b1.hp <= 4 and b1.stun >= 1, "混沌飞弹：1~3 点 + 眩晕")
	await next_own_turn()
	b1.hp = 5
	await play(ck, "ck_rift", b1.cell)
	check(game.chebyshev(ck.cell, b1.cell) == 1 and b1.hp == 3, "实相裂隙：传送到身边 2 点物理")
	await next_own_turn()
	var n_before: int = game.pieces.size()
	await play(ck, "ck_phantasm")
	check(game.pieces.size() == n_before + 2 and find("夜魇·幻象1") != null, "混沌幻象：召唤 2 个幻象")
	check(find("夜魇·幻象1").max_hp == 1, "幻象只有 1 血")

	print("[斧王]")
	await new_game()
	game.end_turn()
	var axe := find("夜魇·斧王")
	b1 = find("天辉·士兵1")
	var b2 := find("天辉·士兵2")
	place(axe, Vector2i(5, 4))       # 不站能量圈
	place(b1, Vector2i(4, 4))
	place(b2, Vector2i(6, 5))
	await play(axe, "axe_call")
	check(b1.stun == 1 and b2.stun == 1 and axe.defense == 1, "狂战士之吼：眩晕 3x3 敌人，自身防御 +1")
	await next_own_turn()
	await play(axe, "axe_helix")
	check(b1.hp == 4 and b2.hp == 4, "反击螺旋：3x3 各 1 点物理")
	await next_own_turn()
	b1.hp = 3
	await play(axe, "axe_cull", b1.cell)
	check(not b1.alive, "淘汰之刃：血量 ≤3 直接斩杀")
	await next_own_turn()
	await play(axe, "axe_cull", b2.cell)
	check(b2.alive and b2.hp == 3, "淘汰之刃：血量 >3 只造成 1 点")

	print("[屠夫]")
	await new_game()
	game.end_turn()
	var pudge := find("夜魇·屠夫")
	b1 = find("天辉·士兵1")
	place(pudge, Vector2i(5, 3))
	place(b1, Vector2i(5, 7))
	await play(pudge, "pudge_hook", b1.cell)
	check(b1.cell == Vector2i(5, 4) and b1.hp == 3, "肉钩：直线拉到身边 + 2 点物理")
	await next_own_turn()
	await play(pudge, "pudge_rot")
	check(b1.hp == 2 and pudge.hp == 4, "腐烂：周围敌人 1 点，自己也 1 点")
	await next_own_turn()
	b1.hp = 5
	await play(pudge, "pudge_dismember", b1.cell)
	check(b1.hp == 2 and pudge.hp == 5, "肢解：3 点魔法伤害，自己回复 1")

	print("[装备]")
	await new_game()
	zeus = find("天辉·宙斯")
	place(zeus, Vector2i(1, 5))
	await play(zeus, "item_boots")
	check(zeus.move == 7 and game.move_cells.has(Vector2i(8, 5)), "速度之靴：移动 +2，本回合生效")
	await next_own_turn()
	await play(zeus, "item_mail")
	check(zeus.defense == 1 and zeus.equipment.has("锁子甲"), "锁子甲：防御 +1，记入装备")
	await next_own_turn()
	await play(zeus, "item_blade")
	check(zeus.atk_bonus == 1, "阔剑：攻击 +1")
	await next_own_turn()
	e1 = find("夜魇·士兵1")
	place(e1, Vector2i(2, 5))
	game._select(zeus)
	game._on_card_pressed("basic_attack")
	game._on_cell_clicked(e1.cell)
	check(e1.hp == 2, "带阔剑的普通攻击造成 3 点")
	await wait(0.8)
	await next_own_turn()
	zeus.hp = 2
	await play(zeus, "item_orb")
	check(zeus.max_hp == 7 and zeus.hp == 4, "活力宝珠：上限 +2，回复 2")
	await next_own_turn()
	await play(zeus, "item_salve")
	check(zeus.hp == 7 and not zeus.equipment.has("治疗药膏"), "治疗药膏：回复 3，不算装备")
	game._damage(zeus, 2, true)
	check(zeus.hp == 6, "防御 1 时 2 点物理伤害只扣 1")

	print("[泉水]")
	await new_game()
	zeus = find("天辉·宙斯")
	zeus.hp = 2
	var r_a := find("夜魇·士兵1")
	var r_b := find("夜魇·士兵2")
	place(r_a, Vector2i(3, 10))
	place(r_b, Vector2i(7, 10))
	await next_own_turn()
	check(zeus.hp == 4, "范围内友军 +2 血")
	check(int(r_a.hp < 5) + int(r_b.hp < 5) == 1, "只随机攻击范围内 1 个敌人")
	var s3 := find("夜魇·士兵3")
	place(s3, Vector2i(5, 7))
	await next_own_turn()
	check(s3.hp == 5, "范围外的敌人不受伤")

	print("[能量圈]")
	await new_game()
	zeus = find("天辉·宙斯")
	place(zeus, Vector2i(2, 5))
	game._select(zeus)
	game._on_cell_clicked(Vector2i(5, 5))
	await wait(0.4)
	check(zeus.cell == Vector2i(5, 5) and game.capture_count == 0, "站上能量圈，当回合不计数")
	game.end_turn()
	game.end_turn()
	check(game.capture_count == 1 and not game.game_over, "己方开场计 1/2")
	game.end_turn()
	game.end_turn()
	check(game.game_over, "己方第 2 次开场仍在圈上 → 获胜")

	print("[离开 / 阵亡清零]")
	await new_game()
	zeus = find("天辉·宙斯")
	place(zeus, Vector2i(5, 5))
	await next_own_turn()
	check(game.capture_count == 1, "计到 1/2")
	game._select(zeus)
	game._on_cell_clicked(Vector2i(5, 7))
	await wait(0.4)
	await next_own_turn()
	check(game.capture_count == 0 and not game.game_over, "离开后清零")
	place(zeus, Vector2i(5, 5))
	await next_own_turn()
	game._damage(zeus, 99)
	check(game.capture_count == 0, "占领者阵亡后清零")

	print("[全灭获胜]")
	for p in game.pieces:
		if p.team == 1:
			game._damage(p, 99)
	check(game._check_win() and game.game_over, "对方棋子全部阵亡 → 获胜")

	print("\n结果：%s（失败 %d 项）" % ["全部通过" if fails == 0 else "有失败", fails])
	quit(1 if fails > 0 else 0)
