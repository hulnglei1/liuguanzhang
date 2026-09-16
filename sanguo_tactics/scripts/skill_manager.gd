class_name SkillManager
extends Node

const UnitData = preload("res://scripts/unit_data.gd")
const Unit = preload("res://scripts/unit.gd")
const GridManager = preload("res://scripts/grid_manager.gd")
const UnitManager = preload("res://scripts/unit_manager.gd")
const FXManager = preload("res://scripts/fx_manager.gd")

signal skill_used(skill_name: String, caster: Unit)
signal barrage_requested(text: String, color: Color)

# 1. 关羽：千里青龙斩
func execute_dragon_slash(guanyu: Unit, target_dir: Vector2i, grid_mgr: GridManager, unit_mgr: UnitManager, fx_mgr: FXManager) -> void:
	var charge = guanyu.data.dragon_charge
	var range_limit = 1
	var base_dmg = guanyu.data.atk

	if charge >= 10:
		range_limit = 16 # 全图无视阻挡贯穿！
		base_dmg = 9999
	elif charge >= 6:
		range_limit = 6
		base_dmg = int(guanyu.data.atk * 6.0)
	elif charge >= 3:
		range_limit = 3
		base_dmg = int(guanyu.data.atk * 2.5)
	else:
		range_limit = 1
		base_dmg = int(guanyu.data.atk * 1.0)

	var start_pos = guanyu.data.grid_pos
	var hit_units: Array[Unit] = []
	var laser_end_grid = start_pos

	for step in range(1, range_limit + 1):
		var check_cell = start_pos + target_dir * step
		if not grid_mgr.is_valid_cell(check_cell):
			break
		laser_end_grid = check_cell
		var u = unit_mgr.get_unit_at(check_cell)
		if u != null and u.data.faction == "enemy":
			hit_units.append(u)
			if charge < 10:
				# 蓄力未达天基大青龙时，被第一个敌方单位阻挡
				break

	# 播放全屏或直线青龙激光
	var from_w = grid_mgr.grid_to_world_center(start_pos)
	var to_w = grid_mgr.grid_to_world_center(laser_end_grid)
	fx_mgr.play_dragon_laser(from_w, to_w, charge)

	# 伤害结算
	for target in hit_units:
		target.take_damage(base_dmg)
		if charge >= 10:
			barrage_requested.emit("华雄：这是什么妖法？！一刀把城门都轰碎了？！", Color(1.0, 0.4, 0.4))
			barrage_requested.emit("曹操：云长之威，真乃天神下凡！酒...这酒甚至还烫手！", Color(1.0, 0.9, 0.2))

	# 清空关羽蓄力步数
	guanyu.data.dragon_charge = 0
	guanyu.update_visuals()
	skill_used.emit("千里青龙斩", guanyu)

# 2. 关羽：给马哥画饼
func execute_draw_pie(guanyu: Unit) -> void:
	var recover_amount = 60
	guanyu.data.horse_stamina = min(guanyu.data.max_horse_stamina, guanyu.data.horse_stamina + recover_amount)
	guanyu.data.is_exhausted = false
	guanyu.spawn_floating_text("🐴 马哥：为了三匹白母马！冲了！(+60体力)", Color(0.2, 1.0, 0.4))
	barrage_requested.emit("老马：二爷你最好说话算数，少一匹我立刻罢工！", Color(1.0, 0.8, 0.3))
	guanyu.update_visuals()
	skill_used.emit("给马哥画饼", guanyu)

# 3. 关羽：再退一米 (微调蓄力)
func execute_step_back(guanyu: Unit, grid_mgr: GridManager) -> bool:
	# 寻找可后退的空格
	var dirs = [Vector2i(-1, 0), Vector2i(0, -1), Vector2i(0, 1), Vector2i(1, 0)]
	for d in dirs:
		var back_cell = guanyu.data.grid_pos + d
		if grid_mgr.is_valid_cell(back_cell) and not grid_mgr.is_solid(back_cell):
			grid_mgr.set_unit_occupy(guanyu.data.grid_pos, false)
			guanyu.data.grid_pos = back_cell
			guanyu.position = grid_mgr.grid_to_world_center(back_cell)
			grid_mgr.set_unit_occupy(back_cell, true)
			
			guanyu.data.dragon_charge += 1
			guanyu.spawn_floating_text("🐴 马哥：？？又特么倒车？(+1龙气)", Color(1.0, 0.9, 0.2))
			guanyu.update_visuals()
			skill_used.emit("再退一米", guanyu)
			return true
	return false

# 4. 张飞：燕人咆哮 (范围音波震退 + 眩晕)
func execute_yanren_roar(zhangfei: Unit, grid_mgr: GridManager, unit_mgr: UnitManager, fx_mgr: FXManager) -> void:
	var center = zhangfei.data.grid_pos
	fx_mgr.play_sonic_shockwave(grid_mgr.grid_to_world_center(center))

	var enemies = unit_mgr.get_enemy_units()
	var hit_count = 0

	for enemy in enemies:
		var dist = abs(enemy.data.grid_pos.x - center.x) + abs(enemy.data.grid_pos.y - center.y)
		if dist <= 2:
			hit_count += 1
			# 造成 150 点音波伤害
			enemy.take_damage(150)
			# 挂上眩晕
			enemy.data.is_stunned = true

			# 计算击退方向向量
			var push_vec = enemy.data.grid_pos - center
			var push_dir = Vector2i.ZERO
			if abs(push_vec.x) >= abs(push_vec.y):
				push_dir = Vector2i(sign(push_vec.x), 0)
			else:
				push_dir = Vector2i(0, sign(push_vec.y))

			# 击退 2 格
			var current_target = enemy.data.grid_pos
			for _step in range(2):
				var next_cell = current_target + push_dir
				if grid_mgr.is_valid_cell(next_cell) and not grid_mgr.is_solid(next_cell) and unit_mgr.get_unit_at(next_cell) == null:
					current_target = next_cell
				else:
					break

			if current_target != enemy.data.grid_pos:
				grid_mgr.set_unit_occupy(enemy.data.grid_pos, false)
				enemy.data.grid_pos = current_target
				enemy.position = grid_mgr.grid_to_world_center(current_target)
				grid_mgr.set_unit_occupy(current_target, true)

			enemy.spawn_floating_text("💥 震碎耳膜！击退+眩晕！", Color(1.0, 0.8, 0.1))
			enemy.update_visuals()

	barrage_requested.emit("张飞：俺老张这一嗓子，问你顶不顶得住！", Color(0.3, 0.7, 1.0))
	skill_used.emit("燕人咆哮", zhangfei)

# 5. 张飞：挑衅肉盾
func execute_taunt(zhangfei: Unit) -> void:
	zhangfei.data.is_taunting = true
	zhangfei.spawn_floating_text("🛡️ 燕人挑衅开启！减伤50%！强制拉仇恨！", Color(1.0, 0.85, 0.2))
	zhangfei.update_visuals()
	skill_used.emit("挑衅肉盾", zhangfei)

# 6. 刘备：医学生急救
func execute_heal(liubei: Unit, target: Unit, fx_mgr: FXManager, grid_mgr: GridManager) -> void:
	fx_mgr.play_heal_sparkle(grid_mgr.grid_to_world_center(target.data.grid_pos))
	target.heal(180)
	barrage_requested.emit("刘备：略懂一点医术，伤口缝合就不用麻药了吧？", Color(0.4, 1.0, 0.4))
	skill_used.emit("医学生急救", liubei)

# 7. 刘备被动：厚颜分摊 (受击判定)
func check_liubei_passive(liubei: Unit, attacker: Unit, raw_dmg: int, unit_mgr: UnitManager, grid_mgr: GridManager) -> int:
	var zhangfei = unit_mgr.get_unit_by_id("zhangfei")
	if zhangfei != null and is_instance_valid(zhangfei):
		var dist = abs(liubei.data.grid_pos.x - zhangfei.data.grid_pos.x) + abs(liubei.data.grid_pos.y - zhangfei.data.grid_pos.y)
		if dist <= 2:
			# 张飞承担 70% 伤害
			var zf_part = int(raw_dmg * 0.7)
			zhangfei.take_damage(zf_part)
			zhangfei.spawn_floating_text("🛡️ 替大哥挡刀！(-%d)" % zf_part, Color(1.0, 0.8, 0.3))

			# 刘备只承受 30%，并反向逃跑 2 格！
			var lb_part = int(raw_dmg * 0.3)
			var flee_dir = Vector2i(sign(liubei.data.grid_pos.x - attacker.data.grid_pos.x), sign(liubei.data.grid_pos.y - attacker.data.grid_pos.y))
			if flee_dir == Vector2i.ZERO:
				flee_dir = Vector2i(-1, 0)

			var flee_target = liubei.data.grid_pos
			for _i in range(2):
				var next_c = flee_target + flee_dir
				if grid_mgr.is_valid_cell(next_c) and not grid_mgr.is_solid(next_c) and unit_mgr.get_unit_at(next_c) == null:
					flee_target = next_c
			
			if flee_target != liubei.data.grid_pos:
				grid_mgr.set_unit_occupy(liubei.data.grid_pos, false)
				liubei.data.grid_pos = flee_target
				liubei.position = grid_mgr.grid_to_world_center(flee_target)
				grid_mgr.set_unit_occupy(flee_target, true)

			liubei.spawn_floating_text("🏃 三弟救我！(厚颜反向逃跑)", Color(1.0, 1.0, 0.4))
			barrage_requested.emit("诸侯联军：刘备这跑路速度，刘翔看了都得递烟！", Color(1.0, 0.9, 0.2))
			return lb_part

	return raw_dmg

# 8. 赵云骑乘合体
func execute_ride_zhaoyun(unit_mgr: UnitManager) -> bool:
	var success = unit_mgr.combine_guan_and_zhao()
	if success:
		barrage_requested.emit("赵云：二哥坐稳了！人肉高铁正式发车！", Color(0.2, 1.0, 0.9))
		barrage_requested.emit("诸侯们全看傻了：骑马见多了，骑赵云是什么兵种？！", Color(1.0, 0.9, 0.3))
	return success
