extends Reference


# this class exists entirely to be preloaded by Util.gd so we can get all the classes
# using load() because static functions don't have any way to reference their own
# class or script path...
func _init(db: Dictionary):
	var path := get_script().resource_path.get_base_dir() as String
	db.ArrayModel = load(path.plus_file("ArrayModel.gd"))
	db.DataModel = load(path.plus_file("DataModel.gd"))
