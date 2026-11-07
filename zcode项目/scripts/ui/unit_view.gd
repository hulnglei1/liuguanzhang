extends RefCounted
## 单位视觉层（Unit View）—— 动画与特效的唯一归属地
##
## 【所有权约定】
##   本文件 = 动画侧（由负责动画的 agent 维护）
##   battle.gd = 机制侧（由负责战斗逻辑的 agent 维护）
##   机制侧只调用下面这几个 static 函数，不关心实现；动画侧不碰 battle.gd。
##   两边永远不会改到同一份文件 → 可以真正并行开发。
##
## 【设计依据】战棋黄金法则（《火焰纹章》《曹操传》《暗黑地牢》模式）
##   1. 美术只出 1 张极品母图，本体不做复杂多帧画皮
##   2. 待机 = 锁脚呼吸（Shader，纯 GPU 驱动，零美术成本，绝对不晃）
##   3. 攻击 = 代码驱动：极速前冲 + 微前倾下压 + 顿挫回弹
##   4. 挥刀的震撼感全部交给"独立全屏特效层"（见 ensure_fx_layer）
##
## 【硬约束 — 违反会导致"滑步/位置脱节"这类经典战棋 bug】
##   * 不要把 node.position 的"落点"改掉。落点由 battle.gd 按格子计算，
##     冲刺位移只能作为临时偏移，**动画结束必须回到原位**
##   * 动画里不得改动任何单位数值（HP / 坐标 / 状态 / acted）
##   * 缺图必须安全回退（build_art 返回 false），不得报错、不得留空白节点
##   * 本文件不 preload battle.gd（避免循环依赖）

const UnitArtLoaderCore := preload("res://scripts/ui/unit_art.gd")

## 贴图高度 = 格子边长 × 该系数
const ART_HEIGHT_RATIO := 1.35
## 贴图相对格子中心的 y 偏移（让脚底压在地面上）
const ART_Y_OFFSET := 6.0
## 冲刺位移距离（像素）
const ATTACK_LUNGE_PX := 14.0

## 本层挂载的全屏特效层节点名
const FX_LAYER_NAME := "UnitFxLayer"


## ---------- 一、外观构建 ----------

const UNIT_SHADER := preload("res://assets/shaders/unit_shader.gdshader")

## 给单位挂"描边光"材质：深色角色在深绿棋盘上会糊掉，靠一圈暖色轮廓把剪影拉出来。
## 只作用于有贴图的单位，不改任何美术资源。
## breath_amp_px > 0 时同时启用锁脚呼吸（静态贴图用；有序列帧的单位不需要）
static func _apply_outline(canvas: CanvasItem, breath_amp_px: float = 0.0) -> void:
	if canvas == null:
		return
	# 无头（Dummy 渲染器）下自定义 shader 会拖住进程退出 → 自动化测试里直接跳过
	if DisplayServer.get_name() == "headless":
		return
	var mat := ShaderMaterial.new()
	mat.shader = UNIT_SHADER
	mat.set_shader_parameter("rim_color", Color(1.0, 0.94, 0.78, 1.0))
	mat.set_shader_parameter("outline_px", 5.0)
	mat.set_shader_parameter("strength", 0.5)
	mat.set_shader_parameter("breath_active", breath_amp_px > 0.0)
	mat.set_shader_parameter("breath_amp", breath_amp_px)
	mat.set_shader_parameter("breath_speed", 2.0)
	canvas.material = mat


## 给单位节点挂上贴图 / 序列帧动画。
## 返回 true = 已用贴图（调用方应隐藏色块底盘与书法字）；false = 无贴图，走色块回退。
static func build_art(node: Node2D, unit_id: String, tile: float) -> bool:
	var art_frames: SpriteFrames = UnitArtLoaderCore.load_frames_for(unit_id)
	var art = UnitArtLoaderCore.load_for(unit_id)

	if art_frames != null:
		var anim_spr := AnimatedSprite2D.new()
		anim_spr.name = "ArtAnim"
		anim_spr.sprite_frames = art_frames
		anim_spr.animation = "idle"
		anim_spr.play("idle")
		anim_spr.centered = true
		var ref_tex: Texture2D = null
		if art is Texture2D:
			ref_tex = art
		else:
			ref_tex = art_frames.get_frame_texture("idle", 0)
		var tex_h: float = float(ref_tex.get_height()) if ref_tex != null else 192.0
		var target_h: float = tile * ART_HEIGHT_RATIO
		var s: float = target_h / maxf(1.0, tex_h)
		anim_spr.scale = Vector2(s, s)
		anim_spr.position = Vector2(0, -target_h * 0.5 + ART_Y_OFFSET)
		_apply_outline(anim_spr, 0.0)   # 序列帧本身就在动，不再叠 shader 呼吸
		node.add_child(anim_spr)
		apply_idle_breath(anim_spr)
		return true

	if art is Texture2D:
		var spr := Sprite2D.new()
		spr.name = "Art"
		spr.texture = art
		spr.centered = true
		var target_h2: float = tile * ART_HEIGHT_RATIO
		var s2: float = target_h2 / float(maxi(1, art.get_height()))
		spr.scale = Vector2(s2, s2)
		spr.position = Vector2(0, -target_h2 * 0.5 + ART_Y_OFFSET)
		var breath_px: float = float(maxi(1, art.get_height())) * 0.018
		_apply_outline(spr, breath_px)
		node.add_child(spr)
		apply_idle_breath(spr)
		return true

	return false


## ---------- 二、待机呼吸 ----------

## 待机呼吸：**锁脚**——脚底牢牢钉在格子上，上半身轻微起伏，零漂移。
##
## TODO(动画侧)：目前是空实现，保持"静态贴图"的既有表现。
## 推荐实现：Shader 顶点位移（assets/shaders/unit_breath.gdshader），
##   纯 GPU、零 CPU 开销，且天然不会产生"格子漂移"。
## 备选：Tween 缩放 sprite.scale.y（注意要以脚底为轴心，否则会上下漂）。
static func apply_idle_breath(sprite: Node2D) -> void:
	# 呼吸已并入 unit_shader（vertex 阶段），这里不再单独挂 material。
	# 保留函数是为了不破坏 battle.gd 的既有调用。
	pass


## ---------- 三、攻击演出 ----------

## 攻击演出：面朝目标 +（若有）播放攻击序列帧 + 冲刺顿挫位移。
## node 的最终位置一定会回到调用时的位置（落点由 battle.gd 掌管）。
static func play_attack(node: Node2D, target_px: Vector2) -> void:
	if node == null or not is_instance_valid(node):
		return
	var from_pos: Vector2 = node.position
	var dir_x: float = target_px.x - from_pos.x

	# 1. 朝向
	var anim_spr: AnimatedSprite2D = node.get_node_or_null("ArtAnim")
	var static_spr: Sprite2D = node.get_node_or_null("Art")
	if anim_spr != null:
		if absf(dir_x) > 2.0:
			anim_spr.flip_h = dir_x < 0.0
		# 有攻击帧就播，播完回 idle（原著"呼吸"由 idle 序列帧/Shader 负责）
		if anim_spr.sprite_frames and anim_spr.sprite_frames.has_animation("attack"):
			anim_spr.play("attack")
			anim_spr.animation_finished.connect(func():
				if is_instance_valid(anim_spr):
					anim_spr.play("idle")
			, CONNECT_ONE_SHOT)
	elif static_spr != null:
		if absf(dir_x) > 2.0:
			static_spr.flip_h = dir_x < 0.0

	# 2. 前冲 + 顿挫回弹（战棋打击感的最小可靠实现）
	#    节奏要让人"看得见"：起手 → 冲到最前 → 停一拍（顿挫）→ 收回。
	#    之前是 0.09s 冲 / 0.14s 回，总共 0.23 秒，4 帧动画还没看清就打完了。
	var offset: Vector2 = (target_px - from_pos).normalized() * ATTACK_LUNGE_PX
	var tw: Tween = node.create_tween()
	tw.tween_property(node, "position", from_pos + offset, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.07)          # 顿挫：在最前点停一拍，刀锋"咬住"目标
	tw.tween_property(node, "position", from_pos, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.finished.connect(func():
		# 兜底归位：防止 Tween 被打断后单位停在半路（滑步 bug 的常见来源）
		if is_instance_valid(node):
			node.position = from_pos
	)


## ---------- 三点五、飞行道具：箭矢 ----------

## 创建一支飞行中的箭（公孙瓒·白马回旋飞弹），默认朝 +X，按飞行方向自动旋转。
##
## 用户反馈"箭头不太像" —— 原来只是一个 emoji 标签（🎯🏹）。
## 这里改成几何图形：外层青光（拖尾感）+ 两片尾羽 + 箭杆 + 箭头 + 高光点。
static func create_arrow_node(from_px: Vector2, to_px: Vector2) -> Node2D:
	var node := Node2D.new()
	node.name = "Arrow"
	node.position = from_px
	node.z_index = 70
	var dir: Vector2 = to_px - from_px
	if dir.length() > 0.01:
		node.rotation = dir.angle()

	# 外层青光（拖尾/破空感）
	var glow := Polygon2D.new()
	glow.polygon = PackedVector2Array([
		Vector2(-22, -1.2), Vector2(-6, -7.0), Vector2(16, -8.0),
		Vector2(22, 0), Vector2(16, 8.0), Vector2(-6, 7.0), Vector2(-22, 1.2),
	])
	glow.color = Color(0.35, 0.8, 1.0, 0.22)
	node.add_child(glow)

	# 两片尾羽
	for sign_y in [-1.0, 1.0]:
		var feather := Polygon2D.new()
		feather.polygon = PackedVector2Array([
			Vector2(-18, 0), Vector2(-10, 6.0 * sign_y), Vector2(-13, 0.8 * sign_y),
		])
		feather.color = Color(0.32, 0.7, 0.95)
		node.add_child(feather)

	# 箭杆
	var shaft := Polygon2D.new()
	shaft.polygon = PackedVector2Array([
		Vector2(-16, -1.5), Vector2(7, -1.5), Vector2(7, 1.5), Vector2(-16, 1.5),
	])
	shaft.color = Color(0.84, 0.89, 0.94)
	node.add_child(shaft)

	# 箭头
	var head := Polygon2D.new()
	head.polygon = PackedVector2Array([
		Vector2(20, 0), Vector2(6, -6.5), Vector2(6, 6.5),
	])
	head.color = Color(0.95, 0.99, 1.0)
	node.add_child(head)

	# 箭头高光（深色战场上更容易看清）
	var tip := Polygon2D.new()
	tip.polygon = PackedVector2Array([Vector2(13, 0), Vector2(3, -2.4), Vector2(3, 2.4)])
	tip.color = Color(0.55, 0.95, 1.0)
	node.add_child(tip)

	return node


## 让节点朝向某个像素位置（箭矢飞行中转向用）
static func face_to(node: Node2D, target_px: Vector2) -> void:
	if node == null or not is_instance_valid(node):
		return
	var dir: Vector2 = target_px - node.position
	if dir.length() > 0.01:
		node.rotation = dir.angle()


## ---------- 四、全屏特效层 ----------
## 确保存在"独立全屏特效层"。刀光/斩击/爆发都挂到这里，
## 与单位节点解耦——单位移动/死亡/重生都不会影响特效，反之亦然。
## 调用一次即可（重复调用返回同一个节点）。
static func ensure_fx_layer(root: Node) -> Node2D:
	var layer: Node2D = root.get_node_or_null(FX_LAYER_NAME)
	if layer == null:
		layer = Node2D.new()
		layer.name = FX_LAYER_NAME
		layer.z_index = 70
		root.add_child(layer)
	return layer
