extends Node

# Global track registry + selection. Used by Main.tscn to instance the active
# track at startup, and by the track picker button to cycle.

const TRACKS: Array[Dictionary] = [
	{"id": "pool_felt", "name": "Pool Felt", "scene": "res://scenes/tracks/Track_Pool_Felt.tscn"},
	{"id": "workshop",  "name": "Workshop",  "scene": "res://scenes/tracks/Track_Workshop.tscn"},
]

var current_track_index: int = 0


func current_track() -> Dictionary:
	return TRACKS[clamp(current_track_index, 0, TRACKS.size() - 1)]


func cycle_next() -> Dictionary:
	current_track_index = (current_track_index + 1) % TRACKS.size()
	return current_track()


func track_count() -> int:
	return TRACKS.size()
