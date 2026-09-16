class_name Main
extends Node2D

const GridManager = preload("res://scripts/grid_manager.gd")
const UnitManager = preload("res://scripts/unit_manager.gd")
const TurnManager = preload("res://scripts/turn_manager.gd")
const SkillManager = preload("res://scripts/skill_manager.gd")
const FXManager = preload("res://scripts/fx_manager.gd")
const UIManager = preload("res://scripts/ui_manager.gd")

@onready var grid_manager: GridManager = $GridManager
@onready var unit_manager: UnitManager = $UnitManager
@onready var turn_manager: TurnManager = $TurnManager
@onready var skill_manager: SkillManager = $SkillManager
@onready var fx_manager: FXManager = $FXManager
@onready var camera: Camera2D = $Camera2D
@onready var ui_layer: UIManager = $UILayer

func _ready() -> void:
	fx_manager.camera = camera
	grid_manager.init_grid()
	unit_manager.setup(grid_manager)
	
	skill_manager.barrage_requested.connect(func(text: String, col: Color):
		ui_layer.spawn_barrage(text, col)
	)

	turn_manager.setup(grid_manager, unit_manager, skill_manager, fx_manager, ui_layer)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var g_pos = grid_manager.world_to_grid(event.position)
		grid_manager.set_hover_cell(g_pos)
		var u = unit_manager.get_unit_at(g_pos)
		if u != null:
			u.is_hovered = true
		else:
			for existing_u in unit_manager.get_all_units():
				existing_u.is_hovered = false

	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var g_pos = grid_manager.world_to_grid(event.position)
		if grid_manager.is_valid_cell(g_pos):
			turn_manager.handle_cell_click(g_pos)
