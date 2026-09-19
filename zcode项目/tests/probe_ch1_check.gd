extends SceneTree
## 第一关验收探针：公孙瓒飞弹 + 小兵耐久度 + 行动后不可再动 + 图标残留
## 运行：Godot_console.exe --headless --path zcode项目 --script res://tests/probe_ch1_check.gd

const BattleScript := preload("res://scripts/battle.gd")
const SaveCore := preload("res://scripts/systems/save.gd")
const CombatCore := preload("res://scripts/core/combat.gd")

var b: Node
var failed: int = 0


func _initialize() -> void:
	var s: Dictionary = SaveCore.load_state()
	s["chapters"] = []
	s["prologues_seen"] = ["chapter1", "chapter2", "chapter3", "chapter4"]
	SaveCore.save_state(s)
	BattleScript.chapter_id = "chapter1"
	change_scene_to_file("res://scenes/battle.tscn")
	_run()


func _wait(x: float) -> void:
	await create_timer(x).timeout


func _chev(a: Vector2i, c: Vector2i) -> int:
	return maxi(absi(a.x - c.x), absi(a.y - c.y))


func _check(ok: bool, msg: String) -> void:
	if ok:
		print("  ✅ %s" % msg)
	else:
		print("  ❌ %s" % msg)
		failed += 1


func _run() -> void:
	await _wait(2.5)
	b = current_scene
	if b.has_method("_on_dialog_skip_pressed"):
		b._on_dialog_skip_pressed()
	await _wait(0.6)

	var gs = b._unit_by_id("gongsunzan")
	if gs == null:
		print("❌ 找不到公孙瓒")
		quit(1)
		return

	print("\n===== 第一关验收开始 =====")
	print("公孙瓒 %s  有效攻击=%d" % [str(gs.cell), gs.effective_atk()])

	# ---------- 1. 击杀刀数核对：不该有"一刀秒"的小兵 ----------
	print("\n---- 1. 补刀效率（技能倍率 1.0，dmg = atk - def）----")
	var enemies: Array = []
	for u in b.units:
		if u.camp == "enemy" and u.alive:
			enemies.append(u)
	enemies.sort_custom(func(x, y): return x.cell.y < y.cell.y)
	for e in enemies:
		var dmg: int = CombatCore.damage(gs.effective_atk(), 1.0, e.effective_def())
		var hits: int = int(ceil(float(e.max_hp) / float(maxi(1, dmg))))
		var tag: String = "主将" if e.is_commander else ""
		var verdict: String = "⚠ 一刀秒" if hits <= 1 else ("%d 刀" % hits)
		print("  %-14s %s  hp=%-4d def=%-3d → 每击 %-3d  %s %s" % [
			e.id, str(e.cell), e.max_hp, e.effective_def(), dmg, verdict, tag])
		if hits <= 1 and not e.is_commander:
			print("      ❌ 该小兵会被公孙瓒一击必杀，耐久偏低")
			failed += 1

	# ---------- 2. 最下面的刀兵：真实点击链路放技能 ----------
	var dao = b._unit_by_id("dao_bing_2")
	if dao == null:
		print("❌ 找不到 dao_bing_2（最下面的刀兵）")
		quit(1)
		return
	print("\n---- 2. 最下面的刀兵 %s（距离 %d 格）飞弹延迟 ----" % [
		str(dao.cell), _chev(gs.cell, dao.cell)])
	var hp_before: int = dao.hp
	b._handle_click(gs.cell)          # 玩家点公孙瓒 → 选中
	await _wait(0.2)
	_check(b.selected_id == "gongsunzan", "点击选中公孙瓒（input_mode=%d）" % b.input_mode)
	b._cmd_skill()                    # 玩家点「绝技」按钮
	await _wait(0.2)
	print("  点绝技后 input_mode=%d" % b.input_mode)
	b._handle_click(dao.cell)         # 玩家点目标刀兵
	await _wait(0.5)
	print("  HP：%d → %d" % [hp_before, dao.hp])
	_check(dao.hp == hp_before, "未立即掉血（箭确实飞出去了）")
	print("  飞弹数据=%d 视觉节点=%d" % [int(b.active_arrows.size()), int(b.arrow_nodes.size())])
	_check(int(b.active_arrows.size()) > 0, "生成了飞行中的飞弹")
	_check(int(b.active_arrows.size()) == int(b.arrow_nodes.size()), "数据与节点数量一致（无隐形弹/无残留）")

	# ---------- 3. 释放技能后：真实点击链路（模拟玩家鼠标） ----------
	print("\n---- 3. 放完技能后玩家能否再操作（真实点击入口）----")
	_check(bool(gs.acted), "公孙瓒已标记 acted")
	print("  技能后残留状态：input_mode=%d selected_id=\"%s\"" % [b.input_mode, b.selected_id])
	_check(b.input_mode == 0, "input_mode 已归零 NONE（不留可操作态）")
	_check(b.selected_id == "", "selected_id 已清空")
	var pos_before: Vector2i = gs.cell
	var side_cell: Vector2i = gs.cell + Vector2i(0, 1)
	b._handle_click(gs.cell)          # 再点自己
	await _wait(0.15)
	b._handle_click(side_cell)        # 再点旁边空地
	await _wait(0.25)
	print("  点自己→点空地 %s：位置 %s → %s" % [str(side_cell), str(pos_before), str(gs.cell)])
	_check(gs.cell == pos_before, "放完技能后点地面不会移动")
	_check(b.selected_id != "gongsunzan", "已行动单位无法被再次选中")

	# 纵深防御：即使直接调用内部入口，也不能移动已行动单位
	var pos2: Vector2i = gs.cell
	b._select_unit("gongsunzan")
	b._do_move(gs.cell + Vector2i(0, 1))
	await _wait(0.2)
	print("  直接调用内部入口后位置：%s → %s" % [str(pos2), str(gs.cell)])
	_check(gs.cell == pos2, "内部入口也无法移动已行动单位（纵深防御）")

	# ---------- 4. 飞弹推进直到命中 ----------
	print("\n---- 4. 飞弹推进（每回合 3 格）----")
	var hp2: int = dao.hp
	var hit_turn: int = -1
	for turn in range(6):
		b._update_homing_arrows()
		await _wait(0.3)
		print("  推进 %d 次：飞弹=%d 节点=%d 刀兵HP=%d" % [
			turn + 1, int(b.active_arrows.size()), int(b.arrow_nodes.size()), dao.hp])
		if dao.hp < hp2 and hit_turn < 0:
			hit_turn = turn + 1
		if b.active_arrows.is_empty() and hit_turn > 0:
			break
	_check(hit_turn > 0, "飞弹最终命中并结算伤害（第 %d 次推进）" % hit_turn)
	if hit_turn > 0:
		print("  命中伤害 = %d（预期 %d）" % [
			hp2 - dao.hp, CombatCore.damage(gs.effective_atk(), 1.0, dao.effective_def())])

	# ---------- 5. 残留检查 ----------
	print("\n---- 5. 视觉残留 ----")
	_check(int(b.arrow_nodes.size()) == 0, "飞弹视觉节点已清空（当前 %d）" % int(b.arrow_nodes.size()))
	_check(int(b.active_arrows.size()) == 0, "飞弹数据已清空")
	# 覆盖层（移动范围绿色高亮）：queue_free 是延迟释放，等两帧再统计
	await _wait(0.5)
	var n_overlay: int = int(b.overlay.get_child_count())
	print("  覆盖层高亮格残留：%d" % n_overlay)
	_check(n_overlay == 0, "移动范围高亮已清空（无残留图标）")

	# ---------- 6. 近距离（相邻 1 格）应立即命中 ----------
	print("\n---- 6. 相邻 1 格应立即命中（设计如此）----")
	var dao1 = b._unit_by_id("dao_bing_1")
	if dao1 != null and dao1.alive:
		gs.acted = false
		gs.cds.clear()
		gs.cell = Vector2i(dao1.cell.x - 1, dao1.cell.y)
		var hp3: int = dao1.hp
		b.selected_id = "gongsunzan"
		b._do_skill(dao1.cell)
		await _wait(0.3)
		print("  距离 %d 格：HP %d → %d" % [_chev(gs.cell, dao1.cell), hp3, dao1.hp])
		_check(dao1.hp < hp3, "相邻目标当回合直接命中")

	print("\n===== 验收结束：%s =====" % ("全部通过 ✅" if failed == 0 else "失败 %d 项 ❌" % failed))
	SaveCore.save_state(SaveCore.new_state())
	quit(0 if failed == 0 else 1)
