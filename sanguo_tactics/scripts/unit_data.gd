class_name UnitData
extends Resource

@export var id: String = ""
@export var unit_name: String = ""
@export var title: String = ""
@export var faction: String = "player" # "player", "enemy", "ally"

@export var max_hp: int = 400
@export var current_hp: int = 400
@export var atk: int = 50
@export var def_val: int = 20
@export var move_range: int = 3

@export var grid_pos: Vector2i = Vector2i.ZERO
@export var color: Color = Color(0.2, 0.6, 0.2)
@export var avatar_char: String = "将"

# 小说专属核心机制
@export var dragon_charge: int = 0         # 关羽千里青龙斩蓄力步数
@export var horse_stamina: int = 100       # 战马“马哥”体力槽
@export var max_horse_stamina: int = 100
@export var is_exhausted: bool = false      # 马哥是否罢工
@export var is_piggybacking: bool = false  # 是否正在骑乘赵云

@export var rage: int = 30                 # 张飞怒气（燕人咆哮）
@export var is_taunting: bool = false      # 是否开启挑衅肉盾

@export var is_stunned: bool = false       # 华雄是否被震晕
@export var has_acted: bool = false        # 本回合是否已行动
