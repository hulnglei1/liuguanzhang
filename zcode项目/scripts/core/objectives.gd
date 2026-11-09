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
		"kill_minions":
			# 除主将外的杂兵全部清光（主将还站着，用于"先清场再单挑"这类阶段）
			return int(ctx.get("minions_alive", 1)) <= 0
		"kill_target":
			return _is_down(ctx, str(win.get("target", "")))
		"recruit_at_hp":
			# 招降：把目标打到最后 X% 血即逼其归顺（原著里许褚是被招揽的，不是被杀）
			# 若一击致死也算达成（剧情按"打昏后收服"处理）
			return _hp_below(ctx, str(win.get("target", "")), float(win.get("ratio", 0.3)))
		"repel_to_edge":
			# 击退到地图边缘（原著：把臧霸打回泰山东边的琅琊郡）
			var u2 := _unit_info(ctx, str(win.get("target", "")))
			if u2.is_empty() or not bool(u2.get("alive", true)):
				return true                      # 目标阵亡也算达成
			var cell: Array = u2.get("cell", [0, 0])
			var edge: String = str(win.get("edge", "east"))
			# 地图变宽后"东边缘"会跟着变远（24 格地图上要跑 12 格）。
			# 关卡若想固定一条撤退线，可在 win 里写 edge_x 覆盖。
			var edge_x: int = int(win.get("edge_x", -1))
			if edge_x >= 0:
				match edge:
					"east":
						return int(cell[0]) >= edge_x
					"west":
						return int(cell[0]) <= edge_x
			var mw: int = int(ctx.get("map_w", 12))
			var mh: int = int(ctx.get("map_h", 10))
			match edge:
				"east":
					return int(cell[0]) >= mw - 1
				"west":
					return int(cell[0]) <= 0
				"south":
					return int(cell[1]) >= mh - 1
				"north":
					return int(cell[1]) <= 0
			return false
		_:
			return false


static func _unit_info(ctx: Dictionary, id: String) -> Dictionary:
	if id.is_empty():
		return {}
	var us: Dictionary = ctx.get("units", {})
	return us.get(id, {})


static func _is_down(ctx: Dictionary, id: String) -> bool:
	var u := _unit_info(ctx, id)
	if u.is_empty():
		return false
	return not bool(u.get("alive", true))


static func _hp_below(ctx: Dictionary, id: String, ratio: float) -> bool:
	var u := _unit_info(ctx, id)
	if u.is_empty():
		return false
	if not bool(u.get("alive", true)):
		return true
	var mx: int = maxi(1, int(u.get("max_hp", 1)))
	return float(int(u.get("hp", mx))) / float(mx) <= ratio


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
