class_name MoraleCore
extends RefCounted

const CombatCore := preload("res://scripts/core/combat.gd")
## 士气系统：阵前挑战（单挑）+ 不应战惩罚（纯逻辑）

## 发起阵前挑战（我方武将 vs 敌方主将）
## 返回 { accepted: bool, events: [...], morale_delta_player, morale_delta_enemy }
static func challenge(challenger, defender, refuse_accept_prob: float = 1.0) -> Dictionary:
	var result := {
		"accepted": true,
		"events": [],
		"morale_delta_player": 0,
		"morale_delta_enemy": 0,
	}
	# 华雄 100% 应战（剧情需要）；后续关可按概率
	var accepted: bool = true
	if accepted:
		result.accepted = true
		result.events.append({"type": "challenge", "challenger": challenger.id, "defender": defender.id, "result": "accepted"})
	else:
		# 不应战：敌军全员 ATK×2（由战斗层对 enemy 单位施加 refuse_penalty）
		result.accepted = false
		result.morale_delta_enemy = -10
		result.events.append({"type": "challenge", "challenger": challenger.id, "defender": defender.id, "result": "refused"})
	return result

## 单挑简化结算：三回合小战斗
## 双方对拼3轮，累积伤害；返回 { winner: "challenger"|"defender"|"draw", events, damage }
static func duel(challenger, defender) -> Dictionary:
	var c_dmg: int = 0
	var d_dmg: int = 0
	for i in range(3):
		c_dmg += CombatCore.damage(challenger.effective_atk(), 1.0, defender.effective_def())
		d_dmg += CombatCore.damage(defender.effective_atk(), 1.0, challenger.effective_def())
	var events: Array = [{"type": "duel", "challenger": challenger.id, "defender": defender.id,
		"c_dmg": c_dmg, "d_dmg": d_dmg}]
	var winner: String = "draw"
	if c_dmg > d_dmg:
		winner = "challenger"
	elif d_dmg > c_dmg:
		winner = "defender"
	events.append({"type": "duel_result", "winner": winner})
	return {"winner": winner, "events": events, "challenger_damage": c_dmg, "defender_damage": d_dmg}

## 士气修正应用到单位
## 士气>70 全属性+10%；<30 −10%（对 camp 阵营生效）
static func apply_morale(units: Array, morale: int) -> void:
	var mult: float = CombatCore.morale_multiplier(morale)
	for u in units:
		u.morale_bonus = mult

## 不应战惩罚：对敌营全体 ×2
static func apply_refuse_penalty(enemy_units: Array) -> void:
	for u in enemy_units:
		u.refuse_penalty = CombatCore.MORALE_REFUSE_MULT
