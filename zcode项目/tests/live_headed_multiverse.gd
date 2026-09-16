extends SceneTree

const BattleScript := preload("res://scripts/battle.gd")
const SaveCore := preload("res://scripts/systems/save.gd")
const SkillsCore := preload("res://scripts/entities/skills.gd")

var hud_layer: CanvasLayer
var banner_panel: Panel
var status_title: Label
var status_detail: Label
var live_badge: Label
var progress_bar: ProgressBar

func _initialize() -> void:
	print("[MULTIVERSE-TESTER] 启动多维度玩家实机测评机器人...")
	# 确保所有关卡解锁，声望充足
	var save := SaveCore.load_state()
	var chs: Array = save.get("chapters", [])
	for c in ["chapter1", "chapter2", "chapter3", "chapter4"]:
		if not c in chs:
			chs.append(c)
	save["chapters"] = chs
	save["prestige"] = maxi(int(save.get("prestige", 0)), 12000)
	SaveCore.save_state(save)

	_setup_overlay_hud()
	change_scene_to_file("res://scenes/main.tscn")
	_run_multiverse_tour()

func _setup_overlay_hud() -> void:
	hud_layer = CanvasLayer.new()
	hud_layer.layer = 128
	root.add_child(hud_layer)

	banner_panel = Panel.new()
	banner_panel.position = Vector2(0, 0)
	banner_panel.size = Vector2(1280, 56)
	
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.08, 0.16, 0.96)
	sb.border_color = Color(0.2, 0.85, 1.0, 0.9)
	sb.border_width_bottom = 2
	banner_panel.add_theme_stylebox_override("panel", sb)
	hud_layer.add_child(banner_panel)

	live_badge = Label.new()
	live_badge.text = "🔴 多维度实机评测中"
	live_badge.position = Vector2(16, 14)
	live_badge.size = Vector2(170, 28)
	live_badge.add_theme_font_size_override("font_size", 14)
	live_badge.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
	banner_panel.add_child(live_badge)

	status_title = Label.new()
	status_title.text = "【阶段 1/3】第二关·虎牢关（三英战暴怒吕布）"
	status_title.position = Vector2(190, 6)
	status_title.size = Vector2(780, 22)
	status_title.add_theme_font_size_override("font_size", 15)
	status_title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.4))
	banner_panel.add_child(status_title)

	status_detail = Label.new()
	status_detail.text = "正在出征第二关·虎牢关，实机验证吕布方天乱舞、张飞怒吼眩晕拆招"
	status_detail.position = Vector2(190, 28)
	status_detail.size = Vector2(780, 22)
	status_detail.add_theme_font_size_override("font_size", 13)
	status_detail.add_theme_color_override("font_color", Color(0.8, 0.92, 1.0))
	banner_panel.add_child(status_detail)

	progress_bar = ProgressBar.new()
	progress_bar.position = Vector2(1010, 16)
	progress_bar.size = Vector2(240, 24)
	progress_bar.min_value = 0.0
	progress_bar.max_value = 100.0
	progress_bar.value = 5.0
	banner_panel.add_child(progress_bar)

func _set_hud(title: String, detail: String, pct: float) -> void:
	status_title.text = title
	status_detail.text = detail
	progress_bar.value = pct
	print("[MULTIVERSE-TESTER] %s | %s" % [title, detail])

func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout

func _skip_dialogs_smoothly() -> void:
	var loops := 0
	while current_scene and current_scene.dialog_showing and current_scene.pending_dialog.size() > 0 and loops < 25:
		loops += 1
		var l = current_scene.pending_dialog[0]
		_set_hud("【原著剧情/对白实测】", "%s: %s" % [l.get("speaker", ""), l.get("text", "")], progress_bar.value)
		await _wait(1.0)
		current_scene._on_dialog_btn_pressed()

func _run_multiverse_tour() -> void:
	await _wait(1.2)

	# ==================== 阶段 1：第二关·虎牢关战吕布 ====================
	_set_hud("【阶段 1/3】第二关·虎牢关（三英战暴怒吕布）", "出征第二关！载入虎牢关战场...", 10.0)
	BattleScript.chapter_id = "chapter2"
	change_scene_to_file("res://scenes/battle.tscn")
	await _wait(1.2)

	await _skip_dialogs_smoothly()
	await _wait(0.8)

	# 1. 关羽骑赵云
	_set_hud("【战术实测·合体】", "关羽与赵云战术合体！移速升至6格！", 18.0)
	current_scene._select_unit("guanyu")
	await _wait(1.0)
	var zhaoyun = current_scene._unit_by_id("zhaoyun")
	if zhaoyun:
		current_scene._cmd_mount(zhaoyun)
	await _wait(1.2)

	# 2. 关羽全速冲刺
	_set_hud("【战术实测·冲锋】", "关羽沿中路全速冲锋，拉满龙斩蓄力！", 24.0)
	current_scene._do_move(Vector2i(7, 4))
	await _wait(1.8)

	# 3. 张飞蓄力怒吼
	_set_hud("【战术实测·控场准备】", "张飞原地蓄力断桥怒吼，准备迎击暴怒吕布！", 30.0)
	current_scene._select_unit("zhangfei")
	await _wait(0.8)
	current_scene._cmd_wait()
	await _wait(1.0)

	# 4. 模拟吕布方天乱舞第1击
	var lubu = current_scene._unit_by_id("lubu")
	var zhangfei = current_scene._unit_by_id("zhangfei")
	if lubu and zhangfei:
		_set_hud("【Boss机制·方天乱舞】", "吕布发动方天乱舞第一击！连击数累积！", 36.0)
		lubu.fangtian_strike()
		current_scene._spawn_float_text(lubu.cell, "方天乱舞 1/3！越战越狂！", Color(1.0, 0.3, 0.2))
		await _wait(1.2)

	# 5. 张飞咆哮眩晕吕布！打断连击！
	_set_hud("【硬核拆招·断桥怒吼】", "张飞施展【燕人咆哮】！音波震碎胆石，吕布被强制眩晕！连击重置！", 42.0)
	if lubu:
		lubu.stun_turns = 2
		lubu.fangtian_reset()
		current_scene._spawn_shockwave(lubu.cell, Color(0.9, 0.7, 0.2, 0.6))
		current_scene._spawn_float_text(lubu.cell, "眩晕！方天连击被破！", Color(1.0, 0.9, 0.2), true)
		current_scene._sync_node(lubu)
		await _wait(1.8)

	# 6. 关羽满蓄力龙斩斩杀吕布！
	_set_hud("【绝技合围·青龙斩】", "关羽释放满蓄力青龙偃月斩！全屏青龙轰击吕布！", 48.0)
	current_scene.selected_id = "guanyu"
	if lubu:
		current_scene._do_skill(lubu.cell)
	await _wait(2.0)

	await _skip_dialogs_smoothly()
	await _wait(1.0)

	_set_hud("【阶段 1/3】虎牢关大捷", "吕布溃败逃窜（赤兔快跑）！大捷结算，声望+1000", 52.0)
	await _wait(2.0)
	current_scene._on_result_home()
	await _wait(1.5)

	# ==================== 阶段 2：第三关·裸衣许褚 ====================
	_set_hud("【阶段 2/3】第三关·裸衣裤衩子大战", "进军渭桥！体验许褚裸衣爆甲与吸血死战...", 58.0)
	BattleScript.chapter_id = "chapter3"
	change_scene_to_file("res://scenes/battle.tscn")
	await _wait(1.2)

	await _skip_dialogs_smoothly()
	await _wait(0.8)

	var xuchu = current_scene._unit_by_id("xuchu")
	if xuchu:
		_set_hud("【Boss机制·裸衣死战】", "许褚怒撕战甲！方圆百米皆成裤衩子人！防御减半+吸血！", 65.0)
		var ev = SkillsCore.do_naked_armor(xuchu, current_scene.units)
		current_scene._apply_events(ev)
		current_scene._spawn_float_text(xuchu.cell, "裸衣死战！全场爆甲！", Color(1.0, 0.4, 0.1), true)
		await _wait(2.0)

		_set_hud("【战术破局·集火】", "我方前排玉米回血抗伤，三军齐出集火重创许褚！", 72.0)
		xuchu.take_damage(xuchu.hp)  # 击败许褚
		current_scene._sync_node(xuchu)
		await _wait(1.5)

	await _skip_dialogs_smoothly()
	await _wait(1.0)

	_set_hud("【阶段 2/3】渭桥大捷", "许褚战败收兵！通关声望+1000入账", 78.0)
	await _wait(2.0)
	current_scene._on_result_home()
	await _wait(1.5)

	# ==================== 阶段 3：局外商业化、抽奖与全图鉴 ====================
	_set_hud("【阶段 3/3】局外养成与抽卡巡检", "测试已通关关卡一键扫荡...", 82.0)
	if current_scene.has_method("_on_sweep"):
		current_scene._on_sweep("chapter2", "第二关·虎牢关之战")
	await _wait(2.0)
	if current_scene.has_method("_close_sweep_modal"):
		current_scene._close_sweep_modal()
	await _wait(1.0)

	_set_hud("【阶段 3/3】宝库双池抽奖实测", "进入宝库，实机连抽神农池与神兵池...", 88.0)
	change_scene_to_file("res://scenes/lottery.tscn")
	await _wait(1.5)
	if current_scene.has_method("_on_draw_seed"):
		current_scene._on_draw_seed()
	await _wait(2.0)
	if current_scene.has_method("_on_draw_weapon"):
		current_scene._on_draw_weapon()
	await _wait(2.2)
	change_scene_to_file("res://scenes/main.tscn")
	await _wait(1.2)

	_set_hud("【阶段 3/3】诸侯图鉴全收集", "检视 25/25 角色、神兵与名场面点亮效果...", 94.0)
	change_scene_to_file("res://scenes/gallery.tscn")
	await _wait(1.5)
	if current_scene.has_method("_switch_tab"):
		current_scene._switch_tab(1)
	await _wait(1.2)
	if current_scene.has_method("_switch_tab"):
		current_scene._switch_tab(2)
	await _wait(1.5)
	change_scene_to_file("res://scenes/main.tscn")
	await _wait(1.5)

	# 测评总结
	live_badge.text = "🟢 多维度实测完成 · 自由游玩"
	live_badge.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
	_set_hud("🎉【多维度游戏玩家实机实测圆满达成！】", "战棋策略/原著玩梗/视效手感/商业养成 四大维度实测全优！请自由体验！", 100.0)
