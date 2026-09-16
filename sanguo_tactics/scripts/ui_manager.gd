class_name UIManager
extends CanvasLayer

const UnitData = preload("res://scripts/unit_data.gd")
const Unit = preload("res://scripts/unit.gd")

signal action_chosen(action_name: String)
signal end_turn_pressed()
signal dialogue_finished()
signal restart_requested()

# 弹幕文本池
var barrage_pool: Array[String] = [
	"马哥：这踏马是我老马的极限！",
	"哪来的虫洞声？",
	"这还不阴？！",
	"曹操：这酒...还温着呢，人怎么跑外圈去了？",
	"袁绍：谁教你这么用青龙偃月刀的？！",
	"华雄：有种别跑！正面刚啊！",
	"关羽：让马哥先热热身！",
	"老马：三匹母马，少一匹我直接趴窝！",
	"潘凤：我大斧还没抡热呢！",
	"张飞：俺老张这大嗓门，震得华雄脑瓜子嗡嗡的！",
	"赵云：常山赵子龙，前来做关二哥的座驾！",
	"诸侯联军：这到底是战棋还是赛马？！",
	"刘备：二弟跑慢点，草鞋都甩飞了！",
	"华雄：14倍神力，打不到人有个屁用啊！",
	"东海郡百姓：听说有土豆吃了？！"
]

var barrage_timer: float = 0.0
var dialog_queue: Array = []
var is_displaying_dialog: bool = false
var current_dialog_text: String = ""
var typewriter_idx: int = 0
var typewriter_timer: float = 0.0

@onready var turn_label: Label = %TurnLabel
@onready var end_turn_btn: Button = %EndTurnBtn

# 武将信息面板
@onready var info_panel: PanelContainer = %UnitInfoPanel
@onready var info_avatar: Label = %InfoAvatar
@onready var info_name: Label = %InfoName
@onready var info_title: Label = %InfoTitle
@onready var info_hp_bar: ProgressBar = %InfoHpBar
@onready var info_hp_text: Label = %InfoHpText
@onready var info_special_box: VBoxContainer = %InfoSpecialBox
@onready var info_special_label: Label = %InfoSpecialLabel
@onready var info_special_bar: ProgressBar = %InfoSpecialBar
@onready var dragon_box: VBoxContainer = %DragonBox
@onready var dragon_charge_bar: ProgressBar = %DragonChargeBar
@onready var dragon_charge_desc: Label = %DragonChargeDesc

# 行动指令菜单
@onready var action_menu: PanelContainer = %ActionMenu
@onready var btn_attack: Button = %BtnAttack
@onready var btn_dragon: Button = %BtnDragon
@onready var btn_pie: Button = %BtnPie
@onready var btn_stepback: Button = %BtnStepBack
@onready var btn_roar: Button = %BtnRoar
@onready var btn_taunt: Button = %BtnTaunt
@onready var btn_heal: Button = %BtnHeal
@onready var btn_ride: Button = %BtnRide
@onready var btn_wait: Button = %BtnWait

# 剧情对话框
@onready var dialog_box: PanelContainer = %DialogBox
@onready var speaker_avatar: Label = %SpeakerAvatar
@onready var speaker_name: Label = %SpeakerName
@onready var dialog_text: Label = %DialogText

# 弹幕层
@onready var barrage_container: Control = %BarrageContainer

# 抽奖与胜利结算
@onready var gacha_panel: PanelContainer = %GachaPanel
@onready var gacha_draw_btn: Button = %GachaDrawBtn
@onready var gacha_result_box: HBoxContainer = %GachaResultBox
@onready var gacha_finish_btn: Button = %GachaFinishBtn

func _ready() -> void:
	_setup_button_signals()
	if info_panel:
		info_panel.visible = false
	if action_menu:
		action_menu.visible = false
	if dialog_box:
		dialog_box.visible = false
	if gacha_panel:
		gacha_panel.visible = false

func _process(delta: float) -> void:
	# 自动弹幕发射轮询
	barrage_timer -= delta
	if barrage_timer <= 0.0:
		barrage_timer = randf_range(2.0, 3.5)
		var rand_text = barrage_pool[randi() % barrage_pool.size()]
		spawn_barrage(rand_text, Color(randf_range(0.8, 1.0), randf_range(0.8, 1.0), randf_range(0.8, 1.0)))

	# 对话框打字机效果
	if is_displaying_dialog and typewriter_idx < current_dialog_text.length():
		typewriter_timer += delta
		if typewriter_timer >= 0.03:
			typewriter_timer = 0.0
			typewriter_idx += 1
			dialog_text.text = current_dialog_text.substr(0, typewriter_idx)

func _setup_button_signals() -> void:
	if end_turn_btn:
		end_turn_btn.pressed.connect(func(): end_turn_pressed.emit())
	if btn_attack:
		btn_attack.pressed.connect(func(): action_chosen.emit("attack"))
	if btn_dragon:
		btn_dragon.pressed.connect(func(): action_chosen.emit("dragon"))
	if btn_pie:
		btn_pie.pressed.connect(func(): action_chosen.emit("pie"))
	if btn_stepback:
		btn_stepback.pressed.connect(func(): action_chosen.emit("stepback"))
	if btn_roar:
		btn_roar.pressed.connect(func(): action_chosen.emit("roar"))
	if btn_taunt:
		btn_taunt.pressed.connect(func(): action_chosen.emit("taunt"))
	if btn_heal:
		btn_heal.pressed.connect(func(): action_chosen.emit("heal"))
	if btn_ride:
		btn_ride.pressed.connect(func(): action_chosen.emit("ride"))
	if btn_wait:
		btn_wait.pressed.connect(func(): action_chosen.emit("wait"))
	if gacha_draw_btn:
		gacha_draw_btn.pressed.connect(_on_gacha_draw_clicked)
	if gacha_finish_btn:
		gacha_finish_btn.pressed.connect(func(): restart_requested.emit())

# 更新回合指示器
func update_turn_info(turn: int, phase: String) -> void:
	if turn_label == null:
		return
	if phase == "player":
		turn_label.text = "【第 %d 回合】蜀汉战术阶段 (请点击武将下达指令)" % turn
		turn_label.modulate = Color(0.3, 1.0, 0.5)
		end_turn_btn.disabled = false
	else:
		turn_label.text = "【第 %d 回合】董卓西凉铁骑阶段..." % turn
		turn_label.modulate = Color(1.0, 0.4, 0.4)
		end_turn_btn.disabled = true
		hide_action_menu()

# 显示选中武将信息
func show_unit_info(unit: Unit) -> void:
	if unit == null or unit.data == null:
		info_panel.visible = false
		return

	info_panel.visible = true
	var d = unit.data
	info_avatar.text = d.avatar_char
	info_avatar.modulate = d.color
	info_name.text = d.unit_name
	info_title.text = d.title
	
	info_hp_bar.max_value = d.max_hp
	info_hp_bar.value = d.current_hp
	info_hp_text.text = "HP: %d / %d   攻击: %d   防御: %d   机动: %d" % [d.current_hp, d.max_hp, d.atk, d.def_val, d.move_range]

	# 关羽专属青龙进度与马哥体力
	if d.id == "guanyu":
		info_special_box.visible = true
		info_special_label.text = "🐴 战马马哥体力 (≤20打响鼻罢工):"
		info_special_bar.max_value = d.max_horse_stamina
		info_special_bar.value = d.horse_stamina
		
		dragon_box.visible = true
		dragon_charge_bar.max_value = 10
		dragon_charge_bar.value = d.dragon_charge
		
		var desc = ""
		if d.dragon_charge >= 10:
			desc = "⚡【天基大青龙】全图贯穿！伤害9999秒杀一切！"
		elif d.dragon_charge >= 6:
			desc = "🐉【高铁巨龙】直线6格贯穿！伤害600%！"
		elif d.dragon_charge >= 3:
			desc = "🐉【水管粗青龙】直线3格贯穿！伤害250%！"
		else:
			desc = "🌱【竹叶青】单体近战！伤害100% (在外圈多跑几圈蓄力！)"
		dragon_charge_desc.text = "蓄力步数: %d/10   形态: %s" % [d.dragon_charge, desc]
	elif d.id == "zhangfei":
		info_special_box.visible = true
		info_special_label.text = "🔥 燕人怒气槽 (受击与咆哮消耗):"
		info_special_bar.max_value = 100
		info_special_bar.value = d.rage
		dragon_box.visible = false
	else:
		info_special_box.visible = false
		dragon_box.visible = false

# 显示行动菜单
func show_action_menu(unit: Unit, can_ride_zhao: bool = false) -> void:
	if unit == null or unit.data.faction != "player" or unit.data.has_acted:
		action_menu.visible = false
		return

	action_menu.visible = true
	var d = unit.data

	# 重置所有按钮可见性
	btn_dragon.visible = (d.id == "guanyu")
	btn_pie.visible = (d.id == "guanyu")
	btn_stepback.visible = (d.id == "guanyu")
	
	btn_roar.visible = (d.id == "zhangfei")
	btn_taunt.visible = (d.id == "zhangfei")
	
	btn_heal.visible = (d.id == "liubei")
	btn_ride.visible = (d.id == "guanyu" and can_ride_zhao)

	# 按钮动态文本
	if d.id == "guanyu":
		if d.dragon_charge >= 10:
			btn_dragon.text = "⚡ 天基大青龙 (全图秒杀!)"
		else:
			btn_dragon.text = "🐉 千里青龙斩 (蓄力%d层)" % d.dragon_charge
		
		if d.is_exhausted:
			btn_pie.text = "🐴 给马哥画饼 (罢工急救!)"
		else:
			btn_pie.text = "🐴 给马哥画饼 (+60体力)"

func hide_action_menu() -> void:
	if action_menu:
		action_menu.visible = false

# 飘屏弹幕生成
func spawn_barrage(content: String, color: Color = Color.WHITE) -> void:
	if barrage_container == null:
		return

	var lbl = Label.new()
	lbl.text = content
	lbl.modulate = color
	lbl.add_theme_font_size_override("font_size", randi_range(16, 22))
	
	var start_y = randf_range(40.0, 220.0)
	lbl.position = Vector2(1290.0, start_y)
	barrage_container.add_child(lbl)

	var move_speed = randf_range(160.0, 240.0)
	var total_dist = 1750.0
	var duration = total_dist / move_speed

	var tw = create_tween()
	tw.tween_property(lbl, "position:x", -450.0, duration)
	await tw.finished
	lbl.queue_free()

# 剧情对白播放系统
func play_dialogue(lines: Array) -> void:
	dialog_queue = lines.duplicate()
	dialog_box.visible = true
	_show_next_dialog()

func _show_next_dialog() -> void:
	if dialog_queue.is_empty():
		dialog_box.visible = false
		is_displaying_dialog = false
		dialogue_finished.emit()
		return

	var line = dialog_queue.pop_front()
	speaker_avatar.text = line.get("avatar", "说")
	speaker_avatar.modulate = line.get("color", Color.WHITE)
	speaker_name.text = line.get("speaker", "人物")
	
	current_dialog_text = line.get("text", "")
	typewriter_idx = 0
	typewriter_timer = 0.0
	dialog_text.text = ""
	is_displaying_dialog = true

func _input(event: InputEvent) -> void:
	if is_displaying_dialog:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if typewriter_idx < current_dialog_text.length():
				# 快速跳过打字机直接显示全句
				typewriter_idx = current_dialog_text.length()
				dialog_text.text = current_dialog_text
			else:
				# 翻到下一句
				_show_next_dialog()

# 战后占领东海郡霸业抽奖
func show_gacha_screen() -> void:
	gacha_panel.visible = true
	gacha_draw_btn.visible = true
	gacha_finish_btn.visible = false
	for child in gacha_result_box.get_children():
		child.queue_free()

func _on_gacha_draw_clicked() -> void:
	gacha_draw_btn.visible = false
	
	var rewards = [
		{"name": "【SSR】毛瑟98k狙击步枪", "desc": "八百里外一枪崩掉敌将，华雄直接懵逼！", "col": Color(1.0, 0.85, 0.2)},
		{"name": "【SSR】纯种白色小母马×3", "desc": "马哥热泪盈眶：关二爷诚不欺我！续航翻倍！", "col": Color(1.0, 0.85, 0.2)},
		{"name": "【SR】高产现代土豆原种", "desc": "亩产八千斤！徐州百姓顿顿吃饱，粮草暴涨！", "col": Color(0.8, 0.4, 1.0)},
		{"name": "【SSR】人肉高铁合体授权书", "desc": "关赵双剑合璧，诸侯联军集体怀疑人生！", "col": Color(1.0, 0.85, 0.2)}
	]

	for item in rewards:
		var card = PanelContainer.new()
		var vbox = VBoxContainer.new()
		var title_lbl = Label.new()
		title_lbl.text = item["name"]
		title_lbl.modulate = item["col"]
		title_lbl.add_theme_font_size_override("font_size", 14)
		
		var desc_lbl = Label.new()
		desc_lbl.text = item["desc"]
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.custom_minimum_size = Vector2(160, 80)
		desc_lbl.add_theme_font_size_override("font_size", 11)

		vbox.add_child(title_lbl)
		vbox.add_child(desc_lbl)
		card.add_child(vbox)
		gacha_result_box.add_child(card)

	gacha_finish_btn.visible = true
	spawn_barrage("🎉 恭喜主公占领东海郡！霸业开局大吉！", Color(1.0, 0.85, 0.2))
