extends Control

@onready var s1_unit: Sprite2D = $Arena/LeftPanel/GuanYu_S1
@onready var s1_vfx: Sprite2D = $Arena/LeftPanel/VFX_Dragon
@onready var s1_dummy: Sprite2D = $Arena/LeftPanel/Dummy_S1
@onready var s1_label: Label = $Arena/LeftPanel/StatusLabel

@onready var s2_body: Sprite2D = $Arena/RightPanel/GuanYu_S2/Body
@onready var s2_shoulder: Node2D = $Arena/RightPanel/GuanYu_S2/Shoulder
@onready var s2_arm: Sprite2D = $Arena/RightPanel/GuanYu_S2/Shoulder/ArmBlade
@onready var s2_dummy: Sprite2D = $Arena/RightPanel/Dummy_S2
@onready var s2_label: Label = $Arena/RightPanel/StatusLabel

@onready var mode_label: Label = $UI/ModeLabel

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
	
	$UI/HBox/BtnIdle.pressed.connect(play_idle_demo)
	$UI/HBox/BtnNormalAtk.pressed.connect(play_normal_attack)
	$UI/HBox/BtnUltimateAtk.pressed.connect(play_ultimate_attack)
	$UI/HBox/BtnAuto.pressed.connect(toggle_auto)

func _process(delta: float) -> void:
	if $UI/HBox/BtnAuto.button_pressed and not is_animating:
		auto_timer += delta
		if auto_timer > 2.5:
			auto_timer = 0.0
			auto_step = (auto_step + 1) % 3
			if auto_step == 0:
				play_idle_demo()
			elif auto_step == 1:
				play_normal_attack()
			else:
				play_ultimate_attack()

# -------------------------------------------------------------
# 1. 待机状态演示 (Idle Breathing)
# -------------------------------------------------------------
func play_idle_demo() -> void:
	mode_label.text = "【当前对比状态：待机呼吸对比】"
	s1_label.text = "方案1: 锁脚Shader呼吸\n(双脚与武器绝对钉死，胸腹微动)"
	s2_label.text = "方案2: 骨骼微幅待机\n(手持大刀保持自然角度)"
	
	s1_unit.texture = tex_s1_idle
	s1_unit.position = s1_orig_pos
	s1_unit.rotation = 0
	s1_vfx.visible = false
	s2_shoulder.rotation = 0

# -------------------------------------------------------------
# 2. 普通攻击对比 (Normal Attack)
# -------------------------------------------------------------
func play_normal_attack() -> void:
	if is_animating: return
	is_animating = true
	
	mode_label.text = "【当前对比状态：普通攻击对比 (0.4秒极速结算)】"
	s1_label.text = "方案1: 切换发力姿态 + Tween冲砍位移 + 目标闪红受击"
	s2_label.text = "方案2: 骨骼手臂向后蓄力 -40° -> 顺时针圆弧劈砍 +60°"
	
	# === 方案1 Tween 冲砍 ===
	s1_unit.texture = tex_s1_windup
	var tw1 = create_tween()
	# 0.08s 快速前冲突刺
	tw1.tween_property(s1_unit, "position:x", s1_orig_pos.x + 45.0, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw1.parallel().tween_property(s1_unit, "rotation_degrees", -8.0, 0.08)
	tw1.tween_callback(func():
		s1_unit.texture = tex_s1_slash
		# 敌人受击
		_hit_dummy(s1_dummy, s1_dummy_orig_pos)
	)
	# 停留顿挫 0.12s
	tw1.tween_interval(0.12)
	# 0.15s 回弹
	tw1.tween_property(s1_unit, "position", s1_orig_pos, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tw1.parallel().tween_property(s1_unit, "rotation_degrees", 0.0, 0.15)
	tw1.tween_callback(func():
		s1_unit.texture = tex_s1_idle
	)
	
	# === 方案2 骨骼关节旋转劈砍 ===
	var tw2 = create_tween()
	# 0.1s 后拉蓄力
	tw2.tween_property(s2_shoulder, "rotation_degrees", -45.0, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# 0.08s 顺时针重斩挥下
	tw2.tween_property(s2_shoulder, "rotation_degrees", 65.0, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw2.tween_callback(func():
		_hit_dummy(s2_dummy, s2_dummy_orig_pos)
	)
	# 停留 0.12s
	tw2.tween_interval(0.12)
	# 0.18s 恢复原位
	tw2.tween_property(s2_shoulder, "rotation_degrees", 0.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	
	tw1.finished.connect(func(): is_animating = false)

# -------------------------------------------------------------
# 3. 特效大招对比 (Ultimate Dragon Attack)
# -------------------------------------------------------------
func play_ultimate_attack() -> void:
	if is_animating: return
	is_animating = true
	
	mode_label.text = "【当前对比状态：必杀绝技《青龙出渊斩》特效对比】"
	s1_label.text = "方案1: 大魄力重斩下压 + 全屏青龙刀光在敌人身上引爆"
	s2_label.text = "方案2: 骨骼大角度高举蓄力 -> 暴力砸地斩"
	
	# === 方案1 特效斩 ===
	s1_unit.texture = tex_s1_windup
	var tw1 = create_tween()
	# 蓄力微退
	tw1.tween_property(s1_unit, "position:x", s1_orig_pos.x - 15.0, 0.12)
	# 爆冲下劈
	tw1.tween_property(s1_unit, "position:x", s1_orig_pos.x + 60.0, 0.10).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tw1.parallel().tween_property(s1_unit, "rotation_degrees", -15.0, 0.10)
	tw1.tween_callback(func():
		s1_unit.texture = tex_s1_slash
		# 播放独立青龙特效层
		s1_vfx.visible = true
		s1_vfx.modulate.a = 0.0
		s1_vfx.scale = Vector2(0.6, 0.6)
		var vfx_tw = create_tween()
		vfx_tw.tween_property(s1_vfx, "modulate:a", 1.0, 0.05)
		vfx_tw.parallel().tween_property(s1_vfx, "scale", Vector2(1.2, 1.2), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		vfx_tw.tween_property(s1_vfx, "modulate:a", 0.0, 0.15)
		vfx_tw.tween_callback(func(): s1_vfx.visible = false)
		
		# 敌人受击大震荡
		_hit_dummy(s1_dummy, s1_dummy_orig_pos, 25.0)
	)
	tw1.tween_interval(0.35)
	tw1.tween_property(s1_unit, "position", s1_orig_pos, 0.2).set_trans(Tween.TRANS_QUAD)
	tw1.parallel().tween_property(s1_unit, "rotation_degrees", 0.0, 0.2)
	tw1.tween_callback(func():
		s1_unit.texture = tex_s1_idle
	)
	
	# === 方案2 骨骼大招 ===
	var tw2 = create_tween()
	tw2.tween_property(s2_shoulder, "rotation_degrees", -70.0, 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw2.tween_property(s2_shoulder, "rotation_degrees", 85.0, 0.10).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tw2.tween_callback(func():
		_hit_dummy(s2_dummy, s2_dummy_orig_pos, 20.0)
	)
	tw2.tween_interval(0.35)
	tw2.tween_property(s2_shoulder, "rotation_degrees", 0.0, 0.25)
	
	tw1.finished.connect(func(): is_animating = false)

func _hit_dummy(dummy: Sprite2D, orig_p: Vector2, shake_dist: float = 12.0) -> void:
	dummy.modulate = Color(1.5, 0.3, 0.3, 1.0) # Flash red
	var tw = create_tween()
	tw.tween_property(dummy, "position:x", orig_p.x + shake_dist, 0.04)
	tw.tween_property(dummy, "position:x", orig_p.x - shake_dist * 0.5, 0.04)
	tw.tween_property(dummy, "position:x", orig_p.x, 0.06)
	tw.parallel().tween_property(dummy, "modulate", Color.WHITE, 0.15)

func toggle_auto() -> void:
	pass
