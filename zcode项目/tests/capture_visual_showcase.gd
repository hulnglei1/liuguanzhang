extends SceneTree

const BattleScript := preload("res://scripts/battle.gd")
const SaveCore := preload("res://scripts/systems/save.gd")
const SkillsCore := preload("res://scripts/entities/skills.gd")

func _initialize() -> void:
	print("[CAPTURE] 启动全流程高清画质截图捕获...")
	var save := SaveCore.load_state()
	save["chapters"] = ["chapter1", "chapter2", "chapter3", "chapter4"]
	save["prestige"] = 8000
	SaveCore.save_state(save)
	change_scene_to_file("res://scenes/main.tscn")
	_run_captures()

func _wait(sec: float) -> void:
	await create_timer(sec).timeout

func _snap(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var vp = root.get_viewport()
	if vp:
		var tex = vp.get_texture()
		if tex:
			var img = tex.get_image()
			if img:
				var path := "res://screenshots/" + filename
				img.save_png(path)
				print("[SNAP] 成功截取: ", path)

func _run_captures() -> void:
	await _wait(1.5)
	# 1. 主城大厅
	await _snap("01_main_menu.png")

	# 2. 一键扫荡庆典弹窗
	if current_scene.has_method("_on_sweep"):
		current_scene._on_sweep("chapter1", "第一关·汜水关之战")
	await _wait(0.6)
	await _snap("02_sweep_modal.png")
	if current_scene.has_method("_close_sweep_modal"):
		current_scene._close_sweep_modal()
	await _wait(0.8)

	# 3. 宝库抽奖
	change_scene_to_file("res://scenes/lottery.tscn")
	await _wait(1.2)
	if current_scene.has_method("_on_draw_weapon"):
		current_scene._on_draw_weapon()
	await _wait(0.8)
	await _snap("03_lottery_weapon.png")

	# 4. 诸侯风云录全图鉴
	change_scene_to_file("res://scenes/gallery.tscn")
	await _wait(1.2)
	await _snap("04_gallery_overview.png")

	# 5. 第一关·汜水关战役
	BattleScript.chapter_id = "chapter1"
	change_scene_to_file("res://scenes/battle.tscn")
	await _wait(1.2)
	# 截对白
	await _snap("05_battle_dialog.png")
	# 跳过对白
	while current_scene and current_scene.dialog_showing and current_scene.pending_dialog.size() > 0:
		current_scene._on_dialog_btn_pressed()
	await _wait(0.6)

	# 关羽合体骑赵云 + 冲锋
	current_scene._select_unit("guanyu")
	var zy = current_scene._unit_by_id("zhaoyun")
	if zy:
		current_scene._cmd_mount(zy)
	current_scene._do_move(Vector2i(7, 5))
	await _wait(0.5)
	await _snap("06_mounted_charge.png")

	# 释放满蓄力青龙偃月斩
	current_scene.selected_id = "guanyu"
	current_scene._do_skill(Vector2i(10, 4))
	await _wait(0.3)
	await _snap("07_dragon_slash_vfx.png")
	await _wait(1.2)

	# 胜利结算
	while current_scene and current_scene.dialog_showing and current_scene.pending_dialog.size() > 0:
		current_scene._on_dialog_btn_pressed()
	await _wait(0.8)
	await _snap("08_victory_settlement.png")

	# 6. 第二关 吕布 vs 张飞咆哮眩晕
	BattleScript.chapter_id = "chapter2"
	change_scene_to_file("res://scenes/battle.tscn")
	await _wait(1.0)
	while current_scene and current_scene.dialog_showing and current_scene.pending_dialog.size() > 0:
		current_scene._on_dialog_btn_pressed()
	await _wait(0.5)
	var lubu = current_scene._unit_by_id("lubu")
	if lubu:
		lubu.stun_turns = 2
		current_scene._spawn_shockwave(lubu.cell, Color(0.9, 0.7, 0.2, 0.7))
		current_scene._spawn_float_text(lubu.cell, "眩晕！方天连击被破！", Color(1.0, 0.9, 0.2), true)
	await _wait(0.3)
	await _snap("09_zhangfei_roar_stun.png")

	print("==== ALL SCREENSHOTS CAPTURED SUCCESSFULLY! ====")
	quit(0)
