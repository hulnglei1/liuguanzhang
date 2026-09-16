class_name UnitManager
extends Node2D

const UnitData = preload("res://scripts/unit_data.gd")
const Unit = preload("res://scripts/unit.gd")
const GridManager = preload("res://scripts/grid_manager.gd")
const UnitScene = preload("res://scenes/Unit.tscn")

signal unit_selected(unit: Unit)
signal unit_died(unit: Unit)
signal zhaoyun_arrived(unit: Unit)

var units: Array[Unit] = []
var grid_mgr: GridManager

func setup(grid_manager: GridManager) -> void:
	grid_mgr = grid_manager
	spawn_initial_units()

func spawn_initial_units() -> void:
	# 1. 关羽 (外围跑道起点，外围绕圈蓄力)
	var guanyu_data = UnitData.new()
	guanyu_data.id = "guanyu"
	guanyu_data.unit_name = "关羽"
	guanyu_data.title = "汉寿亭侯/跑圈核武"
	guanyu_data.faction = "player"
	guanyu_data.max_hp = 450
	guanyu_data.current_hp = 450
	guanyu_data.atk = 75
	guanyu_data.def_val = 35
	guanyu_data.move_range = 4
	guanyu_data.color = Color(0.12, 0.58, 0.28)
	guanyu_data.avatar_char = "关"
	guanyu_data.dragon_charge = 0
	guanyu_data.horse_stamina = 100
	guanyu_data.max_horse_stamina = 100
	_spawn_unit(guanyu_data, Vector2i(1, 1))

	# 2. 张飞 (营前肉盾与音波控制)
	var zhangfei_data = UnitData.new()
	zhangfei_data.id = "zhangfei"
	zhangfei_data.unit_name = "张飞"
	zhangfei_data.title = "燕人翼德/音波肉盾"
	zhangfei_data.faction = "player"
	zhangfei_data.max_hp = 600
	zhangfei_data.current_hp = 600
	zhangfei_data.atk = 85
	zhangfei_data.def_val = 50
	zhangfei_data.move_range = 3
	zhangfei_data.color = Color(0.2, 0.4, 0.72)
	zhangfei_data.avatar_char = "张"
	zhangfei_data.rage = 40
	_spawn_unit(zhangfei_data, Vector2i(4, 4))

	# 3. 刘备 (军营统帅与战地医疗)
	var liubei_data = UnitData.new()
	liubei_data.id = "liubei"
	liubei_data.unit_name = "刘备"
	liubei_data.title = "汉室宗亲/战地医师"
	liubei_data.faction = "player"
	liubei_data.max_hp = 400
	liubei_data.current_hp = 400
	liubei_data.atk = 45
	liubei_data.def_val = 30
	liubei_data.move_range = 3
	liubei_data.color = Color(0.78, 0.62, 0.15)
	liubei_data.avatar_char = "刘"
	_spawn_unit(liubei_data, Vector2i(2, 4))

	# 4. 华雄 (关底魔王 Boss 14倍神力秒杀)
	var huaxiong_data = UnitData.new()
	huaxiong_data.id = "huaxiong"
	huaxiong_data.unit_name = "华雄"
	huaxiong_data.title = "西凉都督/14倍神力"
	huaxiong_data.faction = "enemy"
	huaxiong_data.max_hp = 2800
	huaxiong_data.current_hp = 2800
	huaxiong_data.atk = 999
	huaxiong_data.def_val = 75
	huaxiong_data.move_range = 3
	huaxiong_data.color = Color(0.68, 0.12, 0.15)
	huaxiong_data.avatar_char = "华"
	_spawn_unit(huaxiong_data, Vector2i(13, 4))

	# 5. 西凉铁骑前锋
	var cav1_data = UnitData.new()
	cav1_data.id = "cavalry_1"
	cav1_data.unit_name = "西凉铁骑·前锋"
	cav1_data.title = "董卓精锐"
	cav1_data.faction = "enemy"
	cav1_data.max_hp = 260
	cav1_data.current_hp = 260
	cav1_data.atk = 40
	cav1_data.def_val = 20
	cav1_data.move_range = 4
	cav1_data.color = Color(0.5, 0.22, 0.22)
	cav1_data.avatar_char = "骑"
	_spawn_unit(cav1_data, Vector2i(11, 2))

	# 6. 西凉铁骑侧翼
	var cav2_data = UnitData.new()
	cav2_data.id = "cavalry_2"
	cav2_data.unit_name = "西凉铁骑·侧翼"
	cav2_data.title = "董卓精锐"
	cav2_data.faction = "enemy"
	cav2_data.max_hp = 260
	cav2_data.current_hp = 260
	cav2_data.atk = 40
	cav2_data.def_val = 20
	cav2_data.move_range = 4
	cav2_data.color = Color(0.5, 0.22, 0.22)
	cav2_data.avatar_char = "骑"
	_spawn_unit(cav2_data, Vector2i(11, 6))

func spawn_zhaoyun() -> Unit:
	var zhaoyun_data = UnitData.new()
	zhaoyun_data.id = "zhaoyun"
	zhaoyun_data.unit_name = "赵云"
	zhaoyun_data.title = "常山赵子龙/人肉高铁"
	zhaoyun_data.faction = "player"
	zhaoyun_data.max_hp = 520
	zhaoyun_data.current_hp = 520
	zhaoyun_data.atk = 80
	zhaoyun_data.def_val = 45
	zhaoyun_data.move_range = 7
	zhaoyun_data.color = Color(0.18, 0.65, 0.95)
	zhaoyun_data.avatar_char = "赵"
	
	var unit = _spawn_unit(zhaoyun_data, Vector2i(1, 8))
	zhaoyun_arrived.emit(unit)
	return unit

func _spawn_unit(u_data: UnitData, g_pos: Vector2i) -> Unit:
	var unit: Unit = UnitScene.instantiate()
	var w_pos = grid_mgr.grid_to_world_center(g_pos)
	unit.init_unit(u_data, w_pos, g_pos)
	add_child(unit)
	units.append(unit)

	grid_mgr.set_unit_occupy(g_pos, true)
	unit.tree_exited.connect(_on_unit_removed.bind(unit))
	return unit

func _on_unit_removed(unit: Unit) -> void:
	if units.has(unit):
		grid_mgr.set_unit_occupy(unit.data.grid_pos, false)
		units.erase(unit)
		unit_died.emit(unit)

func get_unit_at(g_pos: Vector2i) -> Unit:
	for u in units:
		if is_instance_valid(u) and u.data.grid_pos == g_pos:
			return u
	return null

func get_player_units() -> Array[Unit]:
	var list: Array[Unit] = []
	for u in units:
		if is_instance_valid(u) and u.data.faction == "player":
			list.append(u)
	return list

func get_enemy_units() -> Array[Unit]:
	var list: Array[Unit] = []
	for u in units:
		if is_instance_valid(u) and u.data.faction == "enemy":
			list.append(u)
	return list

func get_all_units() -> Array[Unit]:
	var list: Array[Unit] = []
	for u in units:
		if is_instance_valid(u):
			list.append(u)
	return list

func get_unit_by_id(id_str: String) -> Unit:
	for u in units:
		if is_instance_valid(u) and u.data.id == id_str:
			return u
	return null

func get_boss() -> Unit:
	return get_unit_by_id("huaxiong")

# 关羽赵云骑乘合体：合体为“关赵巡洋舰”！
func combine_guan_and_zhao() -> bool:
	var guanyu = get_unit_by_id("guanyu")
	var zhaoyun = get_unit_by_id("zhaoyun")
	if guanyu == null or zhaoyun == null:
		return false

	# 关羽合体升级
	guanyu.data.is_piggybacking = true
	guanyu.data.move_range = 7 # 继承赵云超强机动
	guanyu.data.title = "关赵巡洋舰/人肉高铁"
	guanyu.data.avatar_char = "巡"
	guanyu.data.color = Color(0.1, 0.75, 0.7)
	guanyu.data.is_exhausted = false
	guanyu.data.horse_stamina = 100
	guanyu.update_visuals()

	# 移除赵云独立实体
	grid_mgr.set_unit_occupy(zhaoyun.data.grid_pos, false)
	units.erase(zhaoyun)
	zhaoyun.queue_free()

	guanyu.spawn_floating_text("🚀【关赵巡洋舰】合体成功！机动+7！免消耗跑圈！", Color(0.2, 1.0, 0.9))
	return true
