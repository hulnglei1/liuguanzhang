class_name UnitArtLoader
extends RefCounted
## 战场单位贴图加载器（美术资源可后补）
##
## 目录约定：res://assets/units/
##   文件名：{unit_id}.png     例如 guanyu.png / lubu.png / dao_bing_1.png
##   透明 PNG，建议 192×192（2× 于 52px 格子），人物脚底对齐画布底边、水平居中
##
## 有图 → 用贴图替换色块底盘与书法字，仅保留阵营边框与血条
## 无图 → 自动回退到现有的色块 + 书法字渲染（补图不需要改任何代码）

const DIR := "res://assets/units/"


static func load_for(unit_id: String) -> Texture2D:
	var key := unit_id.strip_edges()
	if key.is_empty():
		return null
	var path := DIR + key + ".png"
	if ResourceLoader.exists(path):
		var tex = load(path)
		if tex is Texture2D:
			return tex
	return null


static func has_art(unit_id: String) -> bool:
	return load_for(unit_id) != null


## 加载单位序列帧（SpriteFrames）
## 目录约定：
##   assets/units/{unit_id}_idle/0.png 1.png …     呼吸/待机循环
##   assets/units/{unit_id}_attack/0.png 1.png …   攻击（单次播放）
## 只要有 idle 或 attack 任一序列帧就返回 SpriteFrames；都没有则返回 null（回退静态图/色块）
## 注意：按索引顺序探测文件，不用 DirAccess 列目录 —— 那样在导出的 pck 包里读不到文件
static func load_frames_for(unit_id: String) -> SpriteFrames:
	var key := unit_id.strip_edges()
	if key.is_empty():
		return null
	var idle_frames := _load_frame_dir(DIR + key + "_idle/")
	var attack_frames := _load_frame_dir(DIR + key + "_attack/")
	if idle_frames.is_empty() and attack_frames.is_empty():
		return null
	var static_tex := load_for(key)

	var sf := SpriteFrames.new()
	# 1. 待机（呼吸）循环
	sf.add_animation("idle")
	sf.set_animation_speed("idle", 3.0)
	sf.set_animation_loop("idle", true)
	if not idle_frames.is_empty():
		for f in idle_frames:
			sf.add_frame("idle", f)
	elif static_tex != null:
		sf.add_frame("idle", static_tex)
	else:
		sf.add_frame("idle", attack_frames[0])
	# 2. 攻击（单次）
	sf.add_animation("attack")
	sf.set_animation_speed("attack", 6.0)
	sf.set_animation_loop("attack", false)
	if not attack_frames.is_empty():
		for f in attack_frames:
			sf.add_frame("attack", f)
	else:
		# 没做攻击帧的单位：attack 用 idle 首帧占位，保证动作名存在，调用方不用判空
		sf.add_frame("attack", sf.get_frame_texture("idle", 0))
	return sf


## 按索引顺序加载一个目录里的序列帧（0.png / 00.png …），遇到断档即停
static func _load_frame_dir(dir_path: String, max_frames: int = 24) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	for i in range(max_frames):
		var found: Texture2D = null
		for cand in ["%d.png" % i, "%02d.png" % i]:
			var p: String = dir_path + cand
			if ResourceLoader.exists(p):
				var res = load(p)
				if res is Texture2D:
					found = res
					break
		if found == null:
			if i == 0:
				continue          # 允许从 1.png 起编号
			break
		out.append(found)
	return out
