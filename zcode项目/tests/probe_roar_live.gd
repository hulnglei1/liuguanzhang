extends SceneTree
## 燕人咆哮「喊字」交互链路集成验证（真实加载第二关战斗场景）
## 运行：Godot_console.exe --headless --path zcode项目 --script res://tests/probe_roar_live.gd

const BattleScript := preload("res://scripts/battle.gd")
const SaveCore := preload("res://scripts/systems/save.gd")


func _initialize() -> void:
	var s: Dictionary = SaveCore.load_state()
	s["chapters"] = ["chapter1"]
	s["prologues_seen"] = ["chapter1", "chapter2"]
	s["inventory"] = {}
	SaveCore.save_state(s)
	BattleScript.chapter_id = "chapter2"
	change_scene_to_file("res://scenes/battle.tscn")
	_run()


func _wait(x: float) -> void:
	await create_timer(x).timeout


func _run() -> void:
	await _wait(2.5)
	var b = current_scene
	if b.has_method("_on_dialog_skip_pressed"):
		b._on_dialog_skip_pressed()
	await _wait(0.6)

	var zf = b._unit_by_id("zhangfei")
	if zf == null:
		printerr("[FAIL] 未找到张飞")
		quit(1)
		return
	var lb0 = b._unit_by_id("lubu")
	# 原著里张飞是冲到吕布面前才吼的（「这次离得太近了」）——先把张飞挪到吕布身旁
	zf.cell = Vector2i(maxi(0, lb0.cell.x - 2), lb0.cell.y)
	print("[咆哮] 张飞已前压至 %s（吕布 %s），距离 %d 格" % [str(zf.cell), str(lb0.cell), absi(zf.cell.x - lb0.cell.x)])
	b.selected_id = "zhangfei"
	b._start_roar_charging(zf)
	print("[咆哮] 点技能后进入喊字状态: words=%d input_mode=%d" % [b.roar_words, b.input_mode])

	for i in range(4):
		b._add_roar_word()
	print("[咆哮] 连点 4 次 -> words=%d（期望 10）" % b.roar_words)

	# 继续连点到满，触发自动释放
	for i in range(6):
		b._add_roar_word()
	await _wait(2.5)

	var lb = b._unit_by_id("lubu")
	print("[咆哮] 释放后 吕布: 眩晕=%d 铁皮=%s 连击=%d HP=%d/%d" % [
		lb.stun_turns, str(lb.iron_skin), lb.combo_strikes, lb.hp, lb.max_hp])

	var mates: Array[String] = []
	for u in b.units:
		if u.camp == "player" and u.id != "zhangfei":
			mates.append("%s(stun=%d)" % [u.id, u.stun_turns])
	print("[咆哮] 我方是否被敌我不分波及: ", ", ".join(mates))

	# 耳塞验证：写入耳塞后重放
	var s2: Dictionary = SaveCore.load_state()
	s2["inventory"] = {"earplug": 1}
	SaveCore.save_state(s2)
	for u in b.units:
		u.stun_turns = 0
	lb.stun_turns = 0
	b.selected_id = "zhangfei"
	b._start_roar_charging(zf)
	for i in range(10):
		b._add_roar_word()
	await _wait(2.5)
	var mates2: Array[String] = []
	for u in b.units:
		if u.camp == "player" and u.id != "zhangfei":
			mates2.append("%s(stun=%d)" % [u.id, u.stun_turns])
	print("[咆哮] 戴耳塞后我方状态: ", ", ".join(mates2), " | 吕布眩晕=", lb.stun_turns)
	quit(0)
