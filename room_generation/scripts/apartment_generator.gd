class_name ApartmentGenerator
extends Node3D

signal generation_started
signal room_placed(room: RoomModule)
signal generation_completed(rooms: Array[RoomModule])
signal generation_failed

@export_group("Rooms")
@export var starting_room_scene: PackedScene
@export var room_scenes: Array[PackedScene]
@export var generation_profile: ApartmentGenerationProfile

@export_group("Generation")
@export var generation_seed := 0
@export_range(1, 500, 1) var maximum_placement_attempts := 100

var generated_rooms: Array[RoomModule] = []
var blocked_connectors: Array[RoomConnector] = []
var random := RandomNumberGenerator.new()
var placement_attempts := 0
var target_room_count := 0


func generate_apartment() -> bool:
	if not generation_profile:
		push_error("ApartmentGenerator requires an ApartmentGenerationProfile.")
		generation_failed.emit()
		return false

	generation_started.emit()
	configure_random_seed()

	for retry in range(generation_profile.maximum_generation_retries):
		await clear_generated_rooms()

		target_room_count = random.randi_range(generation_profile.minimum_rooms, generation_profile.maximum_rooms)

		print("Generation attempt ", retry + 1, ". Target rooms: ", target_room_count)

		var starting_room := spawn_starting_room()

		if not starting_room:
			generation_failed.emit()
			return false

		await get_tree().physics_frame

		while generated_rooms.size() < target_room_count and placement_attempts < maximum_placement_attempts:
			placement_attempts += 1

			var target_connector := get_weighted_available_connector()

			if not target_connector:
				break

			var placement_succeeded := await try_place_room_at_connector(target_connector)

			if not placement_succeeded:
				blocked_connectors.append(target_connector)

		if layout_meets_requirements():
			await finalize_unused_connectors()

			print("Generated valid apartment with ", generated_rooms.size(), " rooms.")
			generation_completed.emit(generated_rooms)
			return true

		print("Layout failed requirements. Retrying.")

	await clear_generated_rooms()
	push_error("ApartmentGenerator failed to create a valid layout.")
	generation_failed.emit()
	return false


func configure_random_seed() -> void:
	if generation_seed == 0:
		random.randomize()
	else:
		random.seed = generation_seed


func spawn_starting_room() -> RoomModule:
	if not starting_room_scene:
		push_error("ApartmentGenerator requires a starting room scene.")
		return null

	var instance := starting_room_scene.instantiate()

	if not instance is RoomModule:
		push_error("Starting room scene must inherit from RoomModule.")
		instance.free()
		return null

	add_child(instance)
	instance.global_transform = global_transform
	instance.generation_depth = 0
	instance.parent_room = null

	generated_rooms.append(instance)
	room_placed.emit(instance)

	return instance


func try_place_room_at_connector(target_connector: RoomConnector) -> bool:
	var target_room := get_room_for_connector(target_connector)

	if not target_room:
		return false

	var candidate_depth := target_room.generation_depth + 1
	var required_sizes := get_unmet_room_sizes()
	var scene_indices := get_weighted_scene_order(required_sizes, candidate_depth, target_room)

	for scene_index in scene_indices:
		var room_scene := room_scenes[scene_index]
		var candidate := room_scene.instantiate()

		if not candidate is RoomModule:
			candidate.free()
			continue

		add_child(candidate)
		candidate.generation_depth = candidate_depth
		candidate.parent_room = target_room

		var candidate_connectors := get_compatible_connectors(candidate, target_connector)
		shuffle_connectors(candidate_connectors)

		for candidate_connector in candidate_connectors:
			align_room_connectors(candidate, candidate_connector, target_connector)
			await get_tree().physics_frame

			if not room_overlaps_existing_rooms(candidate):
				target_connector.connect_to(candidate_connector, true)
				candidate_connector.connect_to(target_connector, false)

				generated_rooms.append(candidate)
				room_placed.emit(candidate)

				print(
					"Placed ", candidate.room_name,
					" at depth ", candidate.generation_depth,
					". Rooms: ", generated_rooms.size(),
					" / ", target_room_count
				)

				return true

		candidate.queue_free()
		await get_tree().physics_frame

	return false


func get_weighted_scene_order(required_sizes: Array[int], candidate_depth: int, target_room: RoomModule) -> Array[int]:
	var available_indices: Array[int] = []
	var available_weights: Array[float] = []

	for index in range(room_scenes.size()):
		var preview := room_scenes[index].instantiate()

		if not preview is RoomModule:
			preview.free()
			continue

		if room_is_allowed(preview, required_sizes, candidate_depth, target_room):
			available_indices.append(index)
			available_weights.append(max(preview.generation_weight, 0.01))

		preview.free()

	var ordered_indices: Array[int] = []

	while not available_indices.is_empty():
		var selected_pool_index := choose_weighted_index(available_weights)
		ordered_indices.append(available_indices[selected_pool_index])
		available_indices.remove_at(selected_pool_index)
		available_weights.remove_at(selected_pool_index)

	return ordered_indices


func room_is_allowed(room: RoomModule, required_sizes: Array[int], candidate_depth: int, target_room: RoomModule) -> bool:
	if candidate_depth < room.minimum_depth or candidate_depth > room.maximum_depth:
		return false

	if not required_sizes.is_empty() and not required_sizes.has(room.room_size):
		return false

	if count_rooms_of_size(room.room_size) >= get_maximum_for_size(room.room_size):
		return false

	if room.maximum_instances > 0 and count_rooms_named(room.room_name) >= room.maximum_instances:
		return false

	if room.room_size == RoomModule.RoomSize.HALLWAY:
		if count_consecutive_hallways(target_room) >= generation_profile.maximum_consecutive_hallways:
			return false

	return true


func get_unmet_room_sizes() -> Array[int]:
	var unmet: Array[int] = []

	if count_rooms_of_size(RoomModule.RoomSize.SMALL) < generation_profile.minimum_small_rooms:
		unmet.append(RoomModule.RoomSize.SMALL)

	if count_rooms_of_size(RoomModule.RoomSize.MEDIUM) < generation_profile.minimum_medium_rooms:
		unmet.append(RoomModule.RoomSize.MEDIUM)

	if count_rooms_of_size(RoomModule.RoomSize.LARGE) < generation_profile.minimum_large_rooms:
		unmet.append(RoomModule.RoomSize.LARGE)

	if count_rooms_of_size(RoomModule.RoomSize.HALLWAY) < generation_profile.minimum_hallways:
		unmet.append(RoomModule.RoomSize.HALLWAY)

	return unmet


func get_weighted_available_connector() -> RoomConnector:
	var connectors: Array[RoomConnector] = []
	var weights: Array[float] = []
	var current_max_depth := get_maximum_generated_depth()

	for room in generated_rooms:
		for connector in room.get_available_connectors():
			if blocked_connectors.has(connector):
				continue

			var weight := 1.0

			match room.room_role:
				RoomModule.RoomRole.HUB:
					weight = 4.0
				RoomModule.RoomRole.HALLWAY:
					weight = 3.0
				RoomModule.RoomRole.STANDARD:
					weight = 1.5
				RoomModule.RoomRole.DEAD_END:
					weight = 0.25

			if current_max_depth < generation_profile.minimum_layout_depth:
				weight *= float(room.generation_depth + 1)

			connectors.append(connector)
			weights.append(weight)

	if connectors.is_empty():
		return null

	return connectors[choose_weighted_index(weights)]


func choose_weighted_index(weights: Array[float]) -> int:
	var total_weight := 0.0

	for weight in weights:
		total_weight += weight

	var roll := random.randf_range(0.0, total_weight)
	var accumulated := 0.0

	for index in range(weights.size()):
		accumulated += weights[index]

		if roll <= accumulated:
			return index

	return weights.size() - 1


func layout_meets_requirements() -> bool:
	if generated_rooms.size() < generation_profile.minimum_rooms:
		return false

	if count_rooms_of_size(RoomModule.RoomSize.SMALL) < generation_profile.minimum_small_rooms:
		return false

	if count_rooms_of_size(RoomModule.RoomSize.MEDIUM) < generation_profile.minimum_medium_rooms:
		return false

	if count_rooms_of_size(RoomModule.RoomSize.LARGE) < generation_profile.minimum_large_rooms:
		return false

	if count_rooms_of_size(RoomModule.RoomSize.HALLWAY) < generation_profile.minimum_hallways:
		return false

	if get_maximum_generated_depth() < generation_profile.minimum_layout_depth:
		return false

	return true


func count_rooms_of_size(size: RoomModule.RoomSize) -> int:
	var count := 0

	for room in generated_rooms:
		if room.room_size == size:
			count += 1

	return count


func count_rooms_named(target_name: String) -> int:
	var count := 0

	for room in generated_rooms:
		if room.room_name == target_name:
			count += 1

	return count


func get_maximum_for_size(size: RoomModule.RoomSize) -> int:
	match size:
		RoomModule.RoomSize.SMALL:
			return generation_profile.maximum_small_rooms
		RoomModule.RoomSize.MEDIUM:
			return generation_profile.maximum_medium_rooms
		RoomModule.RoomSize.LARGE:
			return generation_profile.maximum_large_rooms
		RoomModule.RoomSize.HALLWAY:
			return generation_profile.maximum_hallways

	return 999


func count_consecutive_hallways(room: RoomModule) -> int:
	var count := 0
	var current_room := room

	while current_room and current_room.room_size == RoomModule.RoomSize.HALLWAY:
		count += 1
		current_room = current_room.parent_room

	return count


func get_maximum_generated_depth() -> int:
	var maximum_depth := 0

	for room in generated_rooms:
		maximum_depth = max(maximum_depth, room.generation_depth)

	return maximum_depth


func get_room_for_connector(connector: RoomConnector) -> RoomModule:
	for room in generated_rooms:
		if room.is_ancestor_of(connector):
			return room

	return null


func align_room_connectors(room: RoomModule, room_connector: RoomConnector, target_connector: RoomConnector) -> void:
	var connector_relative_transform := room.global_transform.affine_inverse() * room_connector.global_transform
	var opposite_rotation := Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)
	var desired_connector_transform := target_connector.global_transform * opposite_rotation

	room.global_transform = desired_connector_transform * connector_relative_transform.affine_inverse()


func room_overlaps_existing_rooms(candidate: RoomModule) -> bool:
	var candidate_bounds := candidate.get_generation_bounds()

	if candidate_bounds.is_empty():
		push_warning("Room has no GenerationBounds: %s" % candidate.name)
		return true

	for bound_shape in candidate_bounds:
		var bound_area := bound_shape.get_parent() as Area3D

		if not bound_area:
			continue

		for overlapping_area in bound_area.get_overlapping_areas():
			if candidate.is_ancestor_of(overlapping_area):
				continue

			for existing_room in generated_rooms:
				if existing_room.is_ancestor_of(overlapping_area):
					return true

	return false


func get_compatible_connectors(room: RoomModule, target: RoomConnector) -> Array[RoomConnector]:
	var compatible: Array[RoomConnector] = []

	for connector in room.get_available_connectors():
		if connector.is_compatible_with(target):
			compatible.append(connector)

	return compatible


func shuffle_connectors(values: Array[RoomConnector]) -> void:
	for index in range(values.size() - 1, 0, -1):
		var random_index := random.randi_range(0, index)
		var temporary := values[index]
		values[index] = values[random_index]
		values[random_index] = temporary
		
		
func finalize_unused_connectors() -> void:
	await get_tree().physics_frame

	for room in generated_rooms:
		for connector in room.get_connectors():
			connector.finalize_unused_connector(random)

	await get_tree().physics_frame


func clear_generated_rooms() -> void:
	for room in generated_rooms:
		if room and is_instance_valid(room):
			room.queue_free()

	generated_rooms.clear()
	blocked_connectors.clear()
	placement_attempts = 0

	await get_tree().physics_frame
