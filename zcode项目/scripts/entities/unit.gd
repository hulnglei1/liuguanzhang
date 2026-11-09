class_name BattleUnit
extends RefCounted

const CombatCore := preload("res://scripts/core/combat.gd")
## 战斗单位实体：由 data/units.json 数据 + 战场运行时状态组成（纯逻辑，可序列化）

var id: String
var name: String
var cls: String
var camp: String          # "player" | "enemy"
var max_hp: int
var hp: int
var base_atk: int
var base_def: int
var mov: int
var rng: int
var skill_ids: Array = []
var is_commander: bool
var cell: Vector2i        # 当前格

# 战场运行时状态
var acted: bool = false
var charge: int = 0          # 蓄力值（关羽:格数 / 张飞:轮数）
var max_charge: int = 0      # 蓄力上限
var cds: Dictionary = {}     # skill_id -> 剩余冷却
var stun_turns: int = 0      # 眩晕剩余回合
var zhaoyun_guard_used: bool = false   # 【常山铁壁】本回合首次减伤是否已用
var alive: bool = true
var hua_kills: int = 0       # 华雄已斩杀的我方单位数（虎牢狂力层数）
var combo_strikes: int = 0   # 吕布方天乱舞连击计数（第3击翻3倍）
var rage_multiplier: float = 1.0  # 吕布多打少暴怒加成（每死1我方×1.5）
var armor_broken: bool = false  # 许褚裸衣爆甲：敌DEF减半
var lifesteal_active: bool = false  # 许褚裸衣吸血
var on_hill: bool = false      # 臧霸占山为王：是否在高地
var coward_debuff: bool = false  # 昌豨怯战：受击后DEF降低
var morale_bonus: float = 1.0  # 士气修正倍率
var iron_skin: bool = false      # 吕布两息铁皮无敌：免疫一切伤害
var iron_skin_turns: int = 0     # 铁皮剩余回合数
var zhaoyun_strike_count: int = 0 # 赵云普攻计数（每2次追加戳刺）
var gate_broken_debuff: bool = false # 汜水关破门：敌DEF-20%
var exhausted: bool = false      # 挥舞重锤脱力力竭：DEF-30%
var exhausted_turns: int = 0     # 脱力剩余回合数（挥锤=1；被吕布打飞这类重伤=多回合）
var is_protect_target: bool = false # 战场需誓死护卫的核心目标（阵亡直接判负）

# ===== 装备/词条全局加成（P0-1 修复：让抽奖真正生效）=====
var gear_atk: int = 0      # 兵种/武器加攻
var gear_def: int = 0      # 金刚护腕等加防
var gear_hp: int = 0       # 古兽护符加生命
var atk_pct_bonus: float = 1.0  # 番薯种子攻+10%
var hp_regen: int = 0      # 玉米种子每回合回血
var refuse_penalty: float = 1.0 # 不应战惩罚倍率（敌×2）
var mount: Dictionary = {}   # {rider: id, horse: id} 合体状态
var moved_this_turn: bool = false    # 本回合是否已移动过（单位级状态，防止重复移动）
var dragon_guard_used: bool = false  # 关羽骑赵云时「赵云硬扛」——每关免一次蓄力清零

## 从 data/units.json 的字典构造
static func from_data(d: Dictionary, spawn: Vector2i):
	var u: RefCounted = new()
	u.id = d.id
	u.name = d.name
	u.cls = d.cls
	u.camp = d.camp
	u.max_hp = d.get("max_hp", d.hp)
	u.hp = d.hp
	u.base_atk = d.atk
	u.base_def = d.def
	u.mov = d.mov
	u.rng = d.rng
	u.skill_ids = (d.skills as Array).duplicate()
	u.is_commander = d.get("is_commander", false)
	# 华雄开局就带着"斩将"层数（原著：前面几个送菜的把绝技养起来了）
	u.hua_kills = int(d.get("hua_kills", 0))
	u.is_protect_target = d.get("is_protect_target", false)
	u.cell = spawn
	return u

## 应用装备加成血量（gear_hp），初始满血
func apply_hp_gear() -> void:
	max_hp += gear_hp
	hp = max_hp

## 当前实际 ATK（含士气修正、华雄叠层、不应战惩罚）
func effective_atk() -> int:
	var v: float = (float(base_atk) + float(gear_atk)) * morale_bonus * atk_pct_bonus
	if "hua_rage" in skill_ids:
		v *= CombatCore.hua_boost_multiplier(hua_kills)
	if "lubu_fangtian" in skill_ids:
		v *= _fangtian_multiplier()
		v *= rage_multiplier
	if "wuanguo_power" in skill_ids:
		v *= 1.5  # 武安国·重锤巨力（平准化为 1.5 倍，健康爆发力，不喧宾夺主）
	if "king_hill" in skill_ids and on_hill:
		v *= 1.3  # 臧霸占山为王：高地ATK+30%
	if camp == "enemy":
		v *= refuse_penalty
	return int(round(v))

## 吕布·方天乱舞：连击倍率（第3击翻3倍，1/2击×1）
func _fangtian_multiplier() -> float:
	if combo_strikes >= 3:
		return 3.0
	return 1.0

## 当前实际 DEF（含士气修正；裸衣爆甲/昌豨怯战时降低，臧霸高地时提升，城门崩塌时降低，脱力时降低）
func effective_def() -> int:
	var v: float = (float(base_def) + float(gear_def)) * morale_bonus
	if armor_broken:
		v *= 0.5
	if gate_broken_debuff:
		v *= 0.8
	if "king_hill" in skill_ids and on_hill:
		v *= 1.3
	if coward_debuff:
		v *= 0.7
	if exhausted:
		v *= 0.7  # 挥舞沉重铁锤脱力力竭：DEF-30%
	return int(round(v))

## 是否被眩晕
func is_stunned() -> bool:
	return stun_turns > 0

## 是否在合体中（骑乘或被骑）
func is_mounted() -> bool:
	return mount.has("rider") or mount.has("horse")

## 实际移动力：若骑乘赵云，继承6格移动力
func effective_mov() -> int:
	if is_mounted() and mount.has("horse"):
		return 6
	return mov

## 技能是否就绪（无冷却且未眩晕）
func skill_ready(skill_id: String) -> bool:
	if is_stunned():
		return false
	return cds.get(skill_id, 0) <= 0

## 开始冷却
func start_cd(skill_id: String, cd: int) -> void:
	cds[skill_id] = cd

## 回合结束：冷却-1、眩晕-1、华雄叠层+1、脱力恢复
func end_turn() -> void:
	zhaoyun_guard_used = false    # 新回合：常山铁壁恢复
	for k in cds.keys():
		if cds[k] > 0:
			cds[k] -= 1
	if stun_turns > 0:
		stun_turns -= 1
	# 注意：**这里不再每回合叠层**。
	# 原著里华雄的力量是"斩杀敌将"才涨的（「华雄要连斩3名大将，才能达到6倍力量」），
	# 每回合自动叠会让玩家还没交手就看到倍率乱涨。
	if exhausted_turns > 0:
		exhausted_turns -= 1
	exhausted = exhausted_turns > 0
	# 注意：吕布连击跨回合累积（end_turn 不清零），只有被打晕(fangtian_reset)才打断

## 施加脱力。取较长者（不叠加）：挥锤=1 回合；被吕布打飞这类重伤=数回合
func set_exhausted(turns: int) -> void:
	exhausted_turns = maxi(exhausted_turns, turns)
	exhausted = exhausted_turns > 0

## 吕布出击：推进连击计数（供敌方AI调用）
func fangtian_strike() -> void:
	combo_strikes += 1

## 吕布被眩晕/打断：重置连击并破除铁皮无敌
func fangtian_reset() -> void:
	combo_strikes = 0
	iron_skin = false
	iron_skin_turns = 0

## 多打少暴怒：我方每死一个，吕布ATK×1.5（叠乘）
func add_rage() -> void:
	rage_multiplier *= 1.5

## 受击：处于铁皮状态时免除一切伤害
## 扣血。返回**实际扣掉的量**（格挡/减伤后），供事件与飘字使用。
func take_damage(dmg: int) -> int:
	if iron_skin:
		return 0
	var applied := dmg
	# 【常山铁壁】赵云每回合第一次受击减伤 30%。
	# 原著里赵云的底子是"无限耐力、冲阵不死"，减伤比加攻更贴人设，
	# 也让他敢单独钻进敌后（他没有攻击性绝技，全靠基础盘）。
	if id == "zhaoyun" and not zhaoyun_guard_used and dmg > 0:
		applied = maxi(1, int(round(float(dmg) * 0.7)))
		zhaoyun_guard_used = true
	hp -= applied
	if hp <= 0:
		hp = 0
		alive = false
	return applied

## 按百分比自愈生命（返回实际恢复量）
func heal_percent(pct: float) -> int:
	var amt: int = int(round(float(max_hp) * pct))
	amt = mini(amt, max_hp - hp)
	if amt > 0:
		hp += amt
	return amt

## 序列化（存档用）
func to_dict() -> Dictionary:
	return {
		"id": id, "name": name, "cls": cls, "camp": camp,
		"max_hp": max_hp, "hp": hp, "atk": base_atk, "def": base_def,
		"mov": mov, "rng": rng, "skill_ids": skill_ids.duplicate(),
		"is_commander": is_commander,
		"cell": [cell.x, cell.y],
		"acted": acted, "charge": charge, "max_charge": max_charge,
		"cds": cds.duplicate(), "stun_turns": stun_turns,
		"alive": alive, "hua_kills": hua_kills,
		"morale_bonus": morale_bonus, "refuse_penalty": refuse_penalty,
		"mount": mount.duplicate(),
		"iron_skin": iron_skin, "zhaoyun_strike_count": zhaoyun_strike_count,
		"gate_broken_debuff": gate_broken_debuff, "exhausted": exhausted,
		"exhausted_turns": exhausted_turns,
	}

## 是否为骑兵系（十字4向攻击，不可斜打）
func is_cavalry() -> bool:
	if id in ["guanyu", "zhangfei", "zhaoyun", "huaxiong", "lubu", "changxi", "li_bu_fu_1", "li_bu_fu_2"]:
		return true
	if "骑" in cls or cls == "枪兵":
		return true
	return false

## 是否为弓兵/远程
func is_archer() -> bool:
	return rng >= 2 or "弓" in cls

## 获取攻击形状名称与说明
func get_attack_shape_desc() -> String:
	if is_archer():
		return "远程 %d 格" % rng
	elif is_cavalry():
		return "十字 4 向 (不可斜打)"
	else:
		return "九宫 8 向 (可斜打)"
