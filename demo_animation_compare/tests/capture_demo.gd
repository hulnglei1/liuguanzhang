extends SceneTree

var main_scene: Control
var frame_idx: int = 0
var max_frames: int = 60
var out_dir = "d:/huanglei/deepseek/game/demo_animation_compare/captured_frames"

func _init() -> void:
	print("Initializing demo capture runner...")
	DirAccess.make_dir_recursive_absolute(out_dir)
	var sc = load("res://main.tscn")
	main_scene = sc.instantiate()
	root.add_child(main_scene)

func _process(delta: float) -> bool:
	frame_idx += 1
	
	# Phase 1: Idle (frames 1-15)
	if frame_idx == 1:
		main_scene.play_idle_demo()
	# Phase 2: Normal Attack (frames 16-35)
	elif frame_idx == 16:
		main_scene.play_normal_attack()
	# Phase 3: Ultimate Attack (frames 36-55)
	elif frame_idx == 36:
		main_scene.play_ultimate_attack()
		
	if frame_idx <= max_frames:
		var img = root.get_viewport().get_texture().get_image()
		if img and not img.is_empty():
			img.save_png(out_dir + "/frame_%03d.png" % frame_idx)
	else:
		print("Capture complete! Total frames:", max_frames)
		quit()
		return true
	return false
