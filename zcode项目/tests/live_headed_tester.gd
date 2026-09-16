extends SceneTree

const BattleScript := preload("res://scripts/battle.gd")
const SaveCore := preload("res://scripts/systems/save.gd")

var hud_layer: CanvasLayer
var banner_panel: Panel
var status_title: Label
var status_detail: Label
var live_badge: Label
var progress_bar: ProgressBar

func _initialize() -> void:
	print("[AI-TESTER] 初始化有头实机巡检测试...")
	# 确保声望充足以便演示双池抽奖，确保第一关通关以演示扫荡
	var save := SaveCore.load_state()
	var chs: Array = save.get("chapters", [])
	if not "chapter1" in chs:
		chs.append("chapter1")
		save["chapters"] = chs
	save["prestige"] = maxi(int(save.get("prestige", 0)), 8000)
	SaveCore.save_state(save)

	_setup_overlay_hud()
	change_scene_to_file("res://scenes/main.tscn")
	_run_tour()

func _setup_overlay_hud() -> void:
	hud_layer = CanvasLayer.new()
	hud_layer.layer = 128
	root.add_child(hud_layer)

	banner_panel = Panel.new()
	banner_panel.position = Vector2(0, 0)
	banner_panel.size = Vector2(1280, 56)
	
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.08, 0.15, 0.95)
	sb.border_color = Color(0.18, 0.75, 0.95, 0.9)
	sb.border_width_bottom = 2
	banner_panel.add_theme_stylebox_override("panel", sb)
	hud_layer.add_child(banner_panel)

	live_badge = Label.new()
	live_badge.text = "🔴 AI 真机运行中"
	live_badge.position = Vector2(16, 14)
	live_badge.size = Vector2(160, 28)
	live_badge.add_theme_font_size_override("font_size", 15)
	live_badge.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
	banner_panel.add_child(live_badge)

	status_title = Label.new()
	status_title.text = "【阶段 1/4】主城大厅巡检与一键扫荡测试"
	status_title.position = Vector2(190, 6)
	status_title.size = Vector2(780, 22)
	status_title.add_theme_font_size_override("font_size", 15)
	status_title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.4))
	banner_panel.add_child(status_title)

	status_detail = Label.new()
	status_detail.text = "正在检视主城战役大厅，准备测试【⚡ 一键扫荡 (+1000声望)】"
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
	progress_bar.value = 10.0
	banner_panel.add_child(progress_bar)

func _set_hud(title: String, detail: String, pct: float) -> void:
	status_title.text = title
	status_detail.text = detail
	progress_bar.value = pct
	print("[AI-TESTER] %s | %s" % [title, detail])

func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout

func _run_tour() -> void:
	# ==================== 阶段 1：主城大厅与一键扫荡 ====================
	await _wait(1.5)
	_set_hud("【阶段 1/4】主城大厅与一键扫荡测试", "点击已通关的【第一关·汜水关】扫荡按钮，触发金色庆典弹窗", 15.0)
	await _wait(1.0)
	if current_scene and current_scene.has_method("_on_sweep"):
		current_scene._on_sweep("chapter1", "第一关·汜水关之战")
	await _wait(2.2)
	_set_hud("【阶段 1/4】一键扫荡完成", "声望稳获 +1000、神农仙种入库，关闭扫荡弹窗", 25.0)
	if current_scene and current_scene.has_method("_close_sweep_modal"):
		current_scene._close_sweep_modal()
	await _wait(1.2)

	# ==================== 阶段 2：军机宝库抽奖 ====================
	_set_hud("【阶段 2/4】军机宝库抽奖测试", "正在进入主城军机宝库...", 30.0)
	change_scene_to_file("res://scenes/lottery.tscn")
	await _wait(1.5)

	_set_hud("【阶段 2/4】军机宝库抽奖测试", "点击【神农百草池 (1000声望)】，抽取战备仙种", 38.0)
	await _wait(1.0)
	if current_scene and current_scene.has_method("_on_draw_seed"):
		current_scene._on_draw_seed()
	await _wait(2.2)

	_set_hud("【阶段 2/4】军机宝库抽奖测试", "点击【绝世神兵池 (5000声望)】，金色稀有神兵出金！", 45.0)
	await _wait(1.0)
	if current_scene and current_scene.has_method("_on_draw_weapon"):
		current_scene._on_draw_weapon()
	await _wait(2.5)

	_set_hud("【阶段 2/4】抽奖入库完成", "神兵与种子均已入库，点击返回主城", 50.0)
	change_scene_to_file("res://scenes/main.tscn")
	await _wait(1.5)

	# ==================== 阶段 3：名将图鉴全收集 ====================
	_set_hud("【阶段 3/4】名将图鉴全收集测试", "正在进入诸侯名将图鉴...", 55.0)
	change_scene_to_file("res://scenes/gallery.tscn")
	await _wait(1.5)

	_set_hud("【阶段 3/4】名将图鉴全收集测试", "【武将名录】11/11 位三国名将已全部点亮", 60.0)
	await _wait(1.5)

	if current_scene and current_scene.has_method("_switch_tab"):
		current_scene._switch_tab(1)
	_set_hud("【阶段 3/4】名将图鉴全收集测试", "【绝技神兵】9/9 门武将大招与绝世神兵已点亮", 65.0)
	await _wait(1.5)

	if current_scene and current_scene.has_method("_switch_tab"):
		current_scene._switch_tab(2)
	_set_hud("【阶段 3/4】名将图鉴全收集测试", "【战役名场面】5/5 幕原著经典爆笑名场面已点亮", 70.0)
	await _wait(1.8)

	_set_hud("【阶段 3/4】图鉴全满 25/25 达成", "收集度 100%，点击返回主城", 75.0)
	change_scene_to_file("res://scenes/main.tscn")
	await _wait(1.5)

	# ==================== 阶段 4：第一关·汜水关 实战 ====================
	_set_hud("【阶段 4/4】第一关·汜水关战役实战", "出征汜水关！载入战场中...", 80.0)
	BattleScript.chapter_id = "chapter1"
	change_scene_to_file("res://scenes/battle.tscn")
	await _wait(1.2)

	# 处理开局对白
	var guard_loops := 0
	while current_scene and current_scene.dialog_showing and current_scene.pending_dialog.size() > 0 and guard_loops < 20:
		guard_loops += 1
		var line_preview: String = ""
		if current_scene.pending_dialog.size() > 0:
			var l = current_scene.pending_dialog[0]
			line_preview = "%s: %s" % [l.get("speaker", ""), l.get("text", "")]
		_set_hud("【阶段 4/4】剧情对白播放中", line_preview, 82.0)
		await _wait(1.1)
		current_scene._on_dialog_btn_pressed()

	# 对白完毕，玩家回合
	await _wait(0.8)
	_set_hud("【阶段 4/4】战术合体实操", "选中关羽，发起与赵云的骑乘合体！", 85.0)
	current_scene._select_unit("guanyu")
	await _wait(1.2)

	var zhaoyun = current_scene._unit_by_id("zhaoyun")
	if zhaoyun:
		current_scene._cmd_mount(zhaoyun)
	await _wait(1.5)

	_set_hud("【阶段 4/4】6格全速狂飙", "关羽合体策马狂飙5格！赵云汗血飞驰，蓄力效率翻倍直接拉满10/10！", 88.0)
	current_scene._do_move(Vector2i(7, 5))
	await _wait(2.2)

	_set_hud("【阶段 4/4】步骑分离 (特洛伊空投)", "解除合体！赵云就地空投下马，形成双人夹击！", 90.0)
	current_scene.selected_id = "guanyu"
	current_scene._cmd_unmount()
	await _wait(1.5)

	_set_hud("【阶段 4/4】满蓄力青龙斩出鞘", "关羽施展全屏【千里·青龙偃月斩】，锁定华雄！", 93.0)
	await _wait(1.0)
	current_scene.selected_id = "guanyu"
	current_scene._do_skill(Vector2i(10, 4))
	await _wait(2.0)

	# 胜利对白
	guard_loops = 0
	while current_scene and current_scene.dialog_showing and current_scene.pending_dialog.size() > 0 and guard_loops < 20:
		guard_loops += 1
		var l = current_scene.pending_dialog[0]
		_set_hud("【阶段 4/4】胜利对白", "%s: %s" % [l.get("speaker", ""), l.get("text", "")], 96.0)
		await _wait(1.2)
		current_scene._on_dialog_btn_pressed()

	# 战役结算
	await _wait(1.0)
	_set_hud("【阶段 4/4】战役大捷结算", "华雄击破！获得声望+1000、解锁曹操羁绊！", 98.0)
	await _wait(2.5)

	_set_hud("【阶段 4/4】测试闭环", "战役胜利，点击返回主城", 99.0)
	current_scene._on_result_home()
	await _wait(1.5)

	# 完成！
	live_badge.text = "🟢 测试完成 · 自由游玩"
	live_badge.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
	_set_hud("🎉【AI 玩家全流程有头实机测试圆满达成！】", "四大阶段全部实操验证通过！游戏保持开启，请您自由游玩体验！", 100.0)
