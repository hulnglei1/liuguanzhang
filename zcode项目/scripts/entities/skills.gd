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
		"name": "燕人战吼", "cd": 3, "charge_type": "none",
		"max_charge": 0, "desc": "张飞：开局即吼，无需蓄力！范围音波震晕1回合（冷却3回合）",
	},
	"seven_dash": {
		"name": "七进七出", "cd": 3, "charge_type": "none",
		"max_charge": 0, "desc": "穿人多段突刺",
	},
	"hua_rage": {
		"name": "虎牢狂力", "cd": 0, "charge_type": "none",
		"max_charge": 0, "desc": "华雄：每斩一将力量+20%（他上场前已斩3将，开局×1.6）",
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
		"name": "回旋飞弹", "cd": 0, "charge_type": "none",
		"max_charge": 0,
		"desc": "公孙瓒：一次连射 2 支慢速跟踪箭（每回合只推进 1 格、会拐弯）。"
			+ "原著里他能把天上射满箭、从任何方向绕过来命中——慢，但躲不掉。",
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
	# 若关羽骑乘赵云（合体），打出双子合击（关羽刀劈 + 赵云长枪，造成 1.5 倍伤害）
	if caster.is_mounted():
		mult = 1.5
	var attacker_atk: int = caster.effective_atk()
	var target_def: int = target.effective_def()
	var dmg: int = CombatCore.damage(attacker_atk, mult, target_def)
	if target.iron_skin:
		dmg = 0
	# 格挡：只有目标防御 ≥ 攻击时才可能（打杂兵不触发，打高防主将才出现）
	var blocked := false
	if dmg > 0 and randf() < CombatCore.block_chance(attacker_atk, target_def):
		dmg = CombatCore.apply_block(dmg)
		blocked = true
	var applied: int = target.take_damage(dmg)
	var ev: Array = [CombatCore.make_damage_event(target.id, applied, false)]
	if blocked:
		ev.append({"type": "blocked", "target": target.id, "by": caster.id})
	if target.iron_skin:
		ev.append({"type": "iron_skin_block", "target": target.id})
	# 武安国铁锤猛击后脱力（1 回合）
	if "wuanguo_power" in caster.skill_ids:
		caster.set_exhausted(1)
		ev.append({"type": "exhausted", "target": caster.id})
	if not target.alive:
		ev.append({"type": "death", "target": target.id})
	return ev

## 结算【蓄力龙斩】（关羽）：被攻击点及身后贯穿巨龙斩
## 消耗当前蓄力格数，返回事件数组；主目标（被攻击点）承受 100% 满额伤害，被攻击点身后沿线贯穿敌军承受 70% 刀气贯穿伤害
static func do_dragon_slash(caster, target, pierced_targets: Array = []) -> Array:
	var mult: float = CombatCore.dragon_charge_multiplier(caster.charge)
	var tier: int = int(CombatCore.dragon_charge_tier(caster.charge).get("tier", 0))
	var full: bool = tier >= 4      # 10 格以上（劈山裂城 / 裂地千里）都算满档演出
	var dmg: int = CombatCore.damage(caster.effective_atk(), mult, target.effective_def())
	target.take_damage(dmg)
	var ev: Array = [
		{"type": "skill", "skill_id": "dragon_slash", "caster": caster.id,
		 "fx": "dragon_full" if full else "dragon", "value": dmg, "target": target.id},
		CombatCore.make_damage_event(target.id, dmg, false),
	]
	if full:
		# 注：破城门不再靠"打主将附带"，而是由玩家把青龙斩对准城门格触发（battle.gd 的劈门分支）
		ev.append({"type": "fx", "fx": "dragon_full_screen", "target": target.id, "shatter_gate": false})
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

## 结算【燕人战吼】（张飞）
## 原著小说设定：无需蓄力，开局即可吼，纯CD机制！震得敌军失聪目眩（100%眩晕1回合，且震散吕布方天连击与破除铁皮无敌）
static func do_roar(caster, targets: Array, words: int = 6, allies_in_range: Array = []) -> Array:
	# 原著：咆哮的字数越多，威力越大
	#   六字「燕人张飞在此」      -> 1.6x，眩晕 1 回合
	#   十四字「…谁敢与我决一死战」-> 2.4x，眩晕 2 回合，且敌我不分（自己人也晕）
	var w: int = clampi(words, 6, 14)
	# 咆哮是**控制技**，不是输出技（玩家反馈"攻击力应该不高，只是控制比较厉害"）：
	#   六字   0.64x → 主要价值：眩晕 1 回合
	#   十四字 0.96x → 主要价值：眩晕 2 回合 + 震碎吕布铁皮 + 清空方天连击
	# 杀伤刻意压得比普攻低，靠控制与破防吃饭。
	var mult: float = 0.4 + 0.04 * float(w)
	var stun_turns: int = 2 if w >= 14 else 1
	var ev: Array = []
	for t in targets:
		var had_iron_skin: bool = t.iron_skin
		var dmg: int = CombatCore.damage(caster.effective_atk(), mult, t.effective_def())
		t.take_damage(dmg)
		ev.append(CombatCore.make_damage_event(t.id, dmg, false))
		t.stun_turns = max(t.stun_turns, stun_turns)
		ev.append({"type": "stun", "target": t.id, "turns": stun_turns})
		if t.id == "lubu" or "lubu_fangtian" in t.skill_ids:
			t.fangtian_reset()
			if had_iron_skin:
				ev.append({"type": "iron_skin_break", "target": t.id})
		if not t.alive:
			ev.append({"type": "death", "target": t.id})
	# 十四字满控声浪太大，己方也遭殃（原著「群控，敌我不分」）——只晕不伤，戴耳塞者免疫
	for a in allies_in_range:
		a.stun_turns = max(a.stun_turns, 1)
		ev.append({"type": "stun", "target": a.id, "turns": 1, "friendly_fire": true})
	ev.append({"type": "skill", "skill_id": "roar", "caster": caster.id, "fx": "roar", "full": true, "words": w})
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

## 合体后的蓄力效率（原著平衡调整：关羽骑赵云 = 1，移除2倍翻倍）
static func mounted_charge_efficiency() -> int:
	return 1

## 吕布·方天乱舞攻击：推进连击→第3击翻3倍并激活两息铁皮无敌
## 返回事件数组
static func do_lubu_attack(caster, target) -> Array:
	var atk_mult: float = 1.0
	caster.fangtian_strike()
	var is_third: bool = caster.combo_strikes >= 3
	if is_third:
		atk_mult = 3.0
	# 用 effective_atk() 已含连击倍率
	var dmg: int = CombatCore.damage(caster.effective_atk(), 1.0, target.effective_def())
	target.take_damage(dmg)
	var ev: Array = [
		{"type": "skill", "skill_id": "lubu_fangtian", "caster": caster.id,
		 "fx": "fangtian_third" if is_third else "fangtian", "combo": caster.combo_strikes,
		 "value": dmg, "target": target.id},
		CombatCore.make_damage_event(target.id, dmg, is_third),
	]
	if is_third:
		caster.iron_skin = true
		caster.iron_skin_turns = 1
		caster.combo_strikes = 0  # 第3击打完重置
		ev.append({"type": "iron_skin", "target": caster.id})
	if not target.alive:
		ev.append({"type": "death", "target": target.id})
	return ev

## 公孙瓒·回旋飞弹：发射定速追踪飞弹（每回合推进 3 格，全图索敌，CD=0）
## 一次施放连射 2 支（原著"连射数箭、犹如人形防空炮"）。
## 速度 1 格/回合 —— "唯一的缺点就是箭矢速度偏慢"，慢才有天空中攒箭的观感。
static func do_arrow_rain(caster, target, all_units: Array = []) -> Array:
	var dist: int = GridCore.chebyshev(caster.cell, target.cell)
	caster.start_cd("arrow_rain", meta("arrow_rain").cd)
	
	# 贴身（相邻 1 格）才当回合直达命中；
	# 其余距离一律射出飞弹飞过去 —— 否则玩家在全图范围内点选，
	# 3 格内的目标"瞬间命中"，看起来就像箭根本没射出去（玩家实测反馈的问题）
	if dist <= 1:
		var dmg: int = CombatCore.damage(caster.effective_atk(), 1.0, target.effective_def())
		target.take_damage(dmg)
		var ev: Array = [
			{"type": "skill", "skill_id": "arrow_rain", "caster": caster.id, "fx": "arrow_hit", "value": dmg, "target": target.id},
			CombatCore.make_damage_event(target.id, dmg, false)
		]
		if not target.alive:
			ev.append({"type": "death", "target": target.id})
		return ev
	
	# 一次只射 1 支：两支从同一格同速同向出发会完全重叠，看起来就是一支。
	# "多箭"靠的是 CD 0 + 每回合补射，在天上慢慢累积。
	return [{
		"type": "skill", "skill_id": "arrow_rain", "caster": caster.id,
		"fx": "fire_homing_arrow",
		"arrow": {
			"id": "arrow_%d" % [randi() % 100000 + 1],
			"caster_id": caster.id,
			"target_id": target.id,
			"cell": caster.cell,
			"target_cell": target.cell,
			"speed": 1,              # 每回合 1 格：慢，才看得见拐弯
			"mult": 0.85,            # 单支接近普攻（不再靠一次两支堆伤害）
			"phase": "approach",     # approach = 绕向目标身后；strike = 折返命中
			"waypoint": Vector2i(-1, -1),   # 首次推进时按地图边界算出来
			"atk": caster.effective_atk()
		},
		"target": target.id
	}]

## 更新战场上所有正在飞行追击的飞弹（每回合推进 3 格）
## 返回本轮产生的事件（包括飞弹移动、命中伤害、目标死亡等）
static func advance_homing_arrows(active_arrows: Array, all_units: Array, map_w: int = 12, map_h: int = 10) -> Array:
	var events: Array = []
	var finished_indices: Array = []
	
	for i in range(active_arrows.size()):
		var arr: Dictionary = active_arrows[i]
		var target = null
		for u in all_units:
			if u.id == arr.get("target_id", ""):
				target = u
				break
		
		# 若目标已死亡或消失，飞弹失去目标自然消散
		if target == null or not target.alive:
			events.append({"type": "arrow_lost", "arrow_id": arr.get("id")})
			finished_indices.append(i)
			continue
		
		var cur_pos: Vector2i = arr.get("cell", Vector2i(0, 0))
		var target_pos: Vector2i = target.cell
		var speed: int = int(arr.get("speed", 1))

		# ---- 绕后航点：目标身后 2 格（沿"我→目标"方向再往前）----
		# 箭先飞过目标，再折回来打 —— 原著「箭雨绕了个弯」「从他身后擦过肩膀」
		var phase := str(arr.get("phase", "approach"))
		var wp: Vector2i = arr.get("waypoint", Vector2i(-1, -1))
		if phase == "approach" and wp == Vector2i(-1, -1):
			var d: Vector2i = (target_pos - cur_pos).sign()
			if d == Vector2i.ZERO:
				d = Vector2i(1, 0)
			# 绕行航点必须**侧向偏出**：落在"目标正后方"时与目标在同一直线上，
			# 箭会从目标身上穿过去再折回来（实机反馈"穿过华雄还在飞"）。
			# 取"侧向 2 格 + 前出 1 格"，走一条弧线绕到侧后方。
			var perp := Vector2i(-d.y, d.x)
			wp = target_pos + perp * 2 + d
			if wp.x < 0 or wp.x >= map_w or wp.y < 0 or wp.y >= map_h:
				wp = target_pos - perp * 2 + d       # 侧向出界就换另一侧
				wp.x = clampi(wp.x, 0, map_w - 1)
				wp.y = clampi(wp.y, 0, map_h - 1)
			arr["waypoint"] = wp
			wp = arr["waypoint"]

		# 绕后阶段走到位 → 转为折返
		if phase == "approach" and GridCore.chebyshev(cur_pos, wp) <= speed:
			arr["phase"] = "strike"
			phase = "strike"

		var aim_pos: Vector2i = wp if phase == "approach" else target_pos
		var dist: int = GridCore.chebyshev(cur_pos, aim_pos)

		# 折返阶段贴近目标才命中（绕后阶段即使擦过目标也不算命中）
		if phase == "strike" and GridCore.chebyshev(cur_pos, target_pos) <= speed:
			var dmg: int = CombatCore.damage(arr.get("atk", 20), float(arr.get("mult", 1.0)), target.effective_def())
			target.take_damage(dmg)
			events.append({
				"type": "arrow_hit", "arrow_id": arr.get("id"),
				"target": target.id, "value": dmg, "hit_cell": target.cell
			})
			events.append(CombatCore.make_damage_event(target.id, dmg, false))
			if not target.alive:
				events.append({"type": "death", "target": target.id})
			finished_indices.append(i)
		else:
			# 尚未追上：向目标方向逼近 speed 格
			var new_cell := cur_pos
			for s in range(speed):
				var step_diff: Vector2i = aim_pos - new_cell
				if step_diff == Vector2i.ZERO:
					break
				var step_dir := Vector2i(clampi(step_diff.x, -1, 1), clampi(step_diff.y, -1, 1))
				new_cell += step_dir
			arr["cell"] = new_cell
			events.append({
				"type": "arrow_fly", "arrow_id": arr.get("id"),
				"from_cell": cur_pos, "to_cell": new_cell, "target": target.id
			})
			
	# 从后向前移除已命中或消散的飞弹
	finished_indices.reverse()
	for idx in finished_indices:
		active_arrows.remove_at(idx)
		
	return events

## 许褚·裸衣死战：激活绝技
## 1) 爆掉周围半径2（方圆）敌军战甲（armor_broken=true）
## 2) 许褚自身战甲同样震碎爆飞（caster.armor_broken=true），只剩大红裤衩！
## 3) 许褚进入狂暴吸血状态（lifesteal_active=true）与双倍攻速
static func do_naked_armor(caster, all_units: Array) -> Array:
	var ev: Array = []
	var broken: Array = []
	for u in all_units:
		if u.alive and u.camp != caster.camp and GridCore.chebyshev(u.cell, caster.cell) <= 2:
			u.armor_broken = true
			broken.append(u.id)
	# 还原原著：许褚自己也爆衣赤膊只剩红裤衩，防御同样减半！
	caster.armor_broken = true
	broken.append(caster.id)
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

