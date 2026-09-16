class_name GridCore
extends RefCounted
## 网格核心：BFS 移动范围 + 路径计算（纯逻辑，无渲染依赖，可无头测试）

const DIRS4: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
]

const DIRS8: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
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

## 直线贯穿格点：从 start 指向 target 的方向，以 target 为起点向后贯穿 line_len 格
static func line_cells(start: Vector2i, target: Vector2i, line_len: int, w: int, h: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if start == target or line_len <= 0:
		return out
	var diff := target - start
	var step_x := 0
	var step_y := 0
	if abs(diff.x) >= abs(diff.y):
		step_x = 1 if diff.x > 0 else -1
	else:
		step_y = 1 if diff.y > 0 else -1
	var dir := Vector2i(step_x, step_y)
	
	# 被攻击点本身必定在内
	var cur := target
	if in_bounds(cur, w, h):
		out.append(cur)
	# 沿该方向贯穿后面的一条线
	for i in range(1, line_len):
		cur += dir
		if in_bounds(cur, w, h):
			out.append(cur)
		else:
			break
	return out

## 曹操传攻击判定：目标是否在攻击者的普攻范围内
## - 骑兵（is_cavalry）：十字 4 向，不可斜打（当 rng == 1 时）
## - 步兵（非骑兵且 rng == 1）：周围 8 向，可斜打
## - 远程（rng >= 2）：切比雪夫距离 <= rng
static func can_attack(attacker_cell: Vector2i, target_cell: Vector2i, is_cavalry: bool, rng: int) -> bool:
	if attacker_cell == target_cell:
		return false
	if rng >= 2:
		return chebyshev(attacker_cell, target_cell) <= rng
	if is_cavalry:
		return (target_cell - attacker_cell) in DIRS4
	else:
		return chebyshev(attacker_cell, target_cell) <= 1

## 获取普攻覆盖的所有合法地图格子（用于高亮显示）
static func get_attack_cells(center: Vector2i, is_cavalry: bool, rng: int, w: int, h: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if rng >= 2:
		for dy in range(-rng, rng + 1):
			for dx in range(-rng, rng + 1):
				var c := center + Vector2i(dx, dy)
				if in_bounds(c, w, h) and chebyshev(center, c) <= rng and c != center:
					out.append(c)
	elif is_cavalry:
		for dir in DIRS4:
			var c := center + dir
			if in_bounds(c, w, h):
				out.append(c)
	else:
		for dir in DIRS8:
			var c := center + dir
			if in_bounds(c, w, h):
				out.append(c)
	return out
