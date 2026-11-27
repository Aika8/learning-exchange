## LE-410 (issue #93): the 3D client has no Mara harbour line under HARBOUR_MARA — Mara speaks through talk.csv.
## No script or scene reads the key, and the catalogue does not carry it as dead weight.
## (The 2D client keeps its own HARBOUR_MARA in game/i18n/strings.csv; that file is not looked at here.)
extends GutTest

const KEY := "HARBOUR_MARA"
const ROOTS := ["res://scripts", "res://scenes"]


## Every .gd / .tscn file under dir, recursively.
func _files(dir: String, out: PackedStringArray) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd") or f.ends_with(".tscn"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		_files(dir.path_join(d), out)


func test_no_script_or_scene_reads_the_key() -> void:
	var files := PackedStringArray()
	for root: String in ROOTS:
		_files(root, files)
	assert_gt(files.size(), 10, "the scan found the scripts and scenes")
	for path in files:
		var src := FileAccess.get_file_as_string(path)
		assert_false(src.contains(KEY), "%s reads %s" % [path, KEY])


func test_catalogue_has_no_such_key() -> void:
	var cat := Locale.load_catalogue(Locale.CATALOGUE)
	for lang: String in ["ru", "en"]:
		var t: Translation = cat[lang]
		var keys: Array = []
		for k: StringName in t.get_message_list():
			keys.append(str(k))
		assert_gt(keys.size(), 50)
		assert_does_not_have(keys, KEY, "%s catalogue still has %s" % [lang, KEY])
