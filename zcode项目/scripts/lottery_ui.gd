extends Control
## 抽奖界面：种子池 + 武器池双池抽取
## 数据存 user://save.json（SaveCore 管理声望/背包）

const LotteryCore := preload("res://scripts/systems/lottery.gd")
const SaveCore := preload("res://scripts/systems/save.gd")

var save: Dictionary
var label_result: Label
var label_prestige: Label
var btn_seed: Button
var btn_weapon: Button
var btn_back: Button

func _ready() -> void:
	save = SaveCore.load_state()
	_build_ui()

func _build_ui() -> void:
	# 标题
	var title := Label.new()
	title.text = "主城 · 声望去哪了？抽！"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.position = Vector2(40, 40)
	title.size = Vector2(1200, 60)
	add_child(title)

	# 声望显示
	label_prestige = Label.new()
	label_prestige.text = ""
	label_prestige.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_prestige.add_theme_font_size_override("font_size", 20)
	label_prestige.position = Vector2(40, 110)
	label_prestige.size = Vector2(1200, 40)
	add_child(label_prestige)

	# 种子池按钮
	btn_seed = Button.new()
	btn_seed.text = "抽种子池 · 1000声望/次（玉米/土豆/番薯）"
	btn_seed.position = Vector2(360, 200)
	btn_seed.size = Vector2(560, 60)
	btn_seed.pressed.connect(_on_seed)
	add_child(btn_seed)

	# 武器池按钮
	btn_weapon = Button.new()
	btn_weapon.text = "抽武器池 · 5000声望/次（装备/战技）"
	btn_weapon.position = Vector2(360, 280)
	btn_weapon.size = Vector2(560, 60)
	btn_weapon.pressed.connect(_on_weapon)
	add_child(btn_weapon)

	# 结果
	label_result = Label.new()
	label_result.text = "选择奖池抽取！声望来自占领郡府。"
	label_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label_result.add_theme_font_size_override("font_size", 18)
	label_result.position = Vector2(200, 380)
	label_result.size = Vector2(880, 140)
	add_child(label_result)

	# 返回
	btn_back = Button.new()
	btn_back.text = "返回主菜单"
	btn_back.position = Vector2(500, 560)
	btn_back.size = Vector2(280, 50)
	btn_back.pressed.connect(_on_back)
	add_child(btn_back)

	_refresh()

func _refresh() -> void:
	var p: int = int(save.get("prestige", 0))
	label_prestige.text = "当前声望：%d（每占领1郡+1000）" % p
	btn_seed.disabled = p < 1000
	btn_weapon.disabled = p < 5000

func _on_seed() -> void:
	var draw := LotteryCore.draw_seed(save.get("prestige", 0))
	if draw.success:
		SaveCore.award_item(save, draw.item, 1000)
		SaveCore.save_state(save)
		var inv_cnt: int = save["inventory"].get(draw.item.get("id", ""), 0)
		label_result.text = LotteryCore.draw_flavor(draw.item) + "\n（持有 ×%d）" % inv_cnt
		_celebration()
	else:
		label_result.text = draw.get("reason", "抽奖失败")
	_refresh()

func _on_weapon() -> void:
	var draw := LotteryCore.draw_weapon(save.get("prestige", 0))
	if draw.success:
		SaveCore.award_item(save, draw.item, 5000)
		SaveCore.save_state(save)
		var inv_cnt: int = save["inventory"].get(draw.item.get("id", ""), 0)
		label_result.text = LotteryCore.draw_flavor(draw.item) + "\n（持有 ×%d）" % inv_cnt
		_celebration()
		# 武器更高档：再来一次震屏
		var rect2 := ColorRect.new()
		rect2.color = Color(1, 0.85, 0.3, 0.5)
		rect2.set_anchors_preset(Control.PRESET_FULL_RECT)
		rect2.z_index = 90
		add_child(rect2)
		var tw2 := create_tween()
		tw2.tween_property(rect2, "modulate:a", 0.0, 0.4)
		tw2.tween_callback(rect2.queue_free)
	else:
		label_result.text = draw.get("reason", "抽奖失败")
	_refresh()

## 抽中金光演出：按钮闪烁 + 抖动 + 金光扫过
func _celebration() -> void:
	# 金色全屏闪
	var rect := ColorRect.new()
	rect.color = Color(1, 0.85, 0.3, 0.4)
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.z_index = 80
	add_child(rect)
	var tw := create_tween()
	tw.tween_property(rect, "modulate:a", 0.0, 0.5)
	tw.tween_callback(rect.queue_free)
	# 结果文字弹跳
	if label_result:
		var base := label_result.position
		var twb := create_tween()
		twb.tween_property(label_result, "position", base + Vector2(0, -8), 0.1)
		twb.tween_property(label_result, "position", base, 0.1)

func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")