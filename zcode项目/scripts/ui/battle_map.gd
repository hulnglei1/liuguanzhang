class_name BattleMapView
extends RefCounted
## 战场地图渲染层：地面 / 格线 / 高地 / 障碍物。
##
## 从 battle.gd 抽出来的第一批（原来是 3500 行里的 UI 绘制段）。
## 只负责"把地图画出来"，不碰任何战斗规则；坐标由调用方传入，
## 这样它既能在战斗场景用，也能在编辑器预览/测试里单独调。

const TILE_GROUND := preload("res://assets/tiles/ground.png")
const TILE_GROUND_FIRE := preload("res://assets/tiles/ground_fire.png")
const TILE_STONE := preload("res://assets/tiles/stone.png")
const TILE_WALL := preload("res://assets/tiles/wall.png")
const TILE_GATE := preload("res://assets/tiles/gate.png")


## 一整张连续地面 + 极淡格线
## variant: "grass"（默认）/ "fire"（洛阳火场）
static func draw_grid(grid_node: Node, offset: Vector2, tile: float, w: int, h: int, variant: String = "grass") -> void:
	for c in grid_node.get_children():
		c.queue_free()

	var ground := TextureRect.new()
	ground.name = "Ground"
	ground.texture = TILE_GROUND_FIRE if variant == "fire" else TILE_GROUND
	ground.stretch_mode = TextureRect.STRETCH_SCALE
	ground.size = Vector2(w * tile, h * tile)
	ground.position = offset
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid_node.add_child(ground)

	for x in range(w + 1):
		var vline := ColorRect.new()
		vline.color = Color(0, 0, 0, 0.075)
		vline.size = Vector2(1.0, h * tile)
		vline.position = offset + Vector2(x * tile, 0)
		vline.mouse_filter = Control.MOUSE_FILTER_IGNORE
		grid_node.add_child(vline)
	for y in range(h + 1):
		var hline := ColorRect.new()
		hline.color = Color(0, 0, 0, 0.075)
		hline.size = Vector2(w * tile, 1.0)
		hline.position = offset + Vector2(0, y * tile)
		hline.mouse_filter = Control.MOUSE_FILTER_IGNORE
		grid_node.add_child(hline)


## 高地 / 山砦：石质贴图，略微压暗以融进连续地面
static func draw_hills(map_root: Node2D, hills: Array, offset: Vector2, tile: float) -> void:
	for h in hills:
		var cell: Vector2i = h
		var rect := TextureRect.new()
		rect.texture = TILE_STONE
		rect.stretch_mode = TextureRect.STRETCH_SCALE
		rect.size = Vector2(tile - 2.0, tile - 2.0)
		rect.position = offset + Vector2(cell.x * tile + 1.0, cell.y * tile + 1.0)
		rect.modulate = Color(0.95, 0.90, 0.82, 0.88)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		map_root.add_child(rect)


## 障碍物（寨墙 / 关门）。返回 {Vector2i: Node2D}，调用方存起来做后续判定。
static func draw_obstacles(map_root: Node2D, obstacles: Array, offset: Vector2, tile: float, variant: String = "grass") -> Dictionary:
	var nodes: Dictionary = {}
	for o in obstacles:
		var pos := Vector2i(int(o.get("x", 0)), int(o.get("y", 0)))
		var is_gate: bool = bool(o.get("is_gate", false))
		var root := Node2D.new()
		root.position = offset + Vector2(pos.x * tile + tile / 2.0, pos.y * tile + tile / 2.0)
		root.z_index = 8

		var frame := ColorRect.new()
		frame.color = Color(0.05, 0.06, 0.08, 0.95)
		frame.size = Vector2(tile - 1.0, tile - 1.0)
		frame.position = Vector2(-tile * 0.5 + 0.5, -tile * 0.5 + 0.5)
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(frame)

		var tex_rect := TextureRect.new()
		tex_rect.texture = TILE_GATE if is_gate else TILE_WALL
		tex_rect.stretch_mode = TextureRect.STRETCH_SCALE
		tex_rect.size = Vector2(tile - 6.0, tile - 6.0)
		tex_rect.position = Vector2(-tile * 0.5 + 3.0, -tile * 0.5 + 3.0)
		tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if variant == "fire":
			tex_rect.modulate = Color(0.52, 0.40, 0.33)   # 火场里寨墙烧成焦黑
		root.add_child(tex_rect)

		var lbl := Label.new()
		lbl.text = "关门" if is_gate else "寨墙"
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.size = Vector2(tile, tile)
		lbl.position = Vector2(-tile * 0.5, -tile * 0.5)
		lbl.add_theme_font_size_override("font_size", 13 if is_gate else 12)
		lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45) if is_gate else Color(0.88, 0.90, 0.94))
		lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
		lbl.add_theme_constant_override("outline_size", 4)
		root.add_child(lbl)

		map_root.add_child(root)
		nodes[pos] = root
	return nodes
