class_name SkillsCore
extends RefCounted

const CombatCore := preload("res://scripts/core/combat.gd")
const GridCore := preload("res://scripts/core/grid.gd")
## 技能定义与结算（纯逻辑，返回事件数组）
## 事件格式见架构草图：{type, target, value, ...}，由渲染层消费

## 技能元数据表（V1）
const SKILL_META := {
	"dragon_slash": {
		"name": "蓄力龙斩", "cd": 3, "charge_type": "move",
		"max_charge": 10, "desc": "上下左右定向挥刀，贯穿被击点及后方直线，射程随蓄力暴涨",
	},
	"roar": {
		"name": "断桥怒吼", "cd": 4, "charge_type": "wait",
		"max_charge": 3, "desc": "待机蓄力轮数=威力，满蓄力眩晕",
	},
	"seven_dash": {
		"name": "七进七出", "cd": 3, "charge_type": "none",
		"max_charge": 0, "desc": "穿人多段突刺",
	},
	"hua_rage": {
		"name": "虎牢狂力", "cd": 0, "charge_type": "none",
		"max_charge": 0, "desc": "华雄：每回合ATK+15%",
	},
	"lubu_fangtian": {
		"name": "方天乱舞", "cd": 0, "charge_type": "none",
		"max_charge": 0, "desc": "吕布：第3击翻3倍，越战越狂",
	},
	"wuanguo_power": {
		"name": "三倍巨力", "cd": 0, "charge_type": "none",
		"max_charge": 0, "desc": "武安国：被动三倍力量",
	},
	"arrow_rain": {
		"name": "拐弯箭雨", "cd": 3, "charge_type": "none",
		"max_charge": 0, "desc": "公孙瓒：范围箭雨",
	},
	"naked_armor": {
		"name": "裸衣死战", "cd": 4, "charge_type": "none",
		"max_charge": 0, "desc": "许褚：爆甲减防+吸血+二倍攻速",
	},
}

## 获取技能元数据
static func meta(skill_id: String) -> Dictionary:
	return SKILL_META.get(skill_id, {})

## 是否可蓄力技能
static func can_charge(skill_id: String) -> bool:
	var m: Dictionary = SKILL_META.get(skill_id, {})
	return m.get("charge_type", "none") != "none"

## 结算一次普通攻击
## 返回事件数组（伤害事件）
static func do_attack(caster, target) -> Array:
	var mult: float = 1.0
	# 若关羽骑乘中（合体），攻击力用骑乘者关羽、移动用马赵云 —— 伤害用骑乘者atk
	var attacker_atk: int = caster.effective_atk()
	# 目标防御用骑乘叠加（若目标是合体体，取较高的def）
	var target_def: int = target.effective_def()
	var dmg: int = CombatCore.damage(attacker_atk, mult, target_def)
	target.take_damage(dmg)
	var ev: Array = [CombatCore.make_damage_event(target.id, dmg, false)]
	if not target.alive:
		ev.append({"type": "death", "target": target.id})
	return ev

## 结算【蓄力龙斩】（关羽）：被攻击点及身后贯穿巨龙斩
## 消耗当前蓄力格数，返回事件数组；主目标（被攻击点）承受 100% 满额伤害，被攻击点身后沿线贯穿敌军承受 70% 刀气贯穿伤害
static func do_dragon_slash(caster, target, pierced_targets: Array = []) -> Array:
	var mult: float = CombatCore.dragon_charge_multiplier(caster.charge)
	var full: bool = caster.charge >= 10
	var dmg: int = CombatCore.damage(caster.effective_atk(), mult, target.effective_def())
	target.take_damage(dmg)
	var ev: Array = [
		{"type": "skill", "skill_id": "dragon_slash", "caster": caster.id,
		 "fx": "dragon_full" if full else "dragon", "value": dmg, "target": target.id},
		CombatCore.make_damage_event(target.id, dmg, false),
	]
	if full:
		ev.append({"type": "fx", "fx": "dragon_full_screen", "target": target.id, "shatter_gate": true})
		ev.append({"type": "knockback", "target": target.id, "cells": 2})
	if not target.alive:
		ev.append({"type": "death", "target": target.id})

	# 被攻击点身后直线贯穿沿途波及的敌军
	for pt in pierced_targets:
		if pt != null and pt.alive and pt.id != target.id:
			var p_dmg: int = max(int(round(float(dmg) * 0.70)), 1)
			pt.take_damage(p_dmg)
			ev.append(CombatCore.make_damage_event(pt.id, p_dmg, false))
			if full:
				ev.append({"type": "knockback", "target": pt.id, "cells": 1})
			if not pt.alive:
				ev.append({"type": "death", "target": pt.id})

	# 消耗蓄力、进入冷却
	caster.charge = 0
	caster.start_cd("dragon_slash", meta("dragon_slash").cd)
	return ev

## 结算【断桥怒吼】（张飞）
## 蓄力轮数=威力；满蓄力(3)眩晕目标1回合
static func do_roar(caster, targets: Array) -> Array:
	var mult: float = CombatCore.roar_charge_multiplier(caster.charge)
	var full: bool = caster.charge >= 3
	var ev: Array = []
	for t in targets:
		var dmg: int = CombatCore.damage(caster.effective_atk(), mult, t.effective_def())
		t.take_damage(dmg)
		ev.append(CombatCore.make_damage_event(t.id, dmg, false))
		if not t.alive:
			ev.append({"type": "death", "target": t.id})
	if full:
		for t in targets:
			t.stun_turns = max(t.stun_turns, 1)
			ev.append({"type": "stun", "target": t.id, "turns": 1})
	ev.append({"type": "skill", "skill_id": "roar", "caster": caster.id, "fx": "roar", "full": full})
	caster.charge = 0
	caster.start_cd("roar", meta("roar").cd)
	return ev

## 结算【七进七出】（赵云）
## weaves 次突刺，每次 0.4 倍
static func do_seven_dash(caster, target, weaves: int) -> Array:
	var mult: float = CombatCore.dash_multiplier(weaves)
	var dmg: int = CombatCore.damage(caster.effective_atk(), mult, target.effective_def())
	target.take_damage(dmg)
	var ev: Array = [
		{"type": "skill", "skill_id": "seven_dash", "caster": caster.id, "fx": "dash", "value": dmg, "target": target.id},
		CombatCore.make_damage_event(target.id, dmg, false),
	]
	caster.start_cd("seven_dash", meta("seven_dash").cd)
	if not target.alive:
		ev.append({"type": "death", "target": target.id})
	return ev

## 骑乘合体：关羽骑赵云
## 返回事件；合体后：移动力=赵云MOV，攻击=关羽ATK，蓄力效率×2
static func do_mount(rider, horse) -> Array:
	rider.mount["horse"] = horse.id
	horse.mount["rider"] = rider.id
	return [{"type": "mount", "rider": rider.id, "horse": horse.id}]

## 解除合体
static func do_unmount(a, b) -> Array:
	a.mount.erase("horse")
	b.mount.erase("rider")
	return [{"type": "unmount", "rider": a.id, "horse": b.id}]

## 判断两单位可否合体：关羽骑赵云
static func can_mount(rider, horse) -> bool:
	return rider.id == "guanyu" and horse.id == "zhaoyun" and rider.alive and horse.alive \
		and not rider.is_mounted() and not horse.is_mounted() \
		and GridCore.manhattan(rider.cell, horse.cell) <= 2

## 合体后的移动力：取马（赵云）的MOV
static func mounted_mov(unit, horse) -> int:
	return horse.mov

## 合体后的蓄力效率（关羽骑赵云 = ×2）
static func mounted_charge_efficiency() -> int:
	return 2

## 吕布·方天乱舞攻击：推进连击→第3击翻3倍
## 返回事件数组
static func do_lubu_attack(caster, target) -> Array:
	var atk_mult: float = 1.0
	caster.fangtian_strike()
	if caster.combo_strikes >= 3:
		atk_mult = 3.0  # 第3击翻3倍（effective_atk 已含 _fangtian_multiplier，这里用普通乘也算双保险）
	# 用 effective_atk() 已含连击倍率，这里把基础倍率设1
	var dmg: int = CombatCore.damage(caster.effective_atk(), 1.0, target.effective_def())
	var is_third: bool = caster.combo_strikes >= 3
	target.take_damage(dmg)
	var ev: Array = [
		{"type": "skill", "skill_id": "lubu_fangtian", "caster": caster.id,
		 "fx": "fangtian_third" if is_third else "fangtian", "combo": caster.combo_strikes,
		 "value": dmg, "target": target.id},
		CombatCore.make_damage_event(target.id, dmg, false),
	]
	if not target.alive:
		ev.append({"type": "death", "target": target.id})
	return ev

## 公孙瓒·拐弯箭雨：对以 target 为中心半径2的所有敌军造成范围伤害
static func do_arrow_rain(caster, target, all_units: Array) -> Array:
	var ev: Array = []
	for u in all_units:
		if u.alive and u.camp != caster.camp and GridCore.chebyshev(u.cell, target.cell) <= 2:
			var dmg: int = CombatCore.damage(caster.effective_atk(), 0.7, u.effective_def())
			u.take_damage(dmg)
			ev.append(CombatCore.make_damage_event(u.id, dmg, false))
			if not u.alive:
				ev.append({"type": "death", "target": u.id})
	caster.start_cd("arrow_rain", meta("arrow_rain").cd)
	ev.append({"type": "skill", "skill_id": "arrow_rain", "caster": caster.id, "fx": "arrow_rain"})
	return ev

## 许褚·裸衣死战：激活绝技
## 1) 爆掉周围半径2（方圆）敌军战甲（armor_broken=true）
## 2) 许褚进入吸血状态（lifesteal_active=true）
## 3) 提供双倍攻速（AI 据此每回合攻击两次，由调用方处理）
static func do_naked_armor(caster, all_units: Array) -> Array:
	var ev: Array = []
	var broken: Array = []
	for u in all_units:
		if u.alive and u.camp != caster.camp and GridCore.chebyshev(u.cell, caster.cell) <= 2:
			u.armor_broken = true
			broken.append(u.id)
	caster.lifesteal_active = true
	caster.start_cd("naked_armor", meta("naked_armor").cd)
	ev.append({"type": "skill", "skill_id": "naked_armor", "caster": caster.id,
		"fx": "naked", "broken": broken})
	for id in broken:
		ev.append({"type": "armor_broken", "target": id})
	return ev

## 许褚·裸衣攻击：对目标造成伤害，若吸血状态则恢复等量HP
static func do_naked_strike(caster, target) -> Array:
	var dmg: int = CombatCore.damage(caster.effective_atk(), 1.0, target.effective_def())
	target.take_damage(dmg)
	var ev: Array = [{"type": "skill", "skill_id": "naked_strike", "caster": caster.id,
		"fx": "naked_strike", "value": dmg, "target": target.id},
		CombatCore.make_damage_event(target.id, dmg, false)]
	if caster.lifesteal_active and caster.alive:
		var heal: int = dmg  # 吸血全额
		caster.hp = mini(caster.max_hp, caster.hp + heal)
		ev.append({"type": "heal", "target": caster.id, "value": heal})
	if not target.alive:
		ev.append({"type": "death", "target": target.id})
	return ev

## 结算受击反击（被攻击方且在射程内、未被眩晕、依然存活）
static func do_counter_attack(defender, attacker) -> Array:
	if not defender.alive or defender.is_stunned():
		return []
	var dmg: int = CombatCore.counter_damage(defender.effective_atk(), attacker.effective_def())
	attacker.take_damage(dmg)
	var ev: Array = [
		{"type": "counter", "caster": defender.id, "target": attacker.id, "value": dmg},
		CombatCore.make_damage_event(attacker.id, dmg, false)
	]
	if not attacker.alive:
		ev.append({"type": "death", "target": attacker.id})
	return ev

## 步骑分离时赵云的空投连携突刺
static func do_dismount_strike(zhaoyun, target) -> Array:
	if not zhaoyun.alive or not target.alive:
		return []
	var dmg: int = CombatCore.damage(zhaoyun.effective_atk(), 0.5, target.effective_def())
	target.take_damage(dmg)
	var ev: Array = [
		{"type": "dual_strike", "caster": zhaoyun.id, "target": target.id, "value": dmg},
		CombatCore.make_damage_event(target.id, dmg, false)
	]
	if not target.alive:
		ev.append({"type": "death", "target": target.id})
	return ev

## 传世大黄丹：恢复 100% 生命
static func do_use_dahuangdan(target) -> Array:
	if not target.alive:
		return []
	var heal: int = target.max_hp - target.hp
	target.hp = target.max_hp
	return [
		{"type": "item_use", "item": "dahuangdan", "target": target.id, "value": heal},
		{"type": "heal", "target": target.id, "value": heal}
	]

## 微缩版东风：周围半径2格所有敌军受到 25 点狂风伤害并被震退 1 格
static func do_use_dongfeng(caster, all_units: Array) -> Array:
	var ev: Array = [{"type": "item_use", "item": "dongfeng", "caster": caster.id}]
	for u in all_units:
		if u.alive and u.camp != caster.camp and GridCore.chebyshev(u.cell, caster.cell) <= 2:
			var dmg: int = 25
			u.take_damage(dmg)
			ev.append({"type": "damage", "target": u.id, "value": dmg, "crit": false})
			ev.append({"type": "knockback", "target": u.id, "cells": 1})
			if not u.alive:
				ev.append({"type": "death", "target": u.id})
	return ev

