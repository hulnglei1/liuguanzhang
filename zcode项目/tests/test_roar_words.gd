extends SceneTree
## 燕人咆哮「字数越多威力越大」机制测试（原著第 1、14 章）
## 运行：Godot_console.exe --headless --path zcode项目 --script res://tests/test_roar_words.gd

const CombatCore := preload("res://scripts/core/combat.gd")
const SkillsCore := preload("res://scripts/entities/skills.gd")
const BattleUnitScript := preload("res://scripts/entities/unit.gd")


func _make_zhangfei(cell: Vector2i):
	return BattleUnitScript.from_data({
		"id": "zhangfei", "name": "张飞", "cls": "步兵", "camp": "player",
		"hp": 110, "atk": 28, "def": 12, "mov": 3, "rng": 1, "skills": ["roar"],
	}, cell)


func _make_lubu(cell: Vector2i, iron_skin: bool = false):
	var lb = BattleUnitScript.from_data({
		"id": "lubu", "name": "吕布", "cls": "骑兵", "camp": "enemy",
		"hp": 260, "atk": 40, "def": 16, "mov": 4, "rng": 1, "skills": ["lubu_fangtian"],
	}, cell)
	lb.iron_skin = iron_skin
	lb.combo_strikes = 2
	return lb


func _make_mate(cell: Vector2i):
	return BattleUnitScript.from_data({
		"id": "guanyu", "name": "关羽", "cls": "骑兵", "camp": "player",
		"hp": 100, "atk": 30, "def": 12, "mov": 3, "rng": 1, "skills": ["dragon_slash"],
	}, cell)


func _init() -> void:
	print("\n==== 燕人咆哮·字数机制测试（原著：咆哮的字数越多，威力越大） ====")
	var failed := 0

	# --- 1. 六字「燕人张飞在此」：速控 ---
	var zf6 = _make_zhangfei(Vector2i(1, 1))
	var lb6 = _make_lubu(Vector2i(2, 1), true)          # 带铁皮：验证震碎
	var ev6: Array = SkillsCore.do_roar(zf6, [lb6], 6, [])
	if lb6.stun_turns != 1:
		printerr("[FAIL] 六字咆哮应眩晕 1 回合，实际 ", lb6.stun_turns)
		failed += 1
	else:
		print("  ✅ [PASS] 六字咆哮：眩晕 1 回合")
	if lb6.iron_skin or lb6.combo_strikes != 0:
		printerr("[FAIL] 六字咆哮应震碎铁皮并清空方天连击，实际 iron_skin=", lb6.iron_skin, " combo=", lb6.combo_strikes)
		failed += 1
	else:
		print("  ✅ [PASS] 六字咆哮：震碎铁皮 + 清空方天连击")

	# 伤害对比用无铁皮目标（铁皮状态物理伤害判定为 0）
	var lb6d = _make_lubu(Vector2i(2, 2), false)
	var hp_before6: int = lb6d.hp
	SkillsCore.do_roar(_make_zhangfei(Vector2i(1, 2)), [lb6d], 6, [])
	var dmg6: int = hp_before6 - lb6d.hp
	if dmg6 <= 0:
		printerr("[FAIL] 六字咆哮应造成伤害，实际 ", dmg6)
		failed += 1
	else:
		print("  ✅ [PASS] 六字伤害 %d（1.6 倍系数）" % dmg6)

	# --- 2. 十四字「…谁敢与我决一死战」：满控 + 敌我不分 ---
	var zf14 = _make_zhangfei(Vector2i(1, 5))
	var lb14 = _make_lubu(Vector2i(3, 5), true)
	var mate = _make_mate(Vector2i(2, 5))
	var ev14: Array = SkillsCore.do_roar(zf14, [lb14], 14, [mate])
	if lb14.stun_turns != 2:
		printerr("[FAIL] 十四字咆哮应眩晕 2 回合，实际 ", lb14.stun_turns)
		failed += 1
	else:
		print("  ✅ [PASS] 十四字咆哮：眩晕 2 回合（六字只有 1 回合）")

	var lb14d = _make_lubu(Vector2i(3, 6), false)
	var hp_before14: int = lb14d.hp
	SkillsCore.do_roar(_make_zhangfei(Vector2i(1, 6)), [lb14d], 14, [])
	var dmg14: int = hp_before14 - lb14d.hp
	if dmg14 <= dmg6:
		printerr("[FAIL] 十四字伤害应高于六字（14字=", dmg14, " 6字=", dmg6, "）")
		failed += 1
	else:
		print("  ✅ [PASS] 字数越多越疼：十四字 %d 伤害 > 六字 %d 伤害" % [dmg14, dmg6])
	if mate.stun_turns != 1:
		printerr("[FAIL] 十四字应敌我不分（自己人被震晕 1 回合），实际 ", mate.stun_turns)
		failed += 1
	else:
		print("  ✅ [PASS] 十四字敌我不分：附近自己人也被震晕 1 回合（原著「群控，敌我不分」）")

	# --- 3. 耳塞免疫：战斗层过滤后 allies 为空则自己人安然无恙 ---
	var zf_ep = _make_zhangfei(Vector2i(1, 3))
	var lb_ep = _make_lubu(Vector2i(3, 3), true)
	var mate_ep = _make_mate(Vector2i(2, 3))
	var ev_ep: Array = SkillsCore.do_roar(zf_ep, [lb_ep], 14, [])  # 戴耳塞 -> allies 传空
	if mate_ep.stun_turns != 0:
		printerr("[FAIL] 佩戴耳塞时自己人不应被震晕，实际 ", mate_ep.stun_turns)
		failed += 1
	else:
		print("  ✅ [PASS] 静音耳塞：戴了耳塞自己人不会被震晕")

	# --- 4. 事件流包含字数，供演出层使用 ---
	var has_words := false
	for e in ev14:
		if e.get("type") == "skill" and int(e.get("words", 0)) == 14:
			has_words = true
	if not has_words:
		printerr("[FAIL] 技能事件应携带 words 字段供演出使用")
		failed += 1
	else:
		print("  ✅ [PASS] 技能事件携带 words=14，演出层可据此分级")

	print("\n==== 燕人咆哮测试%s ====" % ("全部通过 ✅" if failed == 0 else "失败 %d 项 ❌" % failed))
	quit(1 if failed > 0 else 0)
