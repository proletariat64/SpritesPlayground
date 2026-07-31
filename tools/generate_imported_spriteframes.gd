extends SceneTree

const DataStore := preload("res://godot/scripts/prd_v0_3_data_store.gd")
const Generator := preload("res://godot/scripts/spriteframes_generator.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		push_error("usage: generate_imported_spriteframes.gd -- <character_id>")
		quit(2)
		return
	var character_id := str(args[0])
	var bundle := DataStore.load_runtime_bundle(character_id)
	var errors := DataStore.validate_runtime_bundle(bundle)
	if not errors.is_empty():
		for error in errors:
			push_error(str(error))
		quit(1)
		return
	var result := Generator.generate(bundle["sprite_set"], {"moves": bundle["moves"]})
	if not bool(result.get("ok", false)):
		for error in result.get("errors", []):
			push_error(str(error))
		quit(1)
		return
	print("imported_spriteframes=PASS character=%s path=%s" % [character_id, result["path"]])
	quit(0)
