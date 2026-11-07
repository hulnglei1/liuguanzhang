class_name BattleDashboard
extends RefCounted
## 顶部仪表盘（右侧战斗面板）：我方/敌方概览、选中单位详情、军令目标、各关机制说明。
##
## 从 battle.gd 抽出来的第二块 UI（约 380 行）。原先仪表盘的搭建、刷新、军令文案
## 全堆在战斗主控里，导致 battle.gd 一半是规则一半是控件代码。
## 现在它是一个自洽的对象：battle.gd 只组装 ctx（战斗快照）丢进来刷新。

const CombatCore := preload("res://scripts/core/combat.gd")
const ObjectivesCore := preload("res://scripts/core/objectives.gd")
const UnitViewCore := preload("res://scripts/ui/unit_view.gd")

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

func build(root: Control, chapter_id: String, hills: Array) -> void:
	if root == null:
		return
	for c in root.get_children():
		c.queue_free()

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	root.add_child(margin)

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
	dash_avatar_plate.polygon = UnitViewCore.circle_polygon(22, 16)
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


func update(ctx: Dictionary) -> void:
	if dash_overview == null or dash_unit_view == null:
		return
	if dash_morale_text:
		dash_morale_text.text = "🚩 战局士气：我方 %d vs 敌方 %d（攻防修正 x%.2f / x%.2f）" % [
			int(ctx.get("morale_player", 100)), int(ctx.get("morale_enemy", 100)),
			CombatCore.morale_multiplier(int(ctx.get("morale_player", 100))),
			CombatCore.morale_multiplier(int(ctx.get("morale_enemy", 100)))
		]
	var u = ctx.get("selected_unit", null)
	if u == null or not u.alive:
		dash_overview.visible = true
		dash_unit_view.visible = false
		dash_player_count.text = "🛡️ 我方在列：%d 人" % int(ctx.get("player_count", 0))
		dash_enemy_count.text = "⚔️ 敌方存活：%d 人" % int(ctx.get("enemy_count", 0))
		update_chapter_objectives(ctx)
		return

	dash_overview.visible = false
	dash_unit_view.visible = true

	dash_avatar_plate.color = UnitViewCore.character_base_color(u)
	dash_avatar_text.text = UnitViewCore.character_calligraphy(u)
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
	if u.cell in ctx.get("hills", []):
		dash_status_text.text += " · ⛰️ 高地优势(+30%)"

	dash_hp_text.text = "生命值: %d / %d" % [u.hp, u.max_hp]
	dash_hp_bar.value = float(u.hp) / float(max(u.max_hp, 1)) * 100.0

	var hill_tag := " (⛰️高地)" if u.cell in ctx.get("hills", []) else ""
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


func update_chapter_objectives(ctx: Dictionary) -> void:
	if dash_primary_obj == null or dash_secondary_obj == null or dash_tips_content == null:
		return
	var stages: Array = ctx.get("stages", [])
	var stage_idx: int = int(ctx.get("stage_idx", 0))
	var c_name := str(ctx.get("commander_name", "敌方主将"))
	var c_hp_str := " (HP: %d/%d)" % [int(ctx.get("commander_hp", 0)), int(ctx.get("commander_max_hp", 0))] if bool(ctx.get("commander_alive", false)) else ""

	if ctx.get("commander_seen", false) and not bool(ctx.get("commander_alive", false)):
		# 分阶段军令下：主将死了但如果还有后续阶段（如第 1 关还要破城门），不能显示"大获全胜"
		if stages.is_empty() or stage_idx >= stages.size() - 1:
			dash_primary_obj.text = "🎉 敌将已被击溃！大获全胜！"
			return

	match str(ctx.get("chapter_id", "")):
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
	var active_bonds: Array = ctx.get("active_bonds", [])
	if active_bonds.size() > 0:
		var bond_lines: Array[String] = []
		for b in active_bonds:
			bond_lines.append("• 将缘【%s】：%s" % [b["name"], b["desc"]])
		dash_tips_content.text += "\n" + "\n".join(bond_lines)
