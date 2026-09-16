class_name TurnManager
extends Node

const UnitData = preload("res://scripts/unit_data.gd")
const Unit = preload("res://scripts/unit.gd")
const GridManager = preload("res://scripts/grid_manager.gd")
const UnitManager = preload("res://scripts/unit_manager.gd")
const SkillManager = preload("res://scripts/skill_manager.gd")
const FXManager = preload("res://scripts/fx_manager.gd")
const UIManager = preload("res://scripts/ui_manager.gd")

enum State {
	DIALOGUE,
	PLAYER_STANDBY,
	PLAYER_MOVE_SELECT,
	PLAYER_MOVING,
	PLAYER_ACTION_SELECT,
	PLAYER_TARGET_SELECT,
	ENEMY_TURN,
	GAME_OVER
}

var current_state: State = State.DIALOGUE
var current_turn: int = 1
var current_phase: String = "player"

var selected_unit: Unit = null
var current_reachable_cells: Array[Vector2i] = []
var pending_action: String = ""
var zhaoyun_spawned: bool = false

var grid_mgr: GridManager
var unit_mgr: UnitManager
var skill_mgr: SkillManager
var fx_mgr: FXManager
var ui_mgr: UIManager

func setup(p_grid: GridManager, p_unit: UnitManager, p_skill: SkillManager, p_fx: FXManager, p_ui: UIManager) -> void:
	grid_mgr = p_grid
	unit_mgr = p_unit
	skill_mgr = p_skill
	fx_mgr = p_fx
	ui_mgr = p_ui

	ui_mgr.action_chosen.connect(_on_ui_action_chosen)
	ui_mgr.end_turn_pressed.connect(_on_ui_end_turn_pressed)
	ui_mgr.dialogue_finished.connect(_on_dialogue_finished)
	ui_mgr.restart_requested.connect(_on_restart_requested)

	# 启动开场剧情
	_play_opening_cutscene()

func _play_opening_cutscene() -> void:
	current_state = State.DIALOGUE
	var opening_lines = [
		{"speaker": "华雄", "avatar": "华", "color": Color(0.9, 0.2, 0.2), "text": "某乃西凉大都督华雄！方才俞涉、潘凤皆被某一合斩杀！关东十九路诸侯尽是土鸡瓦狗！谁敢与我一战？！"},
		{"speaker": "曹操", "avatar": "曹", "color": Color(0.9, 0.8, 0.3), "text": "云长真壮士也！且饮此温酒，再去斩华雄不迟！"},
		{"speaker": "关羽", "avatar": "关", "color": Color(0.2, 0.9, 0.4), "text": "开车不喝酒，喝酒不开车！马哥，溜！去外围跑马道先跑十圈热热身！"},
		{"speaker": "袁绍", "avatar": "袁", "color": Color(0.9, 0.7, 0.2), "text": "逃兵？！大敌当前，他居然骑着马往反方向溜圈？！成何体统！"},
		{"speaker": "张飞", "avatar": "张", "color": Color(0.3, 0.6, 1.0), "text": "大哥莫慌！二哥这是在憋大招！俺老张先顶在前面，一嗓子震碎华雄的狗胆！"}
	]
	ui_mgr.play_dialogue(opening_lines)

func _on_dialogue_finished() -> void:
	if current_state == State.DIALOGUE:
		start_player_turn()

func start_player_turn() -> void:
	current_phase = "player"
	current_state = State.PLAYER_STANDBY

	# 检查第3回合赵云救驾
	if current_turn == 3 and not zhaoyun_spawned:
		zhaoyun_spawned = true
		_play_zhaoyun_cutscene()
		return

	# 重置我方行动标记
	for u in unit_mgr.get_player_units():
		u.data.has_acted = false
		u.update_visuals()

	ui_mgr.update_turn_info(current_turn, "player")

func _play_zhaoyun_cutscene() -> void:
	current_state = State.DIALOGUE
	unit_mgr.spawn_zhaoyun()
	var lines = [
		{"speaker": "赵云", "avatar": "赵", "color": Color(0.2, 0.8, 1.0), "text": "吾乃常山赵子龙也！二哥休慌，马哥累了就上我肩膀！子龙牌人肉高铁，机动全图直达！"},
		{"speaker": "关羽", "avatar": "关", "color": Color(0.2, 0.9, 0.4), "text": "子龙来得正好！骑乘合体，青龙斩直接提速！"}
	]
	ui_mgr.play_dialogue(lines)

func handle_cell_click(grid_pos: Vector2i) -> void:
	match current_state:
		State.PLAYER_STANDBY:
			_handle_standby_click(grid_pos)
		State.PLAYER_MOVE_SELECT:
			_handle_move_select_click(grid_pos)
		State.PLAYER_TARGET_SELECT:
			_handle_target_select_click(grid_pos)

func _handle_standby_click(grid_pos: Vector2i) -> void:
	var clicked_unit = unit_mgr.get_unit_at(grid_pos)
	if clicked_unit != null:
		ui_mgr.show_unit_info(clicked_unit)
		if clicked_unit.data.faction == "player" and not clicked_unit.data.has_acted:
			_select_unit_for_move(clicked_unit)
	else:
		_deselect_unit()

func _select_unit_for_move(unit: Unit) -> void:
	selected_unit = unit
	selected_unit.is_selected = true
	
	# 收集除自身外所有占位阻挡
	var occupied: Array[Vector2i] = []
	for u in unit_mgr.get_all_units():
		if u != selected_unit:
			occupied.append(u.data.grid_pos)

	current_reachable_cells = grid_mgr.get_reachable_cells(selected_unit.data.grid_pos, selected_unit.data.move_range, occupied)
	current_reachable_cells.append(selected_unit.data.grid_pos) # 允许原地待命
	
	grid_mgr.set_move_highlights(current_reachable_cells)
	current_state = State.PLAYER_MOVE_SELECT

func _handle_move_select_click(grid_pos: Vector2i) -> void:
	if not current_reachable_cells.has(grid_pos):
		# 点击了非法格子，取消选择或切换其他武将
		var other_unit = unit_mgr.get_unit_at(grid_pos)
		if other_unit != null and other_unit.data.faction == "player" and not other_unit.data.has_acted:
			_deselect_unit()
			_select_unit_for_move(other_unit)
		else:
			_deselect_unit()
		return

	# 执行移动
	current_state = State.PLAYER_MOVING
	grid_mgr.clear_highlights()

	if grid_pos != selected_unit.data.grid_pos:
		var path = grid_mgr.get_path_cells(selected_unit.data.grid_pos, grid_pos)
		grid_mgr.set_unit_occupy(selected_unit.data.grid_pos, false)
		await selected_unit.move_along_path(path, grid_mgr)
		grid_mgr.set_unit_occupy(selected_unit.data.grid_pos, true)

	# 移动结束，弹出行动菜单
	current_state = State.PLAYER_ACTION_SELECT
	var can_ride = false
	var zhao = unit_mgr.get_unit_by_id("zhaoyun")
	if zhao != null and selected_unit.data.id == "guanyu":
		var dist = abs(selected_unit.data.grid_pos.x - zhao.data.grid_pos.x) + abs(selected_unit.data.grid_pos.y - zhao.data.grid_pos.y)
		if dist <= 2:
			can_ride = true

	ui_mgr.show_action_menu(selected_unit, can_ride)
	ui_mgr.show_unit_info(selected_unit)

func _on_ui_action_chosen(action: String) -> void:
	if current_state != State.PLAYER_ACTION_SELECT and current_state != State.PLAYER_TARGET_SELECT:
		return

	match action:
		"attack":
			# 普通近战攻击
			_prepare_basic_attack()
		"dragon":
			# 关羽青龙大招
			_prepare_dragon_slash()
		"pie":
			# 给马哥画饼
			skill_mgr.execute_draw_pie(selected_unit)
			_finish_unit_turn()
		"stepback":
			# 再退一米
			skill_mgr.execute_step_back(selected_unit, grid_mgr)
			_finish_unit_turn()
		"roar":
			# 张飞燕人咆哮
			skill_mgr.execute_yanren_roar(selected_unit, grid_mgr, unit_mgr, fx_mgr)
			_finish_unit_turn()
		"taunt":
			# 张飞挑衅
			skill_mgr.execute_taunt(selected_unit)
			_finish_unit_turn()
		"heal":
			# 刘备急救
			_execute_liubei_heal()
		"ride":
			# 赵云合体
			skill_mgr.execute_ride_zhaoyun(unit_mgr)
			_finish_unit_turn()
		"wait":
			# 待命
			_finish_unit_turn()

func _prepare_basic_attack() -> void:
	pending_action = "attack"
	current_state = State.PLAYER_TARGET_SELECT
	ui_mgr.hide_action_menu()

	# 高亮周围 1 格的敌方单位
	var attack_cells: Array[Vector2i] = []
	var neighbors = [
		selected_unit.data.grid_pos + Vector2i(1, 0),
		selected_unit.data.grid_pos + Vector2i(-1, 0),
		selected_unit.data.grid_pos + Vector2i(0, 1),
		selected_unit.data.grid_pos + Vector2i(0, -1)
	]
	for c in neighbors:
		var u = unit_mgr.get_unit_at(c)
		if u != null and u.data.faction == "enemy":
			attack_cells.append(c)

	if attack_cells.is_empty():
		selected_unit.spawn_floating_text("相邻无敌人！", Color(1.0, 0.4, 0.4))
		current_state = State.PLAYER_ACTION_SELECT
		ui_mgr.show_action_menu(selected_unit)
		return

	grid_mgr.set_attack_highlights(attack_cells)

func _prepare_dragon_slash() -> void:
	pending_action = "dragon"
	current_state = State.PLAYER_TARGET_SELECT
	ui_mgr.hide_action_menu()

	# 关羽千里青龙斩：高亮四方向激光路径供选择
	var dirs = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var laser_cells: Array[Vector2i] = []
	var max_step = 16 if selected_unit.data.dragon_charge >= 10 else 6

	for d in dirs:
		for s in range(1, max_step + 1):
			var c = selected_unit.data.grid_pos + d * s
			if grid_mgr.is_valid_cell(c):
				laser_cells.append(c)
			else:
				break

	grid_mgr.set_laser_highlights(laser_cells)
	selected_unit.spawn_floating_text("请点击目标方向释放青龙斩！", Color(0.2, 1.0, 0.6))

func _execute_liubei_heal() -> void:
	# 寻找相邻掉血友军或自身
	var allies = unit_mgr.get_player_units()
	var healed_any = false
	for ally in allies:
		var dist = abs(ally.data.grid_pos.x - selected_unit.data.grid_pos.x) + abs(ally.data.grid_pos.y - selected_unit.data.grid_pos.y)
		if dist <= 2 and ally.data.current_hp < ally.data.max_hp:
			skill_mgr.execute_heal(selected_unit, ally, fx_mgr, grid_mgr)
			healed_any = true
			break

	if not healed_any:
		skill_mgr.execute_heal(selected_unit, selected_unit, fx_mgr, grid_mgr)

	_finish_unit_turn()

func _handle_target_select_click(grid_pos: Vector2i) -> void:
	grid_mgr.clear_highlights()
	if pending_action == "attack":
		var target = unit_mgr.get_unit_at(grid_pos)
		if target != null and target.data.faction == "enemy":
			fx_mgr.play_slash_fx(grid_mgr.grid_to_world_center(grid_pos))
			target.take_damage(selected_unit.data.atk)
			_finish_unit_turn()
		else:
			current_state = State.PLAYER_ACTION_SELECT
			ui_mgr.show_action_menu(selected_unit)

	elif pending_action == "dragon":
		# 计算方向向量
		var diff = grid_pos - selected_unit.data.grid_pos
		var dir = Vector2i.ZERO
		if abs(diff.x) >= abs(diff.y):
			dir = Vector2i(sign(diff.x), 0)
		else:
			dir = Vector2i(0, sign(diff.y))
		
		if dir != Vector2i.ZERO:
			skill_mgr.execute_dragon_slash(selected_unit, dir, grid_mgr, unit_mgr, fx_mgr)
			_finish_unit_turn()
		else:
			current_state = State.PLAYER_ACTION_SELECT
			ui_mgr.show_action_menu(selected_unit)

func _finish_unit_turn() -> void:
	ui_mgr.hide_action_menu()
	grid_mgr.clear_highlights()
	
	if selected_unit != null:
		selected_unit.data.has_acted = true
		selected_unit.is_selected = false
		selected_unit.update_visuals()

	selected_unit = null
	current_state = State.PLAYER_STANDBY

	# 检查胜负
	_check_battle_status()

func _on_ui_end_turn_pressed() -> void:
	if current_state == State.PLAYER_STANDBY or current_state == State.PLAYER_ACTION_SELECT:
		_deselect_unit()
		_start_enemy_turn()

func _deselect_unit() -> void:
	if selected_unit != null:
		selected_unit.is_selected = false
		selected_unit.update_visuals()
		selected_unit = null
	grid_mgr.clear_highlights()
	ui_mgr.hide_action_menu()
	current_state = State.PLAYER_STANDBY

# 敌人 AI 回合调度
func _start_enemy_turn() -> void:
	current_phase = "enemy"
	current_state = State.ENEMY_TURN
	ui_mgr.update_turn_info(current_turn, "enemy")

	var enemies = unit_mgr.get_enemy_units()

	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy.data.current_hp <= 0:
			continue

		# 眩晕判定
		if enemy.data.is_stunned:
			enemy.data.is_stunned = false
			enemy.spawn_floating_text("💫 耳鸣眩晕中，原地无法动弹！", Color(1.0, 0.8, 0.2))
			enemy.update_visuals()
			await get_tree().create_timer(0.4).timeout
			continue

		# AI 执行移动与攻击
		await _execute_enemy_ai(enemy)
		await get_tree().create_timer(0.3).timeout

		if _check_battle_status():
			return

	# 敌方回合结束，流转到下一回合
	current_turn += 1
	start_player_turn()

func _execute_enemy_ai(enemy: Unit) -> void:
	var players = unit_mgr.get_player_units()
	if players.is_empty():
		return

	# 寻找目标：优先张飞挑衅，否则选距离最近的玩家单位
	var target_player: Unit = null
	for p in players:
		if p.data.is_taunting:
			target_player = p
			break

	if target_player == null:
		var min_dist = 9999
		for p in players:
			var d = abs(p.data.grid_pos.x - enemy.data.grid_pos.x) + abs(p.data.grid_pos.y - enemy.data.grid_pos.y)
			if d < min_dist:
				min_dist = d
				target_player = p

	if target_player == null:
		return

	# 检查是否已相邻
	var current_dist = abs(target_player.data.grid_pos.x - enemy.data.grid_pos.x) + abs(target_player.data.grid_pos.y - enemy.data.grid_pos.y)
	if current_dist > 1:
		# 寻路向目标靠拢
		var occupied: Array[Vector2i] = []
		for u in unit_mgr.get_all_units():
			if u != enemy:
				occupied.append(u.data.grid_pos)

		var reachable = grid_mgr.get_reachable_cells(enemy.data.grid_pos, enemy.data.move_range, occupied)
		# 挑选离目标最近的空格
		var best_cell = enemy.data.grid_pos
		var best_d = current_dist
		for c in reachable:
			var d = abs(target_player.data.grid_pos.x - c.x) + abs(target_player.data.grid_pos.y - c.y)
			if d < best_d:
				best_d = d
				best_cell = c

		if best_cell != enemy.data.grid_pos:
			var path = grid_mgr.get_path_cells(enemy.data.grid_pos, best_cell)
			grid_mgr.set_unit_occupy(enemy.data.grid_pos, false)
			await enemy.move_along_path(path, grid_mgr)
			grid_mgr.set_unit_occupy(enemy.data.grid_pos, true)

	# 移动后如果相邻，发动毁灭性攻击！
	var final_dist = abs(target_player.data.grid_pos.x - enemy.data.grid_pos.x) + abs(target_player.data.grid_pos.y - enemy.data.grid_pos.y)
	if final_dist == 1:
		fx_mgr.play_slash_fx(grid_mgr.grid_to_world_center(target_player.data.grid_pos), Color(1.0, 0.2, 0.2))
		if enemy.data.id == "huaxiong":
			fx_mgr.screen_shake(12.0, 0.4)
			ui_mgr.spawn_barrage("华雄：吃某一合大刀！14倍力劈华山！", Color(1.0, 0.3, 0.3))

		# 刘备被动判定
		if target_player.data.id == "liubei":
			var taken = skill_mgr.check_liubei_passive(target_player, enemy, enemy.data.atk, unit_mgr, grid_mgr)
			target_player.take_damage(taken)
		else:
			target_player.take_damage(enemy.data.atk)

func _check_battle_status() -> bool:
	# 胜利判定：华雄阵亡
	var huaxiong = unit_mgr.get_boss()
	if huaxiong == null or huaxiong.data.current_hp <= 0:
		current_state = State.GAME_OVER
		_trigger_victory()
		return true

	# 失败判定：关羽、张飞或刘备阵亡
	var guanyu = unit_mgr.get_unit_by_id("guanyu")
	var zhangfei = unit_mgr.get_unit_by_id("zhangfei")
	var liubei = unit_mgr.get_unit_by_id("liubei")
	if guanyu == null or zhangfei == null or liubei == null:
		current_state = State.GAME_OVER
		_trigger_defeat()
		return true

	return false

func _trigger_victory() -> void:
	var vic_lines = [
		{"speaker": "华雄", "avatar": "华", "color": Color(0.9, 0.3, 0.3), "text": "这...这踏马到底是什么战术？！绕场跑圈也能杀人？！某不甘心啊——！"},
		{"speaker": "关羽", "avatar": "关", "color": Color(0.2, 0.9, 0.4), "text": "某略施小计，天基大青龙破关拔寨，尔等可服？"},
		{"speaker": "曹操", "avatar": "曹", "color": Color(0.9, 0.8, 0.3), "text": "此役震惊天下！关东诸侯集体被整麻了！传令三军，表刘备为东海郡太守！"}
	]
	ui_mgr.play_dialogue(vic_lines)
	await ui_mgr.dialogue_finished
	ui_mgr.show_gacha_screen()

func _trigger_defeat() -> void:
	var def_lines = [
		{"speaker": "刘备", "avatar": "刘", "color": Color(0.9, 0.4, 0.4), "text": "汉室未兴，二弟三弟...咱们被华雄一刀斩落马下了！"},
		{"speaker": "华雄", "avatar": "华", "color": Color(0.9, 0.2, 0.2), "text": "哈哈哈哈！十九路诸侯不过是一群插标卖首之徒！"}
	]
	ui_mgr.play_dialogue(def_lines)

func _on_restart_requested() -> void:
	get_tree().reload_current_scene()
