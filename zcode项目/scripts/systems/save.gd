class_name SaveCore
extends RefCounted
## 存档与玩家进度（纯逻辑，可无头测试）
## 管理：声望 prestige、背包 inventory、图鉴 collection、通关 chapters
## 持久化到 user://save.json

## 默认初始存档
static func new_state() -> Dictionary:
	return {
		"prestige": 0,
		"inventory": {},      # item_id -> 数量
		"collection": {},     # 图鉴：key -> true（武将/技能/名场面）
		"chapters": [],       # 已通关章节
		"prologues_seen": [], # 已观看过序章过场的章节
	}

static func load_state() -> Dictionary:
	var f := FileAccess.open("user://save.json", FileAccess.READ)
	if f == null:
		return new_state()
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return new_state()
	# 合并默认字段，避免缺字段
	var st := new_state()
	for k in st.keys():
		if parsed.has(k):
			st[k] = parsed[k]
	# 保留存档里默认表之外的扩展字段（避免旧版本新增字段被静默丢弃）
	for k in parsed.keys():
		if not st.has(k):
			st[k] = parsed[k]
	return st

static func save_state(st: Dictionary) -> void:
	var f := FileAccess.open("user://save.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(st))

## 增加声望（占郡）
static func add_prestige(st: Dictionary, amount: int) -> void:
	st["prestige"] = int(st.get("prestige", 0)) + amount

## 抽奖扣声望 + 道具入背包；返回是否成功
static func award_item(st: Dictionary, item: Dictionary, cost: int) -> bool:
	if int(st.get("prestige", 0)) < cost:
		return false
	st["prestige"] = int(st.get("prestige", 0)) - cost
	var inv: Dictionary = st.get("inventory", {})
	var iid: String = item.get("id", "?")
	inv[iid] = int(inv.get(iid, 0)) + 1
	st["inventory"] = inv
	return true

## 解锁图鉴条目
static func collect(st: Dictionary, key: String) -> void:
	if key != "":
		st["collection"][key] = true

## 标记章节通关
static func mark_chapter(st: Dictionary, id: String) -> void:
	var ch: Array = st.get("chapters", [])
	if id not in ch:
		ch.append(id)
	st["chapters"] = ch

## 图鉴已收集条目
static func collected(st: Dictionary) -> Array:
	return st.get("collection", {}).keys()