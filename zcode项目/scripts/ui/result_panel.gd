class_name BattleResultPanel
extends RefCounted
## 结算面板（通关 / 战败后的弹出面板）。
##
## 从 battle.gd 抽出来的第一块 UI。原先面板的搭建、按钮回调、显示逻辑
## 全混在战斗主控里，导致 battle.gd 一半是规则、一半是控件代码。
## 这里把面板自成一个对象，battle.gd 只负责"算出标题和正文"再丢进来。

var panel: PanelContainer = null
var title: Label = null
var body: Label = null
var next_btn: Button = null
var home_btn: Button = null


## 在 ui_root 下搭出面板（默认隐藏）。按钮回调由外部注入。
func build(ui_root: Node, on_next: Callable, on_home: Callable) -> void:
	var mask := ColorRect.new()
	mask.name = "ResultMask"
	mask.visible = false
	mask.color = Color(0.03, 0.04, 0.06, 0.75)
	mask.set_anchors_preset(Control.PRESET_FULL_RECT)
	mask.z_index = 110
	ui_root.add_child(mask)

	var p := PanelContainer.new()
	p.visible = false
	p.position = Vector2(340, 140)
	p.size = Vector2(600, 420)
	p.z_index = 120
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.09, 0.13, 0.98)
	sb.border_color = Color(0.9, 0.78, 0.35, 1.0)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 28
	sb.content_margin_right = 28
	sb.content_margin_top = 24
	sb.content_margin_bottom = 24
	p.add_theme_stylebox_override("panel", sb)
	ui_root.add_child(p)
	panel = p

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 20)
	p.add_child(vbox)

	var t := Label.new()
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 28)
	t.add_theme_color_override("font_color", Color(0.98, 0.85, 0.3))
	vbox.add_child(t)
	title = t

	var b := Label.new()
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_color_override("font_color", Color(0.9, 0.95, 0.9))
	vbox.add_child(b)
	body = b

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	vbox.add_child(row)

	var nxt := Button.new()
	nxt.custom_minimum_size = Vector2(180, 52)
	nxt.text = "奔赴下一关 ⚔️"
	var btn_next_sb := StyleBoxFlat.new()
	btn_next_sb.bg_color = Color(0.18, 0.45, 0.25)
	btn_next_sb.border_color = Color(0.35, 0.85, 0.45)
	btn_next_sb.set_border_width_all(2)
	btn_next_sb.set_corner_radius_all(8)
	nxt.add_theme_stylebox_override("normal", btn_next_sb)
	nxt.add_theme_font_size_override("font_size", 16)
	nxt.pressed.connect(on_next)
	row.add_child(nxt)
	next_btn = nxt

	var home := Button.new()
	home.custom_minimum_size = Vector2(160, 52)
	home.text = "返回主城 🏰"
	var btn_home_sb := StyleBoxFlat.new()
	btn_home_sb.bg_color = Color(0.2, 0.22, 0.28)
	btn_home_sb.border_color = Color(0.5, 0.55, 0.65)
	btn_home_sb.set_border_width_all(2)
	btn_home_sb.set_corner_radius_all(8)
	home.add_theme_stylebox_override("normal", btn_home_sb)
	home.add_theme_font_size_override("font_size", 16)
	home.pressed.connect(on_home)
	row.add_child(home)
	home_btn = home


## 显示结算内容。nxt 为空表示没有下一关（按钮变成"大业告成"并禁用）。
func show(title_text: String, body_text: String, nxt: String) -> void:
	if panel == null:
		return
	title.text = title_text
	body.text = body_text
	next_btn.visible = nxt != ""
	next_btn.disabled = nxt == ""
	next_btn.text = "奔赴下一关 ⚔️" if nxt != "" else "大业告成 🏆"
	panel.visible = true
