class_name PieceDefs
extends RefCounted
## 棋子与卡牌的数据表。调数值、加新棋子/新卡牌只改这里。
##
## 卡牌字段：
##   kind     attack(基础攻击) / skill(技能)
##   target   enemy(选一个敌人) / none(无需目标，直接释放)
##   range    射程（曼哈顿距离）
##   cooldown 冷却：使用后要再过几个己方回合才能再用，0 = 无冷却
##   effect   结算方式，见 game.gd 的 _resolve_card()

const PIECES := {
	"zeus": {
		"name": "宙斯", "short": "宙", "hero": true,
		"hp": 60, "move": 2,
		"cards": ["zeus_attack", "zeus_chain", "zeus_bolt", "zeus_wrath"],
	},
	"chaos_knight": {
		"name": "混沌骑士", "short": "混", "hero": true,
		"hp": 90, "move": 3,
		"cards": ["ck_attack", "ck_bolt", "ck_rift"],
	},
	"soldier": {
		"name": "士兵", "short": "兵", "hero": false,
		"hp": 25, "move": 2,
		"cards": ["soldier_attack"],
	},
}

const CARDS := {
	# ---------- 宙斯：远程法师 ----------
	"zeus_attack": {
		"name": "普通攻击", "kind": "attack", "target": "enemy",
		"range": 3, "cooldown": 0, "effect": "damage", "damage": 6,
		"summary": "射程3 · 伤害6",
		"desc": "对射程内一名敌人造成 6 点伤害。",
	},
	"zeus_chain": {
		"name": "连锁闪电", "kind": "skill", "target": "enemy",
		"range": 4, "cooldown": 2, "effect": "chain",
		"damage": 10, "jumps": 2, "jump_range": 3, "jump_damage": 6,
		"summary": "射程4 · 伤害10 · 弹射2次",
		"desc": "对目标造成 10 点伤害，再弹射到附近（3格内）最多 2 个其他敌人，各造成 6 点伤害。",
	},
	"zeus_bolt": {
		"name": "雷击", "kind": "skill", "target": "enemy",
		"range": 7, "cooldown": 3, "effect": "damage", "damage": 16,
		"summary": "射程7 · 伤害16",
		"desc": "对远处一名敌人造成 16 点伤害。",
	},
	"zeus_wrath": {
		"name": "天罚", "kind": "skill", "target": "none",
		"range": 0, "cooldown": 6, "effect": "global_heroes", "damage": 12,
		"summary": "全场敌方英雄 · 伤害12",
		"desc": "对全场所有敌方英雄各造成 12 点伤害，无视距离。",
	},

	# ---------- 混沌骑士：近战突进 ----------
	"ck_attack": {
		"name": "普通攻击", "kind": "attack", "target": "enemy",
		"range": 1, "cooldown": 0, "effect": "crit_attack",
		"damage": 10, "crit_chance": 0.25,
		"summary": "近战 · 伤害10 · 25%暴击",
		"desc": "对相邻敌人造成 10 点伤害，25% 概率暴击造成双倍伤害。",
	},
	"ck_bolt": {
		"name": "混沌飞弹", "kind": "skill", "target": "enemy",
		"range": 4, "cooldown": 3, "effect": "chaos_bolt",
		"min": 6, "max": 16, "stun_min": 1, "stun_max": 2,
		"summary": "射程4 · 伤害6~16 · 眩晕1~2",
		"desc": "造成 6~16 点随机伤害，并眩晕目标 1~2 回合（被眩晕的棋子不能行动）。",
	},
	"ck_rift": {
		"name": "裂隙突袭", "kind": "skill", "target": "enemy",
		"range": 5, "cooldown": 3, "effect": "rift", "damage": 8,
		"summary": "射程5 · 传送到目标身边 · 伤害8",
		"desc": "传送到目标身边的空格，并造成 8 点伤害。目标周围没有空格时不能选。",
	},

	# ---------- 基础士兵 ----------
	"soldier_attack": {
		"name": "普通攻击", "kind": "attack", "target": "enemy",
		"range": 1, "cooldown": 0, "effect": "damage", "damage": 5,
		"summary": "近战 · 伤害5",
		"desc": "对相邻敌人造成 5 点伤害。",
	},
}
