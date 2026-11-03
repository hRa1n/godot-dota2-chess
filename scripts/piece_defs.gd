class_name PieceDefs
extends RefCounted
## 棋子与卡牌的数据表。调数值、加新棋子/新卡牌只改这里。
##
## 棋子属性：hp 血量 / defense 防御 / move 移动速度（每回合最多走几格）
## 物理伤害：实际伤害 = max(1, 卡牌伤害 - 目标防御)；泉水伤害无视防御
##
## 卡牌字段：
##   kind     attack(基础攻击) / skill(技能)
##   target   enemy(选一个敌人) / none(无需目标，直接释放)
##   range    射程
##   area     square = 方形范围（含斜角，射程1 = 周围一圈8格）/ diamond = 菱形（只算上下左右步数）
##   cooldown 冷却：使用后要再过几个己方回合才能再用，0 = 无冷却
##   effect   结算方式，见 game.gd 的 _resolve_card()

const PIECES := {
	"zeus": {
		"name": "宙斯", "short": "宙", "hero": true,
		"hp": 5, "defense": 0, "move": 5,
		"cards": ["basic_attack"],
	},
	"chaos_knight": {
		"name": "混沌骑士", "short": "混", "hero": true,
		"hp": 5, "defense": 0, "move": 5,
		"cards": ["basic_attack"],
	},
	"soldier": {
		"name": "士兵", "short": "兵", "hero": false,
		"hp": 5, "defense": 0, "move": 5,
		"cards": ["basic_attack"],
	},
}

const CARDS := {
	# ---------- 当前使用 ----------
	"basic_attack": {
		"name": "普通攻击", "kind": "attack", "target": "enemy",
		"range": 1, "area": "square", "cooldown": 0, "effect": "damage",
		"damage": 2, "damage_type": "physical",
		"summary": "3x3范围 · 物理伤害2",
		"desc": "对自身周围 3x3 范围内的一名敌人造成 2 点物理伤害（物理伤害会被防御抵消，至少 1 点）。",
	},

	# ---------- 备用：之前做的技能卡，以后要用直接加进棋子的 cards 列表 ----------
	"zeus_chain": {
		"name": "连锁闪电", "kind": "skill", "target": "enemy",
		"range": 4, "area": "diamond", "cooldown": 2, "effect": "chain",
		"damage": 10, "jumps": 2, "jump_range": 3, "jump_damage": 6,
		"summary": "射程4 · 伤害10 · 弹射2次",
		"desc": "对目标造成 10 点伤害，再弹射到附近（3格内）最多 2 个其他敌人，各造成 6 点伤害。",
	},
	"zeus_bolt": {
		"name": "雷击", "kind": "skill", "target": "enemy",
		"range": 7, "area": "diamond", "cooldown": 3, "effect": "damage", "damage": 16,
		"summary": "射程7 · 伤害16",
		"desc": "对远处一名敌人造成 16 点伤害。",
	},
	"zeus_wrath": {
		"name": "天罚", "kind": "skill", "target": "none",
		"range": 0, "area": "diamond", "cooldown": 6, "effect": "global_heroes", "damage": 12,
		"summary": "全场敌方英雄 · 伤害12",
		"desc": "对全场所有敌方英雄各造成 12 点伤害，无视距离。",
	},
	"ck_bolt": {
		"name": "混沌飞弹", "kind": "skill", "target": "enemy",
		"range": 4, "area": "diamond", "cooldown": 3, "effect": "chaos_bolt",
		"min": 6, "max": 16, "stun_min": 1, "stun_max": 2,
		"summary": "射程4 · 伤害6~16 · 眩晕1~2",
		"desc": "造成 6~16 点随机伤害，并眩晕目标 1~2 回合（被眩晕的棋子不能行动）。",
	},
	"ck_rift": {
		"name": "裂隙突袭", "kind": "skill", "target": "enemy",
		"range": 5, "area": "diamond", "cooldown": 3, "effect": "rift", "damage": 8,
		"summary": "射程5 · 传送到目标身边 · 伤害8",
		"desc": "传送到目标身边的空格，并造成 8 点伤害。目标周围没有空格时不能选。",
	},
}
