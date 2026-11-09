extends SceneTree
## 空格键结束回合验收：有人未行动时必须"先警告、再确认"，不能直接跳过
## 运行：Godot_console.exe --headless --path zcode项目 --script res://tests/probe_space_endturn.gd
##
## 背景（玩家反馈）："怎么空格键就是下一个回合？如果有人没有行动也没提醒就跳过了"
## 走真实输入入口 _input()，而不是直接调 _end_player_turn()。

const BattleScript := preload("res://scripts/battle.gd")
const SaveCore := preload("res://scripts/systems/save.gd")

const PHASE_PLAYER := 0
const PHASE_ENEMY := 1

var b: Node
var failed: int = 0


func _initialize() -> void:
	var s: Dictionary = SaveCore.new_state()
	s["prologues_seen"] = ["chapter1", "chapter2", "chapter3", "chapter4"]
	SaveCore.save_state(s)
	BattleScript.chapter_id = "chapter1"
	change_scene_to_file("res://scenes/battle.tscn")
	_run()


func _wait(x: float) -> void:
	await create_timer(x).timeout


func _check(ok: bool, msg: String) -> void:
	if ok:
		print("  ✅ %s" % msg)
	else:
		print("  ❌ %s" % msg)
		failed += 1


## 走真实输入入口
func _press_space() -> void:
	var ev := InputEventKey.new()
	ev.keycode = KEY_SPACE
	ev.pressed = true
	ev.echo = false
	b._input(ev)


func _clear_ui_state() -> void:
	b.dialog_showing = false
	b.pending_dialog = []
	b.input_mode = 0
	b.selected_id = ""
	b.pending_end_turn = false


func _run() -> void:
	await _wait(2.5)
	b = current_scene
	if b.has_method("_on_dialog_skip_pressed"):
		b._on_dialog_skip_pressed()
	await _wait(1.0)

	print("\n===== 空格键结束回合验收 =====")
	_clear_ui_state()
	var turn0: int = int(b.turn_state.turn)
	print("  当前：phase=%d（0=我方 1=敌方），turn=%d，input_mode=%d" % [
		int(b.turn_state.phase), turn0, int(b.input_mode)])

	# ---------- A. 有人未行动：第一次空格只警告 ----------
	print("\n---- A. 有未行动单位 ----")
	_clear_ui_state()
	for u in b._camp_units("player"):
		u.acted = false
	_press_space()
	await _wait(0.4)
	print("  第一次空格后：pending_end_turn=%s，phase=%d，turn=%d" % [
		str(b.pending_end_turn), int(b.turn_state.phase), int(b.turn_state.turn)])
	_check(bool(b.pending_end_turn), "第一次空格只做二次确认")
	_check(int(b.turn_state.phase) == PHASE_PLAYER, "仍在玩家回合（没有把没行动的人跳过去）")
	_check(int(b.turn_state.turn) == turn0, "回合数未推进")

	# 第二次空格 → 确认结束
	_press_space()
	# 敌方回合时长随敌兵数量变化，改成轮询等待，别写死秒数
	var waited: float = 0.0
	while waited < 15.0 and int(b.turn_state.turn) == turn0:
		await _wait(0.25)
		waited += 0.25
	print("  第二次空格后：phase=%d，turn=%d" % [
		int(b.turn_state.phase), int(b.turn_state.turn)])
	_check(int(b.turn_state.turn) == turn0 + 1, "再按一次空格 → 回合确实推进（%d → %d）" % [turn0, int(b.turn_state.turn)])
	_check(not bool(b.pending_end_turn), "确认后清除待确认状态")

	# ---------- B. 全员已行动：空格直接结束，不弹警告 ----------
	print("\n---- B. 全员已行动 ----")
	await _wait(3.5)                      # 等敌方回合演出走完
	_clear_ui_state()
	for u in b._camp_units("player"):
		u.acted = true
	var turn1: int = int(b.turn_state.turn)
	_press_space()
	await _wait(0.5)
	print("  第一次空格后：pending_end_turn=%s，phase=%d，turn=%d" % [
		str(b.pending_end_turn), int(b.turn_state.phase), int(b.turn_state.turn)])
	_check(not bool(b.pending_end_turn), "全员已行动时不弹警告")
	_check(int(b.turn_state.phase) == PHASE_ENEMY or int(b.turn_state.turn) > turn1,
		"全员行动完毕 → 一次空格直接结束我方回合")

	# ---------- C. 对白播放中，空格应推进对白而不是结束回合 ----------
	print("\n---- C. 对白播放中按空格 ----")
	await _wait(3.5)
	b._play_dialog("chapter1_open")
	await _wait(0.5)
	var turn2: int = int(b.turn_state.turn)
	var showing: bool = bool(b.dialog_showing)
	_press_space()
	await _wait(0.4)
	print("  对白中（showing=%s）按空格后：turn=%d（原 %d）" % [
		str(showing), int(b.turn_state.turn), turn2])
	_check(showing, "空格前对白确实在播放")
	_check(int(b.turn_state.turn) == turn2, "对白播放中按空格不会结束回合（只推进对白）")

	# ---------- D. 我方单位也会"回合流逝"（CD / 眩晕 / 脱力必须递减）----------
	# 此前 end_turn() 只在敌方回合末尾对敌方调用，我方从不调用，后果极严重：
	#   技能冷却永不恢复（放一次就永久灰）／被眩晕后永久定身／脱力永不恢复
	print("\n---- D. 我方单位回合流逝 ----")
	await _wait(3.5)
	_clear_ui_state()
	var gy = b._unit_by_id("guanyu")
	var zf = b._unit_by_id("zhangfei")
	gy.cds["dragon_slash"] = 2
	zf.stun_turns = 1
	zf.exhausted_turns = 2
	zf.exhausted = true
	b._end_player_turn()
	await _wait(5.0)
	print("  冷却 2 → %d；眩晕 1 → %d；脱力 2 → %d" % [
		int(gy.cds.get("dragon_slash", 0)), zf.stun_turns, zf.exhausted_turns])
	_check(int(gy.cds.get("dragon_slash", 0)) < 2, "技能冷却随回合递减（此前永不恢复 → 技能永久灰）")
	_check(zf.stun_turns == 0, "眩晕随回合解除（此前我方被晕 = 永久定身）")
	_check(zf.exhausted_turns == 1, "脱力剩余回合递减（此前永不恢复）")

	# ---------- E. 被眩晕的我方单位自动跳过 ----------
	print("\n---- E. 被眩晕的我方单位自动跳过 ----")
	await _wait(1.5)
	var lb = b._unit_by_id("liubei")
	lb.stun_turns = 1
	b._begin_player_turn()
	await _wait(0.8)
	print("  被眩晕的刘备 acted=%s（应为 true = 自动跳过）" % str(lb.acted))
	_check(bool(lb.acted), "被眩晕的我方单位自动跳过本回合（玩家不用手动处理）")
	lb.stun_turns = 0
	lb.acted = false

	print("\n===== 汇总 =====")
	if failed == 0:
		print("空格键验收：全部通过 ✅")
	else:
		print("空格键验收：失败 %d 项 ❌" % failed)
	SaveCore.save_state(SaveCore.new_state())
	quit(0 if failed == 0 else 1)
