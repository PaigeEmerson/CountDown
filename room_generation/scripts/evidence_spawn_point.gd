class_name EvidenceSpawnPoint
extends Marker3D

enum PlacementType {
	FLOOR,
	TABLE
}

@export_group("Placement")
@export var placement_type := PlacementType.FLOOR

@export_group("Restrictions")
@export var excluded_crime_types: Array[CrimeTypeData] = []

var is_used := false


func can_spawn_evidence(evidence: Evidence) -> bool:
	if is_used:
		return false

	if not evidence:
		return false

	if evidence.crime_type and excluded_crime_types.has(evidence.crime_type):
		return false

	return evidence.can_spawn_on_surface(placement_type)


func mark_used() -> void:
	is_used = true


func reset_spawn_point() -> void:
	is_used = false
