class_name BattleVfx
extends RefCounted
## 战斗演出特效：千里青龙斩、常山·七进七出。
##
## 从 battle.gd 抽出来的第三块视觉代码（约 150 行）。
## 这里只负责"把特效画出来"，震屏/闪白这类**全屏级反馈**仍由 battle.gd 触发
##（它们属于战斗节奏，不属于单个特效）。

const CombatCore := preload("res://scripts/core/combat.gd")
const UnitViewCore := preload("res://scripts/ui/unit_view.gd")


## 千里·青龙斩：三层光柱（气流/气柱/白炽核）+ 沿路径的刃鳞 + 目标新星
static func spawn_dragon(parent: Node, start_px: Vector2, end_px: Vector2, charge: int) -> void:
	var dt: Dictionary = CombatCore.dragon_charge_tier(charge)
	var max_w: float = dt.get("width", 110.0)
	var dir := (end_px - start_px).normalized()
	var dist := start_px.distance_to(end_px)

	var beam_root := Node2D.new()
	beam_root.z_index = 40
	parent.add_child(beam_root)

	# 1. 外层青龙破空气流（满蓄力宽达 120px）
	var outer_line := Line2D.new()
	outer_line.points = PackedVector2Array([start_px, end_px])
	outer_line.width = max_w
	outer_line.default_color = Color(0.15, 0.95, 0.5, 0.45)
	outer_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	outer_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	beam_root.add_child(outer_line)

	# 2. 中层天青龙气巨柱
	var mid_line := Line2D.new()
	mid_line.points = PackedVector2Array([start_px, end_px])
	mid_line.width = max_w * 0.48
	mid_line.default_color = Color(0.35, 1.0, 0.7, 0.9)
	mid_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	mid_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	beam_root.add_child(mid_line)

	# 3. 内层白炽贯穿核
	var core_line := Line2D.new()
	core_line.points = PackedVector2Array([start_px, end_px])
	core_line.width = max(max_w * 0.16, 10.0)
	core_line.default_color = Color(1.0, 1.0, 0.95, 1.0)
	core_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	core_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	beam_root.add_child(core_line)

	# 4. 沿斩击路径排列的青龙刃鳞
	var step_count := int(dist / 28.0)
	for i in range(step_count):
		var t := float(i) / float(max(step_count, 1))
		var pos := start_px + dir * dist * t
		var scale_poly := Polygon2D.new()
		scale_poly.polygon = PackedVector2Array([
			Vector2(-14, -8), Vector2(14, 0), Vector2(-14, 8), Vector2(-8, 0)
		])
		scale_poly.position = pos
		scale_poly.rotation = dir.angle()
		scale_poly.color = Color(0.4, 1.0, 0.75, 0.75)
		beam_root.add_child(scale_poly)

	# 5. 目标爆破新星
	var nova := Polygon2D.new()
	nova.polygon = UnitViewCore.circle_polygon(38.0, 16)
	nova.position = end_px
	nova.color = Color(0.65, 1.0, 0.85, 0.9)
	beam_root.add_child(nova)

	# 6. 动画演播与渐隐
	var tw := parent.create_tween()
	tw.parallel().tween_property(outer_line, "width", 68.0, 0.35)
	tw.parallel().tween_property(mid_line, "width", 32.0, 0.35)
	tw.parallel().tween_property(nova, "scale", Vector2(2.4, 2.4), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(beam_root, "modulate:a", 0.0, 0.4).set_delay(0.12)
	tw.tween_callback(beam_root.queue_free)


## 常山·七进七出：交错极速银枪贯穿破阵


## 常山·七进七出：交错极速银枪贯穿破阵
static func spawn_seven_dash(parent: Node, start_px: Vector2, target_px: Vector2, weaves: int, on_impact: Callable) -> void:
	var dash_root := Node2D.new()
	dash_root.z_index = 45
	parent.add_child(dash_root)

	var count: int = clampi(weaves, 3, 7)
	for i in range(count):
		var delay: float = float(i) * 0.05
		var angle_offset: float = (float(i) - float(count) / 2.0) * 0.42
		var base_dir := (target_px - start_px).normalized()
		if base_dir.length_squared() < 0.1:
			base_dir = Vector2.RIGHT
		var slash_dir := base_dir.rotated(angle_offset)
		var p1 := target_px - slash_dir * 45.0
		var p2 := target_px + slash_dir * 52.0

		var spear_line := Line2D.new()
		spear_line.points = PackedVector2Array([p1, p1])
		spear_line.width = 10.0 if i == count - 1 else 6.0
		spear_line.default_color = Color(0.92, 0.97, 1.0, 0.95) if (i % 2 == 0) else Color(0.35, 0.8, 1.0, 0.9)
		spear_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		spear_line.end_cap_mode = Line2D.LINE_CAP_ROUND
		spear_line.modulate.a = 0.0
		dash_root.add_child(spear_line)

		var head := Polygon2D.new()
		head.polygon = PackedVector2Array([
			Vector2(14, 0), Vector2(-7, -5), Vector2(-2, 0), Vector2(-7, 5)
		])
		head.color = Color(1.0, 1.0, 1.0, 0.95)
		head.position = p1
		head.rotation = slash_dir.angle()
		head.modulate.a = 0.0
		dash_root.add_child(head)

		var tw := parent.create_tween()
		tw.tween_interval(delay)
		tw.tween_callback(func():
			spear_line.modulate.a = 1.0
			head.modulate.a = 1.0
		)
		tw.parallel().tween_method(func(val: Vector2):
			spear_line.points = PackedVector2Array([p1, val])
			head.position = val
		, p1, p2, 0.08)
		tw.parallel().tween_property(spear_line, "width", 1.5, 0.12).set_delay(0.04)
		tw.parallel().tween_property(spear_line, "modulate:a", 0.0, 0.15).set_delay(0.07)
		tw.parallel().tween_property(head, "modulate:a", 0.0, 0.15).set_delay(0.07)

	var finish_delay: float = float(count) * 0.05
	var shock := Polygon2D.new()
	shock.polygon = UnitViewCore.circle_polygon(34.0, 16)
	shock.position = target_px
	shock.color = Color(0.65, 0.88, 1.0, 0.85)
	shock.scale = Vector2(0.2, 0.2)
	shock.modulate.a = 0.0
	dash_root.add_child(shock)

	var tw_fin := parent.create_tween()
	tw_fin.tween_interval(finish_delay)
	tw_fin.tween_callback(func():
		shock.modulate.a = 0.85
		# 震屏等"枪尖命中"这一刻（不是出手就震）→ 由 battle.gd 注入回调
		if on_impact.is_valid():
			on_impact.call(7.0)
	)
	tw_fin.tween_property(shock, "scale", Vector2(2.0, 2.0), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw_fin.parallel().tween_property(shock, "modulate:a", 0.0, 0.22)
	tw_fin.tween_property(dash_root, "modulate:a", 0.0, 0.18)
	tw_fin.tween_callback(dash_root.queue_free)


## 音波圈：从中心扩散的多层圆环（咆哮/范围技）
