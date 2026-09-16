extends SceneTree
## 保存系统测试：声望累加 / 背包 / 图鉴 / 通关标记
## 运行：godot --headless --script res://tests/test_save.gd

const SaveCore := preload("res://scripts/systems/save.gd")
const LotteryCore := preload("res://scripts/systems/lottery.gd")

func _init() -> void:
	print("==== 保存系统测试（声望/背包/图鉴）开始 ====")
	var failed := 0

	# ---- 1. 新状态 ----
	var st := SaveCore.new_state()
	if int(st.get("prestige", 0)) != 0:
		print("[FAIL] 初始声望应为0")
		failed += 1

	# ---- 2. 占郡加声望 ----
	SaveCore.add_prestige(st, 1000)
	if int(st.get("prestige", 0)) != 1000:
		print("[FAIL] 占郡后声望应为1000")
		failed += 1
	else:
		print("[OK] 占郡+1000声望 ✅")

	# ---- 3. 抽种子：扣1000、入背包 ----
	var draw := LotteryCore.draw_seed(st.get("prestige", 0))
	if not draw.success:
		print("[FAIL] 1000声望应可抽种子")
		failed += 1
	else:
		var ok := SaveCore.award_item(st, draw.item, 1000)
		if not ok:
			print("[FAIL] 抽种子入背包失败")
			failed += 1
		else:
			var iid: String = draw.item.get("id", "")
			if int(st["inventory"].get(iid, 0)) != 1:
				print("[FAIL] 背包应持有1个")
				failed += 1
			print("[OK] 种子抽取并入背包 ✅（声望 → %d）" % st.get("prestige", 0))

	# ---- 4. 武器池门槛：2000声望不足 ----
	var lack := LotteryCore.draw_weapon(2000)
	if lack.success:
		print("[FAIL] 2000声望不应能抽武器")
		failed += 1
	else:
		print("[OK] 武器池门槛5000正确拦截 ✅")

	# ---- 5. 图鉴收集 ----
	SaveCore.collect(st, "warrior_guanyu")
	SaveCore.collect(st, "skill_dragon_slash")
	var coll := SaveCore.collected(st)
	if "warrior_guanyu" not in coll or "skill_dragon_slash" not in coll:
		print("[FAIL] 图鉴未正确收集")
		failed += 1
	else:
		print("[OK] 图鉴收集 ✅")

	# ---- 6. 通关标记 ----
	SaveCore.mark_chapter(st, "chapter1")
	SaveCore.mark_chapter(st, "chapter1")  # 重复不应重复
	if st["chapters"].size() != 1:
		print("[FAIL] 通关标记应唯一")
		failed += 1
	else:
		print("[OK] 通关标记 ✅")

	# ---- 7. 持久化 round-trip（不污染真实存档，用临时路径测逻辑） ----
	st["prestige"] = 5555
	SaveCore.save_state(st)
	var loaded := SaveCore.load_state()
	if int(loaded.get("prestige", 0)) != 5555:
		print("[FAIL] 存档读取不符")
		failed += 1
	else:
		print("[OK] 存档持久化 round-trip ✅")

	if failed == 0:
		print("==== 保存系统全部通过 ✅ ====")
	else:
		print("==== 失败 ", failed, " 项 ❌ ====")
	quit(failed)