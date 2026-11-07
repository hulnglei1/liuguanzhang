extends SceneTree
## 美术覆盖率验收：确保"关卡里会出现的每个单位"都有战场贴图，
## 每个会说话的主将都有立绘；缺图时明确报出来（而不是默默回退色块）。
##
## 这条测试的价值：美术是一张张补的，缺一张不会报错、只会退化成色块，
## 肉眼很难发现（尤其小兵）。用测试兜住。

const UnitArtCore := preload("res://scripts/ui/unit_art.gd")
const PortraitCore := preload("res://scripts/ui/portrait_loader.gd")

const CHAPTERS := ["chapter1", "chapter2", "chapter3", "chapter4", "chapter5"]
const SPEAKING := ["liubei", "guanyu", "zhangfei", "zhaoyun",
	"gongsunzan", "wuanguo", "huaxiong", "lubu", "xuchu", "zangba", "changxi"]

var failed := 0


func _initialize() -> void:
	_run()


func _load_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _run() -> void:
	print("\n===== 美术覆盖率验收 =====")

	var used := {}
	for ch in CHAPTERS:
		var d := _load_json("res://data/chapters/%s.json" % ch)
		for key in ["player_spawn", "enemy_spawn"]:
			for s in d.get(key, []):
				used[str(s.get("unit", ""))] = true
	var ids: Array = used.keys()
	ids.sort()

	var miss_units: Array[String] = []
	for uid in ids:
		if not UnitArtCore.has_art(str(uid)):
			miss_units.append(str(uid))

	print("关卡用到的单位：%d 种，有战场贴图：%d 种" % [ids.size(), ids.size() - miss_units.size()])
	if miss_units.is_empty():
		print("  ✅ 战场贴图全覆盖")
	else:
		print("  ❌ 缺贴图：%s" % ", ".join(PackedStringArray(miss_units)))
		failed += miss_units.size()

	var miss_port: Array[String] = []
	for uid in SPEAKING:
		if not PortraitCore.has_portrait(str(uid)):
			miss_port.append(str(uid))
	print("台词主将：%d 位，有立绘：%d 位" % [SPEAKING.size(), SPEAKING.size() - miss_port.size()])
	if miss_port.is_empty():
		print("  ✅ 立绘覆盖全部台词主将")
	else:
		print("  ❌ 缺立绘：%s" % ", ".join(PackedStringArray(miss_port)))
		failed += miss_port.size()

	# 序列帧动画：有则报帧数，没有不算失败（单图 + 代码动效是允许的降级）
	var animated: Array[String] = []
	for uid in ids:
		var sf: SpriteFrames = UnitArtCore.load_frames_for(str(uid))
		if sf != null:
			animated.append("%s(idle %d/attack %d)" % [
				uid, sf.get_frame_count("idle"), sf.get_frame_count("attack")])
	print("带序列帧动画：%s" % ("、".join(PackedStringArray(animated)) if not animated.is_empty() else "（无）"))

	print("\n===== %s =====" % ("全部通过 ✅" if failed == 0 else "失败 %d 项 ❌" % failed))
	quit(0 if failed == 0 else 1)
