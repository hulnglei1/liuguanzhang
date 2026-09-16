extends Node2D
## 战斗场景主控（M0 第一关）
## 职责：加载章节数据 → 建战场 → 回合流转 → 处理玩家输入 → 敌方AI → 事件分发 → 胜负判定
## 纯逻辑部分（GridCore/CombatCore/TurnCore/MoraleCore/SkillsCore）在无头模式下可测；
## 本脚本负责把逻辑接到 Godot 节点上。

## ---------- 依赖数据 ----------
const GridCore := preload("res://scripts/core/grid.gd")
const CombatCore := preload("res://scripts/core/combat.gd")
const TurnCore := preload("res://scripts/core/turn.gd")
const MoraleCore := preload("res://scripts/systems/morale.gd")
const SkillsCore := preload("res://scripts/entities/skills.gd")
const BattleUnitScript := preload("res://scripts/entities/unit.gd")
const LotteryCore := preload("res://scripts/systems/lottery.gd")
const SaveCore := preload("res://scripts/systems/save.gd")

const TILE := 48.0          # 格子像素
const MAP_W := 12
const MAP_H := 10

## 当前要加载的章节 id（由 main.gd 设置）："chapter1" / "chapter2"
static var chapter_id: String = "chapter1"

## ---------- 场景节点引用（battle.tscn 中定义） ----------
@onready var map_root: Node2D = $MapRoot
@onready var unit_root: Node2D = $UnitRoot
@onready var overlay: Node2D = $Overlay       # 高亮覆盖层
@onready var info_label: Label = $UI/InfoLabel
@onready var turn_label: Label = $UI/TurnLabel
@onready var dialog_box: PanelContainer = $UI/DialogBox
@onready var dialog_text: RichTextLabel = $UI/DialogBox/Margin/VBox/Text
@onready var dialog_btn: Button = $UI/DialogBox/Margin/VBox/NextBtn
@onready var end_turn_btn: Button = $UI/EndTurnBtn
@onready var help_btn: Button = $UI/HelpBtn
@onready var command_menu: VBoxContainer = $UI/CommandMenu
## 结算面板（代码构建，节点引用由 _build_result_panel 填充）
var result_panel: PanelContainer
var result_title: Label
var result_body: Label
var result_next: Button
var result_home: Button

## ---------- 运行时状态 ----------
var units: Array = []                 # 所有 BattleUnit
var unit_nodes: Dictionary = {}       # unit_id -> Node2D（场景中的精灵）
var chapter: Dictionary = {}
var dialogs: Dictionary = {}
var hills: Array[Vector2i] = []       # 高地格（臧霸占山为王地形）
var turn_state: Dictionary = {}
var morale: Dictionary = {"player": 100, "enemy": 100}
var refuse_penalty_active := false
var victory := false

# 输入状态机
enum InputMode { NONE, SELECT, MOVE, ATTACK, SKILL }
var input_mode := InputMode.NONE
var selected_id := ""
var move_target: Vector2i
var skill_target: Vector2i
var pending_dialog: Array = []      # 待播对话队列
var dialog_showing := false
var queued_events: Array = []       # 已触发过一次的事件 key
var win_dialog_played := false

func _ready() -> void:
	_configure_display()
	_load_chapter()
	_spawn_units()
	_apply_gear_bonuses()
	_init_environment()
	_ready_init_title()
	# 初次游玩教学 + 帮助按钮
	if not _has_cleared_any_chapter():
		_show_tutorial()
	help_btn.pressed.connect(_show_help)
	_show_open_dialog()
	_update_hud()

## 是否已通关过任意关（新人判断）
func _has_cleared_any_chapter() -> bool:
	var save := SaveCore.load_state()
	var ch: Array = save.get("chapters", [])
	return ch.size() > 0

## 首次进入的教学对话（内建，不依赖章节 dialogs）
func _show_tutorial() -> void:
	var t := [
		{"speaker": "教学", "text": "欢迎来到魂穿刘关张！点蓝色我方武将试试。"},
		{"speaker": "教学", "text": "选中后屏幕右侧出现命令：移动 / 攻击 / 技能 / 待机。"},
		{"speaker": "教学", "text": "【绿色格】=可移动范围。点它移动。跑得越远，关羽龙斩越强！"},
		{"speaker": "教学", "text": "拖太久敌人会变强！想赢=张飞咆哮控住 + 关羽满蓄力斩。"},
	]
	pending_dialog = t
	dialog_showing = true
	dialog_box.visible = true
	_show_next_dialog_line()

## 帮助说明（常驻「?」按钮）
func _show_help() -> void:
	var help := [
		{"speaker": "教学", "text": "【玩法速览】点我方武将→出命令菜单→移动/攻击/技能/待机"},
		{"speaker": "教学", "text": "【蓄力】关羽跑得越远青龙斩越强；张飞待机攒轮数，满3轮怒吼眩晕"},
		{"speaker": "教学", "text": "【组合技】张飞咆哮控住敌人 + 关羽满蓄力青龙斩 = 一波带走"},
		{"speaker": "教学", "text": "【胜利】击杀敌方主将即过关，占郡得声望，回主城抽奖/看图鉴"},
	]
	pending_dialog = help
	dialog_showing = true
	dialog_box.visible = true
	_show_next_dialog_line()

## P0-1：读取背包装备/种子，应用到全局战斗加成（让抽奖真正生效）
func _apply_gear_bonuses() -> void:
	var save := SaveCore.load_state()
	var inv: Dictionary = save.get("inventory", {})
	# 算出全局加成值
	var add_atk := 0
	var add_def := 0
	var add_hp := 0
	var atk_pct := 1.0
	var hp_regen := 0
	var morale_start_extra := 0
	# 武器池
	var weapons := {
		"jinggang_dou": {"def": 6},
		"gu_shou": {"hp": 40},
		"da_he_dan": {"atk": 0, "aoe": true},
		"shi_tou": {"atk": 0, "full_screen": true},
	}
	for item_id in inv:
		var cnt: int = inv[item_id]
		if cnt <= 0:
			continue
		var w = weapons.get(item_id, {})
		if w.has("def"):
			add_def += int(w.def) * cnt
		if w.has("hp"):
			add_hp += int(w.hp) * cnt
	# 种子池（单项buff，取有即用）
	if inv.has("sweet_potato"):
		atk_pct = 1.0 + 0.10 * inv["sweet_potato"]
	if inv.has("corn"):
		hp_regen = 5 * inv["corn"]
	if inv.has("potato"):
		morale_start_extra = 10 * inv["potato"]
	# 应用到全部我方单位
	for u in _camp_units("player"):
		u.gear_atk += add_atk
		u.gear_def += add_def
		u.gear_hp += add_hp
		u.atk_pct_bonus = atk_pct
		u.hp_regen = hp_regen
		u.apply_hp_gear()
	if morale_start_extra > 0:
		morale.player = mini(100, morale.player + morale_start_extra)
		MoraleCore.apply_morale(_camp_units("player"), morale.player)
	# 战斗日志提示（只在有加成时）
	if add_def > 0 or add_hp > 0 or atk_pct > 1.0:
		info_label.text += "\n（背包装备已生效：防+%d 血+%d 攻x%.2f）" % [add_def, add_hp, atk_pct]

## 初始化地形：渲染高地格 + 给臧霸设占山状态
func _init_environment() -> void:
	_draw_hills()
	for u in units:
		if "king_hill" in u.skill_ids:
			u.on_hill = _is_hill(u.cell)

func _is_hill(cell: Vector2i) -> bool:
	return cell in hills

func _draw_hills() -> void:
	for h in hills:
		var rect := ColorRect.new()
		rect.size = Vector2(TILE - 2, TILE - 2)
		rect.position = Vector2(h.x * TILE + 1, h.y * TILE + 1)
		rect.color = Color(0.5, 0.4, 0.3, 0.6)  # 山地色
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		map_root.add_child(rect)
	# 山脉在单位之下、可选加个图例
	if hills.size() > 0:
		info_label.text += "\n（棕黄色格 = 山地高地，臧霸占山攻防+30%）"

func _ready_init_title() -> void:
	# 用章节标题覆盖 UI 默认文本
	if chapter.has("title"):
		info_label.text = chapter["title"]

func _configure_display() -> void:
	# 窗口/相机对齐
	Engine.max_fps = 60
	get_window().size = Vector2i(1280, 720)

func _load_chapter() -> void:
	var ch_file: String = "res://data/chapters/%s.json" % chapter_id
	var dl_file: String = "res://data/dialogs/%s_dialogs.json" % chapter_id
	chapter = _load_json(ch_file)
	dialogs = _load_json(dl_file)
	# 解包 {"dialogs":{...}} 外壳（P0 修复：此前未解包导致剧情对白/胜利结算/声望图鉴全断）
	if dialogs.has("dialogs") and typeof(dialogs["dialogs"]) == TYPE_DICTIONARY:
		dialogs = dialogs["dialogs"]
	turn_state = TurnCore.new_state()
	# 加载高地地形（泰山章）
	hills.clear()
	if chapter.has("map") and chapter["map"].has("hills"):
		for h in chapter["map"]["hills"]:
			hills.append(Vector2i(h.x, h.y))

func _load_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("无法打开: " + path)
		return {}
	var txt := f.get_as_text()
	var parsed = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("JSON 解析失败: " + path)
		return {}
	return parsed

## ---------- 单位生成 ----------
func _spawn_units() -> void:
	var units_data := _load_json("res://data/units.json")
	var unit_defs := {}
	for d in units_data["units"]:
		unit_defs[d["id"]] = d
	units.clear()
	for s in chapter["player_spawn"]:
		var def: Dictionary = unit_defs[s["unit"]]
		var u = BattleUnitScript.from_data(def, Vector2i(s.x, s.y))
		if s.has("camp"):
			u.camp = s.camp  # 允许 spawn 覆盖阵营（如已收服的许褚归我方）
		units.append(u)
	for s in chapter["enemy_spawn"]:
		var def: Dictionary = unit_defs[s["unit"]]
		var u = BattleUnitScript.from_data(def, Vector2i(s.x, s.y))
		if s.has("camp"):
			u.camp = s.camp
		units.append(u)
	# 建场景节点
	for u in units:
		var node := _make_unit_node(u)
		unit_root.add_child(node)
		unit_nodes[u.id] = node
	MoraleCore.apply_morale(_camp_units("player"), morale.player)
	MoraleCore.apply_morale(_camp_units("enemy"), morale.enemy)

func _make_unit_node(u) -> Node2D:
	var node := Node2D.new()
	node.position = _cell_to_px(u.cell)
	node.z_index = 10
	# 色块占位 + 名字
	var rect := ColorRect.new()
	rect.size = Vector2(TILE - 8, TILE - 8)
	rect.position = Vector2(4, 4)
	rect.color = _camp_color(u.camp)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_child(rect)
	var lbl := Label.new()
	lbl.text = u.name
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.size = Vector2(TILE - 8, 20)
	lbl.position = Vector2(4, TILE - 22)
	lbl.add_theme_font_size_override("font_size", 10)
	node.add_child(lbl)
	node.set_meta("unit_id", u.id)
	return node

func _camp_color(camp: String) -> Color:
	return Color(0.2, 0.6, 0.9) if camp == "player" else Color(0.9, 0.3, 0.2)

func _cell_to_px(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * TILE + TILE / 2, cell.y * TILE + TILE / 2)

func _px_to_cell(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / TILE), floori(pos.y / TILE))

## ---------- 辅助 ----------
func _camp_units(camp: String) -> Array:
	var out: Array = []
	for u in units:
		if u.camp == camp and u.alive:
			out.append(u)
	return out

func _unit_by_id(id: String) -> BattleUnitScript:
	for u in units:
		if u.id == id:
			return u
	return null

func _enemy_commander() -> BattleUnitScript:
	for u in units:
		if u.camp == "enemy" and u.is_commander:
			return u
	return null

func _blocked_cells(exclude: String = "") -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for u in units:
		if u.alive and u.id != exclude:
			out.append(u.cell)
	for o in chapter["map"]["obstacles"]:
		out.append(Vector2i(o.x, o.y))
	return out

func _sync_node(u) -> void:
	var node: Node2D = unit_nodes[u.id]
	if node:
		node.position = _cell_to_px(u.cell)
		_sync_text(u)

## 仅更新单位文本（血量/名字），不动位置（用于移动动画期间）
func _sync_text(u) -> void:
	var node: Node2D = unit_nodes[u.id]
	if node:
		# 臧霸占山状态随位置更新
		if "king_hill" in u.skill_ids:
			u.on_hill = _is_hill(u.cell)
		var hp_lbl: Label = node.get_child(1)  # 名字
		hp_lbl.text = "%s\n%d/%d" % [u.name, u.hp, u.max_hp]

## ---------- 输入 ----------
func _unhandled_input(event: InputEvent) -> void:
	if dialog_showing:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var cell := _px_to_cell(get_global_mouse_position())
		_handle_click(cell)

func _handle_click(cell: Vector2i) -> void:
	match input_mode:
		InputMode.SELECT:
			var u: BattleUnitScript = _unit_at(cell)
			if u and u.camp == "player" and u.alive and not u.acted:
				# 点另一个未行动单位 → 重新选择
				if u.id != selected_id:
					_select_unit(u.id)
			# 点空白/自己 → 保持命令菜单
		InputMode.MOVE:
			if _is_in_reachable(cell):
				_do_move(cell)
			else:
				_show_command_menu()  # 点无效处回到命令菜单
		InputMode.ATTACK:
			if _is_in_attack_range(cell):
				_do_attack(cell)
			else:
				_show_command_menu()
		InputMode.SKILL:
			if _is_in_skill_range(cell):
				_do_skill(cell)
			else:
				_show_command_menu()

func _unit_at(cell: Vector2i) -> BattleUnitScript:
	for u in units:
		if u.alive and u.cell == cell:
			return u
	return null

## 选中单位：高亮移动格 + 显示命令菜单
func _select_unit(id: String) -> void:
	selected_id = id
	var u: BattleUnitScript = _unit_by_id(id)
	_clear_overlay()
	var blocked := _blocked_cells(id)
	var reach := GridCore.reachable(u.cell, u.mov, MAP_W, MAP_H, blocked)
	_draw_cells(reach.keys(), Color(0.3, 0.8, 0.3, 0.4))
	input_mode = InputMode.SELECT
	_show_command_menu()

func _max_charge_for(u) -> int:
	if u.skill_ids.size() > 0:
		return SkillsCore.meta(u.skill_ids[0]).get("max_charge", 0)
	return 0

## ---------- 命令菜单 ----------
func _clear_command_menu() -> void:
	for c in command_menu.get_children():
		c.queue_free()

func _show_command_menu() -> void:
	_clear_command_menu()
	var u: BattleUnitScript = _unit_by_id(selected_id)
	if u == null or not u.alive or dialog_showing:
		command_menu.visible = false
		return
	input_mode = InputMode.SELECT
	command_menu.visible = true

	# 移动
	var label := Label.new()
	label.text = "%s 行动" % u.name
	label.add_theme_font_size_override("font_size", 16)
	command_menu.add_child(label)

	var btn_move := Button.new()
	btn_move.text = "移动（%d格）" % u.mov
	btn_move.pressed.connect(_cmd_move)
	command_menu.add_child(btn_move)

	# 攻击（若可攻击范围内有敌人）
	if _has_attackable_target(u):
		var btn_atk := Button.new()
		btn_atk.text = "攻击"
		btn_atk.pressed.connect(_cmd_attack)
		command_menu.add_child(btn_atk)

	# 技能（若有技能就绪）
	if u.skill_ids.size() > 0:
		var skill_id: String = u.skill_ids[0]
		var ready := u.skill_ready(skill_id)
		var btn_skill := Button.new()
		btn_skill.text = "%s%s" % [SkillsCore.meta(skill_id).get("name", "技能"), "" if ready else "（CD中）"]
		btn_skill.disabled = not ready or not _has_skill_target(u, skill_id)
		btn_skill.pressed.connect(_cmd_skill)
		command_menu.add_child(btn_skill)

	# 待机（蓄力武将：张飞蓄轮数；否则单纯跳过）
	var btn_wait := Button.new()
	btn_wait.text = "待机/蓄力"
	btn_wait.pressed.connect(_cmd_wait)
	command_menu.add_child(btn_wait)

func _has_attackable_target(u) -> bool:
	for t in units:
		if t.alive and t.camp != u.camp and GridCore.chebyshev(u.cell, t.cell) <= u.rng:
			return true
	return false

func _has_skill_target(u, skill_id: String) -> bool:
	# 龙斩/范围技：若场上有敌方即可；单体近战技看是否有敌在技能范围
	for t in units:
		if t.alive and t.camp != u.camp:
			return true
	return false

func _cmd_move() -> void:
	input_mode = InputMode.MOVE
	command_menu.visible = false
	info_label.text = "点绿色格子移动，或点其他处取消"

func _cmd_attack() -> void:
	input_mode = InputMode.ATTACK
	command_menu.visible = false
	info_label.text = "点要攻击的敌人（红色格）"

func _cmd_skill() -> void:
	input_mode = InputMode.SKILL
	command_menu.visible = false
	info_label.text = "点技能目标"

func _cmd_wait() -> void:
	var u: BattleUnitScript = _unit_by_id(selected_id)
	if u:
		_do_wait(u)

## 待机：张飞咆哮类蓄力+1轮；否则单纯结束行动
func _do_wait(u) -> void:
	_clear_overlay()
	command_menu.visible = false
	u.acted = true
	# 若张飞有蓄力型咆哮技能，待机=蓄力
	if "roar" in u.skill_ids and u.charge < 3:
		u.charge += 1
		info_label.text = "张飞蓄力 → %d/3 轮！满蓄力怒吼可眩晕大范围！" % u.charge
	else:
		info_label.text = "%s 待机（跳过本回合）" % u.name
	_after_action(u)

## ---------- 移动 ----------
func _is_in_reachable(cell: Vector2i) -> bool:
	var u: BattleUnitScript = _unit_by_id(selected_id)
	var blocked := _blocked_cells(selected_id)
	return GridCore.reachable(u.cell, u.mov, MAP_W, MAP_H, blocked).has(cell)

func _do_move(cell: Vector2i) -> void:
	var u: BattleUnitScript = _unit_by_id(selected_id)
	var blocked := _blocked_cells(selected_id)
	var path := GridCore.path(u.cell, cell, MAP_W, MAP_H, blocked)
	var moved_cells := path.size()
	# 客户端动画：单位沿路径逐格走过去
	_animate_move(u, path)
	u.cell = cell
	u.acted = true
	_sync_text(u)
	# 关羽蓄力：移动格数 = 蓄力值（骑乘效率×2）
	if "dragon_slash" in u.skill_ids:
		var eff := SkillsCore.mounted_charge_efficiency() if u.is_mounted() else 1
		u.charge = clampi(u.charge + moved_cells * eff, 0, 10)
		info_label.text = "关羽蓄力 → %d/10（跑 %d 格）！跑得越远，斩得越狠！" % [u.charge, moved_cells]
	else:
		info_label.text = "%s 移动到 (%d,%d)" % [u.name, cell.x, cell.y]
	_clear_overlay()
	_after_action(u)

## 走格动画：单位节点沿路径平滑移动
func _animate_move(u, path: Array) -> void:
	var node: Node2D = unit_nodes[u.id]
	if node == null or path.size() == 0:
		return
	var tw := create_tween()
	var start := _cell_to_px(u.cell)
	var seg_time := 0.06
	for p in path:
		tw.tween_interval(seg_time)
		tw.tween_property(node, "position", _cell_to_px(p), seg_time)
	# 动画结束校正到最终格
	tw.finished.connect(func(): node.position = _cell_to_px(u.cell))

## ---------- 攻击 ----------
func _is_in_attack_range(cell: Vector2i) -> bool:
	var u: BattleUnitScript = _unit_by_id(selected_id)
	var t: BattleUnitScript = _unit_at(cell)
	return t != null and t.camp != u.camp and GridCore.chebyshev(u.cell, cell) <= u.rng

func _do_attack(cell: Vector2i) -> void:
	var u: BattleUnitScript = _unit_by_id(selected_id)
	var t: BattleUnitScript = _unit_at(cell)
	_clear_overlay()
	var events := SkillsCore.do_attack(u, t)
	_apply_events(events)
	u.acted = true
	_after_action(u)

## ---------- 技能 ----------
func _is_in_skill_range(cell: Vector2i) -> bool:
	var u: BattleUnitScript = _unit_by_id(selected_id)
	var t: BattleUnitScript = _unit_at(cell)
	var skill_id: String = u.skill_ids[0] if u.skill_ids.size() > 0 else ""
	# 自身技（裸衣）不需要目标格；范围技（箭雨）仍需点目标附近
	if skill_id == "naked_armor":
		return true
	if t == null or t.camp == u.camp:
		return false
	match skill_id:
		"dragon_slash":
			return true  # 龙斩：蓄满即可全屏，否则近战
		"roar":
			return GridCore.chebyshev(u.cell, cell) <= 2
		"seven_dash":
			return GridCore.chebyshev(u.cell, cell) <= u.mov
		"arrow_rain":
			return GridCore.chebyshev(u.cell, cell) <= 4
	return false

func _do_skill(cell: Vector2i) -> void:
	var u: BattleUnitScript = _unit_by_id(selected_id)
	var t: BattleUnitScript = _unit_at(cell)
	var skill_id: String = u.skill_ids[0] if u.skill_ids.size() > 0 else ""
	_clear_overlay()
	var events: Array = []
	match skill_id:
		"dragon_slash":
			if u.charge < 10:
				info_label.text = "蓄力不足！当前 %d/10，跑够 10 格再释放满蓄力龙斩！" % u.charge
				_select_unit(u.id)
				return
			# 满蓄力大招演出
			if u.charge >= 10:
				_big_moment("千里·青龙斩！！")
			else:
				_spawn_banner("蓄力龙斩", Color(0.3, 0.9, 0.5))
			if t:
				_spawn_dragon(u.cell, t.cell)
				_spawn_burst(t.cell, Color(0.3, 0.9, 0.5, 0.4), 1)
			events = SkillsCore.do_dragon_slash(u, t)
		"roar":
			_spawn_banner("燕人咆哮！", Color(0.9, 0.7, 0.2))
			_spawn_shockwave(u.cell, Color(0.9, 0.7, 0.2, 0.5))
			_spawn_burst(u.cell, Color(0.9, 0.7, 0.2, 0.4), 2)
			_shake_camera(4.0)
			var targets: Array = []
			for tt in units:
				if tt.alive and tt.camp != u.camp and GridCore.chebyshev(u.cell, tt.cell) <= 2:
					targets.append(tt)
			events = SkillsCore.do_roar(u, targets)
		"seven_dash":
			var weaves: int = mini(7, maxi(1, GridCore.manhattan(u.cell, t.cell) + 1))
			if t:
				_spawn_banner("七进七出！", Color(0.4, 0.8, 1.0))
				# 残影连闪：沿路径来回
				var path := GridCore.path(u.cell, t.cell, MAP_W, MAP_H, _blocked_cells(u.id))
				for i in range(weaves):
					if path.size() > 0:
						var cell1 := path[min(i % path.size(), path.size() - 1)]
						var orb := Polygon2D.new()
						orb.polygon = PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)])
						orb.position = _cell_to_px(cell1)
						orb.color = Color(0.4, 0.8, 1.0, 0.5)
						orb.z_index = 14
						unit_root.add_child(orb)
						var tw := create_tween()
						tw.tween_property(orb, "modulate:a", 0.0, 0.2)
						tw.tween_callback(orb.queue_free)
			events = SkillsCore.do_seven_dash(u, t, weaves)
		"arrow_rain":
			_spawn_banner("拐弯箭雨！", Color(0.8, 0.7, 0.3))
			if t:
				_spawn_shockwave(t.cell, Color(0.8, 0.7, 0.3, 0.5))
			events = SkillsCore.do_arrow_rain(u, t, units)
		"naked_armor":
			_big_moment("裸衣！死战！！")
			_screen_flash(Color(1, 0.4, 0.2, 0.4), 0.4)
			_spawn_shockwave(u.cell, Color(1, 0.4, 0.2, 0.6))
			events = SkillsCore.do_naked_armor(u, units)
			# 显示爆甲范围
			_spawn_burst(u.cell, Color(1, 0.4, 0.2, 0.5), 2)
	_apply_events(events)
	u.acted = true
	_after_action(u)

## ---------- 事件应用 ----------
func _apply_events(events: Array) -> void:
	for ev in events:
		match ev.get("type"):
			"damage":
				var t: BattleUnitScript = _unit_by_id(ev.target)
				if t:
					_flash_unit(t.id, Color(1, 0.3, 0.3))
					_unit_bounce(t.id)
					_spawn_float_text(t.cell, "-%d" % ev.value, Color(1, 0.4, 0.3))
					info_label.text += "\n%s 受到 %d 伤害！" % [t.name, ev.value]
					# 昌豨怯战：受击后DEF-30%
					if "feigui" in t.skill_ids and not t.coward_debuff:
						t.coward_debuff = true
						info_label.text += "\n昌豨胆怯了！防御下降！"
			"death":
				var t2 := _unit_by_id(ev.target)
				if t2:
					# 主将被击杀：大招仪式感（震屏+闪光+大字）
					if t2.is_commander:
						_big_moment("%s 被击败！！" % t2.name)
					else:
						_spawn_banner("%s 溃散！" % t2.name, Color(0.9, 0.2, 0.2))
						_spawn_burst(t2.cell, Color(0.9, 0.2, 0.2, 0.5), 1)
					_unit_node_hide(t2.id)
					info_label.text += "\n%s 阵亡！" % t2.name
					# 吕布暴怒：我方单位倒下，吕布越战越狂（多打少）
					if t2.camp == "player" and chapter_id == "chapter2":
						var lubu := _unit_by_id("lubu")
						if lubu and lubu.alive:
							lubu.add_rage()
							info_label.text += "\n吕布暴怒！攻击力暴涨！(×1.5)"
							_play_dialog("ch2_lubu_rage")
			"skill":
				info_label.text += "\n【技能】%s" % ev.get("value", "")
			"stun":
				var tar := _unit_by_id(ev.target)
				if tar:
					_spawn_float_text(tar.cell, "眩晕！", Color(0.9, 0.8, 0.2))
					_spawn_shockwave(tar.cell, Color(0.9, 0.8, 0.2, 0.6))
					# 连携提示：控住=集火窗口
					_spawn_banner("%s 被控住！快集火！" % tar.name, Color(0.9, 0.8, 0.2))
				info_label.text += "\n%s 被眩晕 %d 回合！" % [_unit_by_id(ev.target).name, ev.turns]
				# 许褚/吕布被眩晕时解除连击/裸衣（打断）
				var stunned := _unit_by_id(ev.target)
				if stunned:
					if "lubu_fangtian" in stunned.skill_ids:
						stunned.fangtian_reset()
			"armor_broken":
				var ab := _unit_by_id(ev.target)
				if ab:
					info_label.text += "\n%s 铠甲被爆！防御减半！（只剩裤衩子…）" % ab.name
			"heal":
				var he := _unit_by_id(ev.target)
				if he:
					info_label.text += "\n%s 吸血恢复 %d HP！" % [he.name, ev.value]
			"fx":
				if ev.fx == "dragon_full_screen":
					_show_win_dialog()

func _flash_unit(id: String, color: Color) -> void:
	var node: Node2D = unit_nodes[id]
	if node and node.get_child_count() > 0:
		var rect: ColorRect = node.get_child(0)
		var orig := rect.color
		rect.color = color
		var tw := create_tween()
		tw.tween_interval(0.15)
		tw.tween_callback(func(): rect.color = orig)

func _unit_node_hide(id: String) -> void:
	var node: Node2D = unit_nodes[id]
	if node:
		node.visible = false

## 伤害/状态飘字：在单位格上方生成上飘渐隐的文字
func _spawn_float_text(cell: Vector2i, text: String, color: Color) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.position = _cell_to_px(cell) + Vector2(-20, -18)
	lbl.z_index = 50
	unit_root.add_child(lbl)
	var tw := create_tween()
	tw.tween_property(lbl, "position", lbl.position + Vector2(0, -22), 0.6)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.6)
	tw.tween_callback(lbl.queue_free)

## 技能大字横幅（居中弹一下消失）
func _spawn_banner(text: String, color: Color) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_size_override("font_size", 30)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position = Vector2(400, 240)
	lbl.size = Vector2(480, 60)
	lbl.z_index = 60
	var ui_layer = $UI
	ui_layer.add_child(lbl)
	var tw := create_tween()
	var base := lbl.position
	tw.tween_property(lbl, "position", base + Vector2(0, 12), 0.25)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.8)
	tw.tween_callback(lbl.queue_free)

## 简单技能范围特效（以某格为中心画圆圈/方块扩散）
func _spawn_burst(cell: Vector2i, color: Color, radius_in_cells: int = 0) -> void:
	var rect := ColorRect.new()
	rect.size = Vector2(TILE - 4, TILE - 4)
	rect.position = _cell_to_px(cell) + Vector2(2 - radius_in_cells * TILE, 2 - radius_in_cells * TILE)
	if radius_in_cells > 0:
		rect.size = Vector2(TILE * (radius_in_cells * 2 + 1) - 4, TILE * (radius_in_cells * 2 + 1) - 4)
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.z_index = 6
	overlay.add_child(rect)
	var tw := create_tween()
	tw.tween_property(rect, "modulate:a", 0.0, 0.5)
	tw.tween_callback(rect.queue_free)

## ===== 战斗爽感特效（升级版） =====

## 屏幕震动（用 MapRoot 轻微偏移，多次往返）
func _shake_camera(strength: float = 6.0) -> void:
	var tw := create_tween()
	var base := Vector2.ZERO
	for i in range(5):
		var off := Vector2(
			randf_range(-strength, strength),
			randf_range(-strength, strength)
		)
		tw.tween_property(map_root, "position", base + off, 0.03)
	tw.tween_property(map_root, "position", base, 0.04)

## 全屏闪光（短暂覆盖一层色，闪亮后隐去）
func _screen_flash(color: Color, duration: float = 0.25) -> void:
	var rect := ColorRect.new()
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.z_index = 80
	var ui_layer = $UI
	ui_layer.add_child(rect)
	var tw := create_tween()
	tw.tween_property(rect, "modulate:a", 0.0, duration)
	tw.tween_callback(rect.queue_free)

## 青龙横贯：从释放者格向目标格扫一条发光光带（拉长的三角形/渐变）
func _spawn_dragon(from_cell: Vector2i, to_cell: Vector2i) -> void:
	var start_px := _cell_to_px(from_cell)
	var end_px := _cell_to_px(to_cell)
	var dir := (end_px - start_px).normalized()
	var len := start_px.distance_to(end_px)
	# 用一串沿路径密集排列的渐隐方块构成光带
	var seg_count := int(len / 12)
	var tw := create_tween()
	for i in range(seg_count):
		var t := float(i) / float(max(seg_count, 1))
		var pos := start_px + dir * len * t
		var orb := Polygon2D.new()
		orb.polygon = PackedVector2Array([
			Vector2(-8, -14), Vector2(8, -14), Vector2(0, 14)
		])
		orb.position = pos
		orb.rotation = dir.angle()
		orb.color = Color(0.3, 1.0, 0.6, 0.9)
		orb.z_index = 20
		unit_root.add_child(orb)
		tw.parallel().tween_property(orb, "scale", Vector2(1.4, 1.4), 0.2).set_trans(Tween.TRANS_QUAD)
		tw.parallel().tween_property(orb, "modulate:a", 0.0, 0.3)
		tw.tween_interval(0.012)
	# 前头一个大光球
	var head := Polygon2D.new()
	head.polygon = PackedVector2Array([
		Vector2(-16, -16), Vector2(16, -16), Vector2(16, 16), Vector2(-16, 16)
	])
	head.position = end_px
	head.color = Color(0.6, 1.0, 0.8, 0.9)
	head.z_index = 21
	unit_root.add_child(head)
	tw.parallel().tween_property(head, "scale", Vector2(2.2, 2.2), 0.25)
	tw.parallel().tween_property(head, "modulate:a", 0.0, 0.3)

## 音波圈：从中心扩散的多层圆环（咆哮/范围技）
func _spawn_shockwave(cell: Vector2i, color: Color) -> void:
	for rad in [1.2, 1.8, 2.4]:
		var ring := Polygon2D.new()
		ring.polygon = _make_circle_polygon(rad * TILE)
		ring.position = _cell_to_px(cell)
		ring.color = color
		ring.z_index = 15
		unit_root.add_child(ring)
		var tw := create_tween()
		tw.tween_property(ring, "scale", Vector2(1.6, 1.6), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(ring, "modulate:a", 0.0, 0.35)
		tw.tween_callback(ring.queue_free)

## 生成正多边形（近似圆）
func _make_circle_polygon(radius: float, segments: int = 20) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(segments):
		var a := TAU * float(i) / float(segments)
		pts.append(Vector2(cos(a), sin(a)) * radius)
	return pts

## 单位受击弹跳（动作感）
func _unit_bounce(id: String) -> void:
	var node: Node2D = unit_nodes[id]
	if node == null:
		return
	var tw := create_tween()
	tw.tween_property(node, "scale", Vector2(1.2, 0.8), 0.06)
	tw.tween_property(node, "scale", Vector2(1, 1), 0.12)

## 大招定格：全屏闪白 + 字幕口号 + 震动
func _big_moment(text: String) -> void:
	_screen_flash(Color(1, 1, 1, 0.5), 0.3)
	_spawn_banner(text, Color(1, 0.85, 0.3))
	_shake_camera(8.0)

## ---------- 回合流转 ----------
func _after_action(u) -> void:
	# 检查胜利
	if _check_victory():
		return
	# 清除选中与命令菜单
	_cancel_input()
	# 全部行动完自动结束回合
	var alive_ids: Array = []
	for uu in _camp_units("player"):
		alive_ids.append(uu.id)
	if TurnCore.all_acted(turn_state, alive_ids):
		_end_player_turn()
	else:
		# 提示还有谁可行动
		var remaining := 0
		for uu in _camp_units("player"):
			if not uu.acted:
				remaining += 1
		if remaining > 0:
			info_label.text += "\n（还有 %d 个单位未行动，点它们继续）" % remaining
		_update_hud()

func _end_player_turn() -> void:
	TurnCore.to_enemy(turn_state)
	info_label.text = "敌方回合…"
	_update_hud()
	_run_enemy_turn()

## 敌方回合：每个存活敌人执行简单 AI（带演出节奏）
func _run_enemy_turn() -> void:
	_spawn_banner("敌方回合", Color(0.8, 0.4, 0.2))
	for u in _camp_units("enemy"):
		if not u.alive:
			continue
		if u.is_stunned():
			continue
		var target: BattleUnitScript = _nearest_player(u)
		if target == null:
			continue
		# 出手前高亮目标 + 短停顿，让玩家看清
		_flash_unit(target.id, Color(1, 0.6, 0.2))
		await get_tree().create_timer(0.12).timeout
		# 弓兵：保持距离2-3格
		if u.cls == "弓兵":
			var dist := GridCore.chebyshev(u.cell, target.cell)
			if dist > u.rng:
				_move_toward(u, target.cell)
				await get_tree().create_timer(0.1).timeout
			elif dist <= 1:
				_move_away(u, target.cell)
				await get_tree().create_timer(0.1).timeout
			else:
				_ai_attack(u, target)
		else:
			var dist := GridCore.chebyshev(u.cell, target.cell)
			if dist <= u.rng:
				_ai_attack(u, target)
			else:
				_move_toward(u, target.cell)
				await get_tree().create_timer(0.1).timeout
	# 敌回合结束
	for u in _camp_units("enemy"):
		u.end_turn()
	TurnCore.to_player(turn_state)
	_begin_player_turn()

func _nearest_player(u) -> BattleUnitScript:
	var best = null
	var best_d := 9999
	for p in _camp_units("player"):
		var d := GridCore.manhattan(u.cell, p.cell)
		if d < best_d:
			best_d = d
			best = p
	return best

func _move_toward(u, target_cell: Vector2i) -> void:
	var blocked := _blocked_cells(u.id)
	var path := GridCore.path(u.cell, target_cell, MAP_W, MAP_H, blocked)
	if path.size() > 0:
		var step := path[min(u.mov, path.size()) - 1]
		u.cell = step
		_sync_node(u)

func _move_away(u, target_cell: Vector2i) -> void:
	var dir: Vector2i = (u.cell - target_cell).sign()
	var nxt: Vector2i = u.cell + dir
	if GridCore.in_bounds(nxt, MAP_W, MAP_H) and nxt not in _blocked_cells(u.id):
		u.cell = nxt
		_sync_node(u)

func _ai_attack(u, target) -> void:
	# 许褚：若裸衣未激活且就绪，先激活；攻击走裸衣吸血；双倍攻速打两次
	if "naked_armor" in u.skill_ids:
		if not u.lifesteal_active and u.skill_ready("naked_armor"):
			_apply_events(SkillsCore.do_naked_armor(u, units))
			info_label.text += "\n许褚！裸衣！死战！！爆甲+吸血+双倍攻速！"
		_apply_events(SkillsCore.do_naked_strike(u, target))
		if u.lifesteal_active:
			_apply_events(SkillsCore.do_naked_strike(u, target))  # 双倍攻速第二击
	elif "lubu_fangtian" in u.skill_ids:
		_apply_events(SkillsCore.do_lubu_attack(u, target))
	else:
		_apply_events(SkillsCore.do_attack(u, target))
	if not target.alive:
		_check_defeat()

func _begin_player_turn() -> void:
	for u in _camp_units("player"):
		u.acted = false
	_check_turn_events()
	_check_pressure_flag()
	input_mode = InputMode.NONE
	selected_id = ""
	_clear_overlay()
	_update_hud()
	info_label.text = "第 %d 回合 · 我方行动" % turn_state.turn

## P1-1：打破「无限拖」——第8回合起敌方援军压境，组装加攻（刺激速战/换打法）
func _check_pressure_flag() -> void:
	if turn_state.turn < 8:
		return
	# 每4回合触发一次敌方增益（8回合/12回合/16…）
	if turn_state.turn % 4 == 0:
		for u in _camp_units("enemy"):
			u.refuse_penalty *= 1.15
		_spawn_banner("敌军援军压境！！", Color(0.9, 0.3, 0.2))
		_shake_camera(4.0)
		info_label.text += "\n⚠ 敌军援军赶到，敌方全体攻击提升！别拖！"

## ---------- 事件/对话 ----------
func _show_open_dialog() -> void:
	# 开场对话 key：ch1_open / ch2_open 由章节决定
	_play_dialog(chapter_id + "_open")

func _check_turn_events() -> void:
	for ev in chapter["events"]:
		if ev.turn == turn_state.turn and ev.type == "dialog" and ev.key not in queued_events:
			queued_events.append(ev.key)
			_play_dialog(ev.key)

func _play_dialog(key: String) -> void:
	if not dialogs.has(key):
		return
	pending_dialog = dialogs[key].duplicate()
	dialog_showing = true
	dialog_box.visible = true
	_show_next_dialog_line()

func _show_next_dialog_line() -> void:
	if pending_dialog.size() == 0:
		dialog_showing = false
		dialog_box.visible = false
		return
	var line: Dictionary = pending_dialog.pop_front()
	var speaker: String = line.get("speaker", "")
	var text: String = line.get("text", "")
	dialog_text.text = "[b]%s[/b]\n%s" % [speaker, text]
	dialog_btn.text = "继续 ▸"

func _on_dialog_btn_pressed() -> void:
	if pending_dialog.size() > 0:
		_show_next_dialog_line()
	else:
		dialog_showing = false
		dialog_box.visible = false
		# 对话结束后：若是胜利对话，进入结算
		if win_dialog_played:
			_go_to_result()

func _on_end_turn_pressed() -> void:
	if dialog_showing:
		return
	if input_mode != InputMode.NONE:
		_cancel_input()
	_end_player_turn()

func _cancel_input() -> void:
	input_mode = InputMode.NONE
	selected_id = ""
	_clear_overlay()
	command_menu.visible = false
	_clear_command_menu()

func _clear_overlay() -> void:
	for c in overlay.get_children():
		c.queue_free()

func _draw_cells(cells, color: Color) -> void:
	for c in cells:
		var rect := ColorRect.new()
		rect.size = Vector2(TILE - 4, TILE - 4)
		rect.position = Vector2(c.x * TILE + 2, c.y * TILE + 2)
		rect.color = color
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.add_child(rect)

## ---------- 胜负判定 ----------
func _check_victory() -> bool:
	var commander := _enemy_commander()
	if commander and not commander.alive:
		victory = true
		_show_win_dialog()
		return true
	return false

func _check_defeat() -> bool:
	var players := _camp_units("player")
	if players.size() == 0:
		_play_dialog(chapter_id + "_lose")
		return true
	return false

func _show_win_dialog() -> void:
	win_dialog_played = true
	_play_dialog(chapter_id + "_win")

## 结算：占郡 +1000 声望 → 图鉴解锁 → 引导抽奖
func _go_to_result() -> void:
	# 结算：扣留战斗交互，弹出结果面板
	var chapter_title: String = chapter.get("title", "未知")
	var save := SaveCore.load_state()
	SaveCore.add_prestige(save, 1000)
	SaveCore.mark_chapter(save, chapter_id)
	_unlock_collection(save)
	SaveCore.save_state(save)
	var prestige: int = int(save.get("prestige", 0))

	# 填结果面板
	var title_text := "🎉 胜利！%s 告破！" % chapter_title
	var body := "获得 声望 +1000（当前 %d）\n图鉴已更新！" % prestige
	# 通关抽一次种子作为奖励预览（若声望足够）
	if prestige >= 1000:
		var draw := LotteryCore.draw_seed(prestige)
		if draw.success:
			SaveCore.award_item(save, draw.item, 1000)
			SaveCore.save_state(save)
			body += "\n🎁 战利品抽得：" + draw.item.get("name", "?")
	var nxt := _next_chapter()
	_show_result_panel(title_text, body, nxt)

func _show_result_panel(title_text: String, body: String, nxt: String) -> void:
	# 若无面板则构建
	if result_panel == null:
		_build_result_panel()
	result_title.text = title_text
	result_body.text = body
	result_next.visible = nxt != ""
	result_next.disabled = nxt == ""
	result_next.text = "下一关" if nxt != "" else "无下一关"
	result_panel.visible = true

## 用代码构建结算面板（避免 tscn 布局解析问题）
func _build_result_panel() -> void:
	var panel := PanelContainer.new()
	panel.visible = false
	panel.position = Vector2(340, 160)
	panel.size = Vector2(600, 400)
	$UI.add_child(panel)
	result_panel = panel

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	var title := Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	vbox.add_child(title)
	result_title = title

	var body := Label.new()
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 18)
	vbox.add_child(body)
	result_body = body

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	vbox.add_child(row)

	var next := Button.new()
	next.custom_minimum_size = Vector2(150, 50)
	next.text = "下一关"
	next.pressed.connect(_on_result_next)
	row.add_child(next)
	result_next = next

	var home := Button.new()
	home.custom_minimum_size = Vector2(150, 50)
	home.text = "返回主城"
	home.pressed.connect(_on_result_home)
	row.add_child(home)
	result_home = home

func _next_chapter() -> String:
	match chapter_id:
		"chapter1": return "chapter2"
		"chapter2": return "chapter3"
		"chapter3": return "chapter4"
		"chapter4": return ""
	return ""

func _on_result_next() -> void:
	var nxt := _next_chapter()
	if nxt == "":
		return
	preload("res://scripts/battle.gd").chapter_id = nxt
	get_tree().reload_current_scene()

func _on_result_home() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")

## 通关后解锁本关图鉴：遭遇武将/技能/名场面
func _unlock_collection(save: Dictionary) -> void:
	# 武将 / 技能：全图显示于本关的敌方单位 + 我方
	var seen_warriors := {}
	var seen_skills := {}
	for u in units:
		if seen_warriors.has(u.id): continue
		seen_warriors[u.id] = true
		SaveCore.collect(save, "warrior_" + u.id)
		for s in u.skill_ids:
			if not seen_skills.has(s):
				seen_skills[s] = true
				SaveCore.collect(save, "skill_" + s)
	# 名场面：按章节
	var scene_key := _scene_key_for_chapter()
	if scene_key != "":
		SaveCore.collect(save, "scene_" + scene_key)

func _scene_key_for_chapter() -> String:
	match chapter_id:
		"chapter1": return "wenjiu_huaxiong"
		"chapter2": return "sanying_lubu"
		"chapter3": return "naked_battle"
		"chapter4": return "qinzheng_taishan"
	return ""

## ---------- HUD ----------
func _update_hud() -> void:
	turn_label.text = "第 %d 回合 · %s" % [turn_state.turn, TurnCore.phase_name(turn_state.phase)]
