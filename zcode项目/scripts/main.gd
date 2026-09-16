extends Control
## 主菜单：宏伟战役章节选择 + 主城功能（抽奖/图鉴/大营状态）

const BATTLE_SCENE := preload("res://scenes/battle.tscn")
const BattleScript := preload("res://scripts/battle.gd")
const SaveCore := preload("res://scripts/systems/save.gd")
const LotteryCore := preload("res://scripts/systems/lottery.gd")

const CHAPTER_DEFS := [
	{
		"id": "chapter1",
		"title": "第一章 · 汜水关 · 温酒斩华雄",
		"subtitle": "关羽假意逃窜绕场蓄力，千里青龙一刀斩落14倍狂力华雄！",
		"boss": "华雄",
		"gimmick": "蓄力龙斩 vs 狂力叠加",
		"color": Color(0.2, 0.6, 0.4)
	},
	{
		"id": "chapter2",
		"title": "第二章 · 虎牢关 · 三英战吕布",
		"subtitle": "张飞雷霆怒吼震慑敌阵，刘关张赵合体骑人，诸侯惊呼鬼神抱头窜！",
		"boss": "吕布",
		"gimmick": "燕人咆哮 + 合体骑人 vs 方天乱舞",
		"color": Color(0.55, 0.25, 0.65)
	},
	{
		"id": "chapter3",
		"title": "第三章 · 渭桥 · 裤衩子人大战",
		"subtitle": "虎痴许褚裸衣狂暴死战，波及方圆百米，诸将全员爆甲狂笑互搏！",
		"boss": "许褚",
		"gimmick": "裸衣爆甲 + 双倍攻速吸血",
		"color": Color(0.85, 0.45, 0.2)
	},
	{
		"id": "chapter4",
		"title": "第四章 · 泰山郡 · 亲征占山王",
		"subtitle": "臧霸昌豨盘踞泰山高地，刘皇叔亲征踏险峰，破其高地壁垒！",
		"boss": "臧霸",
		"gimmick": "高地攻防压制 vs 全军强攻",
		"color": Color(0.7, 0.55, 0.25)
	}
]

var save: Dictionary
var label_status: Label

func _ready() -> void:
	save = SaveCore.load_state()
	_build_menu()

func _create_box_style(bg_col: Color, border_col: Color, radius: int = 8, border_w: int = 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_col
	sb.border_color = border_col
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb

func _create_btn_style(bg_col: Color, border_col: Color, radius: int = 6) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_col
	sb.border_color = border_col
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(radius)
	return sb

func _build_menu() -> void:
	# 全屏深色底
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.05, 0.07, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# 1. 顶部宏伟标题 (1280 x 100)
	var title_panel := Panel.new()
	title_panel.position = Vector2(0, 0)
	title_panel.size = Vector2(1280, 96)
	var top_style := StyleBoxFlat.new()
	top_style.bg_color = Color(0.07, 0.08, 0.11, 0.98)
	top_style.border_color = Color(0.83, 0.69, 0.22, 0.8)
	top_style.border_width_bottom = 2
	title_panel.add_theme_stylebox_override("panel", top_style)
	add_child(title_panel)

	var title := Label.new()
	title.text = "【 魂穿刘关张 · 诸侯们被整麻了 】"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.96, 0.86, 0.45))
	title.position = Vector2(0, 14)
	title.size = Vector2(1280, 36)
	title_panel.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "『备持霸业系统、云有七进七出、羽蓄千里龙斩、飞吼破胆碎石 · 爆笑无厘头硬核SRPG战棋』"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", Color(0.7, 0.78, 0.88))
	subtitle.position = Vector2(0, 56)
	subtitle.size = Vector2(1280, 24)
	title_panel.add_child(subtitle)

	# 2. 中层主城功能与状态条 (1200 x 54)
	var nav_panel := Panel.new()
	nav_panel.position = Vector2(40, 108)
	nav_panel.size = Vector2(1200, 54)
	nav_panel.add_theme_stylebox_override("panel", _create_box_style(Color(0.09, 0.1, 0.14, 0.9), Color(0.83, 0.69, 0.22, 0.5), 8))
	add_child(nav_panel)

	var camp_lbl := Label.new()
	camp_lbl.text = "🏰 徐州幕府大营"
	camp_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	camp_lbl.add_theme_font_size_override("font_size", 16)
	camp_lbl.add_theme_color_override("font_color", Color(0.9, 0.92, 0.95))
	camp_lbl.position = Vector2(16, 12)
	camp_lbl.size = Vector2(160, 30)
	nav_panel.add_child(camp_lbl)

	# 抽奖入口按钮
	var btn_lottery := Button.new()
	btn_lottery.text = "🎲 军机祈赏 (声望抽奖)"
	btn_lottery.position = Vector2(180, 8)
	btn_lottery.size = Vector2(200, 38)
	btn_lottery.add_theme_stylebox_override("normal", _create_btn_style(Color(0.12, 0.22, 0.2), Color(0.3, 0.75, 0.5)))
	btn_lottery.add_theme_stylebox_override("hover", _create_btn_style(Color(0.18, 0.32, 0.28), Color(0.4, 0.9, 0.6)))
	btn_lottery.add_theme_color_override("font_color", Color(0.85, 1.0, 0.9))
	btn_lottery.pressed.connect(_go_lottery)
	nav_panel.add_child(btn_lottery)

	# 图鉴入口按钮
	var btn_gallery := Button.new()
	btn_gallery.text = "📜 诸侯图鉴 (名将绝技)"
	btn_gallery.position = Vector2(400, 8)
	btn_gallery.size = Vector2(200, 38)
	btn_gallery.add_theme_stylebox_override("normal", _create_btn_style(Color(0.2, 0.15, 0.24), Color(0.65, 0.45, 0.8)))
	btn_gallery.add_theme_stylebox_override("hover", _create_btn_style(Color(0.28, 0.22, 0.34), Color(0.8, 0.55, 0.95)))
	btn_gallery.add_theme_color_override("font_color", Color(0.92, 0.88, 1.0))
	btn_gallery.pressed.connect(_go_gallery)
	nav_panel.add_child(btn_gallery)

	# 右侧声望与通关信息徽章胶囊
	var status_badge := Panel.new()
	status_badge.position = Vector2(610, 8)
	status_badge.size = Vector2(574, 38)
	status_badge.add_theme_stylebox_override("panel", _create_box_style(Color(0.06, 0.07, 0.10, 0.95), Color(0.83, 0.69, 0.22, 0.5), 18, 1))
	nav_panel.add_child(status_badge)

	label_status = Label.new()
	label_status.text = _format_status_text()
	label_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label_status.add_theme_font_size_override("font_size", 14)
	label_status.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
	label_status.set_anchors_preset(Control.PRESET_FULL_RECT)
	status_badge.add_child(label_status)

	# 3. 四大章节战役卡片 (2行 x 2列，每张卡片 580 x 230)
	var cleared_chapters: Array = save.get("chapters", [])
	var cleared_set := {}
	for ch in cleared_chapters:
		cleared_set[ch] = true

	var positions := [
		Vector2(40, 176),
		Vector2(660, 176),
		Vector2(40, 426),
		Vector2(660, 426)
	]

	for i in range(CHAPTER_DEFS.size()):
		var def: Dictionary = CHAPTER_DEFS[i]
		var card_pos: Vector2 = positions[i]
		var is_cleared: bool = cleared_set.has(def.id)

		var card := Panel.new()
		card.position = card_pos
		card.size = Vector2(580, 230)
		var border_color: Color = def.color if is_cleared else Color(0.83, 0.69, 0.22, 0.6)
		card.add_theme_stylebox_override("panel", _create_box_style(Color(0.08, 0.09, 0.12, 0.95), border_color, 10, 2))
		add_child(card)

		# 标题
		var ch_title := Label.new()
		ch_title.text = def.title
		ch_title.add_theme_font_size_override("font_size", 18)
		ch_title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.4))
		ch_title.position = Vector2(18, 14)
		ch_title.size = Vector2(400, 26)
		card.add_child(ch_title)

		# 通关标签
		var clear_badge := Panel.new()
		clear_badge.position = Vector2(430, 12)
		clear_badge.size = Vector2(130, 28)
		var b_style := StyleBoxFlat.new()
		b_style.bg_color = Color(0.12, 0.3, 0.18, 0.9) if is_cleared else Color(0.2, 0.18, 0.1, 0.8)
		b_style.border_color = Color(0.4, 0.8, 0.5) if is_cleared else Color(0.7, 0.6, 0.3)
		b_style.set_border_width_all(1)
		b_style.set_corner_radius_all(14)
		clear_badge.add_theme_stylebox_override("panel", b_style)
		card.add_child(clear_badge)

		var clear_lbl := Label.new()
		clear_lbl.text = "✅ 已通关" if is_cleared else "⚔️ 待挑战"
		clear_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		clear_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		clear_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		clear_lbl.add_theme_font_size_override("font_size", 12)
		clear_lbl.add_theme_color_override("font_color", Color(0.6, 1.0, 0.7) if is_cleared else Color(0.9, 0.8, 0.4))
		clear_badge.add_child(clear_lbl)

		# 剧情提要
		var ch_desc := Label.new()
		ch_desc.text = def.subtitle
		ch_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ch_desc.add_theme_font_size_override("font_size", 13)
		ch_desc.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
		ch_desc.position = Vector2(18, 50)
		ch_desc.size = Vector2(544, 46)
		card.add_child(ch_desc)

		# 战役情报
		var boss_info := Label.new()
		boss_info.text = "敌军守将: %s   |   战场机制: %s" % [def.boss, def.gimmick]
		boss_info.add_theme_font_size_override("font_size", 12)
		boss_info.add_theme_color_override("font_color", Color(0.6, 0.7, 0.78))
		boss_info.position = Vector2(18, 108)
		boss_info.size = Vector2(544, 22)
		card.add_child(boss_info)

		# 进军与扫荡按钮
		if is_cleared:
			var btn_sweep := Button.new()
			btn_sweep.text = "⚡ 一键扫荡 (+1000声望)"
			btn_sweep.position = Vector2(18, 148)
			btn_sweep.size = Vector2(265, 46)
			btn_sweep.add_theme_font_size_override("font_size", 15)
			btn_sweep.add_theme_stylebox_override("normal", _create_btn_style(Color(0.12, 0.32, 0.22), Color(0.35, 0.8, 0.5)))
			btn_sweep.add_theme_stylebox_override("hover", _create_btn_style(Color(0.18, 0.45, 0.3), Color(0.5, 1.0, 0.65)))
			btn_sweep.add_theme_color_override("font_color", Color(0.9, 1.0, 0.9))
			btn_sweep.pressed.connect(_on_sweep.bind(def.id, def.title))
			card.add_child(btn_sweep)

			var btn_replay := Button.new()
			btn_replay.text = "🔁 手动重战"
			btn_replay.position = Vector2(297, 148)
			btn_replay.size = Vector2(265, 46)
			btn_replay.add_theme_font_size_override("font_size", 15)
			btn_replay.add_theme_stylebox_override("normal", _create_btn_style(Color(0.16, 0.22, 0.28), Color(0.4, 0.65, 0.85)))
			btn_replay.add_theme_stylebox_override("hover", _create_btn_style(Color(0.22, 0.3, 0.38), Color(0.6, 0.85, 1.0)))
			btn_replay.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
			btn_replay.pressed.connect(_on_chapter.bind(def.id))
			card.add_child(btn_replay)
		else:
			var btn_enter := Button.new()
			btn_enter.text = "⚔️ 进 军 出 征"
			btn_enter.position = Vector2(18, 148)
			btn_enter.size = Vector2(544, 46)
			btn_enter.add_theme_font_size_override("font_size", 16)
			var btn_bg: Color = Color(0.35, 0.18, 0.12)
			var btn_border: Color = Color(0.9, 0.5, 0.3)
			btn_enter.add_theme_stylebox_override("normal", _create_btn_style(btn_bg, btn_border))
			btn_enter.add_theme_stylebox_override("hover", _create_btn_style(btn_bg.lightened(0.2), btn_border.lightened(0.2)))
			btn_enter.add_theme_color_override("font_color", Color(1.0, 0.95, 0.9))
			btn_enter.pressed.connect(_on_chapter.bind(def.id))
			card.add_child(btn_enter)

	# 4. 底部版权与版本提示 (1280 x 40)
	var footer := Label.new()
	footer.text = "v2.2.0 · 战棋重制版 (1280×720 全屏) · Godot 4 SRPG · 《魂穿刘关张，诸侯们被整麻了》"
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_font_size_override("font_size", 12)
	footer.add_theme_color_override("font_color", Color(0.45, 0.48, 0.55))
	footer.position = Vector2(0, 678)
	footer.size = Vector2(1280, 24)
	add_child(footer)

	print("[主菜单] 1280x720 宏伟战役面板就绪")

func _on_chapter(id: String) -> void:
	print("[主菜单] 进军章节：", id)
	BattleScript.chapter_id = id
	get_tree().change_scene_to_file("res://scenes/battle.tscn")

## 一键扫荡已通关关卡：直接领取声望与基础战利品
func _on_sweep(id: String, ch_title: String) -> void:
	SaveCore.add_prestige(save, 1000)
	var draw := LotteryCore.draw_seed(1000)
	var loot_name := "神农仙种"
	if draw.success:
		var inv: Dictionary = save.get("inventory", {})
		var iid: String = draw.item.get("id", "corn")
		inv[iid] = int(inv.get(iid, 0)) + 1
		save["inventory"] = inv
		loot_name = draw.item.get("name", "神农仙种")
	SaveCore.save_state(save)
	_refresh_status_bar()
	_show_sweep_modal(ch_title, loot_name)

func _format_status_text() -> String:
	var p: int = int(save.get("prestige", 0))
	var cleared_chapters: Array = save.get("chapters", [])
	var inv: Dictionary = save.get("inventory", {})
	var items_summary: Array = []
	if int(inv.get("corn", 0)) > 0: items_summary.append("🌽x%d" % inv["corn"])
	if int(inv.get("potato", 0)) > 0: items_summary.append("🥔x%d" % inv["potato"])
	if int(inv.get("sweet_potato", 0)) > 0: items_summary.append("🍠x%d" % inv["sweet_potato"])
	if int(inv.get("bracer", 0)) > 0: items_summary.append("🛡️x%d" % inv["bracer"])
	if int(inv.get("amulet", 0)) > 0: items_summary.append("📿x%d" % inv["amulet"])
	if int(inv.get("dahuangdan", 0)) > 0: items_summary.append("💊x%d" % inv["dahuangdan"])
	if int(inv.get("dongfeng", 0)) > 0: items_summary.append("💨x%d" % inv["dongfeng"])
	var stash_str: String = "  |  🎒 行囊: %s" % (" ".join(items_summary) if items_summary.size() > 0 else "空")
	return "🎖️ 声望: %d   |   🏆 通关: %d/4%s" % [p, cleared_chapters.size(), stash_str]

func _refresh_status_bar() -> void:
	if label_status:
		label_status.text = _format_status_text()

func _show_sweep_modal(ch_title: String, loot_name: String) -> void:
	var modal := Panel.new()
	modal.position = Vector2(380, 220)
	modal.size = Vector2(520, 260)
	modal.add_theme_stylebox_override("panel", _create_box_style(Color(0.08, 0.12, 0.1, 0.98), Color(0.3, 0.85, 0.5), 12, 2))
	modal.z_index = 100
	add_child(modal)

	var title := Label.new()
	title.text = "⚡ 破竹扫荡告捷！"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.4, 1.0, 0.6))
	title.position = Vector2(20, 20)
	title.size = Vector2(480, 32)
	modal.add_child(title)

	var p: int = int(save.get("prestige", 0))
	var info := Label.new()
	info.text = "主公威震四方！大军荡平【%s】！\n\n🎖️ 缴获军功声望 +1000（当前总计 %d）\n🎁 战利品入库：%s ×1" % [ch_title, p, loot_name]
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_theme_font_size_override("font_size", 16)
	info.add_theme_color_override("font_color", Color(0.9, 0.95, 0.92))
	info.position = Vector2(20, 68)
	info.size = Vector2(480, 110)
	modal.add_child(info)

	var btn_ok := Button.new()
	btn_ok.text = "领赏凯旋"
	btn_ok.position = Vector2(170, 192)
	btn_ok.size = Vector2(180, 44)
	btn_ok.add_theme_font_size_override("font_size", 16)
	btn_ok.add_theme_stylebox_override("normal", _create_btn_style(Color(0.15, 0.45, 0.25), Color(0.4, 0.9, 0.6)))
	btn_ok.pressed.connect(modal.queue_free)
	modal.add_child(btn_ok)

func _go_lottery() -> void:
	get_tree().change_scene_to_file("res://scenes/lottery.tscn")

func _go_gallery() -> void:
	get_tree().change_scene_to_file("res://scenes/gallery.tscn")