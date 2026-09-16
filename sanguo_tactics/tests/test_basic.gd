extends SceneTree

func _init() -> void:
	print("Checking scripts/unit_manager.gd...")
	var scr = load("res://scripts/unit_manager.gd")
	if scr == null:
		print("Failed loading unit_manager.gd")
		quit(1)
		return
	print("Successfully loaded unit_manager.gd!")
	quit(0)
