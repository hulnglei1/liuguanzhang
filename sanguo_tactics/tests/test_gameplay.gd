extends SceneTree

const MainScene = preload("res://scenes/Main.tscn")

func _init() -> void:
	print("==================================================")
	print("  【三国战棋 MVP 自动化逻辑与剧情回归测试开始】  ")
	print("==================================================")
	
	var main_node = MainScene.instantiate()
	root.add_child(main_node)

	# 等待一帧让所有节点的 _ready 完成
	await process_frame

	print("[Step 1] 验证战场初始单位生成...")
	var unit_mgr = main_node.unit_manager
	var grid_mgr = main_node.grid_manager
	var turn_mgr = main_node.turn_manager
	var skill_mgr = main_node.skill_manager
	var ui_layer = main_node.ui_layer

	var guanyu = unit_mgr.get_unit_by_id("guanyu")
	var zhangfei = unit_mgr.get_unit_by_id("zhangfei")
	var liubei = unit_mgr.get_unit_by_id("liubei")
	var huaxiong = unit_mgr.get_boss()

	assert(guanyu != null, "关羽未能生成！")
	assert(zhangfei != null, "张飞未能生成！")
	assert(liubei != null, "刘备未能生成！")
	assert(huaxiong != null, "华雄未能生成！")
	print(" -> 关羽位置: %s, 初始HP: %d, 马哥体力: %d" % [guanyu.data.grid_pos, guanyu.data.current_hp, guanyu.data.horse_stamina])
	print(" -> 张飞位置: %s, 初始HP: %d, 怒气: %d" % [zhangfei.data.grid_pos, zhangfei.data.current_hp, zhangfei.data.rage])
	print(" -> 华雄位置: %s, 初始HP: %d, 攻击: %d" % [huaxiong.data.grid_pos, huaxiong.data.current_hp, huaxiong.data.atk])

	print("[Step 2] 验证开场剧情跳过与回合启动...")
	# 模拟玩家点击跳过开场剧情
	turn_mgr._on_dialogue_finished()
	print(" -> 当前回合状态: %s, 当前回合数: %d" % [turn_mgr.current_phase, turn_mgr.current_turn])
	assert(turn_mgr.current_phase == "player", "未正常进入玩家回合！")

	print("[Step 3] 验证关羽跑马道移动与龙气蓄力机制...")
	# 关羽初始在 (1, 1)，沿跑马道移动到 (3, 1)
	var path: Array[Vector2i] = [Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1)]
	grid_mgr.set_unit_occupy(guanyu.data.grid_pos, false)
	await guanyu.move_along_path(path, grid_mgr)
	grid_mgr.set_unit_occupy(guanyu.data.grid_pos, true)
	print(" -> 关羽移动后位置: %s, 龙气蓄力: %d 层, 马哥体力: %d" % [guanyu.data.grid_pos, guanyu.data.dragon_charge, guanyu.data.horse_stamina])
	assert(guanyu.data.dragon_charge == 4, "跑马道每格应蓄力2点，2步应为4层！实际为: %d" % guanyu.data.dragon_charge)
	assert(guanyu.data.horse_stamina == 80, "移动2步马哥体力应减少20！实际为: %d" % guanyu.data.horse_stamina)

	print("[Step 4] 验证关羽专属技能【给马哥画饼】...")
	skill_mgr.execute_draw_pie(guanyu)
	print(" -> 画饼后马哥体力: %d" % guanyu.data.horse_stamina)
	assert(guanyu.data.horse_stamina >= 100, "画饼应回复60体力至上限！")

	print("[Step 5] 验证关羽专属技能【再退一米】(+1龙气)...")
	var prev_charge = guanyu.data.dragon_charge
	var stepped = skill_mgr.execute_step_back(guanyu, grid_mgr)
	print(" -> 倒车成功: %s, 当前龙气: %d" % [stepped, guanyu.data.dragon_charge])
	assert(guanyu.data.dragon_charge == prev_charge + 1, "倒车应增加1点龙气！")

	print("[Step 6] 验证张飞专属绝技【燕人咆哮】(音波+击退+眩晕)...")
	# 将敌方前锋放置在张飞周围2格范围内测试咆哮
	var cav1 = unit_mgr.get_unit_by_id("cavalry_1")
	cav1.data.grid_pos = Vector2i(4, 5)
	var prev_cav_hp = cav1.data.current_hp
	skill_mgr.execute_yanren_roar(zhangfei, grid_mgr, unit_mgr, main_node.fx_manager)
	print(" -> 铁骑受击后HP: %d (原%d), 眩晕状态: %s" % [cav1.data.current_hp, prev_cav_hp, cav1.data.is_stunned])
	assert(cav1.data.current_hp < prev_cav_hp, "燕人咆哮应造成音波伤害！")
	assert(cav1.data.is_stunned == true, "被咆哮击中敌军应陷入眩晕！")

	print("[Step 7] 验证刘备专属技能【医学生急救】与被动【厚颜分摊】...")
	cav1.take_damage(50)
	var hurt_hp = cav1.data.current_hp
	skill_mgr.execute_heal(liubei, cav1, main_node.fx_manager, grid_mgr)
	print(" -> 治疗后目标HP: %d (原%d)" % [cav1.data.current_hp, hurt_hp])
	assert(cav1.data.current_hp > hurt_hp, "急救应恢复目标生命值！")

	# 测试厚颜分摊
	var raw_atk = 100
	var zf_prev_hp = zhangfei.data.current_hp
	var lb_damage = skill_mgr.check_liubei_passive(liubei, huaxiong, raw_atk, unit_mgr, grid_mgr)
	print(" -> 华雄100伤害攻击刘备，张飞代抗70点后HP: %d, 刘备实受: %d" % [zhangfei.data.current_hp, lb_damage])
	assert(zhangfei.data.current_hp < zf_prev_hp, "张飞应承担70%分摊伤害！")

	print("[Step 8] 验证赵云援军登场与【关赵巡洋舰】骑乘合体...")
	var zhaoyun = unit_mgr.spawn_zhaoyun()
	assert(zhaoyun != null, "赵云未能成功生成！")
	print(" -> 赵云登场成功！移动力: %d" % zhaoyun.data.move_range)
	var combo_success = unit_mgr.combine_guan_and_zhao()
	assert(combo_success == true, "合体失败！")
	print(" -> 合体成功！关羽新称号: %s, 移动力: %d, 免马哥体力: %s" % [guanyu.data.title, guanyu.data.move_range, guanyu.data.is_piggybacking])
	assert(guanyu.data.move_range == 7, "关赵合体应继承赵云7格移动！")

	print("[Step 9] 验证关羽十层蓄力【天基大青龙】全图贯穿斩杀华雄...")
	guanyu.data.dragon_charge = 10
	guanyu.data.grid_pos = Vector2i(1, 4)
	huaxiong.data.grid_pos = Vector2i(13, 4)
	print(" -> 关羽蓄力达 10 层！释放天基大青龙贯穿全图！")
	skill_mgr.execute_dragon_slash(guanyu, Vector2i(1, 0), grid_mgr, unit_mgr, main_node.fx_manager)
	print(" -> 华雄承受9999点核武伤害，当前HP: %d" % huaxiong.data.current_hp)
	assert(huaxiong.data.current_hp <= 0, "天基大青龙必须瞬间秒杀华雄！")

	print("[Step 10] 验证战后占领东海郡霸业抽奖...")
	ui_layer.show_gacha_screen()
	ui_layer._on_gacha_draw_clicked()
	var card_count = ui_layer.gacha_result_box.get_child_count()
	print(" -> 霸业抽奖成功！抽取卡牌数: %d" % card_count)
	assert(card_count == 4, "应抽取4张跨次元霸业卡牌！")

	print("==================================================")
	print("  🎉🎉🎉 所有核心机制、技能与流程自动化测试全部通过！ 🎉🎉🎉")
	print("==================================================")
	
	main_node.free()
	quit(0)
