class_name Unit
extends Node2D

const UnitData = preload("res://scripts/unit_data.gd")
const GridManager = preload("res://scripts/grid_manager.gd")

signal unit_clicked(unit: Unit)
signal hp_changed(unit: Unit, current: int, max_val: int)
signal dragon_charge_changed(unit: Unit, charge: int)
signal horse_stamina_changed(unit: Unit, stamina: int)

@export var data: Resource

@onready var avatar_label: Label = $AvatarLabel
@onready var name_label: Label = $NameLabel
@onready var status_label: Label = $StatusLabel
@onready var floating_container: Node2D = $FloatingContainer

var is_selected: bool = false
var is_hovered: bool = false
var anim_time: float = 0.0

func _ready() -> void:
	if data == null:
		data = UnitData.new()
	update_visuals()

func _process(delta: float) -> void:
	anim_time += delta * 5.0
	queue_redraw()
	_update_status_display()

func init_unit(unit_data: UnitData, start_pos: Vector2, grid_pos: Vector2i) -> void:
	data = unit_data
	data.grid_pos = grid_pos
	position = start_pos
	update_visuals()

func update_visuals() -> void:
	if data == null:
		return
	if avatar_label:
		avatar_label.text = data.avatar_char
	if name_label:
		name_label.text = data.unit_name
		if data.faction == "enemy":
			name_label.modulate = Color(1.0, 0.5, 0.5)
		else:
			name_label.modulate = Color(0.8, 1.0, 0.8)
	queue_redraw()

func _update_status_display() -> void:
	if data == null or status_label == null:
		return
	
	var status_texts: Array[String] = []
	if data.is_stunned:
		status_texts.append("💫眩晕")
	if data.is_taunting:
		status_texts.append("🛡️挑衅")
	if data.is_piggybacking:
		status_texts.append("🚀关赵巡洋舰")
	if data.id == "guanyu":
		if data.is_exhausted:
			status_texts.append("🐴罢工!")
		elif data.dragon_charge >= 10:
			status_texts.append("⚡天基大青龙!")
		elif data.dragon_charge >= 6:
			status_texts.append("🐉高铁巨龙")
		elif data.dragon_charge >= 3:
			status_texts.append("🐉水管青龙")

	if status_texts.size() > 0:
		status_label.text = " ".join(status_texts)
		status_label.visible = true
	else:
		status_label.visible = false

func _draw() -> void:
	if data == null:
		return

	var radius: float = 24.0
	var center: Vector2 = Vector2.ZERO

	# 1. 关羽神级青龙光环特效 (根据蓄力层数动态爆发)
	if data.id == "guanyu" and data.dragon_charge > 0:
		_draw_dragon_aura(center)

	# 2. 张飞挑衅护卫金钟罩
	if data.is_taunting:
		var shield_pulse = 1.0 + 0.1 * sin(anim_time)
		draw_arc(center, radius + 8.0 * shield_pulse, 0, TAU, 32, Color(1.0, 0.8, 0.2, 0.6), 3.0)

	# 3. 武将底座圆盘
	var base_col = data.color
	if data.has_acted:
		base_col = base_col.lerp(Color(0.2, 0.2, 0.2), 0.6)
	draw_circle(center, radius, base_col)

	# 4. 武将外边框
	var border_col = Color.WHITE
	var border_width = 2.0
	if is_selected:
		border_col = Color(1.0, 0.85, 0.2, 0.9 + 0.1 * sin(anim_time * 2.0))
		border_width = 4.0
	elif data.faction == "enemy":
		border_col = Color(0.9, 0.2, 0.2, 0.9)
	elif is_hovered:
		border_col = Color(0.5, 0.9, 1.0, 0.9)
	draw_arc(center, radius, 0, TAU, 32, border_col, border_width)

	# 5. 生命值血条 (HP Bar)
	var bar_width: float = 46.0
	var bar_height: float = 6.0
	var bar_pos = Vector2(-bar_width * 0.5, 26.0)
	
	# 血条底槽
	draw_rect(Rect2(bar_pos, Vector2(bar_width, bar_height)), Color(0.1, 0.1, 0.1, 0.85))
	
	# 当前血量填充
	var hp_ratio = clamp(float(data.current_hp) / float(data.max_hp), 0.0, 1.0)
	var hp_fill_color = Color(0.2, 0.85, 0.3) if data.faction == "player" else Color(0.9, 0.25, 0.25)
	if hp_ratio < 0.3:
		hp_fill_color = Color(1.0, 0.2, 0.1) # 垂危红
	draw_rect(Rect2(bar_pos + Vector2(1, 1), Vector2((bar_width - 2) * hp_ratio, bar_height - 2)), hp_fill_color)
	draw_rect(Rect2(bar_pos, Vector2(bar_width, bar_height)), Color(0.3, 0.3, 0.3, 0.8), false, 1.0)

	# 6. 特殊体力/怒气条
	if data.id == "guanyu":
		# 马哥体力槽
		var sta_pos = Vector2(-bar_width * 0.5, 34.0)
		draw_rect(Rect2(sta_pos, Vector2(bar_width, 4.0)), Color(0.1, 0.1, 0.1, 0.8))
		var sta_ratio = clamp(float(data.horse_stamina) / float(data.max_horse_stamina), 0.0, 1.0)
		var sta_color = Color(0.95, 0.65, 0.15)
		if data.horse_stamina <= 20:
			sta_color = Color(1.0, 0.2, 0.2) # 罢工警报红
		draw_rect(Rect2(sta_pos + Vector2(1, 1), Vector2((bar_width - 2) * sta_ratio, 2.0)), sta_color)
	elif data.id == "zhangfei":
		# 张飞怒气条
		var rage_pos = Vector2(-bar_width * 0.5, 34.0)
		draw_rect(Rect2(rage_pos, Vector2(bar_width, 4.0)), Color(0.1, 0.1, 0.1, 0.8))
		var rage_ratio = clamp(float(data.rage) / 100.0, 0.0, 1.0)
		draw_rect(Rect2(rage_pos + Vector2(1, 1), Vector2((bar_width - 2) * rage_ratio, 2.0)), Color(0.9, 0.4, 0.1))

	# 7. 眩晕头顶金星
	if data.is_stunned:
		for i in range(3):
			var star_angle = anim_time * 2.0 + i * (TAU / 3.0)
			var star_pos = center + Vector2(cos(star_angle) * 20.0, sin(star_angle) * 8.0 - 24.0)
			draw_circle(star_pos, 3.0, Color(1.0, 0.9, 0.2))

	# 8. 本回合已行动阴影遮蔽
	if data.has_acted:
		draw_circle(center, radius, Color(0.0, 0.0, 0.0, 0.45))

func _draw_dragon_aura(center: Vector2) -> void:
	var charge = data.dragon_charge
	if charge >= 10:
		# 天基大青龙神力光环 (全屏贯穿暴烈金碧光环)
		var pulse = 1.0 + 0.18 * sin(anim_time * 3.0)
		draw_arc(center, 36.0 * pulse, 0, TAU, 32, Color(0.2, 1.0, 0.5, 0.9), 4.0)
		draw_arc(center, 44.0 * pulse, 0, TAU, 32, Color(1.0, 0.9, 0.2, 0.7), 2.0)
		# 辐射电弧
		for i in range(6):
			var a = anim_time * 1.5 + i * (TAU / 6.0)
			var p1 = center + Vector2(cos(a), sin(a)) * 26.0
			var p2 = center + Vector2(cos(a), sin(a)) * 48.0 * pulse
			draw_line(p1, p2, Color(0.4, 1.0, 0.8, 0.85), 2.0)
	elif charge >= 6:
		# 高铁巨龙光环
		var pulse = 1.0 + 0.12 * sin(anim_time * 2.0)
		draw_arc(center, 32.0 * pulse, 0, TAU, 32, Color(0.2, 0.9, 0.4, 0.8), 3.0)
		draw_arc(center, 38.0 * pulse, 0, TAU, 32, Color(0.1, 0.7, 0.9, 0.6), 2.0)
	elif charge >= 3:
		# 水管粗青龙
		var pulse = 1.0 + 0.08 * sin(anim_time * 1.5)
		draw_arc(center, 28.0 * pulse, 0, TAU, 32, Color(0.2, 0.8, 0.3, 0.7), 2.0)
	else:
		# 竹叶青
		draw_arc(center, 26.0, 0, TAU, 24, Color(0.3, 0.7, 0.3, 0.4), 1.5)

# 平滑网格移动函数
func move_along_path(path: Array[Vector2i], grid_mgr: GridManager, on_step_callback: Callable = Callable()) -> void:
	if path.size() <= 1:
		return

	# 从当前格逐步走向目标格
	for i in range(1, path.size()):
		var target_grid_pos = path[i]
		var target_world_pos = grid_mgr.grid_to_world_center(target_grid_pos)
		
		# 平滑插值动画
		var tween = create_tween()
		tween.tween_property(self, "position", target_world_pos, 0.12).set_trans(Tween.TRANS_SINE)
		await tween.finished

		data.grid_pos = target_grid_pos

		# 关羽步数累加与马哥体力扣减
		if data.id == "guanyu":
			_handle_guanyu_step(grid_mgr, target_grid_pos)
			if data.is_exhausted:
				spawn_floating_text("🐴 马哥：跑不动了！直接罢工！", Color(1.0, 0.3, 0.3))
				break # 战马体力透支，原地停步！

		if on_step_callback.is_valid():
			on_step_callback.call(target_grid_pos)

	queue_redraw()

func _handle_guanyu_step(grid_mgr: GridManager, cell: Vector2i) -> void:
	if data.is_piggybacking:
		# 赵云合体状态：无视战马体力！全速蓄力！
		if grid_mgr.is_racetrack(cell):
			data.dragon_charge += 2
			spawn_floating_text("+2 龙气 (高铁合体飙车!)", Color(0.2, 1.0, 0.9))
		else:
			data.dragon_charge += 1
			spawn_floating_text("+1 龙气", Color(0.2, 1.0, 0.6))
		dragon_charge_changed.emit(self, data.dragon_charge)
		return

	# 常规战马状态
	data.horse_stamina = max(0, data.horse_stamina - 10)
	horse_stamina_changed.emit(self, data.horse_stamina)

	if grid_mgr.is_racetrack(cell):
		data.dragon_charge += 2
		spawn_floating_text("+2 龙气 (跑马道疾驰!)", Color(0.2, 1.0, 0.4))
	else:
		data.dragon_charge += 1
		spawn_floating_text("+1 龙气", Color(0.3, 0.9, 0.3))
	dragon_charge_changed.emit(self, data.dragon_charge)

	# 检查马哥罢工阈值
	if data.horse_stamina <= 20 and not data.is_exhausted:
		data.is_exhausted = true

func take_damage(amount: int) -> int:
	var actual_damage = max(1, amount - data.def_val)
	if data.is_taunting:
		actual_damage = int(actual_damage * 0.5) # 挑衅减伤 50%

	data.current_hp = max(0, data.current_hp - actual_damage)
	hp_changed.emit(self, data.current_hp, data.max_hp)

	spawn_floating_text("-%d" % actual_damage, Color(1.0, 0.25, 0.25))

	# 受击红闪和微震动动画
	var tw = create_tween()
	tw.tween_property(self, "modulate", Color(2.0, 0.4, 0.4), 0.06)
	tw.tween_property(self, "modulate", Color.WHITE, 0.1)

	if data.current_hp <= 0:
		_on_death()

	queue_redraw()
	return actual_damage

func heal(amount: int) -> void:
	data.current_hp = min(data.max_hp, data.current_hp + amount)
	data.is_stunned = false
	hp_changed.emit(self, data.current_hp, data.max_hp)
	spawn_floating_text("+%d HP (已解晕)" % amount, Color(0.2, 1.0, 0.3))
	queue_redraw()

func spawn_floating_text(text: String, col: Color = Color.WHITE) -> void:
	var lbl = Label.new()
	lbl.text = text
	lbl.modulate = col
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position = Vector2(-80, -32)
	lbl.size = Vector2(160, 24)
	floating_container.add_child(lbl)

	var tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y - 30.0, 0.85).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.85).set_delay(0.2)
	await tw.finished
	lbl.queue_free()

func _on_death() -> void:
	var tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "scale", Vector2.ZERO, 0.35).set_trans(Tween.TRANS_BACK)
	tw.tween_property(self, "modulate:a", 0.0, 0.35)
	await tw.finished
	queue_free()
