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
const BondsCore := preload("res://scripts/systems/bonds.gd")
const PortraitLoaderCore := preload("res://scripts/ui/portrait_loader.gd")
const UnitViewCore := preload("res://scripts/ui/unit_view.gd")
const ObjectivesCore := preload("res://scripts/core/objectives.gd")

const TILE := 52.0          # 格子像素（升级为52以充实画面）
const MAP_OFFSET := Vector2(24.0, 66.0) # 棋盘左上角偏移
const MAP_W := 12
const MAP_H := 10

## 当前要加载的章节 id（由 main.gd 设置）："chapter1" / "chapter2"
static var chapter_id: String = "chapter1"

static func set_chapter_id(id: String) -> void:
	chapter_id = id

## ---------- 场景节点引用（battle.tscn 中定义） ----------
@onready var map_root: Node2D = $MapRoot
@onready var unit_root: Node2D = $UnitRoot
@onready var overlay: Node2D = $Overlay       # 高亮覆盖层
@onready var info_label: Label = $UI/BottomPanel/Margin/VBox/InfoLabel
@onready var turn_label: Label = $UI/TopBar/TurnBadge/TurnLabel
@onready var chapter_title_lbl: Label = $UI/TopBar/ChapterTitle
@onready var dialog_box: PanelContainer = $UI/DialogBox
@onready var dialog_text: RichTextLabel = $UI/DialogBox/Margin/VBox/Text
@onready var dialog_btn: Button = $UI/DialogBox/Margin/VBox/BtnRow/NextBtn
@onready var dialog_skip_btn: Button = $UI/DialogBox/Margin/VBox/BtnRow/SkipBtn
@onready var end_turn_btn: Button = $UI/TopBar/EndTurnBtn
@onready var help_btn: Button = $UI/TopBar/HelpBtn
@onready var right_dashboard: PanelContainer = $UI/RightDashboard
@onready var command_menu: VBoxContainer = $UI/CommandMenu

## 结算面板（代码构建，节点引用由 _build_result_panel 填充）
var result_panel: PanelContainer
var result_title: Label
var result_body: Label
var result_next: Button
var result_home: Button

## 右侧仪表盘子组件（由 _init_dashboard 填充）
var dash_overview: VBoxContainer
var dash_unit_view: VBoxContainer
var dash_primary_obj: Label
var dash_secondary_obj: Label
var dash_player_count: Label
var dash_enemy_count: Label
var dash_tips_content: Label
var dash_morale_text: Label

var dash_avatar_plate: Polygon2D
var dash_avatar_text: Label
var dash_name_text: Label
var dash_status_text: Label
var dash_hp_text: Label
var dash_hp_bar: ProgressBar
var dash_stat_atk: Label
var dash_stat_def: Label
var dash_stat_mov: Label
var dash_stat_rng: Label
var dash_gimmick_box: PanelContainer
var dash_gimmick_title: Label
var dash_gimmick_desc: Label
var dash_gimmick_bar: ProgressBar

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
var gate_broken := false
var stages: Array = []           # 曹操传式分阶段军令（数据来自 chapter["stages"]）
var stage_idx: int = 0           # 当前阶段下标
var pending_end_turn := false    # 空格结束回合的二次确认（防止没行动就被跳过）
var defeat := false              # 战败标记：置位后停止一切操作（防"全灭后回合空转卡死"）
var obstacle_nodes: Dictionary = {}
var active_arrows: Array = []          # 战场中正在飞行的回旋飞弹
var arrow_nodes: Dictionary = {}       # arrow_id -> Node2D（飞弹视觉节点）

# 输入状态机
enum InputMode { NONE, SELECT, MOVE, ATTACK, SKILL, POST_MOVE, ROAR }
var input_mode := InputMode.NONE
var selected_id := ""
var move_target: Vector2i
var skill_target: Vector2i
var roar_words: int = 6              # 燕人咆哮已喊字数（原著：字数越多威力越大）
var move_origin_cell: Vector2i = Vector2i(-1, -1)
var move_gained_charge: int = 0
var pending_dialog: Array = []      # 待播对话队列
var dialog_showing := false
var queued_events: Array = []       # 已触发过一次的事件 key
var win_dialog_played := false

func _ready() -> void:
	_configure_display()
	_load_chapter()
	_apply_ui_styles()
	_init_dashboard()
	_draw_grid()
	_spawn_units()
	_apply_gear_bonuses()
	_apply_bonds()
	_setup_portrait_layer()
	_init_environment()
	_ready_init_title()
	_update_chapter_objectives()
	_update_dashboard()
	# 初次游玩教学 + 帮助按钮
	if not _has_cleared_any_chapter():
		_show_tutorial()
	help_btn.pressed.connect(_show_help)
	_show_open_dialog()
	_update_hud()

## 控制对话框与底栏互斥显隐（避免重叠覆盖）
func _set_dialog_visible(is_vis: bool) -> void:
	dialog_showing = is_vis
	if dialog_box:
		dialog_box.visible = is_vis
	if not is_vis and portrait_rect:
		portrait_rect.visible = false
	var bp = $UI/BottomPanel
	if bp:
		bp.visible = not is_vis

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
	_set_dialog_visible(true)
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
	_set_dialog_visible(true)
	_show_next_dialog_line()

## 读取背包装备/种子，应用到全局战斗加成（原著神物与仙种生效）
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
	# 原著专属神兵防具
	if inv.has("military_coat"):
		add_def += 15 * int(inv["military_coat"])
	# 仙种（原著单项buff）
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

## 初始化地形：渲染高地格 + 障碍物城门 + 给臧霸设占山状态
## ---------- 将缘（羁绊）系统 ----------
var active_bonds: Array = []

func _player_ids() -> Array:
	var ids: Array = []
	for u in units:
		if u.camp == "player":
			ids.append(u.id)
	return ids

## 开局结算：把上阵阵容命中的原著组合变成看得见的效果
func _apply_bonds() -> void:
	var ids := _player_ids()
	active_bonds = BondsCore.active_bonds(ids)
	if active_bonds.is_empty():
		return
	var mor_bonus: int = BondsCore.taoyuan_morale_bonus(ids)
	if mor_bonus > 0:
		morale["player"] = int(morale.get("player", 100)) + mor_bonus
	var baima_mult: float = BondsCore.baima_atk_mult(ids)
	if baima_mult > 1.0:
		for u in units:
			if u.id == "gongsunzan":
				u.base_atk = int(round(float(u.base_atk) * baima_mult))
	var names: Array[String] = []
	for b in active_bonds:
		names.append(str(b["name"]))
	_spawn_banner("⚔️ 将缘发动：" + " · ".join(names), Color(0.95, 0.85, 0.45))

## 桃园结义：每回合全体回复
func _bonds_regen() -> void:
	var heal: int = BondsCore.taoyuan_regen(_player_ids())
	if heal <= 0:
		return
	for u in _camp_units("player"):
		if u.hp < u.max_hp:
			u.hp = mini(u.max_hp, u.hp + heal)
			_spawn_float_text(u.cell, "+%d 桃园结义" % heal, Color(0.5, 1.0, 0.6))
	_sync_text_all()

## ---------- 立绘层（美术资源可后补，缺失时自动隐藏） ----------
var portrait_rect: TextureRect

func _setup_portrait_layer() -> void:
	portrait_rect = TextureRect.new()
	portrait_rect.name = "DialogPortrait"
	portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# 立绘置于 UI CanvasLayer 之上，位于对话框上方，绝对不被棋盘遮挡
	portrait_rect.position = Vector2(40, 110)
	portrait_rect.size = Vector2(360, 420)
	portrait_rect.z_index = 80
	portrait_rect.visible = false
	portrait_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$UI.add_child(portrait_rect)

## 按当前对话行更新立绘（无图则隐藏，不占位、不报错）
func _update_dialog_portrait(line: Dictionary) -> void:
	if portrait_rect == null:
		return
	var key := PortraitLoaderCore.resolve_key(line)
	if key.is_empty():
		portrait_rect.visible = false
		return
	var tex := PortraitLoaderCore.load_for(key, PortraitLoaderCore.resolve_emotion(line))
	if tex == null:
		portrait_rect.visible = false
		return
	portrait_rect.texture = tex
	portrait_rect.visible = true

func _sync_text_all() -> void:
	for u in units:
		_sync_text(u)

func _init_environment() -> void:
	_draw_hills()
	_draw_obstacles()
	for u in units:
		if "king_hill" in u.skill_ids:
			u.on_hill = _is_hill(u.cell)

func _is_hill(cell: Vector2i) -> bool:
	return cell in hills

func _draw_grid() -> void:
	var grid_node := map_root.get_node_or_null("GridLines")
	if grid_node == null:
		return
	for c in grid_node.get_children():
		c.queue_free()
	for y in range(MAP_H):
		for x in range(MAP_W):
			var tile_rect := ColorRect.new()
			tile_rect.size = Vector2(TILE - 1.0, TILE - 1.0)
			tile_rect.position = MAP_OFFSET + Vector2(x * TILE + 0.5, y * TILE + 0.5)
			if (x + y) % 2 == 0:
				tile_rect.color = Color(0.12, 0.16, 0.11, 0.85)
			else:
				tile_rect.color = Color(0.09, 0.13, 0.08, 0.85)
			tile_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			grid_node.add_child(tile_rect)

func _draw_hills() -> void:
	for h in hills:
		var rect := ColorRect.new()
		rect.size = Vector2(TILE - 2.0, TILE - 2.0)
		rect.position = MAP_OFFSET + Vector2(h.x * TILE + 1.0, h.y * TILE + 1.0)
		rect.color = Color(0.48, 0.36, 0.22, 0.75)  # 泰山高地岩石色
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		map_root.add_child(rect)
	if hills.size() > 0:
		info_label.text += "\n（棕黄色格 = 山地高地，臧霸占山攻防+30%）"

## 绘制地图障碍与要塞城门（古风城堞与铁木大门）
func _draw_obstacles() -> void:
	for k in obstacle_nodes.keys():
		var n: Node = obstacle_nodes[k]
		if n and is_instance_valid(n):
			n.queue_free()
	obstacle_nodes.clear()

	if not chapter.has("map") or not chapter["map"].has("obstacles"):
		return
	for o in chapter["map"]["obstacles"]:
		var pos := Vector2i(int(o.x), int(o.y))
		var is_gate: bool = bool(o.get("is_gate", false))
		var obs_node := Node2D.new()
		obs_node.position = _cell_to_px(pos)
		obs_node.z_index = 8

		# 底板石板/木纹
		var rect := ColorRect.new()
		rect.size = Vector2(TILE - 4.0, TILE - 4.0)
		rect.position = Vector2(-TILE * 0.5 + 2.0, -TILE * 0.5 + 2.0)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if is_gate:
			rect.color = Color(0.45, 0.25, 0.14, 0.95) # 铁木城门色
		else:
			rect.color = Color(0.30, 0.32, 0.36, 0.92) # 青石城楼色
		obs_node.add_child(rect)

		# 边框与文字标识
		var lbl := Label.new()
		lbl.text = "🚪关门" if is_gate else "🧱寨墙"
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.size = Vector2(TILE, TILE)
		lbl.position = Vector2(-TILE * 0.5, -TILE * 0.5)
		lbl.add_theme_font_size_override("font_size", 13 if is_gate else 12)
		lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45) if is_gate else Color(0.85, 0.85, 0.88))
		obs_node.add_child(lbl)

		map_root.add_child(obs_node)
		obstacle_nodes[pos] = obs_node

func _ready_init_title() -> void:
	if chapter.has("title"):
		chapter_title_lbl.text = chapter["title"]
		info_label.text = "【%s】已就绪，请调兵遣将下达军令！" % chapter["title"]

func _apply_ui_styles() -> void:
	# 1. 顶栏样式
	var top_panel: Panel = $UI/TopBar
	if top_panel:
		var top_style := StyleBoxFlat.new()
		top_style.bg_color = Color(0.11, 0.12, 0.15, 0.98)
		top_style.border_color = Color(0.35, 0.30, 0.22, 1.0)
		top_style.border_width_bottom = 2
		top_panel.add_theme_stylebox_override("panel", top_style)

	# 2. 回合徽章
	var turn_badge_node: PanelContainer = $UI/TopBar/TurnBadge
	if turn_badge_node:
		var turn_style := StyleBoxFlat.new()
		turn_style.bg_color = Color(0.18, 0.35, 0.55, 0.9)
		turn_style.set_corner_radius_all(14)
		turn_style.border_color = Color(0.9, 0.8, 0.5, 0.8)
		turn_style.set_border_width_all(1)
		turn_badge_node.add_theme_stylebox_override("panel", turn_style)

	# 3. 底栏战况日志
	var bottom_panel: PanelContainer = $UI/BottomPanel
	if bottom_panel:
		var bottom_style := StyleBoxFlat.new()
		bottom_style.bg_color = Color(0.10, 0.11, 0.14, 0.96)
		bottom_style.border_color = Color(0.32, 0.28, 0.22, 1.0)
		bottom_style.set_border_width_all(2)
		bottom_style.set_corner_radius_all(6)
		bottom_panel.add_theme_stylebox_override("panel", bottom_style)

	# 4. 右侧战术仪表盘
	if right_dashboard:
		var dash_style := StyleBoxFlat.new()
		dash_style.bg_color = Color(0.10, 0.11, 0.14, 0.96)
		dash_style.border_color = Color(0.35, 0.30, 0.22, 1.0)
		dash_style.set_border_width_all(2)
		dash_style.set_corner_radius_all(6)
		right_dashboard.add_theme_stylebox_override("panel", dash_style)

	# 5. 剧情对话框（高对比度墨玉底板 + 鎏金边框，杜绝底层棋盘透字）
	if dialog_box:
		var dialog_style := StyleBoxFlat.new()
		dialog_style.bg_color = Color(0.09, 0.10, 0.13, 0.98)
		dialog_style.border_color = Color(0.85, 0.72, 0.42, 1.0)
		dialog_style.set_border_width_all(2)
		dialog_style.set_corner_radius_all(8)
		dialog_box.add_theme_stylebox_override("panel", dialog_style)

func _init_dashboard() -> void:
	if right_dashboard == null:
		return
	for c in right_dashboard.get_children():
		c.queue_free()

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	right_dashboard.add_child(margin)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 10)
	margin.add_child(main_vbox)

	# ===== A: 战局总览视图 =====
	dash_overview = VBoxContainer.new()
	dash_overview.add_theme_constant_override("separation", 12)
	main_vbox.add_child(dash_overview)

	var ov_title := Label.new()
	ov_title.text = "📜 战况总览与军机推演"
	ov_title.add_theme_font_size_override("font_size", 18)
	ov_title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55))
	dash_overview.add_child(ov_title)

	var obj_panel := PanelContainer.new()
	dash_overview.add_child(obj_panel)
	var obj_box := VBoxContainer.new()
	obj_box.add_theme_constant_override("separation", 6)
	obj_panel.add_child(obj_box)

	dash_primary_obj = Label.new()
	dash_primary_obj.text = "🎯 主要军令：斩杀敌方主将【华雄】"
	dash_primary_obj.add_theme_color_override("font_color", Color(1, 0.9, 0.6))
	dash_primary_obj.add_theme_font_size_override("font_size", 15)
	obj_box.add_child(dash_primary_obj)

	dash_secondary_obj = Label.new()
	dash_secondary_obj.text = "⭐ 战术目标：5 回合内速胜（防止敌方援军压境）"
	dash_secondary_obj.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	dash_secondary_obj.add_theme_font_size_override("font_size", 13)
	obj_box.add_child(dash_secondary_obj)

	var count_row := HBoxContainer.new()
	count_row.add_theme_constant_override("separation", 24)
	dash_overview.add_child(count_row)

	dash_player_count = Label.new()
	dash_player_count.text = "🛡️ 我方健在：3 / 3"
	dash_player_count.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	dash_player_count.add_theme_font_size_override("font_size", 14)
	count_row.add_child(dash_player_count)

	dash_enemy_count = Label.new()
	dash_enemy_count.text = "⚔️ 敌军存活：4 / 4"
	dash_enemy_count.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4))
	dash_enemy_count.add_theme_font_size_override("font_size", 14)
	count_row.add_child(dash_enemy_count)

	dash_morale_text = Label.new()
	dash_morale_text.text = "🚩 战局士气：我方 100 vs 敌方 100"
	dash_morale_text.add_theme_font_size_override("font_size", 14)
	dash_morale_text.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	dash_overview.add_child(dash_morale_text)

	var tips_panel := PanelContainer.new()
	dash_overview.add_child(tips_panel)
	var tips_box := VBoxContainer.new()
	tips_box.add_theme_constant_override("separation", 4)
	tips_panel.add_child(tips_box)

	var tips_title := Label.new()
	tips_title.text = "💡 破局军机要策："
	tips_title.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5))
	tips_title.add_theme_font_size_override("font_size", 14)
	tips_box.add_child(tips_title)

	var tips_content := Label.new()
	tips_content.text = "• 关羽【千里·青龙斩】：每移动 1 格蓄力+1（骑乘赵云效率翻倍）。跑得越远伤害越高！满 10 格可全屏必杀！\n• 张飞【燕人咆哮】：使用【待机】积蓄怒吼轮数，满 3 轮可大范围强力眩晕敌军！\n• 华雄战力随回合膨胀，切勿打阵地持久战！"
	tips_content.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tips_content.add_theme_font_size_override("font_size", 13)
	tips_content.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	tips_box.add_child(tips_content)
	dash_tips_content = tips_content

	var prompt_lbl := Label.new()
	prompt_lbl.text = "👉 点击左侧战场上的任意武将，下达军令或查看属性"
	prompt_lbl.add_theme_font_size_override("font_size", 13)
	prompt_lbl.add_theme_color_override("font_color", Color(0.6, 0.8, 0.6))
	dash_overview.add_child(prompt_lbl)

	# ===== B: 武将详细属性与操作视图 =====
	dash_unit_view = VBoxContainer.new()
	dash_unit_view.add_theme_constant_override("separation", 8)
	dash_unit_view.visible = false
	main_vbox.add_child(dash_unit_view)

	# 1. 头像徽章与姓名身份横排
	var avatar_row := HBoxContainer.new()
	avatar_row.add_theme_constant_override("separation", 14)
	dash_unit_view.add_child(avatar_row)

	var plate_root := Control.new()
	plate_root.custom_minimum_size = Vector2(46, 46)
	avatar_row.add_child(plate_root)

	dash_avatar_plate = Polygon2D.new()
	dash_avatar_plate.polygon = _make_circle_polygon(22, 16)
	dash_avatar_plate.position = Vector2(23, 23)
	plate_root.add_child(dash_avatar_plate)

	dash_avatar_text = Label.new()
	dash_avatar_text.set_anchors_preset(Control.PRESET_FULL_RECT)
	dash_avatar_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dash_avatar_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dash_avatar_text.add_theme_font_size_override("font_size", 16)
	dash_avatar_text.add_theme_color_override("font_color", Color(1, 0.98, 0.92))
	plate_root.add_child(dash_avatar_text)

	var title_box := VBoxContainer.new()
	title_box.add_theme_constant_override("separation", 2)
	avatar_row.add_child(title_box)

	dash_name_text = Label.new()
	dash_name_text.text = "武将名"
	dash_name_text.add_theme_font_size_override("font_size", 16)
	title_box.add_child(dash_name_text)

	dash_status_text = Label.new()
	dash_status_text.text = "部队状态"
	dash_status_text.add_theme_font_size_override("font_size", 12)
	title_box.add_child(dash_status_text)

	# 2. 生命值状态条 (带数值)
	var hp_box := VBoxContainer.new()
	hp_box.add_theme_constant_override("separation", 3)
	dash_unit_view.add_child(hp_box)

	dash_hp_text = Label.new()
	dash_hp_text.text = "生命值: 100 / 100"
	dash_hp_text.add_theme_font_size_override("font_size", 12)
	dash_hp_text.add_theme_color_override("font_color", Color(0.85, 0.9, 0.85))
	hp_box.add_child(dash_hp_text)

	dash_hp_bar = ProgressBar.new()
	dash_hp_bar.custom_minimum_size = Vector2(0, 10)
	dash_hp_bar.show_percentage = false
	var hp_fill_style := StyleBoxFlat.new()
	hp_fill_style.bg_color = Color(0.2, 0.82, 0.38)
	hp_fill_style.set_corner_radius_all(3)
	var hp_bg_style := StyleBoxFlat.new()
	hp_bg_style.bg_color = Color(0.15, 0.16, 0.18)
	hp_bg_style.set_corner_radius_all(3)
	dash_hp_bar.add_theme_stylebox_override("fill", hp_fill_style)
	dash_hp_bar.add_theme_stylebox_override("background", hp_bg_style)
	hp_box.add_child(dash_hp_bar)

	# 3. 四维属性面板 (攻/防/移/射)
	var stat_panel := PanelContainer.new()
	var stat_sb := StyleBoxFlat.new()
	stat_sb.bg_color = Color(0.08, 0.09, 0.11, 0.8)
	stat_sb.border_color = Color(0.25, 0.25, 0.3, 0.5)
	stat_sb.set_border_width_all(1)
	stat_sb.set_corner_radius_all(4)
	stat_sb.content_margin_left = 10
	stat_sb.content_margin_right = 10
	stat_sb.content_margin_top = 8
	stat_sb.content_margin_bottom = 8
	stat_panel.add_theme_stylebox_override("panel", stat_sb)
	dash_unit_view.add_child(stat_panel)

	var stat_grid := GridContainer.new()
	stat_grid.columns = 2
	stat_grid.add_theme_constant_override("h_separation", 20)
	stat_grid.add_theme_constant_override("v_separation", 6)
	stat_panel.add_child(stat_grid)

	dash_stat_atk = Label.new()
	dash_stat_atk.text = "⚔️ 攻击: 20"
	dash_stat_atk.add_theme_font_size_override("font_size", 13)
	stat_grid.add_child(dash_stat_atk)

	dash_stat_def = Label.new()
	dash_stat_def.text = "🛡️ 防御: 10"
	dash_stat_def.add_theme_font_size_override("font_size", 13)
	stat_grid.add_child(dash_stat_def)

	dash_stat_mov = Label.new()
	dash_stat_mov.text = "👟 移动: 4 格"
	dash_stat_mov.add_theme_font_size_override("font_size", 13)
	stat_grid.add_child(dash_stat_mov)

	dash_stat_rng = Label.new()
	dash_stat_rng.text = "🎯 射程: 1 格"
	dash_stat_rng.add_theme_font_size_override("font_size", 13)
	stat_grid.add_child(dash_stat_rng)

	# 4. 专属机制卡片 (关羽龙斩蓄力 / 吕布方天段数 / 张飞咆哮 / 许褚爆甲 / 臧霸高地)
	dash_gimmick_box = PanelContainer.new()
	var gim_sb := StyleBoxFlat.new()
	gim_sb.bg_color = Color(0.12, 0.13, 0.17, 0.95)
	gim_sb.border_color = Color(0.7, 0.55, 0.25, 0.8)
	gim_sb.set_border_width_all(1)
	gim_sb.set_corner_radius_all(6)
	gim_sb.content_margin_left = 10
	gim_sb.content_margin_right = 10
	gim_sb.content_margin_top = 8
	gim_sb.content_margin_bottom = 8
	dash_gimmick_box.add_theme_stylebox_override("panel", gim_sb)
	dash_unit_view.add_child(dash_gimmick_box)

	var gim_box := VBoxContainer.new()
	gim_box.add_theme_constant_override("separation", 4)
	dash_gimmick_box.add_child(gim_box)

	dash_gimmick_title = Label.new()
	dash_gimmick_title.text = "✨ 专属战技机制"
	dash_gimmick_title.add_theme_font_size_override("font_size", 13)
	dash_gimmick_title.add_theme_color_override("font_color", Color(0.95, 0.8, 0.4))
	gim_box.add_child(dash_gimmick_title)

	dash_gimmick_desc = Label.new()
	dash_gimmick_desc.text = "机制说明文本..."
	dash_gimmick_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dash_gimmick_desc.add_theme_font_size_override("font_size", 12)
	gim_box.add_child(dash_gimmick_desc)

	dash_gimmick_bar = ProgressBar.new()
	dash_gimmick_bar.custom_minimum_size = Vector2(0, 8)
	dash_gimmick_bar.show_percentage = false
	var gim_fill_style := StyleBoxFlat.new()
	gim_fill_style.bg_color = Color(0.85, 0.65, 0.25)
	gim_fill_style.set_corner_radius_all(2)
	var gim_bg_style := StyleBoxFlat.new()
	gim_bg_style.bg_color = Color(0.15, 0.16, 0.18)
	gim_bg_style.set_corner_radius_all(2)
	dash_gimmick_bar.add_theme_stylebox_override("fill", gim_fill_style)
	dash_gimmick_bar.add_theme_stylebox_override("background", gim_bg_style)
	gim_box.add_child(dash_gimmick_bar)

## 动态按章节设置主要军令、战术目标与军机要策
func _update_chapter_objectives() -> void:
	if dash_primary_obj == null or dash_secondary_obj == null or dash_tips_content == null:
		return
	var commander := _enemy_commander()
	var c_name := commander.name if commander else "敌方主将"
	var c_hp_str := " (HP: %d/%d)" % [commander.hp, commander.max_hp] if (commander and commander.alive) else ""

	if commander and not commander.alive:
		# 分阶段军令下：主将死了但如果还有后续阶段（如第 1 关还要破城门），不能显示"大获全胜"
		if stages.is_empty() or stage_idx >= stages.size() - 1:
			dash_primary_obj.text = "🎉 敌将已被击溃！大获全胜！"
			return

	match chapter_id:
		"chapter1":
			dash_primary_obj.text = "🎯 主要军令：斩杀敌方主将【%s】%s" % [c_name, c_hp_str]
			dash_secondary_obj.text = "⭐ 战术目标：5 回合内速胜（防止狂力叠高）"
			dash_tips_content.text = "• 关羽【千里·青龙斩】：每移动 1 格蓄力+1，跑得越远刀芒与贯穿越长！满 10 格震裂城门引发敌军防线崩溃(DEF-20%)！\n• 张飞【燕人咆哮】：点技能后连点喊字，喊得越长威力越大！六字速控，十四字眩晕两回合！\n• 赵云【无限耐力】：牛马神技！行动后直接自愈15%生命！普攻每2次追加一枪！关羽骑乘触发双子合击！\n• 华雄战力随回合膨胀(+15%/回合)，切勿打持久消耗战！"
		"chapter2":
			dash_primary_obj.text = "🎯 主要军令：击退天下无双【%s】%s" % [c_name, c_hp_str]
			dash_secondary_obj.text = "⭐ 战术目标：打断方天连击，破除铁皮无敌"
			dash_tips_content.text = "• 吕布【方天乱舞】：连击第 3 击伤害翻 3 倍，并触发【两息铁皮无敌】（受到一切伤害为0）！\n• 张飞【燕人咆哮】点后连点喊字：十四字「谁敢与我决一死战」可眩晕两回合并震碎铁皮，但声浪敌我不分（静音耳塞可免疫）！\n• 关羽骑乘赵云双子合击（1.5倍输出），抓住破防窗口集火击破！"
		"chapter3":
			dash_primary_obj.text = "🎯 主要军令：降伏虎痴【%s】%s" % [c_name, c_hp_str]
			dash_secondary_obj.text = "⭐ 战术目标：全员爆甲狂笑互搏，集火克敌"
			dash_tips_content.text = "• 许褚【裸衣死战】：半血后爆甲降低 50% 防御，但获得双倍攻速与吸血！\n• 爆甲波及全场，我方防御同样骤降，必须迅速集火秒杀！\n• 活用行囊【大黄丹】AOE 或远距离战法，避免与裸衣许褚近身拼刀！"
		"chapter4":
			dash_primary_obj.text = "🎯 主要军令：扫平泰山盘踞【%s】%s" % [c_name, c_hp_str]
			dash_secondary_obj.text = "⭐ 战术目标：夺取险峰高地，破其坚垒"
			dash_tips_content.text = "• 臧霸【占山为王】：身处棕黄高地格攻防额外提升 30%！\n• 刘皇叔亲征踏险峰，可抢先占领高地或引诱臧霸下山！\n• 高地单位对我方有压制优势，切忌在低洼处迎击！"
		_:
			dash_primary_obj.text = "🎯 主要军令：斩杀敌方主将【%s】%s" % [c_name, c_hp_str]
			dash_secondary_obj.text = "⭐ 战术目标：全歼敌军或斩首敌将"
			dash_tips_content.text = "• 活用走位与技能配合，取得战役胜利！"

	# 分阶段军令（曹操传式）：用当前阶段目标覆盖主/副标题，tips 保留各关的机制说明
	if not stages.is_empty():
		var st: Dictionary = stages[clampi(stage_idx, 0, stages.size() - 1)]
		var total_str: String = "" if stages.size() <= 1 else "（第 %d/%d 阶段）" % [stage_idx + 1, stages.size()]
		dash_primary_obj.text = "🎯 %s%s：%s" % [str(st.get("title", "军令")), total_str, str(st.get("objective", ""))]
		if ObjectivesCore.has_next(stages, stage_idx):
			var nxt: Dictionary = stages[stage_idx + 1]
			dash_secondary_obj.text = "⏭ 预备军令：%s —— %s" % [str(nxt.get("title", "")), str(nxt.get("objective", ""))]
		else:
			dash_secondary_obj.text = "⭐ 最终军令：达成后占郡结算 +1000 声望"

	# 将缘（羁绊）：上阵阵容命中原著组合时，把效果写在面板上，别让玩家猜
	if active_bonds.size() > 0:
		var bond_lines: Array[String] = []
		for b in active_bonds:
			bond_lines.append("• 将缘【%s】：%s" % [b["name"], b["desc"]])
		dash_tips_content.text += "\n" + "\n".join(bond_lines)

func _update_dashboard() -> void:
	if dash_overview == null or dash_unit_view == null:
		return
	if dash_morale_text:
		dash_morale_text.text = "🚩 战局士气：我方 %d vs 敌方 %d（攻防修正 x%.2f / x%.2f）" % [
			morale.player, morale.enemy,
			CombatCore.morale_multiplier(morale.player),
			CombatCore.morale_multiplier(morale.enemy)
		]
	var u: BattleUnitScript = _unit_by_id(selected_id)
	if u == null or not u.alive:
		dash_overview.visible = true
		dash_unit_view.visible = false
		dash_player_count.text = "🛡️ 我方在列：%d 人" % _camp_units("player").size()
		dash_enemy_count.text = "⚔️ 敌方存活：%d 人" % _camp_units("enemy").size()
		_update_chapter_objectives()
		return

	dash_overview.visible = false
	dash_unit_view.visible = true

	dash_avatar_plate.color = _character_base_color(u)
	dash_avatar_text.text = _character_calligraphy(u)
	dash_name_text.text = "%s [%s]" % [u.name, u.cls]
	if u.camp == "player":
		dash_name_text.add_theme_color_override("font_color", Color(0.95, 0.85, 0.45))
		dash_status_text.text = "我方部队 · %s" % ("已行动" if u.acted else "● 待命中")
		dash_status_text.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6) if u.acted else Color(0.4, 0.9, 0.5))
	else:
		dash_name_text.add_theme_color_override("font_color", Color(1.0, 0.4, 0.35))
		dash_status_text.text = "敌方阵营 · %s" % ("主将" if u.is_commander else "精锐")
		dash_status_text.add_theme_color_override("font_color", Color(1.0, 0.5, 0.4))

	if u.is_stunned():
		dash_status_text.text += " · 💫 眩晕中"
	if u.is_mounted():
		dash_status_text.text += " · 🐎 骑乘合体"
	if u.cell in hills:
		dash_status_text.text += " · ⛰️ 高地优势(+30%)"

	dash_hp_text.text = "生命值: %d / %d" % [u.hp, u.max_hp]
	dash_hp_bar.value = float(u.hp) / float(max(u.max_hp, 1)) * 100.0

	var hill_tag := " (⛰️高地)" if u.cell in hills else ""
	dash_stat_atk.text = "⚔️ 攻击力: %d%s" % [u.effective_atk(), hill_tag]
	dash_stat_def.text = "🛡️ 防御力: %d%s" % [u.effective_def(), hill_tag]
	dash_stat_mov.text = "👟 移动力: %d 格" % u.mov
	dash_stat_rng.text = "🎯 射  程: %s" % u.get_attack_shape_desc()

	if "dragon_slash" in u.skill_ids:
		var dt: Dictionary = CombatCore.dragon_charge_tier(u.charge)
		dash_gimmick_title.text = "🐉 千里青龙势 · %s" % dt.name
		dash_gimmick_title.add_theme_color_override("font_color", dt.color)
		var cap: int = CombatCore.dragon_charge_cap(u.is_mounted())
		var next_hint := ""
		if u.charge >= 18 and u.charge < 20:
			next_hint = "\n⚡ 再走 %d 格 = 传说档【裂地千里】：沿直线贯穿 + 破城门 + 声望！" % (20 - u.charge)
		elif u.charge >= 8 and u.charge < 10:
			next_hint = "\n⚡ 再走 %d 格 = 【劈山裂城】质变：贯穿 4→12 格、可破城门！" % (10 - u.charge)
		elif u.charge < 8:
			next_hint = "\n💡 10 格可破城门，20 格（骑赵云）可沿直线一路贯穿到底。"
		if u.charge >= 5:
			var who: String = "10 格内敌军" if u.charge >= 10 else "附近敌军"
			next_hint += "\n⚠ 蓄力外泄，%s 正朝关羽扑来打断！（骑赵云可挡下第一击）" % who
		dash_gimmick_desc.text = "多回合逃窜蓄势: %d/%d格 (倍率 %.1fx)\n💡 绕场跑图叠气势！受击气脉震散直接清零！%s" % [u.charge, cap, CombatCore.dragon_charge_multiplier(u.charge), next_hint]
		dash_gimmick_bar.value = (float(u.charge) / float(cap)) * 100.0
	elif "roar" in u.skill_ids:
		dash_gimmick_title.text = "🗣️ 燕人咆哮 · 字数越多威力越大"
		dash_gimmick_title.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
		var cd_rem: int = u.cds.get("roar", 0)
		if cd_rem > 0:
			dash_gimmick_desc.text = "战吼回气冷却中（剩余 %d 回合）\n💡 原著天生神嗓！点技能后连点喊字，喊多长你说了算。" % cd_rem
			dash_gimmick_bar.value = (float(maxi(0, 3 - cd_rem)) / 3.0) * 100
		else:
			dash_gimmick_desc.text = "绝技【燕人咆哮】已就绪（开局即用）！\n💡 六字「燕人张飞在此」= 速控 1 回合\n💡 十四字「谁敢与我决一死战」= 眩晕 2 回合 + 震碎吕布铁皮，但声浪敌我不分（戴耳塞免疫）"
			dash_gimmick_bar.value = 100
	elif u.id == "huaxiong":
		dash_gimmick_title.text = "🩸 逃兵狂热 (拖延暴怒)"
		dash_gimmick_title.add_theme_color_override("font_color", Color(1.0, 0.3, 0.2))
		dash_gimmick_desc.text = "已拖延 %d 回合，攻击强化 %.2fx (当前 ATK: %d)\n⚠ 必须速战速决！" % [u.hua_rage_turns, CombatCore.hua_boost_multiplier(u.hua_rage_turns), u.effective_atk()]
		dash_gimmick_bar.value = min(u.hua_rage_turns * 20, 100)
	elif "lubu_fangtian" in u.skill_ids:
		dash_gimmick_title.text = "🔥 鬼神方天 (方天连击)"
		dash_gimmick_title.add_theme_color_override("font_color", Color(0.9, 0.4, 1.0))
		dash_gimmick_desc.text = "连击段数 %d/3 (下一击倍率 %.1fx)\n⚠ 连击跨回合保留，第3击翻3倍！用张飞怒吼打断！" % [u.combo_strikes, 3.0 if u.combo_strikes >= 2 else 1.0]
		dash_gimmick_bar.value = (float(u.combo_strikes) / 3.0) * 100
	elif "naked_armor" in u.skill_ids:
		dash_gimmick_title.text = "🛡️ 裸衣死战"
		dash_gimmick_title.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
		dash_gimmick_desc.text = "状态：%s\n💡 爆甲减防50%%，双倍攻速+吸血恢复！" % ("吸血死战中！" if u.lifesteal_active else "蓄势待发")
		dash_gimmick_bar.value = 100 if u.lifesteal_active else 0
	elif "king_hill" in u.skill_ids:
		dash_gimmick_title.text = "⛰️ 占山为王"
		dash_gimmick_title.add_theme_color_override("font_color", Color(0.8, 0.7, 0.4))
		dash_gimmick_desc.text = "高地状态：%s\n💡 占领棕黄高地格攻防额外+30%%" % ("【已占山】攻防大增！" if u.on_hill else "未占领高地")
		dash_gimmick_bar.value = 100 if u.on_hill else 0
	else:
		dash_gimmick_title.text = "⚔️ 兵种特性"
		dash_gimmick_title.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
		dash_gimmick_desc.text = "【%s】常规战阵部队" % u.cls
		dash_gimmick_bar.value = 0

func _configure_display() -> void:
	# 窗口/相机对齐
	Engine.max_fps = 60
	# ⚠ 只在「窗口模式且尺寸不符」时纠正；玩家全屏时强行改 size 会把画面挤到左下角
	var w := get_window()
	if w.mode == Window.MODE_WINDOWED and w.size != Vector2i(1280, 720):
		w.size = Vector2i(1280, 720)

func _load_chapter() -> void:
	var ch_file: String = "res://data/chapters/%s.json" % chapter_id
	var dl_file: String = "res://data/dialogs/%s_dialogs.json" % chapter_id
	chapter = _load_json(ch_file)
	dialogs = _load_json(dl_file)
	# 分阶段军令（曹操传式）：关卡没写 stages 时按 win_condition 合成单阶段，保证旧数据兼容
	var raw_stages = chapter.get("stages", [])
	if typeof(raw_stages) == TYPE_ARRAY and not (raw_stages as Array).is_empty():
		stages = raw_stages
	else:
		stages = ObjectivesCore.build_default_stages(str(chapter.get("win_condition", "kill_commander")))
	stage_idx = 0
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

	# 1. 底部微阴影
	var shadow := Polygon2D.new()
	shadow.name = "Shadow"
	shadow.polygon = _make_circle_polygon(TILE * 0.42, 14)
	shadow.position = Vector2(0, 3)
	shadow.color = Color(0, 0, 0, 0.4)
	node.add_child(shadow)

	# 2. 外层金属令牌边框（金边我方 / 铜红边敌方）
	var rim := Polygon2D.new()
	rim.name = "Rim"
	rim.polygon = _make_circle_polygon(TILE * 0.40, 16)
	var rim_color := Color(0.92, 0.78, 0.36) if u.camp == "player" else Color(0.85, 0.35, 0.30)
	if u.is_commander:
		rim_color = Color(1.0, 0.88, 0.45)
	rim.color = rim_color
	node.add_child(rim)

	# 3. 内核将牌底盘
	var plate := Polygon2D.new()
	plate.name = "Plate"
	plate.polygon = _make_circle_polygon(TILE * 0.34, 16)
	plate.color = _character_base_color(u)
	node.add_child(plate)

	# 4. 中心书法粗体大字
	var char_lbl := Label.new()
	char_lbl.name = "CharLabel"
	char_lbl.text = _character_calligraphy(u)
	char_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	char_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	char_lbl.position = Vector2(-16, -15)
	char_lbl.size = Vector2(32, 30)
	char_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	char_lbl.add_theme_font_size_override("font_size", 17)
	char_lbl.add_theme_color_override("font_color", Color(1, 0.98, 0.92))
	node.add_child(char_lbl)

	# 4.5 单位贴图与序列帧动画
	#     实现全部在 scripts/ui/unit_view.gd（视觉层，动画侧维护）——机制侧只管调用
	var used_art: bool = UnitViewCore.build_art(node, u.id, TILE)
	if used_art:
		plate.visible = false
		char_lbl.visible = false

	# 5. 头顶悬浮动态血条 (背景 + 填充)
	var bar_bg := ColorRect.new()
	bar_bg.name = "HPBarBg"
	bar_bg.size = Vector2(36, 5)
	bar_bg.position = Vector2(-18, -25)
	bar_bg.color = Color(0.1, 0.1, 0.1, 0.85)
	bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_child(bar_bg)

	var bar_fill := ColorRect.new()
	bar_fill.name = "HPBarFill"
	bar_fill.size = Vector2(34, 3)
	bar_fill.position = Vector2(-17, -24)
	bar_fill.color = Color(0.2, 0.85, 0.35)
	bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_child(bar_fill)

	# 6. 底部名字铭牌
	var name_lbl := Label.new()
	name_lbl.name = "NameLabel"
	name_lbl.text = u.name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.position = Vector2(-36, 16)
	name_lbl.size = Vector2(72, 16)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_lbl.add_theme_font_size_override("font_size", 10)
	name_lbl.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
	node.add_child(name_lbl)

	# 7. 状态标签 (💫 / 🐎 / 🔥)
	var status_lbl := Label.new()
	status_lbl.name = "StatusLabel"
	status_lbl.text = ""
	status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_lbl.position = Vector2(-18, -39)
	status_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_lbl.size = Vector2(36, 16)
	status_lbl.add_theme_font_size_override("font_size", 11)
	node.add_child(status_lbl)

	node.set_meta("unit_id", u.id)
	_update_unit_visuals(u, node)
	return node

func _character_calligraphy(u) -> String:
	match u.id:
		"guanyu": return "关"
		"zhangfei": return "张"
		"liubei": return "刘"
		"zhaoyun": return "云"
		"huaxiong": return "雄"
		"lubu": return "布"
		"xuchu": return "褚"
		"zangba": return "霸"
		"changxi": return "豨"
		"wuan_guo": return "国"
	if u.name.length() > 0:
		return u.name[0]
	return "兵"

func _character_base_color(u) -> Color:
	match u.id:
		"guanyu": return Color(0.11, 0.40, 0.22)   # 碧绿长须
		"zhangfei": return Color(0.12, 0.22, 0.48) # 怒雷黑青
		"liubei": return Color(0.65, 0.18, 0.22)   # 汉室玄赤
		"zhaoyun": return Color(0.15, 0.48, 0.56)  # 银龙青霜
		"huaxiong": return Color(0.55, 0.14, 0.14) # 西凉狂血
		"lubu": return Color(0.40, 0.10, 0.35)     # 鬼神紫煞
		"xuchu": return Color(0.65, 0.38, 0.12)    # 虎痴赭黄
		"zangba": return Color(0.38, 0.30, 0.22)   # 泰山磐石
		"changxi": return Color(0.35, 0.38, 0.25)  # 飞龟草绿
	return Color(0.18, 0.42, 0.68) if u.camp == "player" else Color(0.68, 0.22, 0.20)

func _update_unit_visuals(u, node: Node2D) -> void:
	if node == null:
		return
	var fill: ColorRect = node.get_node_or_null("HPBarFill")
	if fill:
		var pct := clampf(float(u.hp) / float(max(u.max_hp, 1)), 0.0, 1.0)
		fill.size.x = 34.0 * pct
		if pct > 0.5:
			fill.color = Color(0.2, 0.85, 0.35)
		elif pct > 0.2:
			fill.color = Color(0.95, 0.75, 0.2)
		else:
			fill.color = Color(0.9, 0.25, 0.2)

	var status: Label = node.get_node_or_null("StatusLabel")
	if status:
		var s := ""
		if u.is_stunned():
			s += "💫"
		if u.is_mounted():
			s += "🐎"
		if u.rage_multiplier > 1.1 or u.hua_rage_turns > 0:
			s += "🔥"
		if u.armor_broken:
			s += "🛡️"
		status.text = s

	# 未行动 vs 已行动半透明调和
	if u.camp == "player":
		node.modulate.a = 0.6 if u.acted else 1.0
	else:
		node.modulate.a = 1.0

func _camp_color(camp: String) -> Color:
	return Color(0.2, 0.6, 0.9) if camp == "player" else Color(0.9, 0.3, 0.2)

func _cell_to_px(cell: Vector2i) -> Vector2:
	return MAP_OFFSET + Vector2(cell.x * TILE + TILE / 2.0, cell.y * TILE + TILE / 2.0)

func _px_to_cell(pos: Vector2) -> Vector2i:
	var rel := pos - MAP_OFFSET
	if rel.x < 0 or rel.y < 0:
		return Vector2i(-1, -1)
	var cx := floori(rel.x / TILE)
	var cy := floori(rel.y / TILE)
	if cx < 0 or cx >= MAP_W or cy < 0 or cy >= MAP_H:
		return Vector2i(-1, -1)
	return Vector2i(cx, cy)

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
			# 被骑乘的坐骑不作为独立占位障碍
			if u.mount.has("rider"):
				continue
			out.append(u.cell)
	for o in chapter["map"]["obstacles"]:
		out.append(Vector2i(o.x, o.y))
	return out

func _get_unit_mov(u: BattleUnitScript) -> int:
	return u.effective_mov()

func _sync_node(u) -> void:
	var node: Node2D = unit_nodes.get(u.id)
	if node:
		node.position = _cell_to_px(u.cell)
		_sync_text(u)

## 仅更新单位文本（血量/名字），不动位置（用于移动动画期间）
func _sync_text(u) -> void:
	var node: Node2D = unit_nodes.get(u.id)
	if node:
		if "king_hill" in u.skill_ids:
			u.on_hill = _is_hill(u.cell)
		_update_unit_visuals(u, node)
	_update_dashboard()

## ---------- 输入交互 ----------
func _input(event: InputEvent) -> void:
	# 1. 剧情对白阶段：点屏幕任意空白处、点对话框、按空格/回车，均立即翻到下一句！
	if dialog_showing:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			# 如果用户点击在“跳过剧情”按钮内，让跳过剧情按钮去处理
			if dialog_skip_btn and dialog_skip_btn.is_visible_in_tree():
				var skip_rect := dialog_skip_btn.get_global_rect()
				if skip_rect.has_point(event.position):
					return
			_on_dialog_btn_pressed()
			get_viewport().set_input_as_handled()
			return
		elif event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and (event.keycode == KEY_SPACE or event.keycode == KEY_ENTER)):
			_on_dialog_btn_pressed()
			get_viewport().set_input_as_handled()
			return
		return

	# 2. 燕人咆哮喊字阶段：连点左键/空格累加字数，字数越多威力越大（原著机制）
	if input_mode == InputMode.ROAR:
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT:
				_add_roar_word()
				get_viewport().set_input_as_handled()
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				# 右键：不喊了，按当前字数直接出手
				_execute_roar(roar_words)
				get_viewport().set_input_as_handled()
			return
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
				_add_roar_word()
				get_viewport().set_input_as_handled()
				return
		return

	# 战败/胜利结算后不再接受战棋操作（对白仍可推进）
	if defeat or victory:
		return

	# 3. 空格 = 结束我方回合（对白/喊字阶段已在上方拦截）
	#    有未行动单位时先警告，再按一次才确认 —— 避免"没行动就被跳过"
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		if input_mode == InputMode.NONE and not dialog_showing:
			_try_end_turn_by_space()
			get_viewport().set_input_as_handled()
			return

	# 4. 正常战棋交互阶段：
	if event is InputEventMouseButton and event.pressed:
		# 右键：快速取消选择/返回自由视角
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_cancel_input()
			get_viewport().set_input_as_handled()
			return

		# 左键点击棋盘：
		if event.button_index == MOUSE_BUTTON_LEFT:
			# 曹操传贴身气泡菜单：若鼠标点击落在命令菜单内，放行给 UI 按钮响应，严禁拦截！
			if command_menu.visible:
				var m_rect: Rect2 = command_menu.get_global_rect()
				for child in command_menu.get_children():
					if child is Control:
						m_rect = m_rect.merge(child.get_global_rect())
				if m_rect.has_point(event.position) or m_rect.has_point(get_global_mouse_position()):
					return

			# 三重坐标判定：优先使用事件原始物理坐标 event.position，回退支持 get_global_mouse_position 与 viewport 坐标
			var cell := _px_to_cell(event.position)
			if cell == Vector2i(-1, -1):
				cell = _px_to_cell(get_global_mouse_position())
			if cell == Vector2i(-1, -1):
				cell = _px_to_cell(get_viewport().get_mouse_position())

			if cell != Vector2i(-1, -1):
				_handle_click(cell)
				get_viewport().set_input_as_handled()

func _handle_click(cell: Vector2i) -> void:
	# 统一前置：点到"本回合已行动完毕的我方单位"一律只做查看，不进入任何可操作态。
	# 否则状态机会残留 SELECT / POST_MOVE，出现"点一下他还能继续移动"、
	# 命令菜单不消失、之后再点地面反应异常等一串怪现象。
	var clicked: BattleUnitScript = _unit_at(cell)
	if clicked != null and clicked.camp == "player" and clicked.alive and clicked.acted:
		_inspect_unit(clicked.id)
		return
	match input_mode:
		InputMode.NONE:
			var u: BattleUnitScript = _unit_at(cell)
			if u:
				if u.camp == "player" and u.alive and not u.acted:
					_select_unit(u.id)
				else:
					_inspect_unit(u.id)
			else:
				_cancel_input()
		InputMode.SELECT:
			var u: BattleUnitScript = _unit_at(cell)
			if u:
				if u.id == selected_id:
					# 再次点击已选中的武将自身：原地待命，在身旁弹出指令气泡
					_clear_overlay()
					_show_command_menu()
				elif u.camp == "player" and u.alive and not u.acted:
					_select_unit(u.id)
				elif _is_in_attack_range(cell):
					# 战棋便捷交互：直接点击射程内敌军，原地发动攻击！
					_do_attack(cell)
				else:
					_inspect_unit(u.id)
			elif _is_in_reachable(cell):
				# 曹操传经典手感：直接点击高亮绿格进行行军！走到目标格后再在身旁弹出指令气泡！
				_do_move(cell)
			else:
				_cancel_input()
		InputMode.MOVE:
			if _is_in_reachable(cell):
				_do_move(cell)
			else:
				_show_command_menu()
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
		InputMode.POST_MOVE:
			if _is_in_attack_range(cell):
				_do_attack(cell)
			elif _is_in_skill_range(cell):
				_do_skill(cell)
			else:
				_show_command_menu()

func _inspect_unit(id: String) -> void:
	selected_id = id
	_clear_overlay()
	_clear_command_menu()
	command_menu.visible = false
	# 仅"查看"用途：绝不能进入 SELECT 可操作态。
	# （这里曾经设成 SELECT，导致玩家点一下已行动的武将查看信息后，
	#   再点地面就能让他移动——即玩家反馈的"放完技能还能移动"）
	input_mode = InputMode.NONE
	_update_dashboard()
	var u: BattleUnitScript = _unit_by_id(id)
	if u:
		if u.camp == "enemy":
			info_label.text = "侦查敌情：【%s】HP %d/%d, 攻 %d, 防 %d" % [u.name, u.hp, u.max_hp, u.effective_atk(), u.effective_def()]
		else:
			info_label.text = "【%s】本回合已行动完毕（仅查看，不可操作）。" % u.name

func _unit_at(cell: Vector2i) -> BattleUnitScript:
	for u in units:
		if u.alive and u.cell == cell:
			return u
	return null

## 选中单位：高亮移动格 + 显示命令菜单
func _select_unit(id: String) -> void:
	# 切换到别的单位时，清空"已移动"上下文
	# （move_origin_cell 是关卡级变量，不清的话：移动 A 之后去选 B，B 会被误判为"已移动"而无法行动）
	if id != selected_id:
		move_origin_cell = Vector2i(-1, -1)
		move_gained_charge = 0
	selected_id = id
	pending_end_turn = false   # 玩家一旦开始操作，取消"结束回合"的待确认状态
	var u: BattleUnitScript = _unit_by_id(id)
	if u == null or not u.alive:
		_cancel_input()
		return
	# 纵深防御：本回合已行动的单位不能被选中操作。
	# 点击入口虽然有 not u.acted 判断，但 _select_unit 是公共入口，任何绕过
	# （直接调用、撤回移动、以后新增的快捷键等）都必须拦得住，否则会出现
	# "放完技能还能移动 / 还能再打一次" 这类漏洞。
	if u.camp == "player" and u.acted:
		selected_id = ""
		input_mode = InputMode.NONE
		_clear_overlay()
		_clear_command_menu()
		command_menu.visible = false
		return
	_clear_overlay()
	var blocked := _blocked_cells(id)
	var reach := GridCore.reachable(u.cell, _get_unit_mov(u), MAP_W, MAP_H, blocked)
	_draw_cells(reach.keys(), Color(0.2, 0.8, 0.4, 0.35))
	input_mode = InputMode.SELECT
	_update_dashboard()
	_clear_command_menu()
	command_menu.visible = false

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
	if u == null or not u.alive or dialog_showing or u.camp != "player" or u.acted:
		command_menu.visible = false
		# 已行动完的单位不该停留在可操作态；这里顺手清掉，避免状态残留
		if u != null and u.acted:
			input_mode = InputMode.NONE
			_clear_overlay()
		return
	input_mode = InputMode.POST_MOVE if move_origin_cell != Vector2i(-1, -1) else InputMode.SELECT
	command_menu.visible = true

	# 曹操传风格贴身浮动弹窗：定位在角色身旁
	var cell_px := _cell_to_px(u.cell)
	var menu_w: float = 144.0
	var menu_x: float = cell_px.x + TILE / 2.0 + 8.0
	if menu_x + menu_w > 640.0:
		menu_x = cell_px.x - TILE / 2.0 - menu_w - 8.0
	if menu_x < 10.0:
		menu_x = 10.0
	var menu_y: float = clampf(cell_px.y - 48.0, 70.0, 460.0)
	command_menu.position = Vector2(menu_x, menu_y)

	var bubble_panel := PanelContainer.new()
	var bubble_sb := StyleBoxFlat.new()
	bubble_sb.bg_color = Color(0.08, 0.10, 0.14, 0.96)
	bubble_sb.border_color = Color(0.9, 0.78, 0.35, 1.0)
	bubble_sb.set_border_width_all(2)
	bubble_sb.set_corner_radius_all(6)
	bubble_sb.content_margin_left = 6
	bubble_sb.content_margin_right = 6
	bubble_sb.content_margin_top = 6
	bubble_sb.content_margin_bottom = 6
	bubble_panel.add_theme_stylebox_override("panel", bubble_sb)
	command_menu.add_child(bubble_panel)

	var list_vbox := VBoxContainer.new()
	list_vbox.add_theme_constant_override("separation", 5)
	bubble_panel.add_child(list_vbox)

	var title_lbl := Label.new()
	title_lbl.text = "【%s】" % u.name
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 13)
	title_lbl.add_theme_color_override("font_color", Color(0.95, 0.85, 0.5))
	list_vbox.add_child(title_lbl)

	# 1. 攻击
	var can_atk := _has_attackable_target(u)
	var btn_atk := Button.new()
	btn_atk.custom_minimum_size = Vector2(136, 34)
	btn_atk.text = "⚔️ 普通攻击"
	btn_atk.disabled = not can_atk
	btn_atk.pressed.connect(_cmd_attack)
	list_vbox.add_child(btn_atk)

	# 2. 绝技
	if u.skill_ids.size() > 0:
		var skill_id: String = u.skill_ids[0]
		var ready := u.skill_ready(skill_id)
		var skill_name: String = SkillsCore.meta(skill_id).get("name", "绝技")
		var btn_skill := Button.new()
		btn_skill.custom_minimum_size = Vector2(136, 34)
		if skill_id == "dragon_slash":
			# 差一格的玩家最容易被骗：明确预告质变档（10 格破城门 / 20 格沿直线贯穿到底）
			var cap: int = CombatCore.dragon_charge_cap(u.is_mounted())
			if u.charge >= cap:
				btn_skill.text = "✨ 龙斩(%d/%d) %s" % [u.charge, cap, "裂地千里!" if cap >= 20 else "劈山裂城!"]
			elif u.charge >= cap - 2:
				btn_skill.text = "✨ 龙斩(%d/%d) ⚡再%d格质变" % [u.charge, cap, cap - u.charge]
			else:
				btn_skill.text = "✨ 龙斩(%d/%d)" % [u.charge, cap]
		elif skill_id == "roar":
			btn_skill.text = "✨ 咆哮·连点喊字%s" % ("" if ready else "(CD)")
		else:
			btn_skill.text = "✨ %s%s" % [skill_name, "" if ready else "(CD)"]
		btn_skill.disabled = not ready or not _has_skill_target(u, skill_id)
		btn_skill.pressed.connect(_cmd_skill)
		list_vbox.add_child(btn_skill)

	# 3. 待机休整
	var btn_wait := Button.new()
	btn_wait.custom_minimum_size = Vector2(136, 34)
	btn_wait.text = "🛡️ 待机休整"
	btn_wait.pressed.connect(_cmd_wait)
	list_vbox.add_child(btn_wait)

	# 4. 移动后撤回 / 未移动取消
	if move_origin_cell != Vector2i(-1, -1):
		var btn_undo := Button.new()
		btn_undo.custom_minimum_size = Vector2(136, 34)
		btn_undo.text = "↩️ 撤回移动"
		btn_undo.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
		btn_undo.pressed.connect(_cmd_undo_move)
		list_vbox.add_child(btn_undo)
	else:
		var btn_cancel := Button.new()
		btn_cancel.custom_minimum_size = Vector2(136, 34)
		btn_cancel.text = "❌ 取消指令"
		btn_cancel.pressed.connect(_cancel_input)
		list_vbox.add_child(btn_cancel)

	# 5. 合体 / 解除合体
	if u.is_mounted():
		var btn_unmount := Button.new()
		btn_unmount.custom_minimum_size = Vector2(136, 34)
		btn_unmount.text = "🏇 解除合体"
		btn_unmount.pressed.connect(_cmd_unmount)
		list_vbox.add_child(btn_unmount)
	else:
		var mount_target := _find_mountable_target(u)
		if mount_target != null:
			var btn_mount := Button.new()
			btn_mount.custom_minimum_size = Vector2(136, 34)
			btn_mount.text = "🐎 战术合体"
			btn_mount.pressed.connect(_cmd_mount.bind(mount_target))
			list_vbox.add_child(btn_mount)

	# 6. 原著神兵 / 军备
	var save := SaveCore.load_state()
	var inv: Dictionary = save.get("inventory", {})
	if int(inv.get("electric_baton", 0)) > 0:
		var btn_baton := Button.new()
		btn_baton.custom_minimum_size = Vector2(136, 34)
		btn_baton.text = "⚡ 电棍(%d)" % int(inv["electric_baton"])
		btn_baton.pressed.connect(_cmd_use_electric_baton)
		list_vbox.add_child(btn_baton)
	if int(inv.get("dongfeng", 0)) > 0:
		var btn_wind := Button.new()
		btn_wind.custom_minimum_size = Vector2(136, 34)
		btn_wind.text = "💨 借东风(%d)" % int(inv["dongfeng"])
		btn_wind.pressed.connect(_cmd_use_dongfeng)
		list_vbox.add_child(btn_wind)
	if int(inv.get("dahuangdan", 0)) > 0:
		var btn_dan := Button.new()
		btn_dan.custom_minimum_size = Vector2(136, 34)
		btn_dan.text = "💊 大黄丹(%d)" % int(inv["dahuangdan"])
		btn_dan.pressed.connect(_cmd_use_dahuangdan)
		list_vbox.add_child(btn_dan)

func _find_mountable_target(u) -> BattleUnitScript:
	for other in units:
		if other.alive and other.camp == u.camp and other.id != u.id:
			if SkillsCore.can_mount(u, other):
				return other
	return null

func _cmd_mount(target: BattleUnitScript) -> void:
	var u: BattleUnitScript = _unit_by_id(selected_id)
	if u and target:
		SkillsCore.do_mount(u, target)
		target.cell = u.cell
		var target_node: Node2D = unit_nodes.get(target.id)
		if target_node:
			target_node.visible = false
		_spawn_banner("🐎 关羽骑赵云天下无敌！双人开火！", Color(0.2, 0.85, 1.0))
		_shake_camera(5.0)
		_spawn_float_text(u.cell, "🐎 关羽骑赵云！双人合击！", Color(0.3, 0.9, 1.0), true)
		info_label.text = "【%s】骑上【%s】！化身全图疾驰战车！（移动力提升至 %d，普攻触发双人合击！）" % [u.name, target.name, _get_unit_mov(u)]
		_sync_text(u)
		_sync_text(target)
		_show_command_menu()

func _cmd_unmount() -> void:
	var u: BattleUnitScript = _unit_by_id(selected_id)
	if u and u.is_mounted():
		var horse_id: String = u.mount.get("horse", "")
		var horse: BattleUnitScript = _unit_by_id(horse_id) if horse_id != "" else null
		if horse:
			SkillsCore.do_unmount(u, horse)
			var horse_node: Node2D = unit_nodes.get(horse.id)
			if horse_node:
				horse_node.visible = true
			var found_cell: Vector2i = Vector2i(-1, -1)
			for d in GridCore.DIRS4:
				var adj: Vector2i = u.cell + d
				if GridCore.in_bounds(adj, MAP_W, MAP_H) and adj not in _blocked_cells(""):
					found_cell = adj
					break
			# 极端阻挡保护：若周围4格受阻，扩大到切比雪夫半径2外圈寻找空格
			if found_cell == Vector2i(-1, -1):
				for c in GridCore.cells_in_radius(u.cell, 2, MAP_W, MAP_H):
					if c != u.cell and c not in _blocked_cells(""):
						found_cell = c
						break
			if found_cell != Vector2i(-1, -1):
				horse.cell = found_cell
			_sync_node(horse)
			info_label.text = "【%s】与【%s】分离！重回各自独立作战！" % [u.name, horse.name]
			# 空投连携突刺：若赵云落脚点与敌军相邻，立即发动突袭！
			var enemy_target: BattleUnitScript = null
			for t in units:
				if t.alive and t.camp != horse.camp and GridCore.chebyshev(horse.cell, t.cell) <= 1:
					enemy_target = t
					break
			if enemy_target:
				_spawn_float_text(horse.cell, "🗡️ 空投连携突刺！", Color(0.3, 0.9, 1.0), true)
				var dual_ev := SkillsCore.do_dismount_strike(horse, enemy_target)
				_apply_events(dual_ev)
				_unit_bounce(horse.id)
			_sync_text(u)
			_sync_text(horse)
			_show_command_menu()

func _cmd_use_electric_baton() -> void:
	var u: BattleUnitScript = _unit_by_id(selected_id)
	if u and u.alive:
		var target: BattleUnitScript = null
		for d in GridCore.DIRS4:
			var check := _unit_at(u.cell + d)
			if check and check.alive and check.camp != u.camp:
				target = check
				break
		if target:
			var save := SaveCore.load_state()
			var inv: Dictionary = save.get("inventory", {})
			if int(inv.get("electric_baton", 0)) > 0:
				inv["electric_baton"] = int(inv["electric_baton"]) - 1
				save["inventory"] = inv
				SaveCore.save_state(save)
				target.take_damage(10)
				target.stun_turns = maxi(target.stun_turns, 1)
				_clear_overlay()
				command_menu.visible = false
				_screen_flash(Color(0.2, 0.9, 1.0, 0.4), 0.25)
				_spawn_burst(target.cell, Color(0.2, 0.9, 1.0), 3)
				_spawn_float_text(target.cell, "⚡ 滋滋滋！高压电击抽搐眩晕！(-10)", Color(0.2, 0.9, 1.0), true)
				info_label.text = "【%s】掏出防暴电棍！【%s】被电得外焦里嫩、浑身抽搐强行眩晕！" % [u.name, target.name]
				_sync_text(target)
				if not target.alive:
					_unit_node_hide(target.id)
				u.acted = true
				move_origin_cell = Vector2i(-1, -1)
				move_gained_charge = 0
				_after_action(u)
		else:
			info_label.text = "防暴电棍攻击距离仅为近身1格！周围上下左右未发现敌军！"

func _cmd_use_dahuangdan() -> void:
	var u: BattleUnitScript = _unit_by_id(selected_id)
	if u and u.alive:
		var save := SaveCore.load_state()
		var inv: Dictionary = save.get("inventory", {})
		if int(inv.get("dahuangdan", 0)) > 0:
			inv["dahuangdan"] = int(inv["dahuangdan"]) - 1
			save["inventory"] = inv
			SaveCore.save_state(save)
			var ev := SkillsCore.do_use_dahuangdan(u)
			_apply_events(ev)
			_spawn_burst(u.cell, Color(1.0, 0.85, 0.2), 3)
			_spawn_float_text(u.cell, "💊 大黄丹金丹回天！HP回满！", Color(1.0, 0.85, 0.2), true)
			info_label.text = "【%s】吞服传世大黄丹！气血瞬间全满！" % u.name
			u.acted = true
			move_origin_cell = Vector2i(-1, -1)
			move_gained_charge = 0
			_after_action(u)

func _cmd_use_dongfeng() -> void:
	var u: BattleUnitScript = _unit_by_id(selected_id)
	if u and u.alive:
		var save := SaveCore.load_state()
		var inv: Dictionary = save.get("inventory", {})
		if int(inv.get("dongfeng", 0)) > 0:
			inv["dongfeng"] = int(inv["dongfeng"]) - 1
			save["inventory"] = inv
			SaveCore.save_state(save)
			_clear_overlay()
			command_menu.visible = false
			_big_moment("🚀 东风快递 · 使命必达！！")
			_screen_flash(Color(1.0, 0.5, 0.2, 0.5), 0.4)
			_shake_camera(8.0)
			for e in _camp_units("enemy"):
				if e.alive:
					e.take_damage(40)
					_spawn_burst(e.cell, Color(1.0, 0.4, 0.1), 3)
					_spawn_float_text(e.cell, "💥 弹道轰炸 -40！", Color(1.0, 0.5, 0.2), true)
					_sync_text(e)
					if not e.alive:
						_unit_node_hide(e.id)
			info_label.text = "【%s】呼叫微缩版东风！巡航火箭呼啸掠空，敌阵全图轰鸣！" % u.name
			u.acted = true
			move_origin_cell = Vector2i(-1, -1)
			move_gained_charge = 0
			_after_action(u)

func _cmd_undo_move() -> void:
	var u: BattleUnitScript = _unit_by_id(selected_id)
	if u and move_origin_cell != Vector2i(-1, -1):
		u.cell = move_origin_cell
		_sync_node(u)
		if u.is_mounted() and u.mount.has("horse"):
			var horse := _unit_by_id(u.mount["horse"])
			if horse:
				horse.cell = u.cell
				_sync_node(horse)
		if "dragon_slash" in u.skill_ids:
			u.charge = maxi(0, u.charge - move_gained_charge)
		move_origin_cell = Vector2i(-1, -1)
		u.moved_this_turn = false    # 撤回移动后，本回合可以重新移动
		move_gained_charge = 0
		_sync_text(u)
		info_label.text = "已撤回移动，【%s】回到原位。" % u.name
		_select_unit(u.id)

func _has_attackable_target(u) -> bool:
	for t in units:
		if t.alive and t.camp != u.camp and GridCore.can_attack(u.cell, t.cell, u.is_cavalry(), u.rng):
			return true
	return false

func _has_skill_target(u, skill_id: String) -> bool:
	if skill_id == "dragon_slash":
		for d in GridCore.DIRS4:
			var c: Vector2i = u.cell + d
			var enemy := _unit_at(c)
			if enemy and enemy.alive and enemy.camp != u.camp:
				return true
		return false
	elif skill_id == "naked_armor":
		return true
	elif skill_id == "roar":
		# 群控不挑目标：只要自己还活着、技能不在 CD 就能喊
		return true
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
	_clear_overlay()
	var u: BattleUnitScript = _unit_by_id(selected_id)
	if u:
		var targets: Array[Vector2i] = []
		for t in units:
			if t.alive and t.camp != u.camp and GridCore.can_attack(u.cell, t.cell, u.is_cavalry(), u.rng):
				targets.append(t.cell)
		_draw_cells(targets, Color(0.95, 0.25, 0.2, 0.5))
		if u.is_cavalry():
			info_label.text = "【骑兵十字】点击十字正向红框敌军发起冲锋攻击（不可斜打）"
		elif u.rng >= 2:
			info_label.text = "【远程射击】点击射程内红框敌军发起射击"
		else:
			info_label.text = "【步兵八向】点击周围红框敌军发起攻击（可斜向挥砍）"

func _cmd_skill() -> void:
	var u0: BattleUnitScript = _unit_by_id(selected_id)
	# 燕人咆哮是全场群控（原著「群控，敌我不分」）——不需要点目标，点技能直接开喊
	if u0 and "roar" in u0.skill_ids:
		command_menu.visible = false
		_clear_overlay()
		_start_roar_charging(u0)
		return
	input_mode = InputMode.SKILL
	command_menu.visible = false
	_clear_overlay()
	var u: BattleUnitScript = _unit_by_id(selected_id)
	if u and "dragon_slash" in u.skill_ids:
		var dt: Dictionary = CombatCore.dragon_charge_tier(u.charge)
		var line_len: int = int(dt.get("line_len", 1))
		info_label.text = "【青龙偃月斩】请点击上下左右相邻敌军！刀芒将贯穿该敌军及后方 %d 格直线！" % line_len
		var valid_cells: Array[Vector2i] = []
		for d in GridCore.DIRS4:
			var c: Vector2i = u.cell + d
			var enemy := _unit_at(c)
			if enemy and enemy.alive and enemy.camp != u.camp:
				valid_cells.append(c)
		_draw_cells(valid_cells, Color(0.95, 0.35, 0.15, 0.55))
	elif u and "arrow_rain" in u.skill_ids:
		info_label.text = "【白马·回旋飞弹】全图超远视距锁定！请点击全图任意敌军，发射定速追踪飞弹！"
		var valid_cells: Array[Vector2i] = []
		for enemy in units:
			if enemy.alive and enemy.camp != u.camp:
				valid_cells.append(enemy.cell)
		_draw_cells(valid_cells, Color(0.35, 0.75, 1.0, 0.55))
	else:
		info_label.text = "点技能目标"

func _cmd_wait() -> void:
	var u: BattleUnitScript = _unit_by_id(selected_id)
	if u:
		_do_wait(u)

## 待机休整
func _do_wait(u) -> void:
	_clear_overlay()
	command_menu.visible = false
	u.acted = true
	move_origin_cell = Vector2i(-1, -1)
	move_gained_charge = 0
	info_label.text = "%s 待机休整（本回合行动完毕）" % u.name
	_after_action(u)

## ---------- 移动 ----------
func _is_in_reachable(cell: Vector2i) -> bool:
	var u: BattleUnitScript = _unit_by_id(selected_id)
	var blocked := _blocked_cells(selected_id)
	return GridCore.reachable(u.cell, _get_unit_mov(u), MAP_W, MAP_H, blocked).has(cell)

func _do_move(cell: Vector2i) -> void:
	var u: BattleUnitScript = _unit_by_id(selected_id)
	if u == null or not u.alive:
		return
	# 防御：本回合已经行动完毕的单位不能再移动
	# （即使状态机被绕过——例如"查看信息"误入可操作态——也拦得住）
	if u.acted:
		info_label.text = "%s 本回合已行动完毕，不能再移动（仅可查看）。" % u.name
		input_mode = InputMode.NONE
		_clear_overlay()
		return
	# 防御：本回合已经移动过的单位不能再移动（单位级状态，换人也不会被绕过）
	if u.moved_this_turn:
		info_label.text = "%s 本回合已经移动过了（移动后只能攻击 / 绝技 / 待机 / 撤回移动）" % u.name
		_show_command_menu()
		return
	u.moved_this_turn = true
	var blocked := _blocked_cells(selected_id)
	var path := GridCore.path(u.cell, cell, MAP_W, MAP_H, blocked)
	var moved_cells := path.size()
	move_origin_cell = u.cell

	# 关羽蓄力：移动格数 = 蓄力值（骑乘效率×2）
	if "dragon_slash" in u.skill_ids:
		var eff := SkillsCore.mounted_charge_efficiency() if u.is_mounted() else 1
		var cap: int = CombatCore.dragon_charge_cap(u.is_mounted())
		var old_charge: int = u.charge
		u.charge = clampi(u.charge + moved_cells * eff, 0, cap)
		move_gained_charge = u.charge - old_charge
		var dt: Dictionary = CombatCore.dragon_charge_tier(u.charge)
		var cap_hint: String = "（骑赵云可蓄到 20 格）" if not u.is_mounted() else "（合体上限 20 格）"
		info_label.text = "关羽多回合逃窜蓄力 → %d/%d【%s】倍率 %.1fx！%s" % [u.charge, cap, dt.name, CombatCore.dragon_charge_multiplier(u.charge), cap_hint]
		if u.charge >= cap:
			if cap >= 20:
				_spawn_float_text(cell, "🐉 裂地千里！苍龙贯穿一线！", Color(0.15, 1.0, 0.6), true)
				_spawn_banner("🐉 传说档【裂地千里】· 沿直线贯穿 + 破城门！", Color(0.15, 1.0, 0.6))
			else:
				_spawn_float_text(cell, "🐉 劈山裂城！百丈真龙显圣！", Color(0.2, 1.0, 0.4), true)
				_spawn_banner("⚡ 骑上赵云可继续蓄到 20 格 → 传说档【裂地千里】", Color(1.0, 0.88, 0.35))
		elif u.charge >= 18:
			_spawn_float_text(cell, "⚡ 苍龙将成！再走 %d 格【裂地千里】！" % (20 - u.charge), Color(1.0, 0.9, 0.3), true)
			_spawn_banner("⚡ 再走 %d 格 = 传说档【裂地千里】· 沿直线贯穿 + 破城门（当前 %.1fx）" % [20 - u.charge, dt.mult], Color(1.0, 0.88, 0.35))
		elif u.charge >= 10:
			_spawn_float_text(cell, "🐉 劈山裂城！百丈青龙真身降世！", Color(0.2, 1.0, 0.45), true)
		elif u.charge >= 8:
			# 高光预告：把「满 10 格才质变」提前告诉玩家，避免 9 格打出小水花的被欺骗感
			_spawn_float_text(cell, "⚡ 青龙欲裂！再走 %d 格解锁【劈山裂城】！" % (10 - u.charge), Color(1.0, 0.9, 0.3), true)
			_spawn_banner("⚡ 再走 %d 格 = 【劈山裂城】质变 · 贯穿 12 格（当前仅 4 格）" % (10 - u.charge), Color(1.0, 0.88, 0.35))
		elif u.charge >= 7:
			_spawn_float_text(cell, "🐉 龙吟震天！百丈青龙成型！", Color(0.3, 0.9, 0.6), true)
		elif u.charge >= 4:
			_spawn_float_text(cell, "🐉 青龙腾云！刀芒暴涨！", Color(0.4, 0.85, 0.9), false)
		elif u.is_mounted():
			_spawn_float_text(cell, "赵云汗血飞驰！神速冲锋！", Color(0.4, 0.9, 1.0))
		else:
			_spawn_float_text(cell, "马哥撑住！逃跑蓄力中！", Color(0.5, 0.8, 0.9))
	else:
		move_gained_charge = 0
		info_label.text = "%s 移动到 (%d,%d)" % [u.name, cell.x, cell.y]

	_clear_overlay()
	_animate_move(u, path)
	u.cell = cell
	if u.is_mounted() and u.mount.has("horse"):
		var horse := _unit_by_id(u.mount["horse"])
		if horse and horse.alive:
			horse.cell = u.cell
			_sync_node(horse)
	_sync_text(u)

	# 移动完成后进入 POST_MOVE 状态，弹出贴身指令弹窗（曹操传模式：移动后仍可攻击）
	var move_duration: float = float(moved_cells) * 0.06
	if move_duration > 0:
		await get_tree().create_timer(move_duration).timeout
	input_mode = InputMode.POST_MOVE
	_show_command_menu()

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
	return u != null and t != null and t.alive and t.camp != u.camp and GridCore.can_attack(u.cell, cell, u.is_cavalry(), u.rng)

func _do_attack(cell: Vector2i) -> void:
	var u: BattleUnitScript = _unit_by_id(selected_id)
	var t: BattleUnitScript = _unit_at(cell)
	_clear_overlay()
	command_menu.visible = false
	if u:
		_play_unit_attack_anim(u.id, cell)
	var events := SkillsCore.do_attack(u, t)
	_apply_events(events)

	# 骑乘双人双打反馈（关羽刀劈 + 赵云长枪）
	if u.is_mounted():
		_spawn_float_text(t.cell, "🐎 关羽赵云·双子合击！", Color(1.0, 0.85, 0.3), true)
		info_label.text += "\n关羽跨赵云冲锋！双刃齐出打出 1.5 倍合击伤害！"

	# 赵云普攻连击：每 2 次攻击必定追加一枪（额外打出 50% 伤害）
	if u.id == "zhaoyun":
		u.zhaoyun_strike_count += 1
		if u.zhaoyun_strike_count >= 2:
			u.zhaoyun_strike_count = 0
			if t and t.alive:
				var extra_dmg: int = max(int(round(CombatCore.damage(u.effective_atk(), 0.5, t.effective_def()))), 1)
				if t.iron_skin:
					extra_dmg = 0
				t.take_damage(extra_dmg)
				_apply_events([CombatCore.make_damage_event(t.id, extra_dmg, false)])
				_spawn_float_text(t.cell, "⚡ 百鸟追击！额外一枪！", Color(0.4, 0.9, 1.0), true)
				info_label.text += "\n赵云长枪如电！追加百鸟戳刺打出额外 %d 伤害！" % extra_dmg

	# 敌方反击判定：若目标仍存活且未被眩晕，且攻击者在反击射程范围内，触发反击！
	if t and t.alive and not t.is_stunned():
		if GridCore.can_attack(t.cell, u.cell, t.is_cavalry(), t.rng):
			_spawn_float_text(t.cell, "⚡ 阵地反击！", Color(1.0, 0.65, 0.2))
			_play_unit_attack_anim(t.id, u.cell)
			var counter_ev := SkillsCore.do_counter_attack(t, u)
			_apply_events(counter_ev)
			_unit_bounce(t.id)
		elif t.is_cavalry() and GridCore.chebyshev(t.cell, u.cell) == 1:
			# 曹操传精髓：步兵斜角白嫖骑兵，骑兵无法斜向反击！
			_spawn_float_text(t.cell, "🛡️ 斜角受挫！无法反击！", Color(0.4, 0.9, 1.0))
	u.acted = true
	move_origin_cell = Vector2i(-1, -1)
	move_gained_charge = 0
	_after_action(u)

## ---------- 技能 ----------
## 该格是否是城门（chapter.map.obstacles 里 is_gate=true 的那个）
func _is_gate_cell(cell: Vector2i) -> bool:
	if gate_broken:
		return false
	if not chapter.has("map"):
		return false
	for o in chapter["map"].get("obstacles", []):
		if int(o.get("x", -1)) == cell.x and int(o.get("y", -1)) == cell.y:
			return bool(o.get("is_gate", false))
	return false

func _is_in_skill_range(cell: Vector2i) -> bool:
	var u: BattleUnitScript = _unit_by_id(selected_id)
	var t: BattleUnitScript = _unit_at(cell)
	var skill_id: String = u.skill_ids[0] if u.skill_ids.size() > 0 else ""
	# 自身技（裸衣）不需要目标格；范围技（箭雨）仍需点目标附近
	if skill_id == "naked_armor":
		return true
	if t == null or t.camp == u.camp:
		# 例外：关羽的千里青龙斩可以直接劈城门（第 1 关「劈关夺门」阶段）
		if t == null and skill_id == "dragon_slash" and _is_gate_cell(cell):
			return (cell - u.cell) in GridCore.DIRS4
		return false
	match skill_id:
		"dragon_slash":
			var diff := cell - u.cell
			return diff in GridCore.DIRS4
		"roar":
			var roar_r := 2
			var save := SaveCore.load_state()
			var inv: Dictionary = save.get("inventory", {})
			if int(inv.get("megaphone", 0)) > 0:
				roar_r = 4
			return GridCore.chebyshev(u.cell, cell) <= roar_r
		"seven_dash":
			return GridCore.chebyshev(u.cell, cell) <= u.mov
		"arrow_rain":
			return t != null and t.alive and t.camp != u.camp
	return false

func _do_skill(cell: Vector2i) -> void:
	var u: BattleUnitScript = _unit_by_id(selected_id)
	var t: BattleUnitScript = _unit_at(cell)
	var skill_id: String = u.skill_ids[0] if u.skill_ids.size() > 0 else ""
	_clear_overlay()
	command_menu.visible = false
	var events: Array = []
	match skill_id:
		"dragon_slash":
			# 劈城门（第 1 关「劈关夺门」阶段）：目标格是城门、没有单位
			if t == null and _is_gate_cell(cell):
				if u.charge >= 10:
					_big_moment("🐉 千里青龙斩 · 劈关夺门！！")
					_spawn_float_text(cell, "🐉 青龙撞门！", Color(0.3, 1.0, 0.5), true)
					_shake_camera(10.0)
					_break_sishui_gate()
					u.charge = 0
				else:
					_spawn_float_text(cell, "🔨 力道不足！", Color(1.0, 0.6, 0.3), true)
					info_label.text = "汜水关城门厚重！【千里青龙斩】需蓄满 10 格才能一击劈开（当前 %d 格）" % u.charge
				u.acted = true
				move_origin_cell = Vector2i(-1, -1)
				move_gained_charge = 0
				_sync_text(u)
				_after_action(u)
				return
			var dt: Dictionary = CombatCore.dragon_charge_tier(u.charge)
			var line_len: int = int(dt.get("line_len", 1))
			var line_path: Array[Vector2i] = GridCore.line_cells(u.cell, t.cell, line_len, MAP_W, MAP_H)
			var pierced_targets: Array = []
			for l_cell in line_path:
				var pu: BattleUnitScript = _unit_at(l_cell)
				if pu and pu.alive and pu.camp != u.camp and pu.id != t.id:
					pierced_targets.append(pu)

			_play_unit_attack_anim(u.id, t.cell if t else cell)
			_big_moment("🐉 %s · 青龙偃月斩！！" % dt.name)
			var hit_desc := "💥 直线贯穿！" if pierced_targets.size() > 0 else "💥 龙芒暴斩！"
			_spawn_float_text(u.cell, hit_desc + dt.title, dt.color, true)
			_shake_camera(6.0 if u.charge >= 10 else 4.0)
			if t:
				var far_cell: Vector2i = line_path.back() if line_path.size() > 0 else t.cell
				_spawn_dragon(u.cell, far_cell, u.charge)
				_spawn_burst(t.cell, dt.color, 3)
				for pt in pierced_targets:
					_spawn_burst(pt.cell, dt.color, 2)
			events = SkillsCore.do_dragon_slash(u, t, pierced_targets)
			u.acted = true
			move_origin_cell = Vector2i(-1, -1)
			move_gained_charge = 0
			_apply_events(events)
			_after_action(u)
			return
		"roar":
			# 原著：咆哮的字数越多，威力越大 —— 进入连点喊字状态，玩家决定喊多长
			_start_roar_charging(u)
			return
		"seven_dash":
			var weaves: int = mini(7, maxi(1, GridCore.manhattan(u.cell, t.cell) + 1))
			_spawn_float_text(u.cell, "七进七出！子龙又穿过去啦！", Color(0.4, 0.9, 1.0))
			if t:
				_big_moment("常山·七进七出！！")
				_spawn_seven_dash(u.cell, t.cell, weaves)
			events = SkillsCore.do_seven_dash(u, t, weaves)
		"arrow_rain":
			_spawn_banner("🏹 白马·定速回旋飞弹！", Color(0.4, 0.85, 1.0))
			_spawn_float_text(u.cell, "🏹 飞弹升空！全图索敌！", Color(0.4, 0.9, 1.0), true)
			_shake_camera(3.0)
			if t:
				_spawn_shockwave(t.cell, Color(0.3, 0.8, 1.0, 0.4))
			events = SkillsCore.do_arrow_rain(u, t, units)
		"naked_armor":
			_big_moment("裸衣！死战！！")
			_screen_flash(Color(1, 0.4, 0.2, 0.4), 0.4)
			_spawn_shockwave(u.cell, Color(1, 0.4, 0.2, 0.6))
			events = SkillsCore.do_naked_armor(u, units)
			_spawn_burst(u.cell, Color(1, 0.4, 0.2, 0.5), 2)
	u.acted = true
	move_origin_cell = Vector2i(-1, -1)
	move_gained_charge = 0
	_apply_events(events)
	_after_action(u)

## ---------- 燕人咆哮：喊字（原著：咆哮的字数越多，威力越大） ----------
const ROAR_WORDS_MIN := 6
const ROAR_WORDS_MAX := 14
const ROAR_FULL_TEXT := "燕人张飞在此，谁敢与我决一死战！"
const ROAR_WINDOW_SEC := 4.0

func _start_roar_charging(u) -> void:
	roar_words = ROAR_WORDS_MIN          # 原著里张飞上来就是六字咆哮
	input_mode = InputMode.ROAR
	command_menu.visible = false
	_clear_overlay()
	_spawn_banner("🗣️ 燕人咆哮 · 连点喊字！", Color(1.0, 0.8, 0.3))
	_update_roar_prompt(u)
	var timer := get_tree().create_timer(ROAR_WINDOW_SEC)
	timer.timeout.connect(_on_roar_window_timeout)

func _on_roar_window_timeout() -> void:
	if is_inside_tree() and input_mode == InputMode.ROAR:
		_execute_roar(roar_words)

func _add_roar_word() -> void:
	if input_mode != InputMode.ROAR:
		return
	roar_words = mini(ROAR_WORDS_MAX, roar_words + 1)
	var u: BattleUnitScript = _unit_by_id(selected_id)
	if u:
		_update_roar_prompt(u)
	if roar_words >= ROAR_WORDS_MAX:
		_execute_roar(roar_words)

func _update_roar_prompt(u) -> void:
	var spoken: String = ROAR_FULL_TEXT.substr(0, roar_words)
	info_label.text = "🗣️ %s（%d/%d 字）—— 连点/空格继续喊，字数越多威力越大！右键直接出手" % [spoken, roar_words, ROAR_WORDS_MAX]
	_spawn_float_text(u.cell, spoken, Color(1.0, 0.85, 0.2), roar_words >= ROAR_WORDS_MAX)

func _execute_roar(words: int) -> void:
	var u: BattleUnitScript = _unit_by_id(selected_id)
	input_mode = InputMode.NONE
	if u == null or not u.alive:
		return
	var full: bool = words >= ROAR_WORDS_MAX
	var roar_r: int = 3 if full else 2
	var save: Dictionary = SaveCore.load_state()
	var inv: Dictionary = save.get("inventory", {})
	if int(inv.get("megaphone", 0)) > 0:
		roar_r += 1
		_spawn_banner("📣 高音大喇叭加持 · 超大声波燕人咆哮！", Color(1.0, 0.8, 0.2))
	else:
		_spawn_banner("🗣️ 燕人咆哮！%d 字！" % words, Color(1.0, 0.7, 0.2))
	_spawn_float_text(u.cell, "这一嗓子，你忍一下！", Color(1.0, 0.85, 0.2), true)
	_spawn_shockwave(u.cell, Color(0.9, 0.7, 0.2, 0.5))
	_spawn_burst(u.cell, Color(0.9, 0.7, 0.2, 0.4), 2)
	_shake_camera(6.0 if full else 4.0)
	var targets: Array = []
	for tt in units:
		if tt.alive and tt.camp != u.camp and GridCore.chebyshev(u.cell, tt.cell) <= roar_r:
			targets.append(tt)
	# 十四字满控：声浪太大，敌我不分（原著「群控，敌我不分」）；戴耳塞者免疫
	var allies: Array = []
	if full:
		var has_earplug: bool = int(inv.get("earplug", 0)) > 0
		if has_earplug:
			_spawn_float_text(u.cell, "🎧 耳塞生效：自己人安然无恙", Color(0.5, 1.0, 0.8))
		else:
			for tt in units:
				if tt.alive and tt.camp == u.camp and tt.id != u.id and GridCore.chebyshev(u.cell, tt.cell) <= roar_r:
					allies.append(tt)
			if allies.size() > 0:
				_spawn_float_text(u.cell, "⚠️ 声浪太猛，自己人也遭殃！", Color(1.0, 0.5, 0.4), true)
	var events: Array = SkillsCore.do_roar(u, targets, words, allies)
	u.acted = true
	move_origin_cell = Vector2i(-1, -1)
	move_gained_charge = 0
	_apply_events(events)
	_after_action(u)

## ---------- 事件应用 ----------
func _apply_events(events: Array) -> void:
	for ev in events:
		if ev.get("shatter_gate", false):
			_break_sishui_gate()
		match ev.get("type"):
			"damage":
				var t: BattleUnitScript = _unit_by_id(ev.target)
				if t:
					if t.iron_skin or int(ev.value) == 0:
						_spawn_float_text(t.cell, "🛡️ 铁皮防弹！刀枪不入！", Color(0.9, 0.9, 0.95), true)
						info_label.text += "\n%s 处于防弹铁皮状态！物理伤害判定为 0！" % t.name
						continue
					_flash_unit(t.id, Color(1, 0.3, 0.3))
					_unit_bounce(t.id)
					var is_crit: bool = ev.get("crit", false) or int(ev.get("value", 0)) >= 50
					var dmg_str: String = ("💥暴击 -%d" if is_crit else "-%d") % ev.value
					var dmg_col: Color = Color(1.0, 0.85, 0.2) if is_crit else Color(1, 0.4, 0.3)
					info_label.text += "\n%s 受到 %d 伤害！" % [t.name, ev.value]

					# 关羽千里逃窜蓄力被打断机制（契合原著小说：受击气脉震散，全部清零）
					# 例外：骑赵云时赵云会硬扛第一击（原著里赵云扛着关羽狂奔，敌人追不上）
					if t.id == "guanyu" and t.charge > 0:
						if t.is_mounted() and not t.dragon_guard_used:
							t.dragon_guard_used = true
							_spawn_float_text(t.cell, "🐎 赵云硬扛！青龙蓄力未散！", Color(0.5, 1.0, 0.85), true)
							info_label.text += "\n赵云替关羽挡下这一击，气脉未散！（合体护航每关仅一次）"
						else:
							t.charge = 0
							_spawn_float_text(t.cell, "💥 气脉震散！蓄力清零(归0)！", Color(1.0, 0.25, 0.25), true)
							info_label.text += "\n关羽遭敌截击气脉震散！青龙蓄力全部清零！快派大哥三弟挡刀！"
							_sync_text(t)

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
					# 动态士气结算
					if t2.camp == "enemy":
						if t2.is_commander:
							_adjust_morale(20, -30)
						else:
							_adjust_morale(5, -5)
					elif t2.camp == "player":
						_adjust_morale(-15, 10)
					# 吕布暴怒：我方单位倒下，吕布越战越狂（多打少）
					if t2.camp == "player" and chapter_id == "chapter2":
						var lubu := _unit_by_id("lubu")
						if lubu and lubu.alive:
							lubu.add_rage()
							info_label.text += "\n吕布暴怒！攻击力暴涨！(×1.5)"
							_play_dialog("ch2_lubu_rage")
			"iron_skin":
				var tar := _unit_by_id(ev.target)
				if tar:
					_spawn_float_text(tar.cell, "🛡️ 铁皮防弹！刀枪不入！", Color(1.0, 0.85, 0.2), true)
					_spawn_banner("吕布进入【两息铁皮状态】！刀枪不入！", Color(1.0, 0.85, 0.2))
					_shake_camera(8.0)
					info_label.text += "\n吕布连击大成进入两息铁皮状态！物理攻击全部无效！唯有张飞战吼能震破其气脉！"
			"iron_skin_block":
				var tar := _unit_by_id(ev.target)
				if tar:
					_spawn_float_text(tar.cell, "🛡️ 铁皮防弹！免疫伤害！", Color(0.9, 0.9, 0.95), true)
					info_label.text += "\n攻击斩在防弹铁皮上火星四溅！无法破防！伤害为 0！"
			"iron_skin_break":
				var tar := _unit_by_id(ev.target)
				if tar:
					_spawn_float_text(tar.cell, "💥 铁皮震破！气脉散乱！", Color(1.0, 0.3, 0.3), true)
					info_label.text += "\n张飞战吼震破了吕布的铁皮气罩！吕布连击与无敌尽散！"
			"skill":
				info_label.text += "\n【技能】%s" % ev.get("value", "")
				if ev.get("fx") == "fire_homing_arrow":
					var arr: Dictionary = ev.get("arrow", {})
					_spawn_homing_arrow_node(arr)
				elif ev.get("fx") == "arrow_hit":
					var t_hit: BattleUnitScript = _unit_by_id(ev.target)
					if t_hit:
						_spawn_float_text(t_hit.cell, "💥 飞弹破空命中！", Color(0.4, 0.9, 1.0), true)
						_spawn_burst(t_hit.cell, Color(0.4, 0.9, 1.0, 0.6), 2)
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
			"exhausted":
				var exh := _unit_by_id(ev.target)
				if exh:
					_spawn_float_text(exh.cell, "⚡ 铁锤沉重！力竭脱力！", Color(0.95, 0.65, 0.2))
					info_label.text += "\n%s 挥出沉重铁锤全力猛击！陷入 1 回合力竭脱力（DEF-30%）！" % exh.name
			"heal":
				var he := _unit_by_id(ev.target)
				if he:
					info_label.text += "\n%s 吸血恢复 %d HP！" % [he.name, ev.value]
			"fx":
				if ev.fx == "dragon_full_screen":
					if ev.get("shatter_gate", false):
						_break_sishui_gate()

func _flash_unit(id: String, color: Color) -> void:
	var node: Node2D = unit_nodes.get(id)
	if node:
		var tw := create_tween()
		tw.tween_property(node, "modulate", Color(2.5, 0.6, 0.6, 1.0), 0.12)
		tw.tween_property(node, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.15)

func _unit_node_hide(id: String) -> void:
	var node: Node2D = unit_nodes.get(id)
	if node:
		node.visible = false

## 伤害/状态飘字：在单位格上方生成带描边上飘渐隐的文字
func _spawn_float_text(cell: Vector2i, text: String, color: Color, is_crit: bool = false) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.add_theme_color_override("font_outline_color", Color(0.04, 0.04, 0.05, 0.95))
	var font_sz := 24 if is_crit else 16
	lbl.add_theme_font_size_override("font_size", font_sz)
	var px := _cell_to_px(cell)
	var text_w := float(text.length()) * (float(font_sz) * 0.95)
	var target_x := px.x - text_w * 0.5
	target_x = clampf(target_x, 30.0, max(30.0, 630.0 - text_w))
	lbl.position = Vector2(target_x, px.y - 32.0)
	lbl.z_index = 55
	unit_root.add_child(lbl)
	var tw := create_tween()
	if is_crit:
		lbl.scale = Vector2(0.5, 0.5)
		tw.tween_property(lbl, "scale", Vector2(1.25, 1.25), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(lbl, "scale", Vector2(1.0, 1.0), 0.1)
		tw.parallel().tween_property(lbl, "position", lbl.position + Vector2(0, -36), 0.7)
	else:
		tw.tween_property(lbl, "position", lbl.position + Vector2(0, -28), 0.65)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.65)
	tw.tween_callback(lbl.queue_free)

## 技能大字横幅（居中弹一下消失）
func _spawn_banner(text: String, color: Color) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_size_override("font_size", 30)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position = Vector2(100, 260)
	lbl.size = Vector2(1080, 60)
	lbl.z_index = 60
	var ui_layer = $UI
	ui_layer.add_child(lbl)
	var tw := create_tween()
	var base := lbl.position
	tw.tween_property(lbl, "position", base + Vector2(0, 10), 0.25)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.8)
	tw.tween_callback(lbl.queue_free)

## 简单技能范围特效（以某格为中心画圆圈/方块扩散）
func _spawn_burst(cell: Vector2i, color: Color, radius_in_cells: int = 0) -> void:
	var rect := ColorRect.new()
	var center := _cell_to_px(cell)
	var sz: float = TILE * (radius_in_cells * 2 + 1) - 4.0
	rect.size = Vector2(sz, sz)
	rect.position = center - Vector2(sz / 2.0, sz / 2.0)
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.z_index = 6
	overlay.add_child(rect)
	var tw := create_tween()
	tw.tween_property(rect, "modulate:a", 0.0, 0.5)
	tw.tween_callback(rect.queue_free)

## ===== 战斗爽感特效（升级版） =====

## 屏幕震动（MapRoot、UnitRoot、Overlay 全体协同震荡）
func _shake_camera(strength: float = 6.0) -> void:
	var tw := create_tween()
	var base_map := map_root.position
	var base_unit := unit_root.position
	var base_overlay := overlay.position
	for i in range(5):
		var off := Vector2(
			randf_range(-strength, strength),
			randf_range(-strength, strength)
		)
		tw.tween_property(map_root, "position", base_map + off, 0.03)
		tw.parallel().tween_property(unit_root, "position", base_unit + off, 0.03)
		tw.parallel().tween_property(overlay, "position", base_overlay + off, 0.03)
	tw.tween_property(map_root, "position", base_map, 0.04)
	tw.parallel().tween_property(unit_root, "position", base_unit, 0.04)
	tw.parallel().tween_property(overlay, "position", base_overlay, 0.04)

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

## 千里·青龙横贯：多层碧霄龙刃辉光 + 爆破龙鳞 + 冲击新星（支持多阶青龙形态）
func _spawn_dragon(from_cell: Vector2i, to_cell: Vector2i, charge: int = 10) -> void:
	var dt: Dictionary = CombatCore.dragon_charge_tier(charge)
	var max_w: float = dt.get("width", 110.0)
	var start_px := _cell_to_px(from_cell)
	var end_px := _cell_to_px(to_cell)
	var dir := (end_px - start_px).normalized()
	var dist := start_px.distance_to(end_px)

	var beam_root := Node2D.new()
	beam_root.z_index = 40
	unit_root.add_child(beam_root)

	# 1. 外层青龙破空气流（满蓄力宽达 120px）
	var outer_line := Line2D.new()
	outer_line.points = PackedVector2Array([start_px, end_px])
	outer_line.width = max_w
	outer_line.default_color = Color(0.15, 0.95, 0.5, 0.45)
	outer_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	outer_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	beam_root.add_child(outer_line)

	# 2. 中层天青龙气巨柱
	var mid_line := Line2D.new()
	mid_line.points = PackedVector2Array([start_px, end_px])
	mid_line.width = max_w * 0.48
	mid_line.default_color = Color(0.35, 1.0, 0.7, 0.9)
	mid_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	mid_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	beam_root.add_child(mid_line)

	# 3. 内层白炽贯穿核
	var core_line := Line2D.new()
	core_line.points = PackedVector2Array([start_px, end_px])
	core_line.width = max(max_w * 0.16, 10.0)
	core_line.default_color = Color(1.0, 1.0, 0.95, 1.0)
	core_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	core_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	beam_root.add_child(core_line)

	# 4. 沿斩击路径排列的青龙刃鳞
	var step_count := int(dist / 28.0)
	for i in range(step_count):
		var t := float(i) / float(max(step_count, 1))
		var pos := start_px + dir * dist * t
		var scale_poly := Polygon2D.new()
		scale_poly.polygon = PackedVector2Array([
			Vector2(-14, -8), Vector2(14, 0), Vector2(-14, 8), Vector2(-8, 0)
		])
		scale_poly.position = pos
		scale_poly.rotation = dir.angle()
		scale_poly.color = Color(0.4, 1.0, 0.75, 0.75)
		beam_root.add_child(scale_poly)

	# 5. 目标爆破新星
	var nova := Polygon2D.new()
	nova.polygon = _make_circle_polygon(38.0, 16)
	nova.position = end_px
	nova.color = Color(0.65, 1.0, 0.85, 0.9)
	beam_root.add_child(nova)

	# 6. 动画演播与渐隐
	var tw := create_tween()
	tw.parallel().tween_property(outer_line, "width", 68.0, 0.35)
	tw.parallel().tween_property(mid_line, "width", 32.0, 0.35)
	tw.parallel().tween_property(nova, "scale", Vector2(2.4, 2.4), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(beam_root, "modulate:a", 0.0, 0.4).set_delay(0.12)
	tw.tween_callback(beam_root.queue_free)

	_shake_camera(12.0)
	_screen_flash(Color(0.2, 1.0, 0.6, 0.35), 0.3)

## 常山·七进七出：交错极速银枪贯穿破阵
func _spawn_seven_dash(from_cell: Vector2i, to_cell: Vector2i, weaves: int) -> void:
	var start_px := _cell_to_px(from_cell)
	var target_px := _cell_to_px(to_cell)
	var dash_root := Node2D.new()
	dash_root.z_index = 45
	unit_root.add_child(dash_root)

	var count: int = clampi(weaves, 3, 7)
	for i in range(count):
		var delay: float = float(i) * 0.05
		var angle_offset: float = (float(i) - float(count) / 2.0) * 0.42
		var base_dir := (target_px - start_px).normalized()
		if base_dir.length_squared() < 0.1:
			base_dir = Vector2.RIGHT
		var slash_dir := base_dir.rotated(angle_offset)
		var p1 := target_px - slash_dir * 45.0
		var p2 := target_px + slash_dir * 52.0

		var spear_line := Line2D.new()
		spear_line.points = PackedVector2Array([p1, p1])
		spear_line.width = 10.0 if i == count - 1 else 6.0
		spear_line.default_color = Color(0.92, 0.97, 1.0, 0.95) if (i % 2 == 0) else Color(0.35, 0.8, 1.0, 0.9)
		spear_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		spear_line.end_cap_mode = Line2D.LINE_CAP_ROUND
		spear_line.modulate.a = 0.0
		dash_root.add_child(spear_line)

		var head := Polygon2D.new()
		head.polygon = PackedVector2Array([
			Vector2(14, 0), Vector2(-7, -5), Vector2(-2, 0), Vector2(-7, 5)
		])
		head.color = Color(1.0, 1.0, 1.0, 0.95)
		head.position = p1
		head.rotation = slash_dir.angle()
		head.modulate.a = 0.0
		dash_root.add_child(head)

		var tw := create_tween()
		tw.tween_interval(delay)
		tw.tween_callback(func():
			spear_line.modulate.a = 1.0
			head.modulate.a = 1.0
		)
		tw.parallel().tween_method(func(val: Vector2):
			spear_line.points = PackedVector2Array([p1, val])
			head.position = val
		, p1, p2, 0.08)
		tw.parallel().tween_property(spear_line, "width", 1.5, 0.12).set_delay(0.04)
		tw.parallel().tween_property(spear_line, "modulate:a", 0.0, 0.15).set_delay(0.07)
		tw.parallel().tween_property(head, "modulate:a", 0.0, 0.15).set_delay(0.07)

	var finish_delay: float = float(count) * 0.05
	var shock := Polygon2D.new()
	shock.polygon = _make_circle_polygon(34.0, 16)
	shock.position = target_px
	shock.color = Color(0.65, 0.88, 1.0, 0.85)
	shock.scale = Vector2(0.2, 0.2)
	shock.modulate.a = 0.0
	dash_root.add_child(shock)

	var tw_fin := create_tween()
	tw_fin.tween_interval(finish_delay)
	tw_fin.tween_callback(func():
		shock.modulate.a = 0.85
		_shake_camera(7.0)
	)
	tw_fin.tween_property(shock, "scale", Vector2(2.0, 2.0), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw_fin.parallel().tween_property(shock, "modulate:a", 0.0, 0.22)
	tw_fin.tween_property(dash_root, "modulate:a", 0.0, 0.18)
	tw_fin.tween_callback(dash_root.queue_free)

	_screen_flash(Color(0.5, 0.85, 1.0, 0.35), 0.25)

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
	var node: Node2D = unit_nodes.get(id)
	if node == null:
		return
	var tw := create_tween()
	tw.tween_property(node, "scale", Vector2(1.25, 0.8), 0.06)
	tw.tween_property(node, "scale", Vector2(1.0, 1.0), 0.12)

## 播放单位攻击动作动画与冲刺打击感（复用 AnimatedSprite2D 与 Tween 轮子能力）
func _play_unit_attack_anim(attacker_id: String, target_cell: Vector2i) -> void:
	## 攻击演出：实现全部在 scripts/ui/unit_view.gd（视觉层，动画侧维护）
	var node: Node2D = unit_nodes.get(attacker_id)
	if node == null:
		return
	UnitViewCore.play_attack(node, _cell_to_px(target_cell))

## 生成在空中定速飞行的回旋飞弹视觉节点
func _spawn_homing_arrow_node(arr: Dictionary) -> void:
	active_arrows.append(arr)
	var node := Node2D.new()
	node.position = _cell_to_px(arr.cell)
	node.z_index = 60
	
	var lbl := Label.new()
	lbl.text = "🎯🏹"
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	lbl.position = Vector2(-16, -16)
	node.add_child(lbl)
	
	unit_root.add_child(node)
	arrow_nodes[arr.id] = node
	info_label.text += "\n🏹 公孙瓒射出定速回旋飞弹！正以每回合3格速度奔袭索敌！"

## 在回合流转时推进战场上所有飞行中的定速回旋飞弹
func _update_homing_arrows() -> void:
	if active_arrows.is_empty():
		return
	var evs: Array = SkillsCore.advance_homing_arrows(active_arrows, units, MAP_W, MAP_H)
	for ev in evs:
		match ev.get("type"):
			"arrow_fly":
				var node: Node2D = arrow_nodes.get(ev.arrow_id)
				if node and is_instance_valid(node):
					var target_px: Vector2 = _cell_to_px(ev.to_cell)
					var tw := create_tween()
					tw.tween_property(node, "position", target_px, 0.35).set_trans(Tween.TRANS_SINE)
			"arrow_hit":
				var node: Node2D = arrow_nodes.get(ev.arrow_id)
				if node and is_instance_valid(node):
					var tw := create_tween()
					tw.tween_property(node, "scale", Vector2(1.5, 1.5), 0.1)
					tw.parallel().tween_property(node, "modulate:a", 0.0, 0.2)
					tw.tween_callback(node.queue_free)
					arrow_nodes.erase(ev.arrow_id)
				var t: BattleUnitScript = _unit_by_id(ev.target)
				if t:
					_spawn_float_text(t.cell, "💥 飞弹命中 -%d！" % ev.value, Color(0.4, 0.9, 1.0), true)
					_spawn_burst(t.cell, Color(0.4, 0.9, 1.0, 0.6), 2)
					info_label.text += "\n🏹 公孙瓒定速飞弹追踪命中 %s！造成 %d 伤害！" % [t.name, ev.value]
					_sync_node(t)
			"arrow_lost":
				var node: Node2D = arrow_nodes.get(ev.arrow_id)
				if node and is_instance_valid(node):
					node.queue_free()
					arrow_nodes.erase(ev.arrow_id)
	_apply_events(evs)
	_check_victory()

## 大招定格：全屏闪白 + 字幕口号 + 震动
func _big_moment(text: String) -> void:
	_screen_flash(Color(1, 1, 0.9, 0.5), 0.35)
	_spawn_banner(text, Color(1, 0.85, 0.3))
	_shake_camera(10.0)

## 汜水关城门崩塌机制：关羽满蓄力青龙斩或大军破门
func _break_sishui_gate() -> void:
	if gate_broken:
		return
	gate_broken = true
	# 瓦解城门障碍物（数据与视觉节点全消除）
	if chapter.has("map") and chapter["map"].has("obstacles"):
		chapter["map"]["obstacles"].clear()
	for pos in obstacle_nodes.keys():
		var n: Node = obstacle_nodes[pos]
		if n and is_instance_valid(n):
			var tw := create_tween()
			tw.tween_property(n, "scale", Vector2(0.2, 0.2), 0.35)
			tw.parallel().tween_property(n, "modulate:a", 0.0, 0.35)
			tw.tween_callback(n.queue_free)
	obstacle_nodes.clear()

	_big_moment("💥 汜水关城门崩塌！守军阵线溃乱！")
	_shake_camera(12.0)
	_screen_flash(Color(1.0, 0.9, 0.3, 0.6), 0.4)
	info_label.text += "\n💥 汜水关城门崩塌瓦解！敌军防线全线溃乱！敌军防御-20%，士气暴跌！"
	for e in _camp_units("enemy"):
		if e.alive:
			e.gate_broken_debuff = true
			_spawn_float_text(e.cell, "🛡️ 防线溃乱 DEF-20%", Color(1.0, 0.4, 0.4))
	_adjust_morale(30, -30)
	# 破门夺关：即刻结算声望（原著霸业系统：占郡即得声望 → 抽奖 → 变强，这才是破城的价值）
	var save: Dictionary = SaveCore.load_state()
	SaveCore.add_prestige(save, 500)
	SaveCore.save_state(save)
	_spawn_banner("🏯 破门夺关！军功声望 +500", Color(1.0, 0.9, 0.4))
	info_label.text += "\n🏯 破门夺关！军功声望 +500（回主城可抽奖）"

## 动态士气调整系统：双方士气（0~150，基准100）
func _adjust_morale(player_delta: int, enemy_delta: int) -> void:
	morale.player = clampi(morale.player + player_delta, 0, 150)
	morale.enemy = clampi(morale.enemy + enemy_delta, 0, 150)
	MoraleCore.apply_morale(_camp_units("player"), morale.player)
	MoraleCore.apply_morale(_camp_units("enemy"), morale.enemy)
	_update_hud()
	_update_dashboard()
	if player_delta != 0:
		info_label.text += "\n我军士气 %s%d（当前：%d）！" % ["+" if player_delta > 0 else "", player_delta, morale.player]
	if enemy_delta != 0:
		info_label.text += "\n敌军士气 %s%d（当前：%d）！" % ["+" if enemy_delta > 0 else "", enemy_delta, morale.enemy]

## ---------- 回合流转 ----------
func _after_action(u) -> void:
	# 战败后不再推进回合作业（避免全灭后回合空转）
	if defeat:
		return
	# 赵云【无限耐力】：行动结束后自愈 15% HP（无需干粮）
	var zhaoyun := _unit_by_id("zhaoyun")
	if zhaoyun and zhaoyun.alive and (u.id == "zhaoyun" or (u.is_mounted() and u.mount.get("horse") == "zhaoyun")):
		var healed := zhaoyun.heal_percent(0.15)
		if healed > 0:
			_spawn_float_text(zhaoyun.cell, "💪 无限耐力！自愈 +%d" % healed, Color(0.3, 1.0, 0.5), false)
			_sync_node(zhaoyun)
			info_label.text += "\n赵云体魄强健无限耐力！行动后自愈 %d HP！" % healed

	# 检查胜利与失败
	if _check_victory():
		return
	if _check_defeat():
		return
	# 完成本行动，重置选中与命令状态
	_finish_turn_action()
	# 全部行动完自动结束回合
	var alive_ids: Array = []
	for uu in _camp_units("player"):
		alive_ids.append(uu.id)
	if TurnCore.all_acted(turn_state, alive_ids):
		_spawn_banner("✅ 我方全员行动完毕 → 敌方回合", Color(0.6, 0.85, 1.0))
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
	pending_end_turn = false
	TurnCore.to_enemy(turn_state)
	info_label.text = "敌方回合…"
	_update_hud()
	_run_enemy_turn()

## 空格结束回合：有未行动单位时先警告，再按一次确认
func _try_end_turn_by_space() -> void:
	if victory or win_dialog_played:
		return
	var pending: Array[String] = []
	for uu in _camp_units("player"):
		if not uu.acted:
			pending.append(uu.name)
	if pending.size() > 0 and not pending_end_turn:
		pending_end_turn = true
		var names := ", ".join(pending)
		_spawn_banner("⚠ 还有 %d 人未行动：%s" % [pending.size(), names], Color(1.0, 0.8, 0.3))
		info_label.text = "还有 %d 人未行动（%s）。\n确认要结束回合，请【再按一次空格】，或点右下角【结束回合】" % [pending.size(), names]
		return
	pending_end_turn = false
	_end_player_turn()

## 敌方回合：每个存活敌人执行简单 AI（带演出节奏）
func _run_enemy_turn() -> void:
	_spawn_banner("敌方回合", Color(0.8, 0.4, 0.2))
	# 吕布两息铁皮无敌自然到期判定（持续1轮敌我攻防，进入敌方回合前衰减）
	for eu in _camp_units("enemy"):
		if eu.alive and eu.iron_skin:
			if eu.iron_skin_turns > 0:
				eu.iron_skin_turns -= 1
			else:
				eu.iron_skin = false
				_spawn_float_text(eu.cell, "🛡️ 铁皮消退", Color(0.8, 0.8, 0.8))
				info_label.text += "\n吕布铁皮防弹持续时间已过，刀枪不入消退！"
	for u in _camp_units("enemy"):
		if not u.alive:
			continue
		if u.is_stunned():
			continue
		var target: BattleUnitScript = _pick_enemy_target(u)
		if target == null:
			continue
		# 昌豨【飞龟怯战】逃窜 AI：挨打胆怯后抱头鼠窜，远离我方并哭爹喊娘
		if u.id == "changxi" and u.coward_debuff:
			_move_away(u, target.cell)
			_spawn_float_text(u.cell, "😭 别打了！大哥饶命！我就是个打下手的！", Color(0.95, 0.85, 0.3), false)
			info_label.text += "\n昌豨被吓破了胆，抱头鼠窜往后撤退！"
			await get_tree().create_timer(0.12).timeout
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
				if GridCore.chebyshev(u.cell, target.cell) <= u.rng:
					_ai_attack(u, target)
			elif dist <= 1:
				_move_away(u, target.cell)
				await get_tree().create_timer(0.1).timeout
				if GridCore.chebyshev(u.cell, target.cell) <= u.rng:
					_ai_attack(u, target)
			else:
				_ai_attack(u, target)
		else:
			if GridCore.can_attack(u.cell, target.cell, u.is_cavalry(), u.rng):
				_ai_attack(u, target)
			else:
				_move_toward(u, target.cell)
				await get_tree().create_timer(0.1).timeout
				if GridCore.can_attack(u.cell, target.cell, u.is_cavalry(), u.rng):
					_ai_attack(u, target)
	# 敌回合结束
	for u in _camp_units("enemy"):
		u.end_turn()
	TurnCore.to_player(turn_state)
	_begin_player_turn()

## 敌军选目标：关羽蓄力越高越「拉仇恨」（原著里李儒专门派人拦路打断他的蓄力）
##   charge ≥ 10：关羽 10 格内的敌军扑向他（地图 12x10，实际就是大半个战场）
##   charge ≥ 5 ：关羽 6 格内的敌军才会被吸引过去
## 远处敌人不跨越全图来凑热闹 —— 那样反而假，玩家也不服气
## 这就是「嘲讽」：不需要额外的技能按钮，蓄力本身就是最大的挑衅
func _pick_enemy_target(u) -> BattleUnitScript:
	var gy: BattleUnitScript = _unit_by_id("guanyu")
	if gy != null and gy.alive and gy.charge >= 5:
		var pull_range: int = 10 if gy.charge >= 10 else 6
		if GridCore.manhattan(u.cell, gy.cell) <= pull_range:
			return gy
	return _nearest_player(u)

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
	var filtered_blocked: Array[Vector2i] = []
	for c in blocked:
		if c != target_cell:
			filtered_blocked.append(c)
	var path := GridCore.path(u.cell, target_cell, MAP_W, MAP_H, filtered_blocked)
	if path.size() > 0:
		var max_step: int = mini(int(u.mov), path.size() - 1)
		if max_step > 0:
			var step: Vector2i = path[max_step - 1]
			u.cell = step
			_sync_node(u)

func _move_away(u, target_cell: Vector2i) -> void:
	var dir: Vector2i = (u.cell - target_cell).sign()
	var nxt: Vector2i = u.cell + dir
	if GridCore.in_bounds(nxt, MAP_W, MAP_H) and nxt not in _blocked_cells(u.id):
		u.cell = nxt
		_sync_node(u)

func _ai_attack(u, target) -> void:
	# 许褚：当生命值 <= 85% 或已进入激战时，气急败坏暴吼脱光只剩红裤衩！双方全员爆甲腰斩DEF + 狂暴吸血与双倍攻速！
	if "naked_armor" in u.skill_ids:
		var hp_ratio: float = float(u.hp) / float(max(u.max_hp, 1))
		if not u.lifesteal_active and u.skill_ready("naked_armor") and (hp_ratio <= 0.85 or turn_state.turn >= 2):
			_spawn_float_text(u.cell, "🔥 热死老子了！脱！脱光了拼命！", Color(1.0, 0.3, 0.2), true)
			_spawn_banner("许褚气急败坏！脱得只剩一条红裤衩！！", Color(1.0, 0.4, 0.2))
			_shake_camera(8.0)
			_apply_events(SkillsCore.do_naked_armor(u, units))
			info_label.text += "\n许褚！气急败坏脱得只剩红裤衩！双方全员爆甲腰斩DEF+吸血狂战！"
		if u.lifesteal_active:
			_apply_events(SkillsCore.do_naked_strike(u, target))
			_apply_events(SkillsCore.do_naked_strike(u, target))  # 双倍攻速第二击
		else:
			_apply_events(SkillsCore.do_attack(u, target))
	elif "lubu_fangtian" in u.skill_ids:
		_apply_events(SkillsCore.do_lubu_attack(u, target))
	else:
		_apply_events(SkillsCore.do_attack(u, target))

	# 我方防守反击与被击反应
	if target.alive and not target.is_stunned():
		if target.id == "liubei":
			_spawn_float_text(target.cell, "别打脸！我全靠长相混饭吃！", Color(1.0, 0.45, 0.45))
		if GridCore.can_attack(target.cell, u.cell, target.is_cavalry(), target.rng):
			_spawn_float_text(target.cell, "⚡ 阵地反击！", Color(0.4, 0.9, 1.0))
			var counter_ev := SkillsCore.do_counter_attack(target, u)
			_apply_events(counter_ev)
			_unit_bounce(target.id)
		elif target.is_cavalry() and GridCore.chebyshev(target.cell, u.cell) == 1:
			_spawn_float_text(target.cell, "🛡️ 斜向受制！", Color(0.8, 0.8, 0.8))

	if not target.alive:
		_check_defeat()

func _begin_player_turn() -> void:
	if defeat or victory:
		return
	_update_homing_arrows()
	for u in _camp_units("player"):
		u.acted = false
		u.moved_this_turn = false    # 新回合：重置"已移动"状态
		# 玉米种子回血：每回合开始时自动恢复生命
		if u.alive and u.hp_regen > 0 and u.hp < u.max_hp:
			var heal: int = mini(u.hp_regen, u.max_hp - u.hp)
			if heal > 0:
				u.hp += heal
				_spawn_float_text(u.cell, "+%d" % heal, Color(0.3, 1.0, 0.4))
				_sync_node(u)
	_check_turn_events()
	_check_pressure_flag()
	_bonds_regen()
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
			# 事件可附带战场效果（数据驱动）。用于让"剧情描写"与"单位状态"一致：
			# 例如第 2 关剧情说武安国被吕布打飞、吐血脱力，那他的血条和 DEF 就得真的变。
			if ev.has("effect"):
				_apply_event_effect(ev["effect"])
			_play_dialog(ev.key)

## 战场事件效果（数据来自 chapterN.json 的 events[].effect，见《游戏设计文档》）
## kind = "smash_unit"：某单位被三倍暴击打飞 —— 扣血（保底不死）+ 长期脱力
func _apply_event_effect(fx: Dictionary) -> void:
	match str(fx.get("kind", "")):
		"smash_unit":
			var victim: BattleUnitScript = _unit_by_id(str(fx.get("target", "")))
			if victim == null or not victim.alive:
				return
			var by: BattleUnitScript = _unit_by_id(str(fx.get("by", "")))
			var turns: int = int(fx.get("exhausted_turns", 3))
			victim.set_exhausted(turns)
			# 扣血：按"施暴者攻击 × mult"算，但保底留下 hp_floor_ratio 的最大生命
			# （原著里武安国是"吐血脱力"被人抬下去，不是当场战死）
			if victim.hp > 1:
				var atk: int = by.effective_atk() if by != null else 30
				var raw: int = CombatCore.damage(atk, float(fx.get("mult", 3.0)), victim.effective_def())
				var floor_hp: int = maxi(1, int(ceil(float(victim.max_hp) * float(fx.get("hp_floor_ratio", 0.3)))))
				var dmg: int = clampi(raw, 1, maxi(1, victim.hp - floor_hp))
				victim.take_damage(dmg)
				_spawn_float_text(victim.cell, "💥 被方天画戟打飞！-%d" % dmg, Color(1.0, 0.35, 0.3), true)
				_spawn_burst(victim.cell, Color(1.0, 0.4, 0.3, 0.6), 2)
				_shake_camera(5.0)
				_sync_text(victim)
				info_label.text += "\n%s 被吕布第三击轰飞！吐血脱力 %d 回合（DEF-30%%）！" % [victim.name, turns]
			else:
				info_label.text += "\n%s 已是强弩之末，只脱力不扣血。" % victim.name

func _play_dialog(key: String) -> void:
	var actual_key := key
	if not dialogs.has(actual_key):
		for i in range(1, 5):
			var short_pref := "ch%d_" % i
			var long_pref := "chapter%d_" % i
			if actual_key.begins_with(short_pref):
				var alt := actual_key.replace(short_pref, long_pref)
				if dialogs.has(alt):
					actual_key = alt
					break
			elif actual_key.begins_with(long_pref):
				var alt := actual_key.replace(long_pref, short_pref)
				if dialogs.has(alt):
					actual_key = alt
					break
	if not dialogs.has(actual_key):
		return
	pending_dialog = dialogs[actual_key].duplicate()
	_set_dialog_visible(true)
	_show_next_dialog_line()

func _show_next_dialog_line() -> void:
	if pending_dialog.size() == 0:
		_set_dialog_visible(false)
		return
	var line: Dictionary = pending_dialog.pop_front()
	var speaker: String = line.get("speaker", "")
	var text: String = line.get("text", "")
	dialog_text.text = "[b]%s[/b]\n%s" % [speaker, text]
	_update_dialog_portrait(line)
	dialog_btn.text = "继续 (Space/点击) ▸"

func _on_dialog_btn_pressed() -> void:
	if pending_dialog.size() > 0:
		_show_next_dialog_line()
	else:
		_set_dialog_visible(false)
		# 对话结束后：若是胜利对话，进入结算
		if win_dialog_played:
			_go_to_result()
		elif defeat:
			# 战败：退回主菜单重整旗鼓（此前只播对白不结束，玩家只能强退）
			get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_dialog_skip_pressed() -> void:
	pending_dialog.clear()
	_set_dialog_visible(false)
	if win_dialog_played:
		_go_to_result()

func _on_end_turn_pressed() -> void:
	if dialog_showing:
		return
	if input_mode != InputMode.NONE:
		_cancel_input()
	_end_player_turn()

func _finish_turn_action() -> void:
	input_mode = InputMode.NONE
	selected_id = ""
	move_origin_cell = Vector2i(-1, -1)
	move_gained_charge = 0
	_clear_command_menu()
	if command_menu:
		command_menu.visible = false
	_clear_overlay()
	_update_dashboard()

func _cancel_input() -> void:
	if move_origin_cell != Vector2i(-1, -1) and (input_mode == InputMode.ATTACK or input_mode == InputMode.SKILL):
		input_mode = InputMode.POST_MOVE
		_clear_overlay()
		_show_command_menu()
		return
	if input_mode == InputMode.POST_MOVE and move_origin_cell != Vector2i(-1, -1):
		_cmd_undo_move()
		return
	_finish_turn_action()

func _clear_overlay() -> void:
	for c in overlay.get_children():
		c.queue_free()

func _draw_cells(cells, color: Color) -> void:
	for c in cells:
		var rect := ColorRect.new()
		rect.size = Vector2(TILE - 4.0, TILE - 4.0)
		rect.position = MAP_OFFSET + Vector2(c.x * TILE + 2.0, c.y * TILE + 2.0)
		rect.color = color
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.add_child(rect)

## ---------- 胜负判定 ----------
func _check_victory() -> bool:
	if victory:
		return true
	if stages.is_empty():
		return _check_victory_legacy()
	return _check_stages()

## 无 stages 数据时的旧逻辑（向后兼容）
func _check_victory_legacy() -> bool:
	var commander := _enemy_commander()
	if commander and not commander.alive:
		victory = true
		_handle_commander_defeat(commander)
		return true
	var living_enemies := _camp_units("enemy")
	if living_enemies.is_empty():
		victory = true
		_show_win_dialog()
		return true
	return false

## 当前阶段的达成上下文
func _build_objective_ctx() -> Dictionary:
	var snap: Dictionary = {}
	var minions_alive := 0
	var commander_down := false
	for u in units:
		if u.camp != "enemy":
			continue
		snap[u.id] = {"hp": u.hp, "max_hp": u.max_hp, "alive": u.alive, "is_commander": u.is_commander}
		if not u.alive:
			if u.is_commander:
				commander_down = true
		elif not u.is_commander:
			minions_alive += 1
	return {
		"commander_down": commander_down,
		"gate_broken": gate_broken,
		"turn": turn_state.turn,
		"enemies_alive": _camp_units("enemy").size(),
		"minions_alive": minions_alive,
		"units": snap,
	}

## 分阶段军令：逐阶段判定，全部达成才算通关
func _check_stages() -> bool:
	var st: Dictionary = stages[clampi(stage_idx, 0, stages.size() - 1)]
	if not ObjectivesCore.stage_cleared(st, _build_objective_ctx()):
		return false
	return _advance_stage()

## 当前阶段达成 → 播报 → 进入下一阶段；已是最后一阶段则通关
func _advance_stage() -> bool:
	var cur: Dictionary = stages[stage_idx]
	_spawn_banner("✅ 军令达成 · %s" % str(cur.get("title", "")), Color(0.4, 1.0, 0.6))
	if ObjectivesCore.has_next(stages, stage_idx):
		stage_idx += 1
		var nxt: Dictionary = stages[stage_idx]
		var hint: String = str(cur.get("on_clear", ""))
		if hint != "":
			info_label.text = hint
		_update_chapter_objectives()
		_update_dashboard()
		var banner_text: String = "🎯 新军令 · %s" % str(nxt.get("title", ""))
		var next_text: String = ObjectivesCore.progress_text(stages, stage_idx)
		get_tree().create_timer(1.1).timeout.connect(func() -> void:
			_spawn_banner(banner_text, Color(1.0, 0.9, 0.4))
			info_label.text += "\n" + next_text)
		return false
	victory = true
	var commander := _enemy_commander()
	if commander and not commander.alive:
		_handle_commander_defeat(commander)
	else:
		_show_win_dialog()
	return true

func _handle_commander_defeat(commander: BattleUnitScript) -> void:
	var remaining_minions: Array = []
	for u in units:
		if u.alive and u.camp == "enemy" and u.id != commander.id:
			remaining_minions.append(u)
	if remaining_minions.size() > 0:
		info_label.text = "💥 敌方主帅【%s】阵亡！残兵全面崩溃溃逃！" % commander.name
		_shake_camera(6.0)
		for minion in remaining_minions:
			_spawn_float_text(minion.cell, "💥 主帅已死！弃甲快逃啊！", Color(1.0, 0.4, 0.2), true)
			var node: Node2D = unit_nodes.get(minion.id)
			if node:
				var tw := create_tween()
				tw.tween_property(node, "modulate:a", 0.0, 0.6)
			minion.alive = false
		await get_tree().create_timer(0.7).timeout
	_show_win_dialog()

func _check_defeat() -> bool:
	if defeat:
		return true
	if victory:
		return false
	var players := _camp_units("player")
	if players.size() == 0:
		# 关键：必须置位结束标记
		# 否则我方全灭后回合会一直空转、失败对白被反复播放，玩家只能强退（实测"游戏卡住"）
		defeat = true
		input_mode = InputMode.NONE
		selected_id = ""
		command_menu.visible = false
		_clear_overlay()
		_spawn_banner("💀 我军全军覆没…", Color(1.0, 0.35, 0.3))
		_play_dialog(chapter_id + "_lose")
		return true
	return false

func _show_win_dialog() -> void:
	if win_dialog_played:
		return
	win_dialog_played = true
	_play_dialog(chapter_id + "_win")

## 结算：占郡 +1000 声望 → 图鉴解锁 → 原著剧情里程碑大礼
func _go_to_result() -> void:
	var chapter_title: String = chapter.get("title", "未知")
	var save := SaveCore.load_state()
	var is_first_clear: bool = not (chapter_id in save.get("chapters", []))
	SaveCore.add_prestige(save, 1000)
	SaveCore.mark_chapter(save, chapter_id)
	_unlock_collection(save)
	var prestige: int = int(save.get("prestige", 0))

	# 填结果面板
	var title_text := "🎉 胜利！%s 告破！" % chapter_title
	var body := "获得 军功声望 +1000（当前总计 %d）\n诸侯图鉴已更新！" % prestige

	# 原著剧情首通里程碑大礼（特定战役首通奖励特定仙种，取消每局无脑随机掉落）
	if is_first_clear:
		var inv: Dictionary = save.get("inventory", {})
		var seed_id := ""
		var seed_name := ""
		match chapter_id:
			"chapter1":
				seed_id = "corn"
				seed_name = "🌽 玉米种子（每回合回血，穿越开荒圣物）"
			"chapter2":
				seed_id = "potato"
				seed_name = "🥔 土豆种子（开局士气暴涨，天下丰饶）"
			"chapter3":
				seed_id = "sweet_potato"
				seed_name = "🍠 番薯种子（全军攻击狂飙，战力翻涌）"
		if seed_id != "":
			inv[seed_id] = int(inv.get(seed_id, 0)) + 1
			save["inventory"] = inv
			body += "\n🎁 原著剧情大礼：解锁【%s】！" % seed_name
	else:
		body += "\n⚔️ 演武重温：磨砺战法，再建奇功！"

	SaveCore.save_state(save)
	var nxt := _next_chapter()
	_show_result_panel(title_text, body, nxt)

func _show_result_panel(title_text: String, body: String, nxt: String) -> void:
	if result_panel == null:
		_build_result_panel()
	var mask := $UI.get_node_or_null("ResultMask")
	if mask:
		mask.visible = true
	result_title.text = title_text
	result_body.text = body
	result_next.visible = nxt != ""
	result_next.disabled = nxt == ""
	result_next.text = "奔赴下一关 ⚔️" if nxt != "" else "大业告成 🏆"
	result_panel.visible = true

## 用代码构建结算面板（避免 tscn 布局解析问题）
func _build_result_panel() -> void:
	var mask := ColorRect.new()
	mask.name = "ResultMask"
	mask.visible = false
	mask.color = Color(0.03, 0.04, 0.06, 0.75)
	mask.set_anchors_preset(Control.PRESET_FULL_RECT)
	mask.z_index = 110
	$UI.add_child(mask)

	var panel := PanelContainer.new()
	panel.visible = false
	panel.position = Vector2(340, 140)
	panel.size = Vector2(600, 420)
	panel.z_index = 120
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.09, 0.13, 0.98)
	sb.border_color = Color(0.9, 0.78, 0.35, 1.0)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 28
	sb.content_margin_right = 28
	sb.content_margin_top = 24
	sb.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", sb)
	$UI.add_child(panel)
	result_panel = panel

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 20)
	panel.add_child(vbox)

	var title := Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.98, 0.85, 0.3))
	vbox.add_child(title)
	result_title = title

	var body := Label.new()
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 18)
	body.add_theme_color_override("font_color", Color(0.9, 0.95, 0.9))
	vbox.add_child(body)
	result_body = body

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	vbox.add_child(row)

	var next := Button.new()
	next.custom_minimum_size = Vector2(180, 52)
	next.text = "奔赴下一关 ⚔️"
	var btn_next_sb := StyleBoxFlat.new()
	btn_next_sb.bg_color = Color(0.18, 0.45, 0.25)
	btn_next_sb.border_color = Color(0.35, 0.85, 0.45)
	btn_next_sb.set_border_width_all(2)
	btn_next_sb.set_corner_radius_all(8)
	next.add_theme_stylebox_override("normal", btn_next_sb)
	next.add_theme_font_size_override("font_size", 16)
	next.pressed.connect(_on_result_next)
	row.add_child(next)
	result_next = next

	var home := Button.new()
	home.custom_minimum_size = Vector2(160, 52)
	home.text = "返回主城 🏰"
	var btn_home_sb := StyleBoxFlat.new()
	btn_home_sb.bg_color = Color(0.2, 0.22, 0.28)
	btn_home_sb.border_color = Color(0.5, 0.55, 0.65)
	btn_home_sb.set_border_width_all(2)
	btn_home_sb.set_corner_radius_all(8)
	home.add_theme_stylebox_override("normal", btn_home_sb)
	home.add_theme_font_size_override("font_size", 16)
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

	# 核心彩蛋与隐藏解锁（保证 25/25 100% 满收集）
	if chapter_id == "chapter1":
		# 汜水关温酒：曹操叹服“这还不阴”，解锁曹操
		SaveCore.collect(save, "warrior_caocao")
	elif chapter_id == "chapter2":
		# 虎牢关击退吕布：吕布惊呼“赤兔快跑”，解锁该名场面
		SaveCore.collect(save, "scene_chitu_kaopao")

func _scene_key_for_chapter() -> String:
	match chapter_id:
		"chapter1": return "wenjiu_huaxiong"
		"chapter2": return "sanying_lubu"
		"chapter3": return "naked_battle"
		"chapter4": return "qinzheng_taishan"
	return ""

## ---------- HUD ----------
func _update_hud() -> void:
	turn_label.text = "第 %d 回合 · %s | 士气: 我方 %d vs 敌军 %d" % [
		turn_state.turn, TurnCore.phase_name(turn_state.phase),
		morale.player, morale.enemy
	]
