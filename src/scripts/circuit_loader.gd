extends Node

# Circuit data loader (autoload).
# Scans res://circuits/*.circuit.json at startup, loads them as Dictionary.
# Other scripts read CircuitLoader.current_circuit() for tunable parameters.
#
# v0.16.2 — foundation only. Circuits define data; engine still uses hardcoded
# values from Track01.tscn / decor.gd / race_manager.gd. Future versions
# will progressively wire each parameter to the loader (arches, ramps, decor seed, etc.)

const CIRCUITS_DIR := "res://circuits/"

var available: Array[Dictionary] = []
var current_index: int = 0


func _ready() -> void:
	_scan()


func _scan() -> void:
	available.clear()
	var dir: DirAccess = DirAccess.open(CIRCUITS_DIR)
	if dir == null:
		push_warning("CircuitLoader: cannot open %s" % CIRCUITS_DIR)
		return
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if fname.ends_with(".circuit.json"):
			var circuit: Dictionary = _load_circuit(CIRCUITS_DIR + fname)
			if not circuit.is_empty():
				available.append(circuit)
		fname = dir.get_next()
	dir.list_dir_end()
	# Sort by name for stable order
	available.sort_custom(func(a, b): return a.get("name", "") < b.get("name", ""))
	if available.is_empty():
		push_warning("CircuitLoader: no .circuit.json found in %s" % CIRCUITS_DIR)
	else:
		print("CircuitLoader: loaded %d circuits — %s" % [available.size(), _names()])


func _load_circuit(path: String) -> Dictionary:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_warning("CircuitLoader: cannot open %s" % path)
		return {}
	var content: String = f.get_as_text()
	f.close()
	var json: JSON = JSON.new()
	var err: int = json.parse(content)
	if err != OK:
		push_warning("CircuitLoader: JSON parse error in %s — %s" % [path, json.get_error_message()])
		return {}
	var data = json.data
	if not (data is Dictionary):
		push_warning("CircuitLoader: %s root is not an object" % path)
		return {}
	(data as Dictionary)["_source_path"] = path
	return data as Dictionary


func _names() -> String:
	var names: Array[String] = []
	for c in available:
		names.append(c.get("name", "?"))
	return ", ".join(names)


func current_circuit() -> Dictionary:
	if available.is_empty():
		return {}
	return available[clamp(current_index, 0, available.size() - 1)]


func set_circuit_by_name(name: String) -> bool:
	for i in range(available.size()):
		if available[i].get("name", "") == name:
			current_index = i
			return true
	return false


func cycle_next() -> Dictionary:
	if available.is_empty():
		return {}
	current_index = (current_index + 1) % available.size()
	return current_circuit()
