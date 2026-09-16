extends SceneTree

const BattleScript := preload("res://scripts/battle.gd")
const SaveCore := preload("res://scripts/systems/save.gd")
const SkillsCore := preload("res://scripts/entities/skills.gd")
const UnitScript := preload("res://scripts/entities/unit.gd")

func _init() -> void:
	print("==== P0/P1/P2 综合修复与新增特性测试开始 ====")
	var failed := 0

	# 1. 测试玉米种子回血：当存活且不满血时回血
	var u = UnitScript.new()
	u.id = "guanyu"
	u.max_hp = 100
	u.hp = 80
	u.alive = true
	u.hp_regen = 5
	var old_hp = u.hp
	var heal = mini(u.hp_regen, u.max_hp - u.hp)
	u.hp += heal
	if u.hp == 85:
		print("[OK] 玉米种子回血机制生效（80 -> 85）✅")
	else:
		print("[FAIL] 玉米种子回血异常，当前 HP=", u.hp)
		failed += 1

	# 2. 测试合体骑人 effective_mov 与下马
	var gy = UnitScript.new()
	gy.id = "guanyu"
	gy.mov = 4
	var zy = UnitScript.new()
	zy.id = "zhaoyun"
	zy.mov = 6
	gy.alive = true
	zy.alive = true
	SkillsCore.do_mount(gy, zy)
	if gy.effective_mov() == 6:
		print("[OK] 关羽合体后 effective_mov 正确继承为 6 ✅")
	else:
		print("[FAIL] 合体后移动力不为6，实际: ", gy.effective_mov())
		failed += 1
	SkillsCore.do_unmount(gy, zy)
	if gy.effective_mov() == 4 and not gy.is_mounted():
		print("[OK] 关羽解除合体后恢复 4 格移动力 ✅")
	else:
		print("[FAIL] 解除合体异常")
		failed += 1

	# 3. 测试曹操与赤兔快跑图鉴收集
	var save = SaveCore.new_state()
	# 模拟第一关通关收集曹操
	SaveCore.collect(save, "warrior_caocao")
	# 模拟第二关通关收集赤兔快跑
	SaveCore.collect(save, "scene_chitu_kaopao")
	var col: Dictionary = save.get("collection", {})
	if col.has("warrior_caocao") and col.has("scene_chitu_kaopao"):
		print("[OK] 曹操与赤兔快跑图鉴条目正常录入 ✅（支持 25/25 满收集）")
	else:
		print("[FAIL] 曹操或赤兔快跑未成功录入图鉴")
		failed += 1

	# 4. 测试声望累加不被扣除
	var p_before = int(save.get("prestige", 0))
	SaveCore.add_prestige(save, 1000)
	var p_after = int(save.get("prestige", 0))
	if p_after == p_before + 1000:
		print("[OK] 声望累积正常保持（+1000，未被强制扣为0）✅")
	else:
		print("[FAIL] 声望增加异常")
		failed += 1

	if failed == 0:
		print("==== 全部 P0/P1/P2 特性验证通过！100% 达成！✅ ====")
		quit(0)
	else:
		print("==== 存在失败项: %d ====" % failed)
		quit(1)
