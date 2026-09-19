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


## 加载单位序列帧动画配置（SpriteFrames）
## 若存在攻击序列帧，构建包含 "idle" 和 "attack" 动作的 SpriteFrames
## 若无序列帧，返回 null
static func load_frames_for(unit_id: String) -> SpriteFrames:
	var key := unit_id.strip_edges()
	if key.is_empty():
		return null
	
	var attack_dir := DIR + key + "_attack/"
	var idle_tex := load_for(key)
	
	# 检索攻击帧
	var attack_frames: Array[Texture2D] = []
	for i in range(16):
		var candidates := [
			attack_dir + str(i) + ".png",
			attack_dir + "%s_attack_sheet_%02d.png" % [key, i],
			attack_dir + "%s_attack_%d.png" % [key, i],
			DIR + "%s_attack_%d.png" % [key, i],
			attack_dir + "%s_attack_%02d.png" % [key, i]
		]
		var found_tex: Texture2D = null
		for p in candidates:
			if ResourceLoader.exists(p):
				var res = load(p)
				if res is Texture2D:
					found_tex = res
					break
		if found_tex != null:
			attack_frames.append(found_tex)
		else:
			if i > 0 and attack_frames.is_empty():
				break
			elif i > 0 and not attack_frames.is_empty():
				break

	if attack_frames.is_empty():
		return null

	var sf := SpriteFrames.new()
	# 1. 待机动作 (idle)
	sf.add_animation("idle")
	sf.set_animation_speed("idle", 2.0)
	sf.set_animation_loop("idle", true)
	if idle_tex != null:
		sf.add_frame("idle", idle_tex)
	else:
		sf.add_frame("idle", attack_frames[0])

	# 2. 攻击动作 (attack)：9 fps，单次播放
	sf.add_animation("attack")
	sf.set_animation_speed("attack", 9.0)
	sf.set_animation_loop("attack", false)
	for f in attack_frames:
		sf.add_frame("attack", f)

	return sf
