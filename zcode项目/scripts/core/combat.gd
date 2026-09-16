class_name CombatCore
extends RefCounted
## 战斗核心：伤害公式、蓄力倍率、士气修正（纯逻辑，返回事件数组，无渲染依赖）

## 基础伤害：ATK × 技能倍率 − 敌 DEF，保底 1
static func damage(atk: int, multiplier: float, def: int) -> int:
	var dmg := int(round(atk * multiplier)) - def
	return max(dmg, 1)

## 关羽【蓄力龙斩】：移动格数 = 蓄力值，倍率 = 0.5 + 0.3 × 格数（上限 10 格 = 3.5 倍）
static func dragon_charge_multiplier(charge_cells: int) -> float:
	var c: int = clampi(charge_cells, 0, 10)
	return 0.5 + 0.3 * float(c)

## 张飞【断桥怒吼】：待机蓄力轮数 = 蓄力值，倍率 = 0.6 × (1 + 轮数)（上限 3 轮 = 2.4 倍）
static func roar_charge_multiplier(charge_turns: int) -> float:
	var t: int = clampi(charge_turns, 0, 3)
	return 0.6 * (1.0 + float(t))

## 赵云【七进七出】：每穿过一格 0.4 倍，最多 7 次 = 2.8 倍
static func dash_multiplier(weaves: int) -> float:
	var w: int = clampi(weaves, 1, 7)
	return 0.4 * float(w)

## 华雄【虎牢狂力】：每回合 ATK +15%，上限 +150%
static func hua_boost_multiplier(turns_elapsed: int) -> float:
	return 1.0 + 0.15 * float(clampi(turns_elapsed, 0, 10))

## 士气修正：士气 >70 全属性 +10%；<30 全属性 −10%（仅作用于 ATK/DEF）
static func morale_multiplier(morale: int) -> float:
	if morale > 70:
		return 1.10
	elif morale < 30:
		return 0.90
	return 1.0

## 士气法则：不应战 → 敌军全员 ATK ×2
const MORALE_REFUSE_MULT: float = 2.0

## 生成一个伤害事件（纯数据）
static func make_damage_event(target_id: String, value: int, crit: bool = false) -> Dictionary:
	return {"type": "damage", "target": target_id, "value": value, "crit": crit}
