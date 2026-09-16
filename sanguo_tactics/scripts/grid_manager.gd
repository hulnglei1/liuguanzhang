class_name GridManager
extends Node2D

# 棋盘网格参数：16 列 x 10 行，单格 64x64 像素
const COLS: int = 16
const ROWS: int = 10
const CELL_SIZE: Vector2 = Vector2(64, 64)
const OFFSET: Vector2 = Vector2(80, 50) # 居中偏移

var astar: AStarGrid2D

# 地形类型枚举
# 0: 平原, 1: 跑马道, 2: 盟军营寨, 3: 汜水关城门, 4: 城墙/障碍
var map_tiles: Array = [
	[4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4],
	[1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 3, 4],
	[1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3, 4],
	[1, 0, 2, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3, 4],
	[1, 0, 2, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3, 4],
	[1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3, 4],
	[1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3, 4],
	[1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3, 4],
	[1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 3, 4],
	[4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4]
]

# 高亮显示数组
var highlighted_move_cells: Array[Vector2i] = []
var highlighted_attack_cells: Array[Vector2i] = []
var highlighted_laser_cells: Array[Vector2i] = []
var hovered_cell: Vector2i = Vector2i(-1, -1)

# 动画计时
var pulse_time: float = 0.0

func _ready() -> void:
	init_grid()

func _process(delta: float) -> void:
	pulse_time += delta * 4.0
	if highlighted_move_cells.size() > 0 or highlighted_attack_cells.size() > 0 or highlighted_laser_cells.size() > 0:
		queue_redraw()

func init_grid() -> void:
	astar = AStarGrid2D.new()
	astar.region = Rect2i(0, 0, COLS, ROWS)
	astar.cell_size = CELL_SIZE
	astar.offset = OFFSET + CELL_SIZE * 0.5
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER # 战棋十字正向移动
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	astar.update()

	# 标记障碍物
	for y in range(ROWS):
		for x in range(COLS):
			var tile_type = map_tiles[y][x]
			if tile_type == 4 or tile_type == 3: # 城墙和城门不可通行
				astar.set_point_solid(Vector2i(x, y), true)

func grid_to_world(grid_pos: Vector2i) -> Vector2:
	return OFFSET + Vector2(grid_pos.x * CELL_SIZE.x, grid_pos.y * CELL_SIZE.y)

func grid_to_world_center(grid_pos: Vector2i) -> Vector2:
	return OFFSET + Vector2(grid_pos.x * CELL_SIZE.x + CELL_SIZE.x * 0.5, grid_pos.y * CELL_SIZE.y + CELL_SIZE.y * 0.5)

func world_to_grid(world_pos: Vector2) -> Vector2i:
	var local = world_pos - OFFSET
	var x = int(floor(local.x / CELL_SIZE.x))
	var y = int(floor(local.y / CELL_SIZE.y))
	return Vector2i(x, y)

func is_valid_cell(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < COLS and pos.y >= 0 and pos.y < ROWS

func is_solid(pos: Vector2i) -> bool:
	if not is_valid_cell(pos):
		return true
	return astar.is_point_solid(pos)

func is_racetrack(pos: Vector2i) -> bool:
	if not is_valid_cell(pos):
		return false
	return map_tiles[pos.y][pos.x] == 1

func is_camp(pos: Vector2i) -> bool:
	if not is_valid_cell(pos):
		return false
	return map_tiles[pos.y][pos.x] == 2

func is_gate(pos: Vector2i) -> bool:
	if not is_valid_cell(pos):
		return false
	return map_tiles[pos.y][pos.x] == 3

func set_unit_occupy(pos: Vector2i, occupied: bool) -> void:
	if is_valid_cell(pos):
		var tile_type = map_tiles[pos.y][pos.x]
		if tile_type != 4 and tile_type != 3:
			astar.set_point_solid(pos, occupied)

func get_reachable_cells(start: Vector2i, move_range: int, occupied_positions: Array[Vector2i] = []) -> Array[Vector2i]:
	var reachable: Array[Vector2i] = []
	var queue: Array = [[start, 0]]
	var visited: Dictionary = {start: 0}

	while queue.size() > 0:
		var item = queue.pop_front()
		var current: Vector2i = item[0]
		var dist: int = item[1]

		if dist > 0 and not reachable.has(current):
			reachable.append(current)

		if dist >= move_range:
			continue

		var neighbors: Array[Vector2i] = [
			Vector2i(current.x + 1, current.y),
			Vector2i(current.x - 1, current.y),
			Vector2i(current.x, current.y + 1),
			Vector2i(current.x, current.y - 1)
		]

		for next_pos in neighbors:
			if not is_valid_cell(next_pos):
				continue
			if is_solid(next_pos):
				continue
			if occupied_positions.has(next_pos) and next_pos != start:
				continue

			var new_dist = dist + 1
			if not visited.has(next_pos) or new_dist < visited[next_pos]:
				visited[next_pos] = new_dist
				queue.append([next_pos, new_dist])

	return reachable

func get_path_cells(from_pos: Vector2i, to_pos: Vector2i) -> Array[Vector2i]:
	var points = astar.get_id_path(from_pos, to_pos)
	var result: Array[Vector2i] = []
	for p in points:
		result.append(p)
	return result

func clear_highlights() -> void:
	highlighted_move_cells.clear()
	highlighted_attack_cells.clear()
	highlighted_laser_cells.clear()
	queue_redraw()

func set_move_highlights(cells: Array[Vector2i]) -> void:
	highlighted_move_cells = cells
	queue_redraw()

func set_attack_highlights(cells: Array[Vector2i]) -> void:
	highlighted_attack_cells = cells
	queue_redraw()

func set_laser_highlights(cells: Array[Vector2i]) -> void:
	highlighted_laser_cells = cells
	queue_redraw()

func set_hover_cell(pos: Vector2i) -> void:
	if hovered_cell != pos:
		hovered_cell = pos
		queue_redraw()

func _draw() -> void:
	# 绘制背景与所有地块
	for y in range(ROWS):
		for x in range(COLS):
			var cell = Vector2i(x, y)
			var pos = grid_to_world(cell)
			var rect = Rect2(pos, CELL_SIZE)
			var tile_type = map_tiles[y][x]
			_draw_tile(rect, tile_type, cell)

	# 绘制可移动格子高亮 (青蓝色)
	var alpha_pulse = 0.35 + 0.12 * sin(pulse_time)
	var border_pulse = 0.7 + 0.25 * sin(pulse_time)
	for cell in highlighted_move_cells:
		var pos = grid_to_world(cell)
		var rect = Rect2(pos + Vector2(2, 2), CELL_SIZE - Vector2(4, 4))
		draw_rect(rect, Color(0.18, 0.62, 0.95, alpha_pulse))
		draw_rect(rect, Color(0.35, 0.85, 1.0, border_pulse), false, 2.0)

	# 绘制可攻击/威胁格子高亮 (猩红色)
	for cell in highlighted_attack_cells:
		var pos = grid_to_world(cell)
		var rect = Rect2(pos + Vector2(2, 2), CELL_SIZE - Vector2(4, 4))
		draw_rect(rect, Color(0.92, 0.22, 0.22, alpha_pulse))
		draw_rect(rect, Color(1.0, 0.45, 0.45, border_pulse), false, 2.0)

	# 绘制全图青龙大招激光贯穿高亮 (神级金绿光束)
	for cell in highlighted_laser_cells:
		var pos = grid_to_world(cell)
		var rect = Rect2(pos + Vector2(2, 2), CELL_SIZE - Vector2(4, 4))
		draw_rect(rect, Color(0.2, 0.95, 0.45, 0.45 + 0.15 * sin(pulse_time * 2.0)))
		draw_rect(rect, Color(0.9, 1.0, 0.3, 0.9), false, 3.0)

	# 绘制鼠标悬停光标框
	if is_valid_cell(hovered_cell):
		var h_pos = grid_to_world(hovered_cell)
		draw_rect(Rect2(h_pos + Vector2(1, 1), CELL_SIZE - Vector2(2, 2)), Color(1.0, 1.0, 0.5, 0.7), false, 2.0)

func _draw_tile(rect: Rect2, tile_type: int, cell: Vector2i) -> void:
	match tile_type:
		0: # 平原
			var bg_color = Color(0.15, 0.20, 0.15) if (cell.x + cell.y) % 2 == 0 else Color(0.18, 0.23, 0.17)
			draw_rect(rect, bg_color)
			draw_rect(rect, Color(0.24, 0.30, 0.23, 0.5), false, 1.0)
		1: # 跑马道 (外围加速跑道)
			var bg_color = Color(0.40, 0.31, 0.18) if (cell.x + cell.y) % 2 == 0 else Color(0.45, 0.35, 0.20)
			draw_rect(rect, bg_color)
			draw_rect(rect, Color(0.70, 0.58, 0.32, 0.8), false, 1.5)
			# 跑道导向箭头小标
			var center = rect.position + rect.size * 0.5
			draw_circle(center, 4.0, Color(0.9, 0.8, 0.4, 0.6))
		2: # 盟军营寨
			draw_rect(rect, Color(0.22, 0.28, 0.40))
			draw_rect(rect, Color(0.40, 0.55, 0.80, 0.8), false, 2.0)
			# 军营斜十字栅栏纹理
			draw_line(rect.position + Vector2(8, 8), rect.position + rect.size - Vector2(8, 8), Color(0.4, 0.6, 0.85, 0.4), 2.0)
			draw_line(rect.position + Vector2(rect.size.x - 8, 8), rect.position + Vector2(8, rect.size.y - 8), Color(0.4, 0.6, 0.85, 0.4), 2.0)
		3: # 汜水关城门 (Boss关隘)
			draw_rect(rect, Color(0.45, 0.14, 0.14))
			draw_rect(rect, Color(0.80, 0.25, 0.25, 0.9), false, 3.0)
			# 铁门栅栏线
			var quarter_w = rect.size.x / 4.0
			for i in range(1, 4):
				var lx = rect.position.x + i * quarter_w
				draw_line(Vector2(lx, rect.position.y + 4), Vector2(lx, rect.position.y + rect.size.y - 4), Color(0.2, 0.08, 0.08, 0.9), 3.0)
		4: # 城墙 / 边界障碍
			draw_rect(rect, Color(0.11, 0.11, 0.15))
			draw_rect(rect, Color(0.20, 0.20, 0.26, 0.8), false, 1.0)
			# 砖墙凹凸纹理
			var mid_y = rect.position.y + rect.size.y * 0.5
			draw_line(Vector2(rect.position.x, mid_y), Vector2(rect.position.x + rect.size.x, mid_y), Color(0.18, 0.18, 0.24), 1.5)
