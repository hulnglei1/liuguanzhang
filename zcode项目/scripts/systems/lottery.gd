class_name LotteryCore
extends RefCounted
## 占郡抽奖系统（V2 完整：种子池 + 武器池）
## 每占一郡 +1000 声望；种子池 1000/抽，武器池 5000/抽

## 种子奖池：消耗1000声望，通关后一次性可持续获得
const SEED_POOL := [
	{"id": "corn", "name": "玉米种子", "desc": "关卡内每回合全体回HP 5", "buff": "hp_regen", "value": 5},
	{"id": "potato", "name": "土豆种子", "desc": "下一关开局士气+10", "buff": "morale_start", "value": 10},
	{"id": "sweet_potato", "name": "番薯种子", "desc": "关卡内我方攻击+10%", "buff": "atk_pct", "value": 0.10},
]

## 武器奖池：消耗5000声望，抽取强力装备/技能词条
const WEAPON_POOL := [
	{"id": "jinggang_dou", "name": "金刚护腕", "desc": "装备：防御+6", "buff": "def_gear", "value": 6},
	{"id": "da_he_dan", "name": "大爆炸·大黄丹", "desc": "技能词条：范围AOE伤害", "buff": "aoe", "value": 1},
	{"id": "shi_tou", "name": "东风·微缩版", "desc": "战技：全屏轰击，秒杀黄巾杂兵", "buff": "full_screen", "value": 1},
	{"id": "gu_shou", "name": "古兽护符", "desc": "装备：生命+40", "buff": "hp_gear", "value": 40},
]

## 抽一次种子（声望≥1000，扣1000），返回 {item, cost, success, new_prestige}
static func draw_seed(shengwang: int) -> Dictionary:
	if shengwang < 1000:
		return {"success": false, "reason": "声望不足（需1000，占1郡）", "new_prestige": shengwang}
	var item: Dictionary = SEED_POOL[randi() % SEED_POOL.size()]
	return {"success": true, "cost": 1000, "item": item, "new_prestige": shengwang - 1000}

## 抽一次武器（声望≥5000，扣5000）
static func draw_weapon(shengwang: int) -> Dictionary:
	if shengwang < 5000:
		return {"success": false, "reason": "声望不足（需5000，占5郡）", "new_prestige": shengwang}
	var item: Dictionary = WEAPON_POOL[randi() % WEAPON_POOL.size()]
	return {"success": true, "cost": 5000, "item": item, "new_prestige": shengwang - 5000}

## 抽奖结果文案
static func draw_flavor(item: Dictionary) -> String:
	return "【叮！恭喜抽中 · %s】\n%s" % [item.get("name", "?"), item.get("desc", "")]