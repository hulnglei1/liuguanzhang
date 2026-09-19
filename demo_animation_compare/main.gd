extends Control

@onready var s1_unit: Sprite2D = $Arena/LeftPanel/GuanYu_S1
@onready var s1_vfx: Sprite2D = $Arena/LeftPanel/VFX_Dragon
@onready var s1_dummy: Sprite2D = $Arena/LeftPanel/Dummy_S1
@onready var s1_label: Label = $Arena/LeftPanel/StatusLabel
@onready var s1_cutin: Control = $Arena/LeftPanel/PortraitCutin

@onready var s2_body: Sprite2D = $Arena/RightPanel/GuanYu_S2/Body
@onready var s2_shoulder: Node2D = $Arena/RightPanel/GuanYu_S2/Shoulder
@onready var s2_arm: Sprite2D = $Arena/RightPanel/GuanYu_S2/Shoulder/ArmBlade
@onready var s2_dummy: Sprite2D = $Arena/RightPanel/Dummy_S2
@onready var s2_label: Label = $Arena/RightPanel/StatusLabel

@onready var mode_label: Label = $UI/ModeLabel
@onready var portrait_modal: Control = $PortraitModal

var tex_s1_idle: Texture2D
var tex_s1_windup: Texture2D
var tex_s1_slash: Texture2D

var s1_orig_pos: Vector2
var s1_dummy_orig_pos: Vector2
var s2_dummy_orig_pos: Vector2

var is_animating: bool = false
var auto_timer: float = 0.0
var auto_step: int = 0

func _ready() -> void:
	tex_s1_idle = load("res://assets/s1_idle.png")
	tex_s1_windup = load("res://assets/s1_windup.png")
	tex_s1_slash = load("res://assets/s1_slash.png")
	
	s1_orig_pos = s1_unit.position
	s1_dummy_orig_pos = s1_dummy.position
	s2_dummy_orig_pos = s2_dummy.position
	
	s1_vfx.visible = false
	s1_cutin.visible = false
	portrait_modal.visible = false
	
	$UI/HBox/BtnIdle.pressed.connect(play_idle_demo)
	$UI/HBox/BtnNormalAtk.pressed.connect(play_normal_attack)
	$UI/HBox/BtnUltimateAtk.pressed.connect(play_ultimate_attack)
	$UI/HBox/BtnPortrait.pressed.connect(toggle_portrait_modal)
	$UI/HBox/BtnAuto.pressed.connect(toggle_auto)
	$PortraitModal/Panel/BtnClose.pressed.connect(func(): portrait_modal.visible = false)

func _process(delta: float) -> void:
	if $UI/HBox/BtnAuto.button_pressed and not is_animating and not portrait_modal.visible:
		auto_timer += delta
		if auto_timer > 3.0:
			auto_timer = 0.0
			auto_step = (auto_step + 1) % 4
			if auto_step == 0:
				play_idle_demo()
			elif auto_step == 1:
				play_normal_attack()
			elif auto_step == 2:
				play_ultimate_attack()
			else:
				toggle_portrait_modal()

# -------------------------------------------------------------
# 1. 待机状态演示 (Idle Breathing)
# -------------------------------------------------------------
func play_idle_demo() -> void:
	portrait_modal.visible = false
	mode_label.text = "【当前对比状态：待机呼吸对比】"
	s1_label.text = "方案1: 锁脚Shader呼吸 (双脚贴地绝对钉死，胸腹微动)"
	s2_label.text = "方案2: 骨骼微幅待机 (手持大刀保持自然角度)"
	
	s1_unit.material.set_shader_parameter("is_active", true)
	s1_unit.texture = tex_s1_idle
	s1_unit.position = s1_orig_pos
	s1_unit.rotation = 0
	s1_vfx.visible = false
	s1_cutin.visible = false
	s2_shoulder.rotation = 0

# -------------------------------------------------------------
# 2. 普通攻击对比 (Normal Attack)
# -------------------------------------------------------------
func play_normal_attack() -> void:
	if is_animating: return
	is_animating = true
	portrait_modal.visible = false
	
	mode_label.text = "【当前对比状态：普通攻击对比 (0.4秒极速结算)】"
	s1_label.text = "方案1: 切换发力姿态 + Tween冲砍位移 + 目标闪红受击"
	s2_label.text = "方案2: 骨骼手臂向后蓄力 -40° -> 顺时针圆弧劈砍 +60°"
	
	# === 方案1 Tween 冲砍 ===
	s1_unit.material.set_shader_parameter("is_active", false)
	s1_unit.texture = tex_s1_windup
	var tw1 = create_tween()
	# 0.08s 快速前冲突刺
	tw1.tween_property(s1_unit, "position:x", s1_orig_pos.x + 45.0, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw1.parallel().tween_property(s1_unit, "rotation_degrees", -8.0, 0.08)
	tw1.tween_callback(func():
		s1_unit.texture = tex_s1_slash
		_hit_dummy(s1_dummy, s1_dummy_orig_pos)
	)
	# 停留顿挫 0.12s
	tw1.tween_interval(0.12)
	# 0.15s 回弹
	tw1.tween_property(s1_unit, "position", s1_orig_pos, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tw1.parallel().tween_property(s1_unit, "rotation_degrees", 0.0, 0.15)
	tw1.tween_callback(func():
		s1_unit.texture = tex_s1_idle
		s1_unit.material.set_shader_parameter("is_active", true)
	)
	
	# === 方案2 骨骼劈砍 ===
	var tw2 = create_tween()
	tw2.tween_property(s2_shoulder, "rotation_degrees", -45.0, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw2.tween_property(s2_shoulder, "rotation_degrees", 65.0, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw2.tween_callback(func():
		_hit_dummy(s2_dummy, s2_dummy_orig_pos)
	)
	tw2.tween_interval(0.12)
	tw2.tween_property(s2_shoulder, "rotation_degrees", 0.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	
	tw1.finished.connect(func(): is_animating = false)

# -------------------------------------------------------------
# 3. 特效大招对比 (Ultimate Attack with Pure Dragon VFX & Cut-in)
# -------------------------------------------------------------
func play_ultimate_attack() -> void:
	if is_animating: return
	is_animating = true
	portrait_modal.visible = false
	
	mode_label.text = "【当前对比状态：必杀绝技《青龙出渊斩》· 纯独立特效层】"
	s1_label.text = "方案1: 武圣立绘特写 -> 突刺下斩 -> 纯青龙刀光引爆 (无任何人物重影！)"
	s2_label.text = "方案2: 骨骼大角度高举蓄力 -> 暴力砸地斩"
	
	# 1. 弹出暴击立绘横幅特写 (0.35s)
	s1_cutin.visible = true
	s1_cutin.modulate.a = 0.0
	s1_cutin.position.x = 20.0
	var cutin_tw = create_tween()
	cutin_tw.tween_property(s1_cutin, "modulate:a", 1.0, 0.06)
	cutin_tw.parallel().tween_property(s1_cutin, "position:x", 40.0, 0.08)
	cutin_tw.tween_interval(0.28)
	cutin_tw.tween_property(s1_cutin, "modulate:a", 0.0, 0.10)
	cutin_tw.tween_callback(func(): s1_cutin.visible = false)
	
	# === 方案1 绝技冲砍 ===
	s1_unit.material.set_shader_parameter("is_active", false)
	s1_unit.texture = tex_s1_windup
	var tw1 = create_tween()
	# 蓄力微退
	tw1.tween_property(s1_unit, "position:x", s1_orig_pos.x - 18.0, 0.15)
	# 爆冲下劈
	tw1.tween_property(s1_unit, "position:x", s1_orig_pos.x + 65.0, 0.10).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tw1.parallel().tween_property(s1_unit, "rotation_degrees", -14.0, 0.10)
	tw1.tween_callback(func():
		s1_unit.texture = tex_s1_slash
		# 播放纯青龙刀光特效（纯能量层，零人像肢体）
		s1_vfx.visible = true
		s1_vfx.modulate.a = 0.0
		s1_vfx.scale = Vector2(0.5, 0.5)
		var vfx_tw = create_tween()
		vfx_tw.tween_property(s1_vfx, "modulate:a", 1.0, 0.04)
		vfx_tw.parallel().tween_property(s1_vfx, "scale", Vector2(1.15, 1.15), 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		vfx_tw.tween_property(s1_vfx, "modulate:a", 0.0, 0.16)
		vfx_tw.tween_callback(func(): s1_vfx.visible = false)
		
		# 敌人受击大震荡
		_hit_dummy(s1_dummy, s1_dummy_orig_pos, 30.0)
	)
	tw1.tween_interval(0.40)
	tw1.tween_property(s1_unit, "position", s1_orig_pos, 0.22).set_trans(Tween.TRANS_QUAD)
	tw1.parallel().tween_property(s1_unit, "rotation_degrees", 0.0, 0.22)
	tw1.tween_callback(func():
		s1_unit.texture = tex_s1_idle
		s1_unit.material.set_shader_parameter("is_active", true)
	)
	
	# === 方案2 骨骼大招 ===
	var tw2 = create_tween()
	tw2.tween_property(s2_shoulder, "rotation_degrees", -70.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw2.tween_property(s2_shoulder, "rotation_degrees", 85.0, 0.10).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tw2.tween_callback(func():
		_hit_dummy(s2_dummy, s2_dummy_orig_pos, 20.0)
	)
	tw2.tween_interval(0.40)
	tw2.tween_property(s2_shoulder, "rotation_degrees", 0.0, 0.25)
	
	tw1.finished.connect(func(): is_animating = false)

# -------------------------------------------------------------
# 4. 查看高精立绘与全套资产卡
# -------------------------------------------------------------
func toggle_portrait_modal() -> void:
	portrait_modal.visible = not portrait_modal.visible
	if portrait_modal.visible:
		mode_label.text = "【当前视图：关羽高精立绘与全套母图资产规格】"
	else:
		mode_label.text = "【当前对比状态：待机呼吸对比】"

func _hit_dummy(dummy: Sprite2D, orig_p: Vector2, shake_dist: float = 12.0) -> void:
	dummy.modulate = Color(1.8, 0.3, 0.3, 1.0)
	var tw = create_tween()
	tw.tween_property(dummy, "position:x", orig_p.x + shake_dist, 0.04)
	tw.tween_property(dummy, "position:x", orig_p.x - shake_dist * 0.6, 0.04)
	tw.tween_property(dummy, "position:x", orig_p.x, 0.06)
	tw.parallel().tween_property(dummy, "modulate", Color.WHITE, 0.15)

func toggle_auto() -> void:
	pass
