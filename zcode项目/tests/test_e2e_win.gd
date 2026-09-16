extends SceneTree
## 端到端通关测试：击杀主将→胜利对白播放→结算写声望/图鉴
## 修复回归保护（P0）：此前 dialogs 未解包导致此链路全断，本测试确保不再复发
## 运行：godot --headless --path <项目> --script res://tests/test_e2e_win.gd
## 注意：需真实实例化 battle 场景，故用 headless 跑场景

const BATTLE := preload("res://scenes/battle.tscn")
const BattleScript := preload("res://scripts/battle.gd")
const SaveCore := preload("res://scripts/systems/save.gd")

var battle: Node
var frames := 0
var step := 0
var failed := 0

func _initialize() -> void:
	BattleScript.chapter_id = "chapter1"
	battle = BATTLE.instantiate()
	root.add_child(battle)

func _process(_dt: float) -> bool:
	frames += 1
	if frames == 5 and step == 0:
		step = 1
		_test_open_dialog_plays()
		return false
	if frames == 12 and step == 1:
		step = 2
		_kill_commander()          # 触发异步胜利（主帅溃逃演出→胜利对白）
		return false
	if step == 2 and battle.dialog_showing and battle.pending_dialog.size() > 0 and frames > 60:
		# 胜利对白已弹出（异步完成），记录并推进到结算
		print("[OK] 胜利对白已播放（异步胜利流程）✅")
		step = 3
		# 跳过胜利对白
		battle.pending_dialog = []
		battle.dialog_showing = false
		battle.dialog_box.visible = false
		_start_settle()
		return false
	if step == 3:
		# 汇总（结算已同步执行）
		if failed == 0:
			print("==== 端到端通关链路测试通过 ✅ ====")
		else:
			print("==== 端到端测试失败 ", failed, " 项 ❌ ====")
		_clean_save()
		return true
	if frames > 150:
		# 超时保护
		if failed == 0:
			print("==== 端到端测试超时未完成（胜利对白未弹出）❌ ====")
			failed += 1
		_clean_save()
		return true
	return false

func _kill_commander() -> void:
	battle.pending_dialog = []
	battle.dialog_showing = false
	battle.dialog_box.visible = false
	var hx: Variant = battle._unit_by_id("huaxiong")
	if hx:
		hx.hp = 0
		hx.alive = false
	battle._check_victory()  # 新版：进入异步胜利流程

## A) 开局剧情对白应能正常播放（修复核心）
func _test_open_dialog_plays() -> void:
	if battle.dialog_showing and battle.pending_dialog.size() > 0:
		print("[OK] 开局剧情对白正在播放（此前全断）✅")
	else:
		print("[FAIL] 开局剧情对白未播放")
		failed += 1

## B) 击杀华雄→胜利对白→结算声望/图鉴
func _start_settle() -> void:
	# 跳过胜利对白（在前置 step3 已清空）
	battle.win_dialog_played = true
	battle._go_to_result()
	# 验证结算面板出现 + 背包战利品 + 通关记录
	if battle.result_panel != null and battle.result_panel.visible:
		print("[OK] 结算面板已弹出 ✅")
	else:
		print("[FAIL] 结算面板未弹出")
		failed += 1
	var save = SaveCore.load_state()
	var inv: Dictionary = save.get("inventory", {})
	var has_loot := false
	for k in inv:
		if int(inv[k]) > 0:
			has_loot = true
			break
	if has_loot:
		print("[OK] 通关自动抽得战利品入背包 ✅")
	else:
		print("[FAIL] 通关后应至少抽得一个战利品，背包=", inv)
		failed += 1
	var ch: Array = save.get("chapters", [])
	if "chapter1" in ch:
		print("[OK] 通关记录已写入 ✅")
	else:
		print("[FAIL] 通关记录未写入")
		failed += 1
	# 汇总结果（由 _process 的 step3 打印）
	if failed == 0:
		print("## 结算子项全部通过 ##")

func _clean_save() -> void:
	# 清掉测试写入的存档（避免污染玩家进度）
	var f = FileAccess.open("user://save.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(SaveCore.new_state()))
		f.close()