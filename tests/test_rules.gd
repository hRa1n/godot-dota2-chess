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


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await new_game()

	print("[布置与属性]")
	check(Board.COLS == 11 and Board.ROWS == 11, "地图 11x11")
	check(game.pieces.size() == 10, "双方各 5 个棋子")
	var zeus := find("天辉·宙斯")
	var ck := find("夜魇·混沌骑士")
	check(zeus != null and zeus.team == 0, "天辉有宙斯")
	check(ck != null and ck.team == 1, "夜魇有混沌骑士")
	check(find("天辉·混沌骑士") == null and find("夜魇·宙斯") == null, "双方各只有一个英雄")
	var counts := [0, 0]
	for p in game.pieces:
		if p.type_id == "soldier":
			counts[p.team] += 1
	check(counts == [4, 4], "双方各 4 个小兵")
	var all_ok := true
	for p in game.pieces:
		if p.max_hp != 5 or p.defense != 0 or p.move != 5 or p.cards != ["basic_attack"]:
			all_ok = false
	check(all_ok, "所有棋子 血量5 / 防御0 / 移动5，只有基础攻击卡")
	check(game.FOUNTAIN_CELLS[0] == Vector2i(5, 10) and game.FOUNTAIN_CELLS[1] == Vector2i(5, 0), "泉水：天辉下边中间，夜魇上边中间")
	check(game.ENERGY_CELL == Vector2i(5, 5), "能量圈在正中 6-6")
	check(game.fmt(Vector2i(5, 0)) == "1-6", "坐标显示为 行-列")

	print("[移动]")
	place(zeus, Vector2i(0, 4))      # 空旷处
	game._on_cell_clicked(zeus.cell)
	check(game.move_cells.has(Vector2i(5, 4)), "可以走 5 格")
	check(not game.move_cells.has(Vector2i(6, 4)), "不能走 6 格")

	print("[基础攻击：3x3 范围，物理伤害 2]")
	var r_s1 := find("夜魇·士兵1")
	place(zeus, Vector2i(3, 4))
	place(r_s1, Vector2i(4, 5))      # 斜角
	game._select(zeus)
	game._on_card_pressed("basic_attack")
	check(game.target_cells.has(Vector2i(4, 5)), "斜角相邻的敌人可以攻击")
	check(game.range_cells.size() == 8, "攻击范围是周围 8 格（3x3）")
	game._on_cell_clicked(Vector2i(4, 5))
	check(r_s1.hp == 3, "造成 2 点伤害，剩 %d" % r_s1.hp)
	game.end_turn()
	game.end_turn()
	r_s1.defense = 1
	game._select(zeus)
	game._on_card_pressed("basic_attack")
	game._on_cell_clicked(r_s1.cell)
	check(r_s1.hp == 2, "防御 1 时只受 1 点伤害，剩 %d" % r_s1.hp)
	game.end_turn()
	game.end_turn()
	r_s1.defense = 9
	game._select(zeus)
	game._on_card_pressed("basic_attack")
	game._on_cell_clicked(r_s1.cell)
	check(r_s1.hp == 1, "防御高于伤害时至少 1 点，剩 %d" % r_s1.hp)
	r_s1.defense = 0
	place(r_s1, Vector2i(5, 6))      # 距离 2
	game.end_turn()
	game.end_turn()
	game._select(zeus)
	game._on_card_pressed("basic_attack")
	check(not game.target_cells.has(Vector2i(5, 6)), "2 格外的敌人打不到")
	game._cancel_targeting()

	print("[泉水]")
	await new_game()
	zeus = find("天辉·宙斯")
	zeus.hp = 2
	var r_a := find("夜魇·士兵1")
	var r_b := find("夜魇·士兵2")
	place(r_a, Vector2i(3, 9))
	place(r_b, Vector2i(7, 9))
	game.end_turn()   # -> 夜魇
	game.end_turn()   # -> 天辉回合开始，泉水结算
	check(zeus.hp == 4, "范围内友军 +2 血（2 -> %d）" % zeus.hp)
	var hit := int(r_a.hp < 5) + int(r_b.hp < 5)
	check(hit == 1, "只随机攻击范围内 1 个敌人")
	check((not r_a.alive) or (not r_b.alive), "泉水伤害 5，5 血的棋子直接阵亡")
	zeus.hp = 4
	game.end_turn()
	game.end_turn()
	check(zeus.hp == 5, "回血不超过上限")
	var s3 := find("夜魇·士兵3")
	place(s3, Vector2i(5, 7))         # 距泉水 3 格，范围外
	game.end_turn()
	game.end_turn()
	check(s3.hp == 5, "范围外的敌人不受伤")

	print("[能量圈]")
	await new_game()
	zeus = find("天辉·宙斯")
	place(zeus, Vector2i(2, 5))
	game._select(zeus)
	game._on_cell_clicked(Vector2i(5, 5))    # 走上能量圈
	await wait(0.4)
	check(zeus.cell == Vector2i(5, 5), "能量圈可以站上去")
	check(game.capture_count == 0, "站上去当回合不计数")
	game.end_turn()            # 夜魇
	check(game.capture_count == 0, "对方回合不计数")
	game.end_turn()            # 天辉第 1 次开场
	check(game.capture_count == 1 and not game.game_over, "己方开场计 1/2")
	game.end_turn()
	game.end_turn()            # 天辉第 2 次开场
	check(game.game_over, "己方第 2 次开场仍在圈上 → 获胜")

	print("[离开能量圈清零]")
	await new_game()
	zeus = find("天辉·宙斯")
	place(zeus, Vector2i(5, 5))
	game.end_turn()
	game.end_turn()
	check(game.capture_count == 1, "计到 1/2")
	game._select(zeus)
	game._on_cell_clicked(Vector2i(5, 7))
	await wait(0.4)
	game.end_turn()
	game.end_turn()
	check(game.capture_count == 0 and not game.game_over, "离开后清零")

	print("[被打死清零]")
	place(zeus, Vector2i(5, 5))
	game.end_turn()
	game.end_turn()
	check(game.capture_count == 1, "重新占领计 1/2")
	game._damage(zeus, 99)
	check(game.capture_count == 0, "占领者阵亡后清零")

	print("[全灭获胜]")
	for p in game.pieces:
		if p.team == 1:
			p.hp = 1
			game._damage(p, 5)
	check(game._check_win() and game.game_over, "对方棋子全部阵亡 → 获胜")

	print("\n结果：%s（失败 %d 项）" % ["全部通过" if fails == 0 else "有失败", fails])
	quit(1 if fails > 0 else 0)
