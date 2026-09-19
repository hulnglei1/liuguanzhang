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

## 关羽蓄力上限：不骑乘 15 格；骑上赵云 20 格（赵云无限体力，能扛着跑更远 —— 原著第 13 章）
const DRAGON_CHARGE_CAP_BASE := 15
const DRAGON_CHARGE_CAP_MOUNTED := 20

static func dragon_charge_cap(mounted: bool) -> int:
	return DRAGON_CHARGE_CAP_MOUNTED if mounted else DRAGON_CHARGE_CAP_BASE

## 关羽【蓄力龙斩】：移动格数 = 蓄力值
## 10 格以内每格 +0.3（0.5 → 3.5）；10 格以上每格 +0.35（3.5 → 7.0）
## 设计意图：满档必须"能定胜负"——否则敌人没有理由拼命打断你，机制就不闭环了
static func dragon_charge_multiplier(charge_cells: int) -> float:
	var c: int = clampi(charge_cells, 0, DRAGON_CHARGE_CAP_MOUNTED)
	if c <= 10:
		return 0.5 + 0.3 * float(c)
	return 3.5 + 0.35 * float(c - 10)

## 原著关羽千里蓄力五阶蜕变（初阶微芒 -> 中阶腾云 -> 高阶百丈 -> 极阶劈山裂城 -> 传说裂地千里）
static func dragon_charge_tier(charge: int) -> Dictionary:
	var c: int = clampi(charge, 0, DRAGON_CHARGE_CAP_MOUNTED)
	if c >= 20:
		return {
			"tier": 5,
			"name": "传说 · 裂地千里苍龙",
			"title": "🐉 裂地千里！苍龙贯穿一线！",
			"mult": dragon_charge_multiplier(c),
			"line_len": 12,
			"width": 160.0,
			"fx": "dragon_world_breaker",
			"can_shatter_gate": true,
			"color": Color(0.15, 1.0, 0.6)
		}
	if c >= 10:
		return {
			"tier": 4,
			"name": "极阶 · 劈山裂城神威青龙",
			"title": "🐉 劈山裂城！百丈青龙真身降世！",
			"mult": dragon_charge_multiplier(c),
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
			"line_len": 5,
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
			"line_len": 3,
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
			"line_len": 2,
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

## 士气修正：基准 100 为 1.0；每偏离 1 点士气调整 0.5% 攻防（范围 0.50 ~ 1.50）
static func morale_multiplier(morale: int) -> float:
	return clampf(1.0 + float(morale - 100) * 0.005, 0.5, 1.5)

## 士气法则：不应战 → 敌军全员 ATK ×2
const MORALE_REFUSE_MULT: float = 2.0

## 生成一个伤害事件（纯数据）
static func make_damage_event(target_id: String, value: int, crit: bool = false) -> Dictionary:
	return {"type": "damage", "target": target_id, "value": value, "crit": crit}
