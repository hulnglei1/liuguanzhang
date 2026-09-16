class_name TurnCore
extends RefCounted
## 回合状态机：PLAYER → ENEMY → PLAYER（纯逻辑）

enum Phase { PLAYER, ENEMY, END }

## 回合状态（可序列化存档）
static func new_state() -> Dictionary:
	return {
		"phase": Phase.PLAYER,
		"turn": 1,            # 当前第几回合（从1起）
		"acted_ids": [],      # 本回合已行动单位 id
	}

static func phase_name(p: int) -> String:
	match p:
		Phase.PLAYER: return "我方回合"
		Phase.ENEMY: return "敌方回合"
		Phase.END: return "结束"
	return "?"

## 标记某单位已行动
static func mark_acted(state: Dictionary, unit_id: String) -> void:
	if unit_id not in state.acted_ids:
		state.acted_ids.append(unit_id)

## 判断当前存活单位是否全部行动完（供"结束回合"判断）
static func all_acted(state: Dictionary, alive_ids: Array) -> bool:
	for id in alive_ids:
		if id not in state.acted_ids:
			return false
	return true

## 切换到敌方回合
static func to_enemy(state: Dictionary) -> void:
	state.phase = Phase.ENEMY
	state.acted_ids = []

## 切换到我方回合（回合数+1）
static func to_player(state: Dictionary) -> void:
	state.phase = Phase.PLAYER
	state.turn += 1
	state.acted_ids = []

## 战斗结束判定：我方全灭 或 敌方主将死亡
static func check_end(player_alive: Array, enemy_commander_dead: bool) -> int:
	if player_alive.size() == 0:
		return Phase.END  # 战败
	if enemy_commander_dead:
		return Phase.END  # 胜利
	return -1  # 未结束
