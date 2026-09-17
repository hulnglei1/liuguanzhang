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
