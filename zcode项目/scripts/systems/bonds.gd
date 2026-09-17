class_name BondsCore
extends RefCounted
## 将缘（武将羁绊）系统 —— 纯逻辑，可无头测试
##
## 设计原则（未做成"对话好感度条"）：
##   1. 只做战场上"看得见的效果"：士气 / 回复 / 攻防 / 机动
##   2. 不做数值膨胀，不做刷好感度的重复劳动
##   3. 素材取自原著里的现成关系（桃园结义、白马义从、关羽骑赵云）
##
## "骑赵云"（关羽 + 赵云合体）的战斗机制早已在 battle.gd 里实现，
## 这里只把它显性化：让玩家知道"这算一条将缘"，而不是隐藏彩蛋。

const BONDS := [
	{
		"id": "taoyuan",
		"name": "桃园结义",
		"members": ["liubei", "guanyu", "zhangfei"],
		"desc": "刘关张同在阵中：开局士气 +10，且每回合全体回复 5 HP",
		"tag": "回复",
	},
	{
		"id": "baima",
		"name": "白马义从",
		"members": ["gongsunzan", "liubei"],
		"desc": "公孙瓒与刘备同阵：公孙瓒攻击 +15%（白马义从骑射战法）",
		"tag": "增益",
	},
	{
		"id": "qiji",
		"name": "云长为马",
		"members": ["guanyu", "zhaoyun"],
		"desc": "关羽可与赵云【合体】：继承极速并打出 1.5 倍双人合击（原著名场面）",
		"tag": "绝技",
	},
]


## 返回当前阵容已激活的将缘列表
static func active_bonds(unit_ids: Array) -> Array:
	var out: Array = []
	for b in BONDS:
		var ok := true
		for m in b["members"]:
			if not unit_ids.has(m):
				ok = false
				break
		if ok:
			out.append(b)
	return out


static func has_bond(unit_ids: Array, bond_id: String) -> bool:
	for b in active_bonds(unit_ids):
		if b["id"] == bond_id:
			return true
	return false


## 桃园结义：开局士气加成
static func taoyuan_morale_bonus(unit_ids: Array) -> int:
	return 10 if has_bond(unit_ids, "taoyuan") else 0


## 桃园结义：每回合全体回复
static func taoyuan_regen(unit_ids: Array) -> int:
	return 5 if has_bond(unit_ids, "taoyuan") else 0


## 白马义从：公孙瓒攻击加成倍率
static func baima_atk_mult(unit_ids: Array) -> float:
	return 1.15 if has_bond(unit_ids, "baima") else 1.0


## 面板展示用的一行摘要
static func summary_line(unit_ids: Array) -> String:
	var act := active_bonds(unit_ids)
	if act.is_empty():
		return "将缘：暂无（凑齐原著组合可激活）"
	var parts: Array[String] = []
	for b in act:
		parts.append("【%s】%s" % [b["name"], b["desc"]])
	return "将缘：" + "\n　　　".join(parts)
