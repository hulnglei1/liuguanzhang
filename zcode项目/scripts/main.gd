extends Control
## 主菜单：章节选择 + 主城功能（抽奖/图鉴）

const BATTLE_SCENE := preload("res://scenes/battle.tscn")
const BattleScript := preload("res://scripts/battle.gd")
const MAIN_THEME := preload("res://theme.tres")

const CHAPTERS := {
	"chapter1": "第一关 · 汜水关·温酒斩华雄",
	"chapter2": "第二关 · 虎牢关·三英战吕布",
	"chapter3": "第三关 · 裸衣·裤衩子大战",
	"chapter4": "第四关 · 亲征泰山郡",
}

func _ready() -> void:
	if MAIN_THEME:
		get_window().theme = MAIN_THEME
	_build_menu()

func _build_menu() -> void:
	# 标题
	var title := Label.new()
	title.text = "魂穿刘关张 · 战棋"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.position = Vector2(40, 60)
	title.size = Vector2(1200, 60)
	add_child(title)

	# 主城功能区（图鉴/抽奖）
	var btn_lottery := Button.new()
	btn_lottery.text = "主城 · 声望抽奖"
	btn_lottery.position = Vector2(140, 160)
	btn_lottery.size = Vector2(300, 55)
	btn_lottery.pressed.connect(_go_lottery)
	add_child(btn_lottery)

	var btn_gallery := Button.new()
	btn_gallery.text = "主城 · 图鉴"
	btn_gallery.position = Vector2(840, 160)
	btn_gallery.size = Vector2(300, 55)
	btn_gallery.pressed.connect(_go_gallery)
	add_child(btn_gallery)

	# 章节按钮
	var y := 260
	for id in CHAPTERS:
		var btn := Button.new()
		btn.text = CHAPTERS[id]
		btn.position = Vector2(400, y)
		btn.size = Vector2(480, 55)
		btn.add_theme_font_size_override("font_size", 18)
		btn.pressed.connect(_on_chapter.bind(id))
		add_child(btn)
		y += 75

	print("[主菜单] 就绪，请选择关卡或功能")

func _on_chapter(id: String) -> void:
	print("[主菜单] 进入：", CHAPTERS[id])
	BattleScript.chapter_id = id
	get_tree().change_scene_to_file("res://scenes/battle.tscn")

func _go_lottery() -> void:
	get_tree().change_scene_to_file("res://scenes/lottery.tscn")

func _go_gallery() -> void:
	get_tree().change_scene_to_file("res://scenes/gallery.tscn")