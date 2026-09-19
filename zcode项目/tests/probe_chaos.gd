extends SceneTree
## 混沌测试：随机操作 + 不变量断言，自动抓"卡死/残留/状态错乱"这类偶发 bug
##
## 思路：人手工点是点不出所有组合的。这个脚本随机模拟玩家的各种操作
##       （选中/移动/攻击/技能/待机/结束回合），每步都校验一组"永远该成立"的不变量，
##       一旦被破坏就打印当时的现场（第几步、什么操作、哪个单位、什么状态）。
##
## 运行：
##   --script res://tests/probe_chaos.gd                 # 默认 60 步
##   --script res://tests/probe_chaos.gd -- 200 999      # 200 步，随机种子 999（可复现）
##   --script res://tests/probe_chaos.gd -- 200 999 chapter2

const BattleScript := preload("res://scripts/battle.gd")
const SaveCore := preload("res://scripts/systems/save.gd")

var b: Node
var rng := RandomNumberGenerator.new()
var max_steps := 60
var chapter := "chapter1"

var anomalies: Array[String] = []
var action_log: Array[String] = []
var minions_before := 0
var move_tracker := {}   # "回合:单位id" -> 该回合成功移动次数


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		max_steps = int(args[0])
	if args.size() > 1:
		rng.seed = int(args[1])
	else:
		rng.seed = 20260919
	if args.size() > 2:
		chapter = args[2]

	var s: Dictionary = SaveCore.load_state()
	s["chapters"] = []
	s["prologues_seen"] = ["chapter1", "chapter2", "chapter3", "chapter4"]
	SaveCore.save_state(s)

	print("==== 混沌测试：%d 步，seed=%d，关卡=%s ====" % [max_steps, rng.seed, chapter])
	BattleScript.chapter_id = chapter
	change_scene_to_file("res://scenes/battle.tscn")
	_run()


func _wait(x: float) -> void:
	await create_timer(x).timeout


func _bad(what: String, detail: String) -> void:
	var msg := "第%d步 [%s] %s" % [action_log.size(), what, detail]
	if not anomalies.has(msg):
		anomalies.append(msg)
		print("  ⚠ 不变量被破坏 → ", msg)


## ---------- 不变量检查 ----------
func _check_invariants(op: String) -> void:
	# 1. 单位 id 唯一（随机操作不应产生重复条目）
	var seen := {}
	for u in b.units:
		if seen.has(u.id):
			_bad("重复单位id", "%s 出现两次，操作=%s" % [u.id, op])
		seen[u.id] = true

	# 2. 飞弹：数据与视觉节点必须一一对应（否则就是"图标残留"或"隐形飞弹"）
	var n_arr: int = int(b.active_arrows.size())
	var n_node: int = int(b.arrow_nodes.size())
	if n_arr != n_node:
		_bad("飞弹数据/节点不一致", "active_arrows=%d 但 arrow_nodes=%d（操作=%s）" % [n_arr, n_node, op])

	# 3. 已行动的单位不应还能被选中操作（防"放完技能还能动"）
	#    关卡已结束时跳过（战败/胜利后不再接受操作，残留选中无害）
	if b.selected_id != "" and not b.victory and not b.defeat:
		var sel = b._unit_by_id(b.selected_id)
		if sel != null and sel.acted and b.input_mode == 0:
			# input_mode==NONE(0) 时不该处于"选中已行动单位"的待操作态
			_bad("已行动单位仍处于可操作状态", "%s acted=true 但仍是 selected（操作=%s）" % [sel.id, op])

	# 4. 回合数单调（不该回退或卡在 0）
	if int(b.turn_state.turn) < 1:
		_bad("回合数异常", "turn=%d" % int(b.turn_state.turn))

	# 5. 场上临时节点不应无限增长（卡死/泄漏的先兆）
	var n := _count_temp_nodes()
	if n > 400:
		_bad("临时节点疑似泄漏", "当前 %d 个（操作=%s）" % [n, op])

	# 6. 我方单位不应凭空增加
	var alive: int = int(b._camp_units("player").size())
	if alive > minions_before:
		_bad("我方单位数异常增加", "初始 %d，现在 %d" % [minions_before, alive])


func _count_temp_nodes() -> int:
	var root2: Node = b.get_node_or_null("MapRoot")
	if root2 == null:
		return 0
	return root2.get_child_count()


## ---------- 随机操作 ----------
func _random_action() -> String:
	var actors: Array = []
	for u in b._camp_units("player"):
		if not u.acted:
			actors.append(u)
	if actors.is_empty():
		b._end_player_turn()
		return "结束回合（无人可动）"

	var u = actors[rng.randi() % actors.size()]
	b._select_unit(u.id)

	var enemies: Array = b._camp_units("enemy")
	var roll := rng.randi() % 100

	# 待机
	if roll < 12:
		if b.has_method("_cmd_wait"):
			b._cmd_wait()
			return "%s 待机" % u.id

	# 攻击（优先相邻敌人）
	if roll < 45 and not enemies.is_empty():
		var adj: Array = []
		for e in enemies:
			if maxi(absi(e.cell.x - u.cell.x), absi(e.cell.y - u.cell.y)) <= u.rng:
				adj.append(e)
		if not adj.is_empty():
			var t = adj[rng.randi() % adj.size()]
			b._do_attack(t.cell)
			return "%s 攻击 %s" % [u.id, t.id]

	# 技能（任何敌人，含超距目标 —— 专门触发飞弹/远程逻辑）
	if roll < 75 and not enemies.is_empty() and u.skill_ids.size() > 0:
		var sk: String = str(u.skill_ids[0])
		if u.skill_ready(sk):
			var t = enemies[rng.randi() % enemies.size()]
			if sk == "roar":
				# 喊字是异步交互，直接以六字释放，避免测试挂住
				b.selected_id = u.id
				b._start_roar_charging(u)
				b._execute_roar(6)
				return "%s 咆哮(6字)" % u.id
			b._do_skill(t.cell)
			return "%s 技能 %s → %s" % [u.id, sk, t.id]

	# 移动（随机挑一个合法的可达格）
	var moved := _try_random_move(u)
	if moved != "":
		return moved

	# 兜底：待机
	if b.has_method("_cmd_wait"):
		b._cmd_wait()
	return "%s 待机(兜底)" % u.id


func _try_random_move(u) -> String:
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]
	var mv: int = u.effective_mov()
	var best := Vector2i(-1, -1)
	for d in dirs:
		for k in range(1, mv + 1):
			var c: Vector2i = u.cell + d * k
			if c.x < 0 or c.y < 0 or c.x >= 12 or c.y >= 10:
				continue
			if b._is_in_reachable(c):
				best = c
				break
	if best == Vector2i(-1, -1):
		return ""
	var before: Vector2i = u.cell
	b._do_move(best)
	if u.cell == before:
		# 位置没变 = 被"本回合已移动"防御拦住了，保护生效
		return ""
	# 不变量：同一单位同一回合只能成功移动一次
	var key := "%d:%s" % [int(b.turn_state.turn), u.id]
	var n: int = int(move_tracker.get(key, 0)) + 1
	move_tracker[key] = n
	if n > 1:
		_bad("同回合重复移动", "%s 在同一回合成功移动 %d 次" % [u.id, n])
	return "%s 移动 → %s" % [u.id, str(best)]


## ---------- 主循环 ----------
func _run() -> void:
	await _wait(2.5)
	b = current_scene
	if b.has_method("_on_dialog_skip_pressed"):
		b._on_dialog_skip_pressed()
	await _wait(0.6)
	minions_before = b._camp_units("player").size()
	print("  初始：我方 %d 人，敌方 %d 人，地图 12x10" % [
		minions_before, b._camp_units("enemy").size()])

	for i in range(max_steps):
		if b.victory or b.win_dialog_played or b.defeat:
			print("  第 %d 步：关卡已结束（victory=%s defeat=%s）" % [i, str(b.victory), str(b.defeat)])
			break
		var op := _random_action()
		action_log.append(op)
		await _wait(0.12)
		_check_invariants(op)
		# 对白弹出会卡住操作，随手跳过
		if b.dialog_showing:
			b._on_dialog_skip_pressed()
			await _wait(0.1)

	print("\n==== 混沌测试结果 ====")
	print("  执行操作 %d 次" % action_log.size())
	print("  末态：回合=%d，我方存活=%d，敌方存活=%d，飞弹=%d" % [
		int(b.turn_state.turn), b._camp_units("player").size(),
		b._camp_units("enemy").size(), int(b.active_arrows.size())])
	if anomalies.is_empty():
		print("  ✅ 未发现不变量被破坏（%d 步随机操作）" % action_log.size())
	else:
		print("  ❌ 发现 %d 处异常：" % anomalies.size())
		for a in anomalies:
			print("    - ", a)
	print("  （最后 12 步操作）")
	for line in action_log.slice(maxi(0, action_log.size() - 12)):
		print("    · ", line)

	SaveCore.save_state(SaveCore.new_state())
	quit(1 if anomalies.size() > 0 else 0)
