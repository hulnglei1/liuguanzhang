class_name GridCore
extends RefCounted
## 网格核心：BFS 移动范围 + 路径计算（纯逻辑，无渲染依赖，可无头测试）

const DIRS4: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
]

## 格子是否在地图内
static func in_bounds(cell: Vector2i, w: int, h: int) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < w and cell.y < h

## 计算从 start 出发，移动力 mov 内所有可到达格（BFS，忽略障碍）
## 返回: Dictionary[Vector2i -> int]  格子 -> 最短步数
static func reachable(start: Vector2i, mov: int, w: int, h: int, blocked: Array[Vector2i] = []) -> Dictionary:
	var blocked_set := {}
	for c in blocked:
		blocked_set[c] = true
	# 起点本身被占时不可用
	if blocked_set.has(start):
		return {}
	var dist := {}
	var queue: Array[Vector2i] = [start]
	dist[start] = 0
	var idx := 0
	while idx < queue.size():
		var cur: Vector2i = queue[idx]
		idx += 1
		var d: int = dist[cur]
		if d >= mov:
			continue
		for dir in DIRS4:
			var nxt: Vector2i = cur + dir
			if not in_bounds(nxt, w, h):
				continue
			if blocked_set.has(nxt):
				continue
			if dist.has(nxt):
				continue
			dist[nxt] = d + 1
			queue.append(nxt)
	return dist

## 从 start 到 goal 的 BFS 最短路径（不含起点，含终点），不可达返回 []
static func path(start: Vector2i, goal: Vector2i, w: int, h: int, blocked: Array[Vector2i] = []) -> Array[Vector2i]:
	if start == goal:
		return []
	var blocked_set := {}
	for c in blocked:
		blocked_set[c] = true
	var prev := {}
	var queue: Array[Vector2i] = [start]
	var seen := {start: true}
	var idx := 0
	while idx < queue.size():
		var cur: Vector2i = queue[idx]
		idx += 1
		for dir in DIRS4:
			var nxt: Vector2i = cur + dir
			if not in_bounds(nxt, w, h):
				continue
			if blocked_set.has(nxt) or seen.has(nxt):
				continue
			prev[nxt] = cur
			if nxt == goal:
				# 回溯路径
				var path_cells: Array[Vector2i] = []
				var walk: Vector2i = goal
				while walk != start:
					path_cells.push_front(walk)
					walk = prev[walk]
				return path_cells
			seen[nxt] = true
			queue.append(nxt)
	return []

## 曼哈顿距离
static func manhattan(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)

## 切比雪夫距离（用于技能范围）
static func chebyshev(a: Vector2i, b: Vector2i) -> int:
	return max(abs(a.x - b.x), abs(a.y - b.y))

## 技能范围：以 center 为中心、半径 radius（切比雪夫）内的所有格（不含障碍之外的判断，仅几何）
static func cells_in_radius(center: Vector2i, radius: int, w: int, h: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var c := center + Vector2i(dx, dy)
			if in_bounds(c, w, h) and chebyshev(center, c) <= radius:
				out.append(c)
	return out

## 直线贯穿格点：从 start 向 target 方向投射一条直线（用于青龙偃月贯穿AOE）
static func line_cells(start: Vector2i, target: Vector2i, max_len: int, w: int, h: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if start == target:
		return out
	var diff := target - start
	var step_x := 0
	var step_y := 0
	if abs(diff.x) > abs(diff.y) * 2:
		step_x = 1 if diff.x > 0 else -1
		step_y = 0
	elif abs(diff.y) > abs(diff.x) * 2:
		step_x = 0
		step_y = 1 if diff.y > 0 else -1
	else:
		step_x = 1 if diff.x > 0 else (-1 if diff.x < 0 else 0)
		step_y = 1 if diff.y > 0 else (-1 if diff.y < 0 else 0)
	
	var dir := Vector2i(step_x, step_y)
	var cur := start
	for i in range(max_len):
		cur += dir
		if in_bounds(cur, w, h):
			out.append(cur)
		else:
			break
	return out
