class_name CombatCore
extends RefCounted
## 战斗核心：伤害公式、蓄力倍率、士气修正（纯逻辑，返回事件数组，无渲染依赖）

## 基础伤害：ATK × 技能倍率 − 敌 DEF，保底 1
static func damage(atk: int, multiplier: float, def: int) -> int:
	var dmg := int(round(atk * multiplier)) - def
	return max(dmg, 1)

## 反击伤害：ATK × 0.7 − 敌 DEF，保底 1
static func counter_damage(atk: int, def: int) -> int:
	var dmg := int(round(float(atk) * 0.7)) - def
	return max(dmg, 1)

## 关羽【蓄力龙斩】：移动格数 = 蓄力值，倍率 = 0.5 + 0.3 × 格数（上限 10 格 = 3.5 倍）
static func dragon_charge_multiplier(charge_cells: int) -> float:
	var c: int = clampi(charge_cells, 0, 10)
	return 0.5 + 0.3 * float(c)

## 原著关羽千里蓄力四阶蜕变（初阶微芒 -> 中阶腾云 -> 高阶百丈 -> 极阶劈山裂城）
static func dragon_charge_tier(charge: int) -> Dictionary:
	var c: int = clampi(charge, 0, 10)
	if c >= 10:
		return {
			"tier": 4,
			"name": "极阶 · 劈山裂城神威青龙",
			"title": "🐉 劈山裂城！百丈青龙真身降世！",
			"mult": 3.5,
			"line_len": 12,
			"width": 120.0,
			"fx": "dragon_mountain_breaker",
			"can_shatter_gate": true,
			"color": Color(0.2, 1.0, 0.45)
		}
	elif c >= 7:
		return {
			"tier": 3,
			"name": "高阶 · 百丈怒龙冲霄",
			"title": "🐉 龙吟震天！百丈怒龙威压全场！",
			"mult": 0.5 + 0.3 * float(c),
			"line_len": 4,
			"width": 85.0,
			"fx": "dragon_giant",
			"can_shatter_gate": false,
			"color": Color(0.3, 0.9, 0.6)
		}
	elif c >= 4:
		return {
			"tier": 2,
			"name": "中阶 · 青龙腾云逐日",
			"title": "🐉 刀势如虹！青龙腾云咆哮！",
			"mult": 0.5 + 0.3 * float(c),
			"line_len": 2,
			"width": 60.0,
			"fx": "dragon_soar",
			"can_shatter_gate": false,
			"color": Color(0.35, 0.85, 0.8)
		}
	elif c >= 1:
		return {
			"tier": 1,
			"name": "初阶 · 青龙微芒破晓",
			"title": "🐉 逃兵绕场！青龙微芒初现！",
			"mult": 0.5 + 0.3 * float(c),
			"line_len": 1,
			"width": 38.0,
			"fx": "dragon_breeze",
			"can_shatter_gate": false,
			"color": Color(0.6, 0.75, 0.85)
		}
	else:
		return {
			"tier": 0,
			"name": "未蓄力 · 寻常刀势",
			"title": "寻常刀法（打Boss如刮痧）",
			"mult": 0.5,
			"line_len": 1,
			"width": 24.0,
			"fx": "dragon",
			"can_shatter_gate": false,
			"color": Color(0.7, 0.7, 0.7)
		}

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
