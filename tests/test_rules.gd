extends SceneTree
## 规则自动测试（无界面运行）：
##   godot --headless -s res://tests/test_rules.gd
## 注意：测试里的坐标是内部坐标（从 0 开始），界面显示的是 +1 后的坐标。

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


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await new_game()

	print("[布置与属性]")
	check(game.pieces.size() == 12, "双方各 6 个棋子")
	var all_ok := true
	for p in game.pieces:
		if p.max_hp != 5 or p.defense != 0 or p.move != 5 or p.cards != ["basic_attack"]:
			all_ok = false
	check(all_ok, "所有棋子 血量5 / 防御0 / 移动5，只有基础攻击卡")
	check(game.FOUNTAIN_CELLS[0] == Vector2i(0, 10) and game.FOUNTAIN_CELLS[1] == Vector2i(20, 10), "泉水在 1-11 和 21-11")
	check(game.ENERGY_CELL == Vector2i(10, 10), "能量圈在正中 11-11")
	var b_ck := find("蓝·混沌骑士")
	var r_ck := find("红·混沌骑士")
	check(r_ck.cell == Vector2i(20 - b_ck.cell.x, b_ck.cell.y), "红方左右镜像布置")

	print("[移动]")
	place(b_ck, Vector2i(8, 4))      # 空旷处
	game._on_cell_clicked(b_ck.cell)
	check(game.move_cells.has(b_ck.cell + Vector2i(5, 0)), "可以走 5 格")
	check(not game.move_cells.has(b_ck.cell + Vector2i(6, 0)), "不能走 6 格")

	print("[基础攻击：3x3 范围，物理伤害 2]")
	var r_s1 := find("红·士兵1")
	place(b_ck, Vector2i(10, 5))
	place(r_s1, Vector2i(11, 6))     # 斜角
	game._select(b_ck)
	game._on_card_pressed("basic_attack")
	check(game.target_cells.has(Vector2i(11, 6)), "斜角相邻的敌人可以攻击")
	check(game.range_cells.size() == 8, "攻击范围是周围 8 格（3x3）")
	game._on_cell_clicked(Vector2i(11, 6))
	check(r_s1.hp == 3, "造成 2 点伤害，剩 %d" % r_s1.hp)
	game.end_turn()
	game.end_turn()
	r_s1.defense = 1
	game._select(b_ck)
	game._on_card_pressed("basic_attack")
	game._on_cell_clicked(r_s1.cell)
	check(r_s1.hp == 2, "防御 1 时只受 1 点伤害，剩 %d" % r_s1.hp)
	game.end_turn()
	game.end_turn()
	r_s1.defense = 9
	game._select(b_ck)
	game._on_card_pressed("basic_attack")
	game._on_cell_clicked(r_s1.cell)
	check(r_s1.hp == 1, "防御高于伤害时至少 1 点，剩 %d" % r_s1.hp)
	r_s1.defense = 0
	place(r_s1, Vector2i(12, 7))     # 距离 2
	game.end_turn()
	game.end_turn()
	game._select(b_ck)
	game._on_card_pressed("basic_attack")
	check(not game.target_cells.has(Vector2i(12, 7)), "2 格外的敌人打不到")
	game._cancel_targeting()

	print("[泉水]")
	await new_game()
	var b_zeus := find("蓝·宙斯")
	b_zeus.hp = 2
	var r_a := find("红·士兵1")
	var r_b := find("红·士兵2")
	place(r_a, Vector2i(2, 9))
	place(r_b, Vector2i(2, 11))
	game.end_turn()   # -> 红方
	game.end_turn()   # -> 蓝方回合开始，泉水结算
	check(b_zeus.hp == 4, "范围内友军 +2 血（2 -> %d）" % b_zeus.hp)
	var hit := int(r_a.hp < 5) + int(r_b.hp < 5)
	check(hit == 1, "只随机攻击范围内 1 个敌人")
	check((not r_a.alive) or (not r_b.alive), "泉水伤害 5，5 血的棋子直接阵亡")
	b_zeus.hp = 4
	game.end_turn()
	game.end_turn()
	check(b_zeus.hp == 5, "回血不超过上限")
	r_ck = find("红·混沌骑士")
	place(find("红·士兵3"), Vector2i(3, 13))   # 范围外
	var s3_hp := find("红·士兵3").hp
	game.end_turn()
	game.end_turn()
	check(find("红·士兵3").hp == s3_hp, "范围外的敌人不受伤")

	print("[能量圈]")
	await new_game()
	b_ck = find("蓝·混沌骑士")
	place(b_ck, Vector2i(7, 10))
	game._select(b_ck)
	game._on_cell_clicked(Vector2i(10, 10))   # 走上能量圈
	await wait(0.4)
	check(b_ck.cell == Vector2i(10, 10), "能量圈可以站上去")
	check(game.capture_count == 0, "站上去当回合不计数")
	game.end_turn()            # 红方
	check(game.capture_count == 0, "对方回合不计数")
	game.end_turn()            # 蓝方第 1 次开场
	check(game.capture_count == 1 and not game.game_over, "己方开场计 1/2")
	game.end_turn()
	game.end_turn()            # 蓝方第 2 次开场
	check(game.game_over, "己方第 2 次开场仍在圈上 → 获胜")

	print("[离开能量圈清零]")
	await new_game()
	b_ck = find("蓝·混沌骑士")
	place(b_ck, Vector2i(10, 10))
	game.end_turn()
	game.end_turn()
	check(game.capture_count == 1, "计到 1/2")
	game._select(b_ck)
	game._on_cell_clicked(Vector2i(10, 12))
	await wait(0.4)
	game.end_turn()
	game.end_turn()
	check(game.capture_count == 0 and not game.game_over, "离开后清零")

	print("[被打死清零]")
	place(b_ck, Vector2i(10, 10))
	game.end_turn()
	game.end_turn()
	check(game.capture_count == 1, "重新占领计 1/2")
	game._damage(b_ck, 99)
	check(game.capture_count == 0, "占领者阵亡后清零")

	print("[全灭获胜]")
	for p in game.pieces:
		if p.team == 1:
			p.hp = 1
			game._damage(p, 5)
	check(game._check_win() and game.game_over, "对方棋子全部阵亡 → 获胜")

	print("\n结果：%s（失败 %d 项）" % ["全部通过" if fails == 0 else "有失败", fails])
	quit(1 if fails > 0 else 0)
