class_name ObjectivesCore
extends RefCounted
## 曹操传式多阶段军令（胜利条件数据驱动，纯逻辑可无头测试）
##
## 关卡数据里用 stages 数组描述，每一阶段有自己的达成条件：
##   {"type":"kill_commander"}                 斩杀敌方主将
##   {"type":"defeat_commander"}               击退主将（血量归零即算，剧情上是撤退/败走）
##   {"type":"break_gate"}                     攻破城门
##   {"type":"survive_turns","value":3}        坚守 N 回合
##   {"type":"kill_all"}                       全歼敌军
##
## 没写 stages 的旧关卡由 battle.gd 调 build_default_stages() 合成单阶段，向后兼容。

## 单阶段是否达成；ctx 由 battle.gd 每帧组装
static func stage_cleared(stage: Dictionary, ctx: Dictionary) -> bool:
	var win: Dictionary = stage.get("win", {})
	match str(win.get("type", "kill_commander")):
		"kill_commander", "defeat_commander":
			return bool(ctx.get("commander_down", false))
		"break_gate":
			return bool(ctx.get("gate_broken", false))
		"survive_turns":
			return int(ctx.get("turn", 1)) >= int(win.get("value", 1))
		"kill_all":
			return int(ctx.get("enemies_alive", 1)) <= 0
		_:
			return false


## 旧关卡（无 stages）兼容：按 win_condition 合成单阶段
static func build_default_stages(win_condition: String) -> Array:
	if win_condition == "kill_all":
		return [{
			"id": "legacy", "title": "全歼敌军",
			"objective": "歼灭场上全部敌军",
			"win": {"type": "kill_all"},
		}]
	return [{
		"id": "legacy", "title": "斩将",
		"objective": "斩杀敌方主将",
		"win": {"type": "kill_commander"},
	}]


## 阶段目标的一句话描述（面板/横幅用）
static func progress_text(stages: Array, idx: int) -> String:
	if stages.is_empty():
		return "军令：—"
	var i: int = clampi(idx, 0, stages.size() - 1)
	var st: Dictionary = stages[i]
	var total: String = "" if stages.size() <= 1 else "（第 %d/%d 阶段）" % [i + 1, stages.size()]
	return "🎯 %s%s：%s" % [str(st.get("title", "军令")), total, str(st.get("objective", ""))]


## 是否有下一阶段（用于 UI 判断要不要显示"下一目标"）
static func has_next(stages: Array, idx: int) -> bool:
	return idx + 1 < stages.size()
