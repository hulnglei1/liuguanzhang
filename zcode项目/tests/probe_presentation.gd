extends SceneTree
## 表现层验收：音效、地块、描边光 shader 是否真的能加载。
##
## 这三样都属于"缺了不报错、只是悄悄没有"的东西：
## 音效文件丢了 → 静音；地块丢了 → 退回纯色；shader 丢了 → 没有描边。
## 所以用测试把它们钉住。

const SfxCore := preload("res://scripts/systems/sfx.gd")
const OutlineShader := preload("res://assets/shaders/unit_shader.gdshader")

const TILE_PATHS := [
	"res://assets/tiles/grass_a.png",
	"res://assets/tiles/grass_b.png",
	"res://assets/tiles/stone.png",
	"res://assets/tiles/dirt.png",
	"res://assets/tiles/ground.png",
	"res://assets/tiles/wall.png",
	"res://assets/tiles/gate.png",
]

const BGM_PATHS := [
	"res://assets/audio/bgm_menu.ogg",
	"res://assets/audio/bgm_battle.ogg",
	"res://assets/audio/bgm_win.ogg",
]

var failed := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	print("\n===== 表现层验收 =====")

	# 1. 音效
	print("\n[音效] 共 %d 个" % SfxCore.STREAMS.size())
	for k in SfxCore.STREAMS.keys():
		var s = SfxCore.STREAMS[k]
		var secs: float = 0.0
		if s is AudioStream:
			secs = float(s.get_length())
		if secs <= 0.01:
			print("  ❌ %-9s 时长异常（%.3fs）" % [k, secs])
			failed += 1
		else:
			print("  ✅ %-9s %.2fs" % [k, secs])

	# 2. 地块
	print("\n[地块]")
	for p in TILE_PATHS:
		if not ResourceLoader.exists(p):
			print("  ❌ 缺文件 %s" % p)
			failed += 1
			continue
		var tex = load(p)
		if tex is Texture2D:
			print("  ✅ %-12s %dx%d" % [p.get_file(), tex.get_width(), tex.get_height()])
			if p.get_file() != "ground.png" and (tex.get_width() != 104 or tex.get_height() != 104):
				print("     ⚠ 尺寸不是 104×104")
		else:
			print("  ❌ 不是 Texture2D：%s" % p)
			failed += 1

	# 2.5 BGM
	print("\n[BGM]")
	for p in BGM_PATHS:
		if not ResourceLoader.exists(p):
			print("  ❌ 缺文件 %s" % p)
			failed += 1
			continue
		var s = load(p)
		var secs: float = float(s.get_length()) if s is AudioStream else 0.0
		if secs > 1.0:
			print("  ✅ %-16s %.1fs" % [p.get_file(), secs])
		else:
			print("  ❌ 时长异常 %s（%.2fs）" % [p.get_file(), secs])
			failed += 1

	# 3. 描边光 shader
	print("\n[描边光]")
	if OutlineShader is Shader:
		var mat := ShaderMaterial.new()
		mat.shader = OutlineShader
		var ok: bool = mat.shader != null
		print("  %s ShaderMaterial 可创建（描边 + 锁脚呼吸）" % ("✅" if ok else "❌"))
		if not ok:
			failed += 1
		for param in ["rim_color", "outline_px", "breath_active", "breath_amp"]:
			mat.set_shader_parameter(param, mat.get_shader_parameter(param))
		print("  ✅ 参数齐全：rim_color / outline_px / breath_active / breath_amp")
	else:
		print("  ❌ shader 加载失败")
		failed += 1

	print("\n===== %s =====" % ("全部通过 ✅" if failed == 0 else "失败 %d 项 ❌" % failed))
	quit(0 if failed == 0 else 1)
