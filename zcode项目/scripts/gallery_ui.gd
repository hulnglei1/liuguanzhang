extends Control
## 图鉴系统：武将 / 技能 / 名场面收集展示
## 数据源：data/collection.json + save.json 中已收集条目

const SaveCore := preload("res://scripts/systems/save.gd")

var collection_data: Dictionary
var save: Dictionary
var label_warriors: RichTextLabel
var label_skills: RichTextLabel
var label_scenes: RichTextLabel

func _ready() -> void:
	save = SaveCore.load_state()
	collection_data = _load_json("res://data/collection.json")
	_build_ui()

func _load_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

func _build_ui() -> void:
	var title := Label.new()
	title.text = "图鉴 · 名将录"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.position = Vector2(40, 30)
	title.size = Vector2(1200, 60)
	add_child(title)

	var collected := _collected_set()

	# 武将列
	label_warriors = RichTextLabel.new()
	label_warriors.position = Vector2(60, 120)
	label_warriors.size = Vector2(360, 500)
	label_warriors.bbcode_enabled = true
	label_warriors.fit_content = true
	add_child(label_warriors)

	# 技能列
	label_skills = RichTextLabel.new()
	label_skills.position = Vector2(460, 120)
	label_skills.size = Vector2(340, 500)
	label_skills.bbcode_enabled = true
	label_skills.fit_content = true
	add_child(label_skills)

	# 名场面列
	label_scenes = RichTextLabel.new()
	label_scenes.position = Vector2(840, 120)
	label_scenes.size = Vector2(360, 500)
	label_scenes.bbcode_enabled = true
	label_scenes.fit_content = true
	add_child(label_scenes)

	# 返回
	var btn_back := Button.new()
	btn_back.text = "返回主菜单"
	btn_back.position = Vector2(500, 640)
	btn_back.size = Vector2(280, 50)
	btn_back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main.tscn"))
	add_child(btn_back)

	_render(collected)

func _collected_set() -> Dictionary:
	return save.get("collection", {})

## 渲染三列：已收集的显示，未收集的显示？？？
func _render(collected: Dictionary) -> void:
	var w_text = "[b]【武将】[/b]\n"
	for w in collection_data.get("warriors", []):
		var key: String = "warrior_" + str(w.get("id", ""))
		if collected.has(key):
			w_text += "✅ %s\n   %s\n" % [w.name, w.desc]
		else:
			w_text += "❌ ???\n"
	label_warriors.text = w_text

	var s_text = "[b]【绝技】[/b]\n"
	for sk in collection_data.get("skills", []):
		var key: String = "skill_" + str(sk.get("id", ""))
		if collected.has(key):
			s_text += "✅ %s\n   %s\n" % [sk.name, sk.desc]
		else:
			s_text += "❌ ???\n"
	label_skills.text = s_text

	var sc_text = "[b]【名场面】[/b]\n"
	for sc in collection_data.get("scenes", []):
		var key: String = "scene_" + str(sc.get("id", ""))
		if collected.has(key):
			sc_text += "✅ %s\n   %s\n" % [sc.name, sc.desc]
		else:
			sc_text += "❌ ???\n"
	label_scenes.text = sc_text