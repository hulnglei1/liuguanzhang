extends Control
## 章节序章（曹操传式开场过场）
## 在进入关卡前播放：章节标题卡 -> 卷轴旁白 / 人物对白 / 系统提示
## 数据来源：res://data/prologues/<chapter_id>.json
## 推进：Space / 鼠标左键 / 「继续」按钮；可随时「跳过序章」

const BattleScript := preload("res://scripts/battle.gd")
const SaveCore := preload("res://scripts/systems/save.gd")
const PortraitLoaderCore := preload("res://scripts/ui/portrait_loader.gd")

const COL_BG := Color(0.035, 0.045, 0.06, 1.0)
const COL_GOLD := Color(0.85, 0.72, 0.42)
const COL_GOLD_DIM := Color(0.55, 0.46, 0.26)
const COL_TEXT := Color(0.93, 0.89, 0.80)
const COL_SCROLL := Color(0.78, 0.83, 0.88)
const COL_SYS := Color(0.42, 0.85, 0.78)

# 说话人名牌配色（未登记的说话人走默认色）
const SPEAKER_COLORS := {
	"刘备": Color(0.55, 0.28, 0.22),
	"关羽": Color(0.24, 0.48, 0.30),
	"张飞": Color(0.30, 0.32, 0.55),
	"赵云": Color(0.28, 0.50, 0.62),
	"公孙瓒": Color(0.52, 0.50, 0.28),
	"武安国": Color(0.45, 0.35, 0.52),
	"系统": Color(0.20, 0.45, 0.45),
	"旁白": Color(0.35, 0.36, 0.40),
}

var chapter_id: String = "chapter1"
var data: Dictionary = {}
var card: Dictionary = {}
var lines: Array = []
var idx: int = -1

var title_layer: Control
var body_layer: Control
var card_panel: PanelContainer
var speaker_plate: PanelContainer
var speaker_label: Label
var text_label: RichTextLabel
var progress_label: Label
var prompt_label: Label

var typing := false
var type_tween: Tween
var portrait_rect: TextureRect
var portrait_prev: TextureRect
var illustration_rect: TextureRect
var _last_speaker_key: String = ""
## 进入序章后的输入冷静期（毫秒时间戳）。
## 点"进军出征"的那次鼠标/按键事件会漏进刚创建的序章，一次点击能推进好几行。
var _input_grace_until: int = 0


func _ready() -> void:
	chapter_id = BattleScript.chapter_id
	_load_data()
	_build_ui()
	_run()


func _load_data() -> void:
	var path := "res://data/prologues/%s.json" % chapter_id
	if not FileAccess.file_exists(path):
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	data = parsed
	card = data.get("title_card", {})
	lines = data.get("opening", [])


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = COL_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# 左右金色竖线，营造卷轴感
	for x in [64.0, 1216.0]:
		var rule := ColorRect.new()
		rule.color = Color(COL_GOLD_DIM.r, COL_GOLD_DIM.g, COL_GOLD_DIM.b, 0.35)
		rule.position = Vector2(x, 60)
		rule.size = Vector2(1, 600)
		rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(rule)

	# 顶部章节进度
	progress_label = Label.new()
	progress_label.position = Vector2(80, 40)
	progress_label.size = Vector2(400, 24)
	progress_label.add_theme_font_size_override("font_size", 13)
	progress_label.add_theme_color_override("font_color", COL_GOLD_DIM)
	add_child(progress_label)

	title_layer = _build_title_layer()
	add_child(title_layer)

	body_layer = _build_body_layer()
	body_layer.visible = false
	add_child(body_layer)

	# 底部操作提示
	prompt_label = Label.new()
	prompt_label.text = "点击 / 空格 继续  ▸"
	prompt_label.position = Vector2(0, 660)
	prompt_label.size = Vector2(1280, 24)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size", 13)
	prompt_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	add_child(prompt_label)

	var skip_btn := Button.new()
	skip_btn.text = "跳过序章 ⏩"
	skip_btn.position = Vector2(1120, 648)
	skip_btn.size = Vector2(120, 32)
	skip_btn.add_theme_font_size_override("font_size", 13)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.13, 0.16)
	sb.border_color = COL_GOLD_DIM
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	skip_btn.add_theme_stylebox_override("normal", sb)
	skip_btn.add_theme_color_override("font_color", Color(0.8, 0.78, 0.7))
	skip_btn.pressed.connect(_finish)
	add_child(skip_btn)


func _build_title_layer() -> Control:
	var layer := Control.new()
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var chap := Label.new()
	chap.text = str(card.get("chapter", ""))
	chap.position = Vector2(0, 250)
	chap.size = Vector2(1280, 40)
	chap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chap.add_theme_font_size_override("font_size", 30)
	chap.add_theme_color_override("font_color", COL_GOLD)
	layer.add_child(chap)

	var name_lbl := Label.new()
	name_lbl.text = str(card.get("name", ""))
	name_lbl.position = Vector2(0, 306)
	name_lbl.size = Vector2(1280, 56)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 44)
	name_lbl.add_theme_color_override("font_color", COL_TEXT)
	layer.add_child(name_lbl)

	var tag := Label.new()
	tag.text = str(card.get("tagline", ""))
	tag.position = Vector2(0, 384)
	tag.size = Vector2(1280, 28)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_theme_font_size_override("font_size", 16)
	tag.add_theme_color_override("font_color", COL_SCROLL)
	layer.add_child(tag)

	return layer


func _build_body_layer() -> Control:
	var layer := Control.new()
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 立绘位（美术资源后补；缺图自动隐藏，不影响文字演出）
	portrait_rect = TextureRect.new()
	portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait_rect.position = Vector2(840, 150)
	portrait_rect.size = Vector2(360, 480)
	portrait_rect.visible = false
	portrait_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(portrait_rect)

	# 关键剧情用"整幅构图"（多人同框、大场面）：一张图胜过三张单人像并排
	illustration_rect = TextureRect.new()
	illustration_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	illustration_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	illustration_rect.position = Vector2(120, 58)
	illustration_rect.size = Vector2(1040, 556)
	illustration_rect.visible = false
	illustration_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(illustration_rect)

	# 左侧"上一位说话人"：用来做"两人同框"的近似（左暗右亮）
	# 真正的双人立绘需要成对的构图素材；这里用"维持上一位 + 压暗"换 80% 的观感
	portrait_prev = TextureRect.new()
	portrait_prev.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait_prev.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait_prev.position = Vector2(60, 190)
	portrait_prev.size = Vector2(320, 420)
	portrait_prev.visible = false
	portrait_prev.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_prev.modulate = Color(0.62, 0.62, 0.68, 0.85)
	layer.add_child(portrait_prev)

	# 人物名牌（对白用）
	speaker_plate = PanelContainer.new()
	# 名牌放在右侧当前立绘这一边（左边是上一位说话人，别压住他的脸）
	speaker_plate.position = Vector2(700, 276)
	speaker_plate.size = Vector2(120, 36)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.3, 0.3, 0.3)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	speaker_plate.add_theme_stylebox_override("panel", sb)
	speaker_label = Label.new()
	speaker_label.add_theme_font_size_override("font_size", 17)
	speaker_label.add_theme_color_override("font_color", Color(1, 0.98, 0.92))
	speaker_plate.add_child(speaker_label)
	layer.add_child(speaker_plate)

	# 正文
	text_label = RichTextLabel.new()
	text_label.position = Vector2(180, 330)
	text_label.size = Vector2(640, 240)
	text_label.bbcode_enabled = true
	text_label.scroll_active = false
	text_label.fit_content = false
	text_label.add_theme_font_size_override("normal_font_size", 22)
	text_label.add_theme_constant_override("line_separation", 10)
	text_label.add_theme_color_override("default_color", COL_TEXT)
	layer.add_child(text_label)

	return layer


func _run() -> void:
	if lines.is_empty():
		_finish()
		return
	# 标题卡停留后进入正文
	await get_tree().create_timer(2.4).timeout
	title_layer.visible = false
	body_layer.visible = true
	# 360ms 内忽略输入：挡住"点进关"的那一下点击/按键漏进序章
	_input_grace_until = Time.get_ticks_msec() + 360
	_next()


func _next() -> void:
	idx += 1
	if idx >= lines.size():
		_finish()
		return
	var line: Dictionary = lines[idx]
	var kind := str(line.get("type", "scroll"))
	progress_label.text = "%s   %d / %d" % [str(card.get("name", "")), idx + 1, lines.size()]

	var speaker := str(line.get("speaker", ""))
	var body := str(line.get("text", ""))
	if illustration_rect != null:
		illustration_rect.visible = false
	_update_portrait(line)

	match kind:
		"dialog":
			speaker_plate.visible = true
			speaker_label.text = speaker
			var c: Color = SPEAKER_COLORS.get(speaker, Color(0.32, 0.34, 0.38))
			var sb := StyleBoxFlat.new()
			sb.bg_color = c
			sb.set_corner_radius_all(4)
			sb.content_margin_left = 12
			sb.content_margin_right = 12
			sb.content_margin_top = 4
			sb.content_margin_bottom = 4
			speaker_plate.add_theme_stylebox_override("panel", sb)
			text_label.position = Vector2(180, 330)
			text_label.size = Vector2(640, 240)
			text_label.add_theme_color_override("default_color", COL_TEXT)
			_type_in(body)
		"illustration":
			# 整幅构图：收起单人立绘与名牌，图占主体，文字做图下注释
			speaker_plate.visible = false
			portrait_rect.visible = false
			if portrait_prev != null:
				portrait_prev.visible = false
			_last_speaker_key = ""
			var img := str(line.get("image", ""))
			if img != "" and ResourceLoader.exists(img):
				illustration_rect.texture = load(img)
				illustration_rect.visible = true
			text_label.position = Vector2(160, 596)
			text_label.size = Vector2(960, 76)
			text_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
			text_label.add_theme_constant_override("shadow_offset_x", 2)
			text_label.add_theme_constant_override("shadow_offset_y", 2)
			text_label.add_theme_color_override("default_color", COL_SCROLL)
			_type_in("[center][i]" + body + "[/i][/center]")
		"system":
			speaker_plate.visible = false
			text_label.position = Vector2(180, 300)
			text_label.size = Vector2(640, 280)
			text_label.add_theme_color_override("default_color", COL_SYS)
			_type_in("[center]\n" + body + "\n[/center]")
		_:
			speaker_plate.visible = false
			text_label.position = Vector2(140, 318)
			text_label.size = Vector2(700, 260)
			text_label.add_theme_color_override("default_color", COL_SCROLL)
			_type_in("[center][i]" + body + "[/i][/center]")


func _update_portrait(line: Dictionary) -> void:
	if portrait_rect == null:
		return
	var key := PortraitLoaderCore.resolve_key(line)
	if key.is_empty():
		# 纯旁白：画面交给留白，人物全部收起
		portrait_rect.visible = false
		if portrait_prev != null:
			portrait_prev.visible = false
		_last_speaker_key = ""
		return
	var tex := PortraitLoaderCore.load_for(key, PortraitLoaderCore.resolve_emotion(line))
	if tex == null:
		portrait_rect.visible = false
		return
	portrait_rect.texture = tex
	portrait_rect.visible = true
	# 换人说话时，把上一位挪到左边继续站着（暗一档）——近似"两人同框"
	if portrait_prev != null:
		if key != _last_speaker_key and not _last_speaker_key.is_empty():
			var prev_tex := PortraitLoaderCore.load_for(_last_speaker_key)
			if prev_tex != null:
				portrait_prev.texture = prev_tex
				portrait_prev.visible = true
		elif key == _last_speaker_key:
			pass
	_last_speaker_key = key


func _type_in(body: String) -> void:
	text_label.text = body
	text_label.visible_characters = 0
	if type_tween and type_tween.is_valid():
		type_tween.kill()
	typing = true
	var total := text_label.get_total_character_count()
	var dur: float = clampf(float(total) * 0.022, 0.35, 2.2)
	type_tween = create_tween()
	type_tween.tween_property(text_label, "visible_characters", total, dur)
	type_tween.finished.connect(func() -> void: typing = false)


func _advance() -> void:
	if typing:
		# 打字中：立即补全
		if type_tween and type_tween.is_valid():
			type_tween.kill()
		text_label.visible_characters = -1
		typing = false
	else:
		_next()


## 用 _input 而不是 _unhandled_input：
## 序章里铺了满屏 Control（背景板/对话框），默认 mouse_filter=STOP 会把点击吃掉，
## _unhandled_input 永远收不到 —— 表现就是"左键点了没反应，只能按空格"。
func _input(event: InputEvent) -> void:
	if Time.get_ticks_msec() < _input_grace_until:
		_mark_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			_advance()
			_mark_handled()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_advance()
			_mark_handled()


## 标记输入已消费。--script 测试模式下没有 viewport，必须判空。
func _mark_handled() -> void:
	var vp := get_viewport()
	if vp != null:
		vp.set_input_as_handled()


func _finish() -> void:
	# 记录已观看，下次直接进关
	var save: Dictionary = SaveCore.load_state()
	var seen: Array = save.get("prologues_seen", [])
	if not seen.has(chapter_id):
		seen.append(chapter_id)
	save["prologues_seen"] = seen
	SaveCore.save_state(save)
	get_tree().change_scene_to_file("res://scenes/battle.tscn")
