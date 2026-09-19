extends SceneTree
## 多风格虚拟玩家：每种"玩家性格"都用点击操作**完整通关第一关**
## 运行（headless 即可）：Godot_console.exe --headless --path zcode项目 --script res://tests/probe_player_styles.gd
##
## 目的：验证第一关对**不同打法**都是可通的 —— 不会出现"只有一种套路能赢"，
##       也不会出现"某种风格会卡死/打不过"。
## 四种风格：
##   莽夫型 —— 全员直冲最近的敌人，只普攻，不蓄力不用技能
##   技能流 —— 有技能就放（咆哮/飞弹/龙斩），否则普攻
##   龟缩型 —— 不主动移动，等敌人进入攻击范围再打（测防御反击）
##   精准型 —— 集火血量最低的敌人，尽快减员
## 所有操作都走点击分派（_handle_click / 按钮 pressed），不直接改战斗状态。

const BattleScript := preload("res://scripts/battle.gd")
const SaveCore := preload("res://scripts/systems/save.gd")

const MAX_TURNS := 20
const STYLES: Array[String] = ["莽夫型", "技能流", "龟缩型", "精准型"]

var b: Node
var results: Array = []
var cur_log: Array[String] = []
var bad: int = 0


func _initialize() -> void:
	_run()


func _wait(x: float) -> void:
	await create_timer(x).timeout


## 玩家点击某个格子
func _click(cell: Vector2i) -> void:
	b._handle_click(cell)
	await create_timer(0.12).timeout


func _skip_dialog() -> void:
	var n: int = 0
	while bool(b.dialog_showing) and n < 40:
		b._on_dialog_btn_pressed()
		await create_timer(0.06).timeout
		n += 1


func _find_skill_btn() -> Button:
	for c in b.command_menu.find_children("*", "Button", true, false):
		if c is Button and (c as Button).text.begins_with("✨"):
			return c
	return null


# ---------------- 主流程 ----------------

func _run() -> void:
	print("\n===== 多风格虚拟玩家：各自完整通关第一关 =====")
	for st in STYLES:
		await _play(st)

	print("\n===== 汇总 =====")
	for r in results:
		print("  %-6s %s（%d 回合）" % [r["style"], "通关 ✅" if r["win"] else "未通关 ❌", int(r["turns"])])
		if not bool(r["win"]):
			bad += 1
	if bad == 0:
		print("  结论：四种打法的玩家都能通关 ✅")
	else:
		print("  结论：有 %d 种打法无法通关 ❌" % bad)
	SaveCore.save_state(SaveCore.new_state())
	quit(0 if bad == 0 else 1)


func _play(style: String) -> void:
	print("\n---- 玩家风格：%s ----" % style)
	cur_log = []
	var s: Dictionary = SaveCore.new_state()
	s["prologues_seen"] = ["chapter1", "chapter2", "chapter3", "chapter4"]
	SaveCore.save_state(s)
	BattleScript.chapter_id = "chapter1"
	change_scene_to_file("res://scenes/battle.tscn")
	await _wait(2.5)
	b = current_scene
	await _skip_dialog()

	var turn: int = 0
	while turn < MAX_TURNS and not bool(b.victory) and not bool(b.defeat):
		turn += 1
		await _play_turn(style)
		if bool(b.victory) or bool(b.defeat):
			break

	var win: bool = bool(b.victory)
	results.append({"style": style, "win": win, "turns": turn})
	for l in cur_log:
		print("      " + l)
	print("  → %s（%d 回合）" % ["通关 ✅" if win else "未通关 ❌", turn])


func _play_turn(style: String) -> void:
	for u in b._camp_units("player"):
		if bool(b.victory) or bool(b.defeat):
			return
		var uu = b._unit_by_id(u.id)
		if uu == null or not uu.alive or uu.acted or uu.is_stunned():
			continue
		await _act(uu, style)
	if bool(b.victory) or bool(b.defeat):
		return
	b._end_player_turn()
	await _wait(1.8)                 # 等敌方回合走完
	await _skip_dialog()


func _act(u, style: String) -> void:
	await _click(u.cell)             # 选中

	# 阶段 2「劈关夺门」：关羽去劈门，其余人继续清场
	if int(b.stage_idx) == 1 and u.id == "guanyu":
		await _breach_attempt(u)
		return

	# 龟缩型：不主动移动，只打射程内的
	if style == "龟缩型":
		for e in b._camp_units("enemy"):
			if e.alive and b._is_in_attack_range(e.cell):
				await _click(e.cell)
				cur_log.append("%s 原地反击 %s" % [u.name, e.name])
				return
		b._cmd_wait()
		return

	# 技能流：技能就绪就放
	if style == "技能流" and u.skill_ids.size() > 0:
		var sk: String = str(u.skill_ids[0])
		if u.skill_ready(sk) and await _try_skill(u, sk):
			return

	var t = _pick_target(u, style)
	if t == null:
		b._cmd_wait()
		return
	if b._is_in_attack_range(t.cell):
		await _click(t.cell)
		cur_log.append("%s 攻击 %s" % [u.name, t.name])
		return
	var step: Vector2i = _best_step_toward(u, t.cell)
	if step != u.cell:
		await _click(step)
		await _wait(0.1)
		if b._is_in_attack_range(t.cell):
			await _click(t.cell)
			cur_log.append("%s 冲上去打 %s" % [u.name, t.name])
			return
	b._cmd_wait()


## 放技能；返回 true 表示技能真的出手了
func _try_skill(u, sk: String) -> bool:
	if sk == "roar":
		# 张飞：直接开喊（点技能即进入喊字），停手会自动出手
		var btn := await _open_menu_and_get_skill(u)
		if btn == null:
			return false
		btn.pressed.emit()
		await _wait(1.4)             # 等"停手 0.9 秒自动出手"
		cur_log.append("%s 燕人咆哮" % u.name)
		return true
	if sk == "arrow_rain":
		var t = _pick_target(u, "莽夫型")
		if t == null:
			return false
		var btn2 := await _open_menu_and_get_skill(u)
		if btn2 == null:
			return false
		btn2.pressed.emit()
		await _wait(0.25)
		await _click(t.cell)         # 全图锁敌
		cur_log.append("%s 回旋飞弹 → %s" % [u.name, t.name])
		return true
	if sk == "dragon_slash":
		# 龙斩要贴身：只有相邻有敌人才用（否则交给普攻逻辑去走位）
		var adj = null
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var e = b._unit_at(u.cell + d)
			if e != null and e.alive and e.camp != u.camp:
				adj = e
				break
		if adj == null:
			return false
		if u.charge < 5:
			return false             # 蓄力太少，不如普攻
		var btn3 := await _open_menu_and_get_skill(u)
		if btn3 == null:
			return false
		btn3.pressed.emit()
		await _wait(0.25)
		await _click(adj.cell)
		cur_log.append("%s 青龙斩 %s（贯穿身后）" % [u.name, adj.name])
		return true
	return false


func _open_menu_and_get_skill(u) -> Button:
	await _click(u.cell)             # 再点自己 → 弹命令菜单
	await _wait(0.15)
	return _find_skill_btn()


## 关羽劈城门：先蓄力（来回跑），够了再对准城门出刀
func _breach_attempt(u) -> void:
	var gy = b._unit_by_id("guanyu")
	if gy == null:
		return
	if gy.charge < 10:
		var goal: Vector2i = Vector2i(0, 4) if gy.cell.x > 4 else Vector2i(9, 4)
		var step: Vector2i = _best_step_toward(gy, goal)
		if step != gy.cell:
			await _click(step)
			cur_log.append("关羽跑动蓄力 %d/10" % int(gy.charge))
		else:
			b._cmd_wait()
		return
	if gy.cell.y != 4:
		var step2: Vector2i = _best_step_toward(gy, Vector2i(gy.cell.x, 4))
		if step2 != gy.cell:
			await _click(step2)
			return
	var btn := await _open_menu_and_get_skill(gy)
	if btn == null:
		b._cmd_wait()
		return
	btn.pressed.emit()
	await _wait(0.25)
	await _click(Vector2i(10, 4))    # 城门格
	cur_log.append("关羽劈向城门（蓄力 %d）" % int(gy.charge))


# ---------------- 决策辅助（只读，不改战斗状态）----------------

func _pick_target(u, style: String):
	var enemies: Array = []
	for e in b._camp_units("enemy"):
		if e.alive:
			enemies.append(e)
	if enemies.is_empty():
		return null
	if style == "精准型":
		var weak = enemies[0]
		for e in enemies:
			if e.hp < weak.hp:
				weak = e
		return weak
	var near = enemies[0]
	var nd: int = 99999
	for e in enemies:
		var d: int = absi(e.cell.x - u.cell.x) + absi(e.cell.y - u.cell.y)
		if d < nd:
			nd = d
			near = e
	return near


func _best_step_toward(u, goal: Vector2i) -> Vector2i:
	var best: Vector2i = u.cell
	var bd: int = 99999
	for x in range(12):
		for y in range(10):
			var c := Vector2i(x, y)
			if not b._is_in_reachable(c):
				continue
			var d: int = absi(c.x - goal.x) + absi(c.y - goal.y)
			if d < bd:
				bd = d
				best = c
	return best
