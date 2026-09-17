extends SceneTree
## 第三关（招降许褚）与第四关（拔山砦→打回琅琊）分阶段军令验证
## 运行：Godot_console.exe --headless --path zcode项目 --script res://tests/probe_ch34_stages.gd

const BattleScript := preload("res://scripts/battle.gd")
const SaveCore := preload("res://scripts/systems/save.gd")

var failed := 0


func _initialize() -> void:
	var s: Dictionary = SaveCore.load_state()
	s["chapters"] = ["chapter1", "chapter2"]
	s["prologues_seen"] = ["chapter1", "chapter2", "chapter3", "chapter4"]
	SaveCore.save_state(s)
	_run()


func _wait(x: float) -> void:
	await create_timer(x).timeout


func _enter(chapter: String) -> Node:
	BattleScript.chapter_id = chapter
	change_scene_to_file("res://scenes/battle.tscn")
	await _wait(2.5)
	var b = current_scene
	if b.has_method("_on_dialog_skip_pressed"):
		b._on_dialog_skip_pressed()
	await _wait(0.6)
	return b


func _run() -> void:
	print("\n==== 第三关 · 招降许褚 ====")
	var b = await _enter("chapter3")
	print("  军令数 %d，首阶段：%s" % [b.stages.size(), b.stages[0].get("title", "")])

	# 阶段1：清光黄巾乱兵（许褚本人不算杂兵）
	var minions := 0
	for u in b.units:
		if u.camp == "enemy" and not u.is_commander:
			u.hp = 0
			u.alive = false
			minions += 1
	print("  清光 %d 名乱兵" % minions)
	b._check_victory()
	await _wait(0.6)
	if int(b.stage_idx) == 1 and not b.victory:
		print("  ✅ 阶段1「乱军围将」达成 → 进入阶段2「降伏虎痴」")
	else:
		print("  ❌ 阶段1 未正确推进（stage_idx=%d victory=%s）" % [b.stage_idx, str(b.victory)])
		failed += 1

	# 阶段2：把许褚打到三成血以下 → 应逼其归顺（而不是打死）
	var xc = b._unit_by_id("xuchu")
	print("  许褚 HP %d/%d（归顺阈值 %.0f）" % [xc.hp, xc.max_hp, xc.max_hp * 0.3])
	xc.hp = int(xc.max_hp * 0.29)
	b._check_victory()
	await _wait(0.8)
	if b.victory:
		print("  ✅ 许褚残血未死 → 触发归顺 → 通关（而不是把他打死）")
	else:
		print("  ❌ 许褚残血后未通关")
		failed += 1
	print("  许褚仍存活：%s（原著里他是被招揽的，不是被杀）" % str(xc.alive))

	print("\n==== 第四关 · 亲征泰山郡 ====")
	b = await _enter("chapter4")
	print("  军令数 %d，首阶段：%s" % [b.stages.size(), b.stages[0].get("title", "")])
	var zangba = b._unit_by_id("zangba")
	var changxi = b._unit_by_id("changxi")
	b._check_victory()
	if int(b.stage_idx) == 1:
		print("  ✅ 阶段1「攻破山砦」判定为已达成？(changxi alive=%s) → 不对" % str(changxi.alive))
		failed += 1

	# 阶段1：击破昌豨（据守山砦）
	changxi.hp = 0
	changxi.alive = false
	b._check_victory()
	await _wait(0.6)
	if int(b.stage_idx) == 1 and not b.victory:
		print("  ✅ 击破昌豨 → 阶段1达成 → 进入阶段2「打回琅琊」")
	else:
		print("  ❌ 击破昌豨后阶段未推进（stage_idx=%d victory=%s）" % [b.stage_idx, str(b.victory)])
		failed += 1

	# 阶段2：击退臧霸
	zangba.hp = 0
	zangba.alive = false
	b._check_victory()
	await _wait(0.8)
	if b.victory:
		print("  ✅ 击退臧霸 → 两阶段达成 → 通关（打回琅琊郡）")
	else:
		print("  ❌ 击退臧霸后未通关")
		failed += 1

	print("\n==== 第3/4关军令测试%s ====" % ("全部通过 ✅" if failed == 0 else "失败 %d 项 ❌" % failed))
	SaveCore.save_state(SaveCore.new_state())
	quit(1 if failed > 0 else 0)
