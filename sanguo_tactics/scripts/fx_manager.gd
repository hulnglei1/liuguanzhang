class_name FXManager
extends Node2D

var camera: Camera2D
var shake_intensity: float = 0.0
var shake_timer: float = 0.0

func _process(delta: float) -> void:
	if shake_timer > 0.0 and camera != null:
		shake_timer -= delta
		var offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake_intensity
		camera.offset = offset
		if shake_timer <= 0.0:
			camera.offset = Vector2.ZERO

func screen_shake(intensity: float = 8.0, duration: float = 0.35) -> void:
	shake_intensity = intensity
	shake_timer = duration

# 关羽千里青龙大招激光贯穿特效
func play_dragon_laser(from_pos: Vector2, to_pos: Vector2, charge: int) -> void:
	var outer_line = Line2D.new()
	var inner_line = Line2D.new()

	var base_width = 16.0
	var outer_color = Color(0.2, 0.9, 0.4, 0.8)
	var inner_color = Color(0.8, 1.0, 0.7, 0.95)

	if charge >= 10:
		# 天基大青龙核武级激光
		base_width = 38.0
		outer_color = Color(0.1, 1.0, 0.6, 0.9)
		inner_color = Color(1.0, 1.0, 0.4, 1.0)
		screen_shake(16.0, 0.6)
	elif charge >= 6:
		base_width = 24.0
		outer_color = Color(0.15, 0.85, 0.45, 0.85)
		inner_color = Color(0.9, 1.0, 0.8, 0.95)
		screen_shake(8.0, 0.4)
	elif charge >= 3:
		base_width = 14.0
		screen_shake(4.0, 0.25)

	outer_line.width = base_width
	outer_line.default_color = outer_color
	outer_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	outer_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	outer_line.add_point(from_pos)
	outer_line.add_point(to_pos)
	add_child(outer_line)

	inner_line.width = base_width * 0.4
	inner_line.default_color = inner_color
	inner_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	inner_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	inner_line.add_point(from_pos)
	inner_line.add_point(to_pos)
	add_child(inner_line)

	# 缓动收束淡出
	var tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(outer_line, "width", 0.0, 0.4).set_delay(0.2).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(inner_line, "width", 0.0, 0.35).set_delay(0.2).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(outer_line, "modulate:a", 0.0, 0.4).set_delay(0.2)
	tw.tween_property(inner_line, "modulate:a", 0.0, 0.35).set_delay(0.2)
	await tw.finished
	outer_line.queue_free()
	inner_line.queue_free()

# 张飞燕人咆哮冲击波光环
func play_sonic_shockwave(center_pos: Vector2, max_radius: float = 140.0) -> void:
	screen_shake(7.0, 0.35)
	var wave_node = Node2D.new()
	add_child(wave_node)
	wave_node.position = center_pos

	var tw = create_tween()
	var radius: float = 10.0
	var alpha: float = 0.9
	
	wave_node.draw.connect(func():
		wave_node.draw_arc(Vector2.ZERO, radius, 0, TAU, 36, Color(1.0, 0.8, 0.2, alpha), 4.0)
		wave_node.draw_arc(Vector2.ZERO, radius * 0.7, 0, TAU, 36, Color(1.0, 0.4, 0.1, alpha * 0.8), 2.5)
	)

	tw.set_parallel(true)
	tw.tween_method(func(r: float):
		radius = r
		wave_node.queue_redraw()
	, 10.0, max_radius, 0.4).set_trans(Tween.TRANS_CUBIC)
	tw.tween_method(func(a: float):
		alpha = a
	, 0.9, 0.0, 0.4).set_trans(Tween.TRANS_QUAD)

	await tw.finished
	wave_node.queue_free()

# 普攻利刃劈砍光效
func play_slash_fx(target_pos: Vector2, color: Color = Color(1.0, 0.9, 0.3)) -> void:
	var slash_line = Line2D.new()
	slash_line.width = 6.0
	slash_line.default_color = color
	slash_line.add_point(target_pos + Vector2(-24, -24))
	slash_line.add_point(target_pos + Vector2(24, 24))
	add_child(slash_line)

	var tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(slash_line, "width", 0.0, 0.2).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(slash_line, "modulate:a", 0.0, 0.2)
	await tw.finished
	slash_line.queue_free()

# 医疗治愈光柱
func play_heal_sparkle(target_pos: Vector2) -> void:
	var heal_node = Node2D.new()
	add_child(heal_node)
	heal_node.position = target_pos

	var y_offset: float = 0.0
	var alpha: float = 1.0

	heal_node.draw.connect(func():
		var c = Vector2(0, y_offset)
		heal_node.draw_rect(Rect2(c + Vector2(-4, -14), Vector2(8, 28)), Color(0.2, 1.0, 0.3, alpha))
		heal_node.draw_rect(Rect2(c + Vector2(-14, -4), Vector2(28, 8)), Color(0.2, 1.0, 0.3, alpha))
	)

	var tw = create_tween()
	tw.set_parallel(true)
	tw.tween_method(func(y: float):
		y_offset = y
		heal_node.queue_redraw()
	, 0.0, -35.0, 0.45).set_trans(Tween.TRANS_CUBIC)
	tw.tween_method(func(a: float):
		alpha = a
	, 1.0, 0.0, 0.45)

	await tw.finished
	heal_node.queue_free()
