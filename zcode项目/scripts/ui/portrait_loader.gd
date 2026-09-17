class_name PortraitLoader
extends RefCounted
## 立绘加载器（美术资源可后补）
##
## 目录约定：res://assets/portraits/
##   文件名：{unit_id}_{emotion}.png    例如 guanyu_normal.png / guanyu_angry.png / zhangfei_roar.png
##   透明背景 PNG，建议 900×1200（3:4），人物居中、脚底对齐画布底边
##   emotion 缺省为 normal；找不到对应表情时会自动回退到 {unit_id}_normal.png
##
## 缺图时 load_for() 返回 null，调用方自行回退到色块占位 —— 所以补图不需要改任何代码。

const DIR := "res://assets/portraits/"

## 说话人名 -> 单位 id（对话 JSON 里只写了中文名时的兜底映射）
const SPEAKER_TO_ID := {
	"刘备": "liubei", "关羽": "guanyu", "张飞": "zhangfei", "赵云": "zhaoyun",
	"公孙瓒": "gongsunzan", "武安国": "wuanguo", "许褚": "xuchu",
	"华雄": "huaxiong", "吕布": "lubu", "臧霸": "zangba", "昌豨": "changxi",
	"曹操": "caocao", "袁绍": "yuanshao", "系统": "system",
}


## 取立绘贴图；找不到返回 null
static func load_for(unit_id: String, emotion: String = "normal") -> Texture2D:
	var key := unit_id.strip_edges()
	if key.is_empty():
		return null
	var candidates: Array[String] = []
	if not emotion.is_empty() and emotion != "normal":
		candidates.append(key + "_" + emotion)
	candidates.append(key + "_normal")
	candidates.append(key)
	for fname in candidates:
		var path := DIR + fname + ".png"
		if ResourceLoader.exists(path):
			var tex = load(path)
			if tex is Texture2D:
				return tex
	return null


## 该角色是否已有立绘（UI 可据此决定要不要给立绘留位置）
static func has_portrait(unit_id: String) -> bool:
	return load_for(unit_id, "normal") != null


## 从对话行解析应该显示谁的立绘：优先行内 portrait 字段，其次说话人名映射
static func resolve_key(line: Dictionary) -> String:
	var explicit := str(line.get("portrait", ""))
	if not explicit.is_empty():
		return explicit
	var speaker := str(line.get("speaker", ""))
	return SPEAKER_TO_ID.get(speaker, "")


## 从对话行解析表情
static func resolve_emotion(line: Dictionary) -> String:
	var emo := str(line.get("emotion", ""))
	if not emo.is_empty():
		return emo
	# 原作对话里的口头情绪标记 -> 表情名
	match str(line.get("mood", "")):
		"怒": return "angry"
		"喜", "笑": return "happy"
		"悲": return "sad"
		"惊": return "shock"
		_: return "normal"
