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
var alive: bool = true
var hua_rage_turns: int = 0  # 华雄叠层回合计数（虎牢狂力）
var combo_strikes: int = 0   # 吕布方天乱舞连击计数（第3击翻3倍）
var rage_multiplier: float = 1.0  # 吕布多打少暴怒加成（每死1我方×1.5）
var armor_broken: bool = false  # 许褚裸衣爆甲：敌DEF减半
var lifesteal_active: bool = false  # 许褚裸衣吸血
var on_hill: bool = false      # 臧霸占山为王：是否在高地
var coward_debuff: bool = false  # 昌豨怯战：受击后DEF降低
var morale_bonus: float = 1.0  # 士气修正倍率

# ===== 装备/词条全局加成（P0-1 修复：让抽奖真正生效）=====
var gear_atk: int = 0      # 兵种/武器加攻
var gear_def: int = 0      # 金刚护腕等加防
var gear_hp: int = 0       # 古兽护符加生命
var atk_pct_bonus: float = 1.0  # 番薯种子攻+10%
var hp_regen: int = 0      # 玉米种子每回合回血
var refuse_penalty: float = 1.0 # 不应战惩罚倍率（敌×2）
var mount: Dictionary = {}   # {rider: id, horse: id} 合体状态

## 从 data/units.json 的字典构造
static func from_data(d: Dictionary, spawn: Vector2i):
	var u: RefCounted = new()
	u.id = d.id
	u.name = d.name
	u.cls = d.cls
	u.camp = d.camp
	u.max_hp = d.hp
	u.hp = d.hp
	u.base_atk = d.atk
	u.base_def = d.def
	u.mov = d.mov
	u.rng = d.rng
	u.skill_ids = (d.skills as Array).duplicate()
	u.is_commander = d.get("is_commander", false)
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
		v *= CombatCore.hua_boost_multiplier(hua_rage_turns)
	if "lubu_fangtian" in skill_ids:
		v *= _fangtian_multiplier()
		v *= rage_multiplier
	if "wuanguo_power" in skill_ids:
		v *= 3.0  # 武安国·三倍巨力（P0-2 修复：原被动是死的）
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

## 当前实际 DEF（含士气修正；裸衣爆甲/昌豨怯战时降低，臧霸高地时提升）
func effective_def() -> int:
	var v: float = (float(base_def) + float(gear_def)) * morale_bonus
	if armor_broken:
		v *= 0.5
	if "king_hill" in skill_ids and on_hill:
		v *= 1.3
	if coward_debuff:
		v *= 0.7
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

## 回合结束：冷却-1、眩晕-1、华雄叠层+1
func end_turn() -> void:
	for k in cds.keys():
		if cds[k] > 0:
			cds[k] -= 1
	if stun_turns > 0:
		stun_turns -= 1
	if "hua_rage" in skill_ids and alive:
		hua_rage_turns += 1
	# 注意：吕布连击跨回合累积（end_turn 不清零），只有被打晕(fangtian_reset)才打断

## 吕布出击：推进连击计数（供敌方AI调用）
func fangtian_strike() -> void:
	combo_strikes += 1

## 吕布被眩晕/打断：重置连击
func fangtian_reset() -> void:
	combo_strikes = 0

## 多打少暴怒：我方每死一个，吕布ATK×1.5（叠乘）
func add_rage() -> void:
	rage_multiplier *= 1.5

## 受击
func take_damage(dmg: int) -> void:
	hp -= dmg
	if hp <= 0:
		hp = 0
		alive = false

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
		"alive": alive, "hua_rage_turns": hua_rage_turns,
		"morale_bonus": morale_bonus, "refuse_penalty": refuse_penalty,
		"mount": mount.duplicate(),
	}
