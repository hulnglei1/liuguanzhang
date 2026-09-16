extends Control
## 抽奖界面：神农仙种池 + 天工神兵池双池抽取
## 数据存 user://save.json（SaveCore 管理声望/背包）

const LotteryCore := preload("res://scripts/systems/lottery.gd")
const SaveCore := preload("res://scripts/systems/save.gd")

var save: Dictionary
var label_result: Label
var label_prestige: Label
var btn_seed: Button
var btn_weapon: Button
var btn_back: Button

# 动态持有个数标签映射
var seed_item_labels: Dictionary = {}
var weapon_item_labels: Dictionary = {}

func _ready() -> void:
	save = SaveCore.load_state()
	_build_ui()
	_refresh()

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

func _build_ui() -> void:
	# 全屏深色背景
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.06, 0.09, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# 1. 顶部导航栏 (1280 x 64)
	var top_bar := Panel.new()
	top_bar.position = Vector2(0, 0)
	top_bar.size = Vector2(1280, 64)
	var top_style := StyleBoxFlat.new()
	top_style.bg_color = Color(0.08, 0.09, 0.12, 0.98)
	top_style.border_color = Color(0.83, 0.69, 0.22, 0.8)
	top_style.border_width_bottom = 2
	top_bar.add_theme_stylebox_override("panel", top_style)
	add_child(top_bar)

	# 返回按钮
	btn_back = Button.new()
	btn_back.text = "🔙 返回主菜单"
	btn_back.position = Vector2(24, 12)
	btn_back.size = Vector2(140, 40)
	btn_back.add_theme_stylebox_override("normal", _create_btn_style(Color(0.15, 0.16, 0.2), Color(0.83, 0.69, 0.22, 0.6)))
	btn_back.add_theme_stylebox_override("hover", _create_btn_style(Color(0.25, 0.26, 0.35), Color(1.0, 0.85, 0.3)))
	btn_back.add_theme_color_override("font_color", Color(0.9, 0.92, 0.95))
	btn_back.pressed.connect(_on_back)
	top_bar.add_child(btn_back)

	# 标题与副标
	var title := Label.new()
	title.text = "【 军 机 宝 库 · 声 望 祈 赏 】"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.45))
	title.position = Vector2(250, 8)
	title.size = Vector2(600, 28)
	top_bar.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "攻克郡城 缴获战功 · 祈取五谷仙种与百炼神兵，助匡扶汉室！"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.add_theme_color_override("font_color", Color(0.65, 0.72, 0.8))
	subtitle.position = Vector2(250, 36)
	subtitle.size = Vector2(600, 20)
	top_bar.add_child(subtitle)

	# 军功声望徽章
	var badge_panel := Panel.new()
	badge_panel.position = Vector2(1000, 12)
	badge_panel.size = Vector2(256, 40)
	badge_panel.add_theme_stylebox_override("panel", _create_box_style(Color(0.15, 0.12, 0.05, 0.9), Color(0.9, 0.75, 0.25), 20, 2))
	top_bar.add_child(badge_panel)

	label_prestige = Label.new()
	label_prestige.text = "🎖️ 军功声望: 0"
	label_prestige.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_prestige.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label_prestige.add_theme_font_size_override("font_size", 16)
	label_prestige.add_theme_color_override("font_color", Color(1.0, 0.88, 0.2))
	label_prestige.set_anchors_preset(Control.PRESET_FULL_RECT)
	badge_panel.add_child(label_prestige)

	# 2. 卡片区域：左侧神农池，右侧神兵池 (各 580 x 440)
	_build_seed_card()
	_build_weapon_card()

	# 3. 底部记事板与展示区 (1200 x 170)
	var bottom_panel := Panel.new()
	bottom_panel.position = Vector2(40, 530)
	bottom_panel.size = Vector2(1200, 166)
	bottom_panel.add_theme_stylebox_override("panel", _create_box_style(Color(0.08, 0.09, 0.12, 0.95), Color(0.83, 0.69, 0.22, 0.7), 10))
	add_child(bottom_panel)

	var log_header := Label.new()
	log_header.text = "📜 军机库令 · 祈赏实录"
	log_header.add_theme_font_size_override("font_size", 14)
	log_header.add_theme_color_override("font_color", Color(0.85, 0.75, 0.35))
	log_header.position = Vector2(20, 12)
	log_header.size = Vector2(300, 22)
	bottom_panel.add_child(log_header)

	label_result = Label.new()
	label_result.text = "主公威震四方！在各战役中破阵斩将、攻克城池即可缴获军功声望。\n点击上方奖池，开启神农宝种或百炼神兵祈赏！"
	label_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_result.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label_result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label_result.add_theme_font_size_override("font_size", 17)
	label_result.add_theme_color_override("font_color", Color(0.9, 0.92, 0.96))
	label_result.position = Vector2(20, 42)
	label_result.size = Vector2(1160, 110)
	bottom_panel.add_child(label_result)

func _build_seed_card() -> void:
	var card := Panel.new()
	card.position = Vector2(40, 80)
	card.size = Vector2(580, 430)
	card.add_theme_stylebox_override("panel", _create_box_style(Color(0.06, 0.11, 0.09, 0.95), Color(0.25, 0.65, 0.4), 12, 2))
	add_child(card)

	var title := Label.new()
	title.text = "🌿 神农仙种池 · 农本兴邦"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.45, 0.9, 0.55))
	title.position = Vector2(20, 14)
	title.size = Vector2(540, 28)
	card.add_child(title)

	var desc := Label.new()
	desc.text = "军屯五谷仙种，产出可永久入库，并在出征前提供强效战役庇佑"
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color", Color(0.65, 0.8, 0.7))
	desc.position = Vector2(20, 44)
	desc.size = Vector2(540, 20)
	card.add_child(desc)

	# 种子条目列表
	var y := 76
	for item in LotteryCore.SEED_POOL:
		var row := Panel.new()
		row.position = Vector2(24, y)
		row.size = Vector2(532, 74)
		row.add_theme_stylebox_override("panel", _create_box_style(Color(0.04, 0.08, 0.06, 0.8), Color(0.2, 0.45, 0.3), 6, 1))
		card.add_child(row)

		var icon_str := "🌽" if item.id == "corn" else ("🥔" if item.id == "potato" else "🍠")
		var lbl_name := Label.new()
		lbl_name.text = "%s  %s" % [icon_str, item.name]
		lbl_name.add_theme_font_size_override("font_size", 16)
		lbl_name.add_theme_color_override("font_color", Color(0.9, 0.95, 0.85))
		lbl_name.position = Vector2(16, 12)
		lbl_name.size = Vector2(220, 24)
		row.add_child(lbl_name)

		var lbl_desc := Label.new()
		lbl_desc.text = item.desc
		lbl_desc.add_theme_font_size_override("font_size", 12)
		lbl_desc.add_theme_color_override("font_color", Color(0.65, 0.85, 0.7))
		lbl_desc.position = Vector2(16, 40)
		lbl_desc.size = Vector2(360, 22)
		row.add_child(lbl_desc)

		var lbl_count := Label.new()
		lbl_count.text = "持有: ×0"
		lbl_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		lbl_count.add_theme_font_size_override("font_size", 15)
		lbl_count.add_theme_color_override("font_color", Color(0.4, 0.95, 0.6))
		lbl_count.position = Vector2(380, 24)
		lbl_count.size = Vector2(130, 26)
		row.add_child(lbl_count)
		seed_item_labels[item.id] = lbl_count

		y += 82

	# 抽奖按钮
	btn_seed = Button.new()
	btn_seed.text = "🌱 消耗 1000 军功 · 祈得仙种"
	btn_seed.position = Vector2(24, 345)
	btn_seed.size = Vector2(532, 60)
	btn_seed.add_theme_font_size_override("font_size", 17)
	btn_seed.add_theme_stylebox_override("normal", _create_btn_style(Color(0.12, 0.35, 0.2), Color(0.35, 0.8, 0.45)))
	btn_seed.add_theme_stylebox_override("hover", _create_btn_style(Color(0.18, 0.48, 0.28), Color(0.5, 1.0, 0.6)))
	btn_seed.add_theme_stylebox_override("disabled", _create_btn_style(Color(0.15, 0.16, 0.18), Color(0.3, 0.32, 0.35)))
	btn_seed.pressed.connect(_on_seed)
	card.add_child(btn_seed)

func _build_weapon_card() -> void:
	var card := Panel.new()
	card.position = Vector2(660, 80)
	card.size = Vector2(580, 430)
	card.add_theme_stylebox_override("panel", _create_box_style(Color(0.12, 0.06, 0.08, 0.95), Color(0.75, 0.3, 0.3), 12, 2))
	add_child(card)

	var title := Label.new()
	title.text = "⚔️ 天工神兵池 · 诸侯战栗"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(1.0, 0.55, 0.5))
	title.position = Vector2(20, 14)
	title.size = Vector2(540, 28)
	card.add_child(title)

	var desc := Label.new()
	desc.text = "锻铸稀世神甲与爆笑杀器，解锁强悍装备属性与范围绝杀战技"
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color", Color(0.85, 0.7, 0.7))
	desc.position = Vector2(20, 44)
	desc.size = Vector2(540, 20)
	card.add_child(desc)

	# 武器条目列表
	var y := 72
	for item in LotteryCore.WEAPON_POOL:
		var row := Panel.new()
		row.position = Vector2(24, y)
		row.size = Vector2(532, 58)
		row.add_theme_stylebox_override("panel", _create_box_style(Color(0.08, 0.04, 0.05, 0.8), Color(0.5, 0.22, 0.25), 6, 1))
		card.add_child(row)

		var icon_str := "🛡️" if item.id == "jinggang_dou" else ("💥" if item.id == "da_he_dan" else ("🚀" if item.id == "shi_tou" else "🧿"))
		var lbl_name := Label.new()
		lbl_name.text = "%s  %s" % [icon_str, item.name]
		lbl_name.add_theme_font_size_override("font_size", 15)
		lbl_name.add_theme_color_override("font_color", Color(1.0, 0.9, 0.85))
		lbl_name.position = Vector2(16, 8)
		lbl_name.size = Vector2(220, 22)
		row.add_child(lbl_name)

		var lbl_desc := Label.new()
		lbl_desc.text = item.desc
		lbl_desc.add_theme_font_size_override("font_size", 11)
		lbl_desc.add_theme_color_override("font_color", Color(0.85, 0.65, 0.65))
		lbl_desc.position = Vector2(16, 32)
		lbl_desc.size = Vector2(360, 20)
		row.add_child(lbl_desc)

		var lbl_count := Label.new()
		lbl_count.text = "持有: ×0"
		lbl_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		lbl_count.add_theme_font_size_override("font_size", 14)
		lbl_count.add_theme_color_override("font_color", Color(1.0, 0.65, 0.4))
		lbl_count.position = Vector2(380, 16)
		lbl_count.size = Vector2(130, 24)
		row.add_child(lbl_count)
		weapon_item_labels[item.id] = lbl_count

		y += 66

	# 抽奖按钮
	btn_weapon = Button.new()
	btn_weapon.text = "🔥 消耗 5000 军功 · 锻铸神兵"
	btn_weapon.position = Vector2(24, 345)
	btn_weapon.size = Vector2(532, 60)
	btn_weapon.add_theme_font_size_override("font_size", 17)
	btn_weapon.add_theme_stylebox_override("normal", _create_btn_style(Color(0.4, 0.15, 0.15), Color(0.9, 0.35, 0.35)))
	btn_weapon.add_theme_stylebox_override("hover", _create_btn_style(Color(0.55, 0.2, 0.2), Color(1.0, 0.5, 0.5)))
	btn_weapon.add_theme_stylebox_override("disabled", _create_btn_style(Color(0.15, 0.16, 0.18), Color(0.3, 0.32, 0.35)))
	btn_weapon.pressed.connect(_on_weapon)
	card.add_child(btn_weapon)

func _refresh() -> void:
	var p: int = int(save.get("prestige", 0))
	label_prestige.text = "🎖️ 军功声望: %d" % p
	btn_seed.disabled = (p < 1000)
	btn_weapon.disabled = (p < 5000)

	var inv: Dictionary = save.get("inventory", {})
	for item_id in seed_item_labels:
		var cnt: int = int(inv.get(item_id, 0))
		seed_item_labels[item_id].text = "持有: ×%d" % cnt

	for item_id in weapon_item_labels:
		var cnt: int = int(inv.get(item_id, 0))
		weapon_item_labels[item_id].text = "持有: ×%d" % cnt

func _on_seed() -> void:
	var p: int = int(save.get("prestige", 0))
	var draw := LotteryCore.draw_seed(p)
	if draw.success:
		SaveCore.award_item(save, draw.item, 1000)
		SaveCore.save_state(save)
		var inv_cnt: int = int(save["inventory"].get(draw.item.get("id", ""), 0))
		label_result.text = "【🌿 神农赐福！】获得：%s\n%s\n（现已持有 ×%d）" % [
			draw.item.get("name", ""), draw.item.get("desc", ""), inv_cnt
		]
		_celebration(Color(0.4, 0.9, 0.5, 0.4))
	else:
		label_result.text = "❌ " + str(draw.get("reason", "抽奖失败"))
	_refresh()

func _on_weapon() -> void:
	var p: int = int(save.get("prestige", 0))
	var draw := LotteryCore.draw_weapon(p)
	if draw.success:
		SaveCore.award_item(save, draw.item, 5000)
		SaveCore.save_state(save)
		var inv_cnt: int = int(save["inventory"].get(draw.item.get("id", ""), 0))
		label_result.text = "【⚔️ 宝库出世！】获得：%s\n%s\n（现已持有 ×%d）" % [
			draw.item.get("name", ""), draw.item.get("desc", ""), inv_cnt
		]
		_celebration(Color(1.0, 0.4, 0.3, 0.45))
		_celebration_shake()
	else:
		label_result.text = "❌ " + str(draw.get("reason", "抽奖失败"))
	_refresh()

## 抽中金光演出：全屏光芒 + 结果弹跳
func _celebration(glow_color: Color) -> void:
	var flash := ColorRect.new()
	flash.color = glow_color
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.z_index = 80
	add_child(flash)
	var tw := create_tween()
	tw.tween_property(flash, "modulate:a", 0.0, 0.45)
	tw.tween_callback(flash.queue_free)

	if label_result:
		var base := label_result.position
		var twb := create_tween()
		twb.tween_property(label_result, "position", base + Vector2(0, -10), 0.08)
		twb.tween_property(label_result, "position", base, 0.12)

func _celebration_shake() -> void:
	var base_pos := position
	var tw := create_tween()
	tw.tween_property(self, "position", base_pos + Vector2(4, -3), 0.04)
	tw.tween_property(self, "position", base_pos + Vector2(-4, 3), 0.04)
	tw.tween_property(self, "position", base_pos, 0.04)

func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")