extends Control
## 图鉴系统：武将列传 / 武学绝技 / 传世名场面
## 数据源：res://data/collection.json + user://save.json

const SaveCore := preload("res://scripts/systems/save.gd")

var collection_data: Dictionary
var save: Dictionary
var label_progress: Label

const WARRIOR_CHARS: Dictionary = {
	"liubei": "刘",
	"guanyu": "关",
	"zhangfei": "张",
	"zhaoyun": "云",
	"huaxiong": "雄",
	"lubu": "布",
	"xuchu": "褚",
	"zangba": "霸",
	"changxi": "豨",
	"wuanguo": "国",
	"gongsunzan": "瓒",
	"caocao": "操",
}

const SKILL_ICONS: Dictionary = {
	"dragon_slash": "🐉",
	"roar": "🦁",
	"seven_dash": "⚡",
	"hua_rage": "👹",
	"lubu_fangtian": "戟",
	"naked_armor": "🩲",
	"king_hill": "⛰️",
	"arrow_rain": "🏹",
}

func _ready() -> void:
	save = SaveCore.load_state()
	collection_data = _load_json("res://data/collection.json")
	_build_ui()

func _load_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

func _create_box_style(bg_col: Color, border_col: Color, radius: int = 8, border_w: int = 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_col
	sb.border_color = border_col
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
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
	var btn_back := Button.new()
	btn_back.text = "🔙 返回主菜单"
	btn_back.position = Vector2(24, 12)
	btn_back.size = Vector2(140, 40)
	btn_back.add_theme_stylebox_override("normal", _create_btn_style(Color(0.15, 0.16, 0.2), Color(0.83, 0.69, 0.22, 0.6)))
	btn_back.add_theme_stylebox_override("hover", _create_btn_style(Color(0.25, 0.26, 0.35), Color(1.0, 0.85, 0.3)))
	btn_back.add_theme_color_override("font_color", Color(0.9, 0.92, 0.95))
	btn_back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main.tscn"))
	top_bar.add_child(btn_back)

	# 标题与副标
	var title := Label.new()
	title.text = "【 诸 侯 风 云 录 · 典 藏 宝 鉴 】"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.45))
	title.position = Vector2(250, 8)
	title.size = Vector2(600, 28)
	top_bar.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "百战名将列传 · 盖世武学绝技 · 荒诞反转名场面全收录"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.add_theme_color_override("font_color", Color(0.65, 0.72, 0.8))
	subtitle.position = Vector2(250, 36)
	subtitle.size = Vector2(600, 20)
	top_bar.add_child(subtitle)

	# 收集度徽章
	var badge_panel := Panel.new()
	badge_panel.position = Vector2(1000, 12)
	badge_panel.size = Vector2(256, 40)
	badge_panel.add_theme_stylebox_override("panel", _create_box_style(Color(0.15, 0.12, 0.05, 0.9), Color(0.9, 0.75, 0.25), 20, 2))
	top_bar.add_child(badge_panel)

	label_progress = Label.new()
	label_progress.text = "🏆 总收集度: 0/25 (0%)"
	label_progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_progress.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label_progress.add_theme_font_size_override("font_size", 15)
	label_progress.add_theme_color_override("font_color", Color(1.0, 0.88, 0.2))
	label_progress.set_anchors_preset(Control.PRESET_FULL_RECT)
	badge_panel.add_child(label_progress)

	# 2. 三列卡片容器 (每列宽 386px，间隔 20px)
	var collected: Dictionary = save.get("collection", {})
	_build_warriors_column(collected)
	_build_skills_column(collected)
	_build_scenes_column(collected)
	_update_total_progress(collected)

func _is_collected(collected: Dictionary, prefix: String, id: String) -> bool:
	return collected.has(prefix + id) or collected.has(id)

func _build_warriors_column(collected: Dictionary) -> void:
	var col_x := 30
	var panel := Panel.new()
	panel.position = Vector2(col_x, 76)
	panel.size = Vector2(386, 626)
	panel.add_theme_stylebox_override("panel", _create_box_style(Color(0.08, 0.09, 0.12, 0.95), Color(0.83, 0.69, 0.22, 0.6), 10))
	add_child(panel)

	var warriors: Array = collection_data.get("warriors", [])
	var unlocked_count := 0
	for w in warriors:
		if _is_collected(collected, "warrior_", str(w.get("id", ""))):
			unlocked_count += 1

	var header := Label.new()
	header.text = "👤 武将列传  (%d/%d)" % [unlocked_count, warriors.size()]
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 18)
	header.add_theme_color_override("font_color", Color(0.95, 0.85, 0.45))
	header.position = Vector2(10, 10)
	header.size = Vector2(366, 26)
	panel.add_child(header)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(10, 44)
	scroll.size = Vector2(366, 570)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(vbox)

	for w in warriors:
		var wid: String = str(w.get("id", ""))
		var is_unlocked := _is_collected(collected, "warrior_", wid)
		var item_panel := PanelContainer.new()
		item_panel.custom_minimum_size = Vector2(350, 72)
		vbox.add_child(item_panel)

		if is_unlocked:
			item_panel.add_theme_stylebox_override("panel", _create_box_style(Color(0.1, 0.13, 0.18, 0.9), Color(0.3, 0.6, 0.85), 6, 1))
			var hbox := HBoxContainer.new()
			hbox.add_theme_constant_override("separation", 10)
			item_panel.add_child(hbox)

			# 武将印玺头像
			var avatar_panel := Panel.new()
			avatar_panel.custom_minimum_size = Vector2(48, 48)
			avatar_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			var av_style := StyleBoxFlat.new()
			av_style.bg_color = Color(0.18, 0.22, 0.3)
			av_style.border_color = Color(0.9, 0.75, 0.25)
			av_style.set_border_width_all(2)
			av_style.set_corner_radius_all(24)
			avatar_panel.add_theme_stylebox_override("panel", av_style)
			hbox.add_child(avatar_panel)

			var av_lbl := Label.new()
			av_lbl.text = WARRIOR_CHARS.get(wid, "将")
			av_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			av_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			av_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
			av_lbl.add_theme_font_size_override("font_size", 20)
			av_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
			avatar_panel.add_child(av_lbl)

			# 文本信息
			var info_vbox := VBoxContainer.new()
			info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			info_vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			hbox.add_child(info_vbox)

			var name_lbl := Label.new()
			name_lbl.text = "✅ " + str(w.get("name", "武将"))
			name_lbl.add_theme_font_size_override("font_size", 15)
			name_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.3))
			info_vbox.add_child(name_lbl)

			var desc_lbl := Label.new()
			desc_lbl.text = str(w.get("desc", ""))
			desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			desc_lbl.add_theme_font_size_override("font_size", 11)
			desc_lbl.add_theme_color_override("font_color", Color(0.75, 0.82, 0.9))
			info_vbox.add_child(desc_lbl)
		else:
			item_panel.add_theme_stylebox_override("panel", _create_box_style(Color(0.08, 0.08, 0.1, 0.6), Color(0.2, 0.22, 0.25), 6, 1))
			var locked_vbox := VBoxContainer.new()
			locked_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			locked_vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			item_panel.add_child(locked_vbox)

			var lock_lbl := Label.new()
			lock_lbl.text = "🔒 ？？？ [未收录武将]"
			lock_lbl.add_theme_font_size_override("font_size", 14)
			lock_lbl.add_theme_color_override("font_color", Color(0.5, 0.52, 0.55))
			locked_vbox.add_child(lock_lbl)

			var hint_lbl := Label.new()
			hint_lbl.text = "推进主线剧情战役，在战场交手或招募后解锁"
			hint_lbl.add_theme_font_size_override("font_size", 11)
			hint_lbl.add_theme_color_override("font_color", Color(0.4, 0.42, 0.45))
			locked_vbox.add_child(hint_lbl)

func _build_skills_column(collected: Dictionary) -> void:
	var col_x := 446
	var panel := Panel.new()
	panel.position = Vector2(col_x, 76)
	panel.size = Vector2(386, 626)
	panel.add_theme_stylebox_override("panel", _create_box_style(Color(0.08, 0.09, 0.12, 0.95), Color(0.3, 0.7, 0.6, 0.6), 10))
	add_child(panel)

	var skills: Array = collection_data.get("skills", [])
	var unlocked_count := 0
	for s in skills:
		if _is_collected(collected, "skill_", str(s.get("id", ""))):
			unlocked_count += 1

	var header := Label.new()
	header.text = "✨ 武学绝技  (%d/%d)" % [unlocked_count, skills.size()]
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 18)
	header.add_theme_color_override("font_color", Color(0.45, 0.9, 0.75))
	header.position = Vector2(10, 10)
	header.size = Vector2(366, 26)
	panel.add_child(header)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(10, 44)
	scroll.size = Vector2(366, 570)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(vbox)

	for s in skills:
		var sid: String = str(s.get("id", ""))
		var is_unlocked := _is_collected(collected, "skill_", sid)
		var item_panel := PanelContainer.new()
		item_panel.custom_minimum_size = Vector2(350, 68)
		vbox.add_child(item_panel)

		if is_unlocked:
			item_panel.add_theme_stylebox_override("panel", _create_box_style(Color(0.08, 0.14, 0.12, 0.9), Color(0.2, 0.6, 0.45), 6, 1))
			var info_vbox := VBoxContainer.new()
			info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			item_panel.add_child(info_vbox)

			var icon_str: String = SKILL_ICONS.get(sid, "⚔️")
			var name_lbl := Label.new()
			name_lbl.text = "✅ %s %s" % [icon_str, str(s.get("name", "技能"))]
			name_lbl.add_theme_font_size_override("font_size", 15)
			name_lbl.add_theme_color_override("font_color", Color(0.4, 0.95, 0.7))
			info_vbox.add_child(name_lbl)

			var desc_lbl := Label.new()
			desc_lbl.text = str(s.get("desc", ""))
			desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			desc_lbl.add_theme_font_size_override("font_size", 12)
			desc_lbl.add_theme_color_override("font_color", Color(0.75, 0.9, 0.8))
			info_vbox.add_child(desc_lbl)
		else:
			item_panel.add_theme_stylebox_override("panel", _create_box_style(Color(0.08, 0.08, 0.1, 0.6), Color(0.2, 0.22, 0.25), 6, 1))
			var locked_vbox := VBoxContainer.new()
			locked_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			item_panel.add_child(locked_vbox)

			var lock_lbl := Label.new()
			lock_lbl.text = "🔒 ？？？ [未领悟绝技]"
			lock_lbl.add_theme_font_size_override("font_size", 14)
			lock_lbl.add_theme_color_override("font_color", Color(0.5, 0.52, 0.55))
			locked_vbox.add_child(lock_lbl)

			var hint_lbl := Label.new()
			hint_lbl.text = "需在战场亲历或施展此项绝学后收录"
			hint_lbl.add_theme_font_size_override("font_size", 11)
			hint_lbl.add_theme_color_override("font_color", Color(0.4, 0.42, 0.45))
			locked_vbox.add_child(hint_lbl)

func _build_scenes_column(collected: Dictionary) -> void:
	var col_x := 864
	var panel := Panel.new()
	panel.position = Vector2(col_x, 76)
	panel.size = Vector2(386, 626)
	panel.add_theme_stylebox_override("panel", _create_box_style(Color(0.08, 0.09, 0.12, 0.95), Color(0.85, 0.45, 0.3, 0.6), 10))
	add_child(panel)

	var scenes: Array = collection_data.get("scenes", [])
	var unlocked_count := 0
	for sc in scenes:
		if _is_collected(collected, "scene_", str(sc.get("id", ""))):
			unlocked_count += 1

	var header := Label.new()
	header.text = "📜 传世名场面  (%d/%d)" % [unlocked_count, scenes.size()]
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 18)
	header.add_theme_color_override("font_color", Color(1.0, 0.6, 0.45))
	header.position = Vector2(10, 10)
	header.size = Vector2(366, 26)
	panel.add_child(header)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(10, 44)
	scroll.size = Vector2(366, 570)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(vbox)

	for sc in scenes:
		var scid: String = str(sc.get("id", ""))
		var is_unlocked := _is_collected(collected, "scene_", scid)
		var item_panel := PanelContainer.new()
		item_panel.custom_minimum_size = Vector2(350, 84)
		vbox.add_child(item_panel)

		if is_unlocked:
			item_panel.add_theme_stylebox_override("panel", _create_box_style(Color(0.14, 0.08, 0.09, 0.9), Color(0.7, 0.35, 0.3), 6, 1))
			var info_vbox := VBoxContainer.new()
			info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			item_panel.add_child(info_vbox)

			var name_lbl := Label.new()
			name_lbl.text = "🏆 【%s】" % str(sc.get("name", "名场面"))
			name_lbl.add_theme_font_size_override("font_size", 15)
			name_lbl.add_theme_color_override("font_color", Color(1.0, 0.75, 0.4))
			info_vbox.add_child(name_lbl)

			var desc_lbl := Label.new()
			desc_lbl.text = str(sc.get("desc", ""))
			desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			desc_lbl.add_theme_font_size_override("font_size", 12)
			desc_lbl.add_theme_color_override("font_color", Color(0.9, 0.8, 0.75))
			info_vbox.add_child(desc_lbl)
		else:
			item_panel.add_theme_stylebox_override("panel", _create_box_style(Color(0.08, 0.08, 0.1, 0.6), Color(0.2, 0.22, 0.25), 6, 1))
			var locked_vbox := VBoxContainer.new()
			locked_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			item_panel.add_child(locked_vbox)

			var lock_lbl := Label.new()
			lock_lbl.text = "🔒 ？？？ [未见证名场面]"
			lock_lbl.add_theme_font_size_override("font_size", 14)
			lock_lbl.add_theme_color_override("font_color", Color(0.5, 0.52, 0.55))
			locked_vbox.add_child(lock_lbl)

			var hint_lbl := Label.new()
			hint_lbl.text = "推进战役并触发荒诞原著名桥段解锁"
			hint_lbl.add_theme_font_size_override("font_size", 11)
			hint_lbl.add_theme_color_override("font_color", Color(0.4, 0.42, 0.45))
			locked_vbox.add_child(hint_lbl)

func _update_total_progress(collected: Dictionary) -> void:
	var total_items := 0
	var unlocked_items := 0

	var warriors: Array = collection_data.get("warriors", [])
	total_items += warriors.size()
	for w in warriors:
		if _is_collected(collected, "warrior_", str(w.get("id", ""))):
			unlocked_items += 1

	var skills: Array = collection_data.get("skills", [])
	total_items += skills.size()
	for s in skills:
		if _is_collected(collected, "skill_", str(s.get("id", ""))):
			unlocked_items += 1

	var scenes: Array = collection_data.get("scenes", [])
	total_items += scenes.size()
	for sc in scenes:
		if _is_collected(collected, "scene_", str(sc.get("id", ""))):
			unlocked_items += 1

	var pct := int(float(unlocked_items) / float(maxi(total_items, 1)) * 100.0)
	if label_progress:
		label_progress.text = "🏆 总收集度: %d/%d (%d%%)" % [unlocked_items, total_items, pct]