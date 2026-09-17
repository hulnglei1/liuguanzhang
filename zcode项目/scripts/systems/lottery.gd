class_name LotteryCore
extends RefCounted
## 占郡抽奖系统（V2 完整：种子池 + 武器池）
## 每占一郡 +1000 声望；种子池 1000/抽，武器池 5000/抽

## 种子奖池：消耗1000声望，通关后一次性可持续获得
const SEED_POOL := [
	{"id": "corn", "name": "玉米种子", "desc": "关卡内每回合全体回HP 5", "buff": "hp_regen", "value": 5},
	{"id": "potato", "name": "土豆种子", "desc": "下一关开局士气+10", "buff": "morale_start", "value": 10},
	{"id": "sweet_potato", "name": "番薯种子", "desc": "关卡内我方攻击+10%", "buff": "atk_pct", "value": 0.10},
	{"id": "earplug", "name": "静音耳塞", "desc": "原著刘备同款：免疫张飞十四字咆哮的敌我不分，自己人不会被震晕！", "buff": "roar_immune", "value": 1},
]

## 现代降维与沙雕神物奖池：消耗5000声望，抽取原著穿越系统专属神物
const WEAPON_POOL := [
	{"id": "electric_baton", "name": "现代防暴电棍", "desc": "伤害仅10点，但强力高压电击敌将抽搐口吐白沫、强制眩晕1回合！", "buff": "stun_baton", "value": 10},
	{"id": "dongfeng", "name": "东风·微缩版", "desc": "降维大杀器：战术呼叫全图爆炸轰击，范围爆破！", "buff": "full_screen", "value": 1},
	{"id": "megaphone", "name": "高音大喇叭", "desc": "张飞专属扩音神物：燕人咆哮范围翻倍，震穿敌军耳膜！", "buff": "roar_boost", "value": 2},
	{"id": "military_coat", "name": "防寒军大衣", "desc": "皇叔御寒战袍：全军抗击打提升，防御+15，坚韧耐揍！", "buff": "def_gear", "value": 15},
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