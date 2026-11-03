extends SceneTree
## 规则自动测试（无界面运行）：
##   godot --headless -s res://tests/test_rules.gd

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


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame

	print("[布置]")
	check(game.pieces.size() == 12, "双方各 6 个棋子")
	check(game.current_team == 0, "蓝方先手")
	var b_ck := find("蓝·混沌骑士")
	var b_zeus := find("蓝·宙斯")
	var r_zeus := find("红·宙斯")
	var r_ck := find("红·混沌骑士")
	var r_s1 := find("红·士兵1")
	check(b_ck != null and r_zeus != null and r_s1 != null, "棋子命名正确")
	check(r_zeus.cell == Vector2i(18, 2), "红方布置为中心对称")

	print("[移动 + 普通攻击]")
	place(r_s1, Vector2i(4, 13))
	game._on_cell_clicked(b_ck.cell)
	check(game.selected == b_ck, "点击己方棋子可选中")
	check(game.move_cells.has(Vector2i(4, 14)), "显示可移动格")
	check(not game.move_cells.has(Vector2i(4, 13)), "有棋子的格子不能走")
	game._on_cell_clicked(Vector2i(4, 14))
	await wait(0.4)
	check(b_ck.cell == Vector2i(4, 14), "移动成功")
	game._on_cell_clicked(b_zeus.cell)
	check(not game.can_control(b_zeus), "移动后本回合锁定为该棋子")
	game._on_cell_clicked(b_ck.cell)
	game._on_card_pressed("ck_attack")
	check(game.target_cells.has(Vector2i(4, 13)), "相邻敌人可作为攻击目标")
	game._on_cell_clicked(Vector2i(4, 13))
	check(r_s1.hp == 15 or r_s1.hp == 5, "普通攻击造成 10 伤害（或暴击 20），剩 %d" % r_s1.hp)
	await wait(1.0)
	check(game.current_team == 1, "移动+出牌后自动结束回合")

	print("[天罚 + 冷却]")
	var ck_hp := b_ck.hp
	var zeus_hp := b_zeus.hp
	game._on_cell_clicked(r_zeus.cell)
	game._on_card_pressed("zeus_wrath")
	check(b_ck.hp == ck_hp - 12 and b_zeus.hp == zeus_hp - 12, "天罚命中全场敌方英雄")
	check(r_zeus.cooldown_of("zeus_wrath") == 6, "天罚进入冷却 6")
	check(not game.card_usable(r_zeus, "zeus_attack"), "一回合只能出一张牌")
	game.end_turn()
	check(r_zeus.cooldown_of("zeus_wrath") == 5, "己方回合结束冷却 -1")

	print("[混沌飞弹 + 眩晕]")
	r_s1.hp = r_s1.max_hp   # 保证不会被打死，便于检查眩晕
	game._on_cell_clicked(b_ck.cell)
	game._on_card_pressed("ck_bolt")
	check(game.target_cells.has(r_s1.cell), "混沌飞弹可选目标")
	game._on_cell_clicked(r_s1.cell)
	if r_s1.alive:
		check(r_s1.stun >= 1, "目标被眩晕 %d 回合" % r_s1.stun)
		game.end_turn()
		check(not game.can_control(r_s1), "被眩晕的棋子不能行动")
		game.end_turn()
	else:
		print("  (士兵已被击杀，跳过眩晕检查)")
		game.end_turn()
		game.end_turn()

	print("[裂隙突袭]")
	check(game.current_team == 0, "回到蓝方回合")
	b_ck.cooldowns.clear()
	place(r_ck, Vector2i(7, 12))   # 与 (4,14) 距离 5
	game._on_cell_clicked(b_ck.cell)
	game._on_card_pressed("ck_rift")
	check(game.target_cells.has(r_ck.cell), "裂隙突袭可选 5 格内敌人")
	var rck_hp := r_ck.hp
	game._on_cell_clicked(r_ck.cell)
	await wait(0.5)
	check(Game_manhattan(b_ck.cell, r_ck.cell) == 1, "传送到目标相邻格 %s" % str(b_ck.cell))
	check(r_ck.hp == rck_hp - 8, "裂隙突袭造成 8 伤害")
	game.end_turn()

	print("[泉水]")
	var r_s2 := find("红·士兵2")
	place(r_s2, Vector2i(1, 19))
	var s2_hp := r_s2.hp
	game.end_turn()   # 红方结束 -> 蓝方回合开始，蓝方泉水攻击范围内的敌人
	check(r_s2.hp == maxi(0, s2_hp - 20), "敌方进入泉水范围受到 20 伤害")
	b_zeus.hp = 10
	place(b_zeus, Vector2i(2, 18))
	game.end_turn()
	game.end_turn()
	check(b_zeus.hp == 20, "己方在泉水范围内回复 10 生命")

	print("[胜负]")
	r_zeus.hp = 1
	r_ck.hp = 1
	game._damage(r_zeus, 5)
	game._damage(r_ck, 5)
	check(game._check_win(), "消灭对方全部英雄后游戏结束")
	check(game.game_over, "game_over 状态正确")

	print("\n结果：%s（失败 %d 项）" % ["全部通过" if fails == 0 else "有失败", fails])
	quit(1 if fails > 0 else 0)


func Game_manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)
