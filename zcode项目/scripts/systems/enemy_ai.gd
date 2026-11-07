class_name EnemyAI
extends RefCounted
## 敌方 AI 的**决策层**（纯逻辑，不碰场景节点）。
##
## 拆分理由：battle.gd 里原本"决定做什么"和"执行动作（移动/攻击动画/等待）"
## 混在一起，导致每一关调 AI 都要翻 70 行异步流程。
## 现在这里只回答三个问题——打谁、怎么打、要不要撤；
## 真正的执行（走位、动画、await）留在 battle.gd。
##
## 这样调 AI 可以在无头模式下直接测，不用跑整场战斗。

const GridCore := preload("res://scripts/core/grid.gd")


## 选目标：关羽蓄力越高越"拉仇恨"（原著里李儒专门派人拦路打断他的蓄力）
##   charge ≥ 10：关羽 10 格内的敌军扑向他
##   charge ≥ 5 ：关羽 6 格内的敌军才会被吸引过去
## 远处敌人不跨越全图来凑热闹——那样反而假，玩家也不服气。
## 这就是「嘲讽」：不需要额外的技能按钮，蓄力本身就是最大的挑衅。
static func pick_target(u, guanyu, nearest_player: Callable) -> Object:
	if guanyu != null and guanyu.alive and int(guanyu.charge) >= 5:
		var pull_range: int = 10 if int(guanyu.charge) >= 10 else 6
		if GridCore.manhattan(u.cell, guanyu.cell) <= pull_range:
			return guanyu
	return nearest_player.call(u)


## 这一回合怎么打：返回 "kite_approach" / "kite_back" / "attack" / "approach"
##   kite_approach：弓兵离太远 → 往前靠
##   kite_back    ：弓兵被贴脸 → 后撤
##   attack       ：已经在射程内 → 直接打
##   approach     ：够不着 → 走过去
static func attack_intent(u, target) -> String:
	if target == null:
		return "none"
	if u.cls == "弓兵":
		var dist: int = GridCore.chebyshev(u.cell, target.cell)
		if dist > int(u.rng):
			return "kite_approach"
		if dist <= 1:
			return "kite_back"
		return "attack"
	if GridCore.can_attack(u.cell, target.cell, u.is_cavalry(), u.rng):
		return "attack"
	return "approach"


## 击退到边缘：当前阶段是 repel_to_edge 且该单位已跌破撤退血线？
## 原著第 88 章：刘备的目标不是歼灭臧霸，而是"把他打回泰山东边的琅琊郡"。
static func should_retreat(stages: Array, stage_idx: int, u) -> bool:
	if stages.is_empty():
		return false
	var st: Dictionary = stages[clampi(stage_idx, 0, stages.size() - 1)]
	var win: Dictionary = st.get("win", {})
	if str(win.get("type", "")) != "repel_to_edge":
		return false
	if str(win.get("target", "")) != u.id:
		return false
	var ratio: float = float(win.get("ratio", 0.5))
	return float(u.hp) / float(maxi(1, u.max_hp)) <= ratio


## 撤退方向：朝指定边缘逐格后退（默认东边 = 琅琊方向）
static func retreat_step(u, map_w: int, map_h: int, edge: String = "east") -> Vector2i:
	match edge:
		"west":
			return Vector2i(maxi(0, u.cell.x - 1), u.cell.y)
		"south":
			return Vector2i(u.cell.x, mini(map_h - 1, u.cell.y + 1))
		"north":
			return Vector2i(u.cell.x, maxi(0, u.cell.y - 1))
		_:
			return Vector2i(mini(map_w - 1, u.cell.x + 1), u.cell.y)
