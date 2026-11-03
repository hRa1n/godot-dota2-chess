class_name PieceDefs
extends RefCounted
## 棋子与卡牌的数据表。调数值、加新棋子/新卡牌只改这里。
##
## 棋子属性：hp 血量 / defense 防御 / move 移动速度（每回合最多走几格）
## 伤害类型：
##   physical 物理：实际伤害 = max(1, 伤害 + 攻击加成(仅攻击卡) - 目标防御)
##   magic    魔法：无视防御
##   泉水伤害无视防御
##
## 卡牌字段：
##   kind     attack 基础攻击 / skill 英雄技能 / equip 装备
##   owner    技能卡专属的英雄。抽到技能卡 = 给这个英雄永久解锁该技能（加入它的行动卡）
##   cooldown 冷却：用过之后接下来几个己方回合不能再用（只有技能有）
##   target   enemy 选一个敌人 / none 直接释放（作用于自己或以自己为中心）
##   range    射程；area = square 时为方形范围，射程 1 = 3x3，2 = 5x5 …
##   effect   结算方式，见 game.gd 的 _resolve_card()
##   card_text 卡面文字；desc 鼠标悬停的完整说明；art 卡面插画

const PIECES := {
	# ---------- 天辉英雄 ----------
	"zeus": {
		"name": "宙斯", "short": "宙", "hero": true,
		"hp": 5, "defense": 0, "move": 5, "cards": ["basic_attack"],
	},
	"crystal_maiden": {
		"name": "水晶室女", "short": "冰", "hero": true,
		"hp": 5, "defense": 0, "move": 5, "cards": ["basic_attack"],
	},
	"juggernaut": {
		"name": "剑圣", "short": "剑", "hero": true,
		"hp": 5, "defense": 0, "move": 5, "cards": ["basic_attack"],
	},
	# ---------- 夜魇英雄 ----------
	"chaos_knight": {
		"name": "混沌骑士", "short": "混", "hero": true,
		"hp": 5, "defense": 0, "move": 5, "cards": ["basic_attack"],
	},
	"axe": {
		"name": "斧王", "short": "斧", "hero": true,
		"hp": 5, "defense": 0, "move": 5, "cards": ["basic_attack"],
	},
	"pudge": {
		"name": "屠夫", "short": "屠", "hero": true,
		"hp": 5, "defense": 0, "move": 5, "cards": ["basic_attack"],
	},
	# ---------- 小兵 / 召唤物 ----------
	"soldier": {
		"name": "士兵", "short": "兵", "hero": false,
		"hp": 5, "defense": 0, "move": 5, "cards": ["basic_attack"],
	},
	"illusion": {
		"name": "幻象", "short": "幻", "hero": false,
		"hp": 1, "defense": 0, "move": 5, "cards": ["illusion_attack"],
	},
}

## 每个英雄的 3 张专属技能卡
const HERO_SKILLS := {
	"zeus": ["zeus_chain", "zeus_bolt", "zeus_wrath"],
	"crystal_maiden": ["cm_nova", "cm_frostbite", "cm_field"],
	"juggernaut": ["jugg_fury", "jugg_ward", "jugg_omni"],
	"chaos_knight": ["ck_bolt", "ck_rift", "ck_phantasm"],
	"axe": ["axe_call", "axe_helix", "axe_cull"],
	"pudge": ["pudge_hook", "pudge_rot", "pudge_dismember"],
}

## 装备卡（双方牌库都有）
const EQUIPMENT := ["item_mail", "item_blade", "item_boots", "item_orb", "item_salve"]

## 牌库：本方每个英雄的技能卡各 SKILL_COPIES 张 + 每种装备各 EQUIP_COPIES 张
const SKILL_COPIES := 1
const EQUIP_COPIES := 2


static func build_deck(hero_types: Array) -> Array:
	var deck := []
	for hero in hero_types:
		for id in HERO_SKILLS.get(hero, []):
			for i in SKILL_COPIES:
				deck.append(id)
	for id in EQUIPMENT:
		for i in EQUIP_COPIES:
			deck.append(id)
	return deck


const CARDS := {
	# ======================= 基础攻击 =======================
	"basic_attack": {
		"name": "普通攻击", "kind": "attack", "target": "enemy",
		"range": 1, "area": "square", "effect": "damage",
		"damage": 2, "damage_type": "physical", "art": "sword",
		"card_text": "对周围 3x3 内一名敌人造成 2 点物理伤害",
		"desc": "对自身周围 3x3 范围内的一名敌人造成 2 点物理伤害（会被防御抵消，至少 1 点）。",
	},
	"illusion_attack": {
		"name": "幻象攻击", "kind": "attack", "target": "enemy",
		"range": 1, "area": "square", "effect": "damage",
		"damage": 1, "damage_type": "physical", "art": "knight",
		"card_text": "对周围 3x3 内一名敌人造成 1 点物理伤害",
		"desc": "幻象的攻击：对周围 3x3 内一名敌人造成 1 点物理伤害。",
	},

	# ======================= 宙斯 =======================
	"zeus_chain": {
		"name": "连锁闪电", "kind": "skill", "cooldown": 2, "owner": "zeus", "target": "enemy",
		"range": 3, "area": "square", "effect": "chain",
		"damage": 2, "jumps": 2, "jump_range": 2, "jump_damage": 1, "art": "zeus",
		"card_text": "7x7 内一名敌人 2 点魔法伤害，再弹射 2 个敌人各 1 点",
		"desc": "对 7x7 范围内一名敌人造成 2 点魔法伤害，然后弹射到它附近 5x5 内最多 2 个其他敌人，各造成 1 点魔法伤害。",
	},
	"zeus_bolt": {
		"name": "雷击", "kind": "skill", "cooldown": 2, "owner": "zeus", "target": "enemy",
		"range": 5, "area": "square", "effect": "damage", "damage": 3, "art": "zeus",
		"card_text": "对 11x11 内一名敌人造成 3 点魔法伤害",
		"desc": "对 11x11 范围内一名敌人造成 3 点魔法伤害（无视防御）。",
	},
	"zeus_wrath": {
		"name": "天罚", "kind": "skill", "cooldown": 4, "owner": "zeus", "target": "none",
		"range": 0, "effect": "global_enemies", "damage": 1, "art": "storm",
		"card_text": "全场所有敌人各受到 1 点魔法伤害",
		"desc": "召唤雷霆，对全场所有敌方棋子各造成 1 点魔法伤害，无视距离。",
	},

	# ======================= 水晶室女 =======================
	"cm_nova": {
		"name": "冰霜新星", "kind": "skill", "cooldown": 2, "owner": "crystal_maiden", "target": "enemy",
		"range": 4, "area": "square", "effect": "aoe_at_target",
		"damage": 1, "radius": 1, "art": "snow",
		"card_text": "9x9 内选一名敌人，它周围 3x3 的敌人各受 1 点魔法伤害",
		"desc": "以 9x9 范围内一名敌人为中心爆发寒冰，3x3 范围内所有敌人各受到 1 点魔法伤害。",
	},
	"cm_frostbite": {
		"name": "冰封禁制", "kind": "skill", "cooldown": 2, "owner": "crystal_maiden", "target": "enemy",
		"range": 3, "area": "square", "effect": "damage_stun",
		"damage": 1, "stun": 1, "art": "snow",
		"card_text": "7x7 内一名敌人 1 点魔法伤害，并冻结 1 回合",
		"desc": "冻住 7x7 范围内一名敌人：1 点魔法伤害，并让它下一个己方回合不能行动。",
	},
	"cm_field": {
		"name": "极寒领域", "kind": "skill", "cooldown": 4, "owner": "crystal_maiden", "target": "none",
		"range": 0, "effect": "aoe_self", "damage": 2, "radius": 3, "art": "snow",
		"card_text": "自身周围 7x7 内所有敌人各受 2 点魔法伤害",
		"desc": "在身边降下暴风雪：自身周围 7x7 范围内所有敌人各受到 2 点魔法伤害。",
	},

	# ======================= 剑圣 =======================
	"jugg_fury": {
		"name": "剑刃风暴", "kind": "skill", "cooldown": 2, "owner": "juggernaut", "target": "none",
		"range": 0, "effect": "aoe_self", "damage": 2, "radius": 1, "art": "blade",
		"card_text": "自身周围 3x3 内所有敌人各受 2 点魔法伤害",
		"desc": "原地旋转刀刃：自身周围 3x3 范围内所有敌人各受到 2 点魔法伤害。",
	},
	"jugg_ward": {
		"name": "治疗守卫", "kind": "skill", "cooldown": 3, "owner": "juggernaut", "target": "none",
		"range": 0, "effect": "heal_area", "heal": 2, "radius": 2, "art": "ward",
		"card_text": "自身周围 5x5 内所有友军回复 2 点血量",
		"desc": "放下治疗守卫：自身周围 5x5 范围内所有友军（包括自己）回复 2 点血量。",
	},
	"jugg_omni": {
		"name": "无敌斩", "kind": "skill", "cooldown": 4, "owner": "juggernaut", "target": "enemy",
		"range": 3, "area": "square", "effect": "omnislash",
		"damage": 1, "hits": 3, "damage_type": "physical", "art": "blade",
		"card_text": "闪到 7x7 内一名敌人身边，连斩 3 次，每次 1 点物理伤害",
		"desc": "闪到 7x7 范围内一名敌人身边，连斩 3 次：每次随机攻击身边 3x3 内的一个敌人，造成 1 点物理伤害。",
	},

	# ======================= 混沌骑士 =======================
	"ck_bolt": {
		"name": "混沌飞弹", "kind": "skill", "cooldown": 2, "owner": "chaos_knight", "target": "enemy",
		"range": 3, "area": "square", "effect": "chaos_bolt",
		"min": 1, "max": 3, "stun_min": 1, "stun_max": 2, "art": "chaos",
		"card_text": "7x7 内一名敌人 1~3 点魔法伤害，眩晕 1~2 回合",
		"desc": "对 7x7 范围内一名敌人造成 1~3 点随机魔法伤害，并眩晕 1~2 回合。",
	},
	"ck_rift": {
		"name": "实相裂隙", "kind": "skill", "cooldown": 2, "owner": "chaos_knight", "target": "enemy",
		"range": 4, "area": "square", "effect": "rift",
		"damage": 2, "damage_type": "physical", "art": "rift",
		"card_text": "传送到 9x9 内一名敌人身边，造成 2 点物理伤害",
		"desc": "传送到 9x9 范围内一名敌人身边的空格，并造成 2 点物理伤害。目标周围没有空格时不能选。",
	},
	"ck_phantasm": {
		"name": "混沌幻象", "kind": "skill", "cooldown": 4, "owner": "chaos_knight", "target": "none",
		"range": 0, "effect": "summon", "summon": "illusion", "count": 2, "art": "knight",
		"card_text": "在身边召唤 2 个幻象（1 血，攻击 1）",
		"desc": "在身边空格召唤 2 个幻象。幻象：1 点血量，移动 5，攻击造成 1 点物理伤害。",
	},

	# ======================= 斧王 =======================
	"axe_call": {
		"name": "狂战士之吼", "kind": "skill", "cooldown": 3, "owner": "axe", "target": "none",
		"range": 0, "effect": "berserkers_call", "radius": 1, "stun": 1, "defense": 1, "art": "axe",
		"card_text": "眩晕周围 3x3 内所有敌人 1 回合，自身防御 +1",
		"desc": "怒吼：自身周围 3x3 范围内所有敌人眩晕 1 回合，斧王防御永久 +1。",
	},
	"axe_helix": {
		"name": "反击螺旋", "kind": "skill", "cooldown": 1, "owner": "axe", "target": "none",
		"range": 0, "effect": "aoe_self", "damage": 1, "radius": 1,
		"damage_type": "physical", "art": "axe",
		"card_text": "自身周围 3x3 内所有敌人各受 1 点物理伤害",
		"desc": "抡斧旋转：自身周围 3x3 范围内所有敌人各受到 1 点物理伤害。",
	},
	"axe_cull": {
		"name": "淘汰之刃", "kind": "skill", "cooldown": 3, "owner": "axe", "target": "enemy",
		"range": 1, "area": "square", "effect": "cull", "threshold": 3, "damage": 1, "art": "axe",
		"card_text": "3x3 内一名敌人：血量 ≤3 直接斩杀，否则 1 点魔法伤害",
		"desc": "对 3x3 范围内一名敌人：如果它血量不超过 3，直接斩杀；否则造成 1 点魔法伤害。",
	},

	# ======================= 屠夫 =======================
	"pudge_hook": {
		"name": "肉钩", "kind": "skill", "cooldown": 2, "owner": "pudge", "target": "enemy",
		"range": 5, "area": "line", "effect": "hook",
		"damage": 2, "damage_type": "physical", "art": "hook",
		"card_text": "直线 5 格内第一个敌人拉到身边，造成 2 点物理伤害",
		"desc": "朝上下左右扔出肉钩：同一行或同一列 5 格内、中间没有阻挡的第一个敌人被拉到屠夫身边，并受到 2 点物理伤害。",
	},
	"pudge_rot": {
		"name": "腐烂", "kind": "skill", "cooldown": 1, "owner": "pudge", "target": "none",
		"range": 0, "effect": "rot", "damage": 1, "radius": 1, "self_damage": 1, "art": "rot",
		"card_text": "周围 3x3 内敌人各受 1 点魔法伤害，自己也受 1 点",
		"desc": "散发腐臭：自身周围 3x3 范围内所有敌人各受到 1 点魔法伤害，屠夫自己也受到 1 点。",
	},
	"pudge_dismember": {
		"name": "肢解", "kind": "skill", "cooldown": 3, "owner": "pudge", "target": "enemy",
		"range": 1, "area": "square", "effect": "dismember", "damage": 3, "heal": 1, "art": "hook",
		"card_text": "3x3 内一名敌人 3 点魔法伤害，自己回复 1 点",
		"desc": "对 3x3 范围内一名敌人造成 3 点魔法伤害，屠夫回复 1 点血量。",
	},

	# ======================= 装备 =======================
	"item_mail": {
		"name": "锁子甲", "kind": "equip", "target": "none", "effect": "equip",
		"stats": {"defense": 1}, "art": "armor", "slot_text": "防御 +1",
		"card_text": "装备：防御 +1",
		"desc": "给选中的己方英雄装备：防御永久 +1（物理伤害减 1）。不占行动；占 1 个装备栏，装上不能卸。",
	},
	"item_blade": {
		"name": "阔剑", "kind": "equip", "target": "none", "effect": "equip",
		"stats": {"atk": 1}, "art": "sword", "slot_text": "攻击 +1",
		"card_text": "装备：基础攻击伤害 +1",
		"desc": "给选中的己方英雄装备：基础攻击伤害永久 +1。不占行动；占 1 个装备栏，装上不能卸。",
	},
	"item_boots": {
		"name": "速度之靴", "kind": "equip", "target": "none", "effect": "equip",
		"stats": {"move": 2}, "art": "boots", "slot_text": "移动 +2",
		"card_text": "装备：移动速度 +2",
		"desc": "给选中的己方英雄装备：移动速度永久 +2，还没移动的话本回合就生效。不占行动；占 1 个装备栏，装上不能卸。",
	},
	"item_orb": {
		"name": "活力宝珠", "kind": "equip", "target": "none", "effect": "equip",
		"stats": {"max_hp": 2, "heal": 2}, "art": "orb", "slot_text": "血量上限 +2",
		"card_text": "装备：血量上限 +2，并回复 2 点",
		"desc": "给选中的己方英雄装备：血量上限永久 +2，并立即回复 2 点。不占行动；占 1 个装备栏，装上不能卸。",
	},
	"item_salve": {
		"name": "治疗药膏", "kind": "equip", "target": "none", "effect": "equip",
		"stats": {"heal": 3}, "consumable": true, "art": "potion",
		"card_text": "消耗品：回复 3 点血量",
		"desc": "消耗品：选中的己方棋子（英雄或小兵都行）立即回复 3 点血量。不占行动，不占装备栏。",
	},
}
