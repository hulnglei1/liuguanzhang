extends SceneTree
## 单位序列帧动画验证：idle 呼吸循环 + attack 播放 + 播完复位
## 运行：Godot_console.exe --headless --path zcode项目 --script res://tests/probe_anim.gd

const BattleScript := preload("res://scripts/battle.gd")
const SaveCore := preload("res://scripts/systems/save.gd")
const UnitArtLoaderCore := preload("res://scripts/ui/unit_art.gd")

var failed := 0


func _initialize() -> void:
	print("\n==== 一、序列帧加载器（无场景） ====")
	var sf: SpriteFrames = UnitArtLoaderCore.load_frames_for("guanyu")
	if sf == null:
		print("  ❌ load_frames_for('guanyu') 返回 null（是否已 --import？）")
		failed += 1
	else:
		var idle_n: int = sf.get_frame_count("idle")
		var atk_n: int = sf.get_frame_count("attack")
		print("  idle 帧数 = %d，attack 帧数 = %d" % [idle_n, atk_n])
		if idle_n >= 2:
			print("  ✅ 呼吸动画有序列帧（不再是单张静态图）")
		else:
			print("  ❌ idle 只有 %d 帧，呼吸动画不会动" % idle_n)
			failed += 1
		if atk_n >= 2:
			print("  ✅ 攻击动画有序列帧")
		else:
			print("  ❌ attack 只有 %d 帧" % atk_n)
			failed += 1
		print("  动画速度：idle %.1ffps，attack %.1ffps" % [
			sf.get_animation_speed("idle"), sf.get_animation_speed("attack")])

	# 没做动画的单位应回退（不能报错）
	# 主将/主角都已补序列帧；杂兵仍是静态图 → 应该回退成 null（走静态 sprite 分支）
	var sf_soldier: SpriteFrames = UnitArtLoaderCore.load_frames_for("taishan_1")
	print("  未做动画的杂兵（taishan_1）→ %s（应为 null，回退静态）" % ("null ✅" if sf_soldier == null else "非 null ⚠"))
	if sf_soldier != null:
		failed += 1

	_run_scene()


func _run_scene() -> void:
	BattleScript.chapter_id = "chapter2"
	change_scene_to_file("res://scenes/battle.tscn")
	await create_timer(2.5).timeout
	var b = current_scene
	if b.has_method("_on_dialog_skip_pressed"):
		b._on_dialog_skip_pressed()
	await create_timer(0.6).timeout

	print("\n==== 二、战场节点（真实场景） ====")
	var node: Node2D = b.unit_nodes.get("guanyu")
	if node == null:
		print("  ❌ 找不到关羽节点")
		failed += 1
		quit(1)
		return
	var anim: AnimatedSprite2D = node.get_node_or_null("ArtAnim")
	if anim == null:
		print("  ❌ 关羽节点上没有 ArtAnim（序列帧没接上）")
		failed += 1
		quit(1)
		return
	print("  ✅ 关羽使用 AnimatedSprite2D，当前动作：%s" % anim.animation)

	# 四位主角都应走序列帧（手绘 + 程序化都必须接上 ArtAnim）
	for uid in ["liubei", "zhangfei", "zhaoyun"]:
		var n2: Node2D = b.unit_nodes.get(uid) if b.unit_nodes.has(uid) else null
		if n2 == null:
			# 该关没上这个人，跳过（第 1 关只有刘关张赵，通常都在）
			print("  ⚠ %s 不在本关编成内，跳过" % uid)
			continue
		var a2: AnimatedSprite2D = n2.get_node_or_null("ArtAnim")
		if a2 == null:
			print("  ❌ %s 没有 ArtAnim（序列帧没接上，退回静态图了）" % uid)
			failed += 1
		else:
			print("  ✅ %s 使用序列帧，当前动作：%s（帧数 %d）" % [uid, a2.animation, a2.sprite_frames.get_frame_count("idle")])
	if anim.animation == "idle" and anim.is_playing():
		print("  ✅ 待机呼吸动画正在循环播放")
	else:
		print("  ⚠ 待机动画未在播放（animation=%s playing=%s）" % [anim.animation, str(anim.is_playing())])

	# 触发一次攻击，验证切到 attack 再回 idle
	var gy = b._unit_by_id("guanyu")
	b._play_unit_attack_anim("guanyu", Vector2i(gy.cell.x + 1, gy.cell.y))
	await create_timer(0.15).timeout
	print("  攻击触发后动作：%s（应为 attack）" % anim.animation)
	if anim.animation != "attack":
		print("  ❌ 攻击时没切到 attack 动画")
		failed += 1
	await create_timer(1.2).timeout
	print("  1.2 秒后动作：%s（应已复位为 idle）" % anim.animation)
	if anim.animation != "idle":
		print("  ❌ 攻击动画播完没有复位回 idle")
		failed += 1
	else:
		print("  ✅ 攻击动画播完自动复位 idle")

	print("\n==== 动画验证%s ====" % ("全部通过 ✅" if failed == 0 else "失败 %d 项 ❌" % failed))
	quit(1 if failed > 0 else 0)
