extends SceneTree

var main_scene: Control
var frame_idx: int = 0
var max_frames: int = 100
var out_dir = "d:/huanglei/deepseek/game/demo_animation_compare/captured_frames"

func _init() -> void:
	print("Initializing full demo capture runner...")
	DirAccess.make_dir_recursive_absolute(out_dir)
	var dir = DirAccess.open(out_dir)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".png"):
				dir.remove(file_name)
			file_name = dir.get_next()
	
	var sc = load("res://main.tscn")
	main_scene = sc.instantiate()
	root.add_child(main_scene)

func _process(delta: float) -> bool:
	frame_idx += 1
	
	# Phase 1: Idle (frames 1-18)
	if frame_idx == 1:
		main_scene.play_idle_demo()
	# Phase 2: Normal Attack (frames 19-42)
	elif frame_idx == 19:
		main_scene.play_normal_attack()
	# Phase 3: Ultimate Attack (frames 43-78)
	elif frame_idx == 43:
		main_scene.play_ultimate_attack()
	# Phase 4: Portrait & Specs Card (frames 79-100)
	elif frame_idx == 79:
		main_scene.toggle_portrait_modal()
		
	if frame_idx <= max_frames:
		var img = root.get_viewport().get_texture().get_image()
		if img and not img.is_empty():
			img.save_png(out_dir + "/frame_%03d.png" % frame_idx)
	else:
		print("Capture complete! Total frames:", max_frames)
		quit()
		return true
	return false
