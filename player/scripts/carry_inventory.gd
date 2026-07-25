class_name CarryInventory
extends Node

signal inventory_changed(current_count: int, maximum_count: int)
signal active_item_changed(item: CarryableEvidence)
signal inventory_cleared(disposed_count: int)
signal pickup_failed(message: String)
signal item_used(message: String)

@export_range(1, 10, 1) var capacity := 3
@export var held_item_anchor: Marker3D

var carried_items: Array[CarryableEvidence] = []
var capacity_bonus := 0


func _ready() -> void:
	add_to_group("player_inventory")

	if not held_item_anchor:
		push_error("CarryInventory requires a HeldItemAnchor.")

	inventory_changed.emit(carried_items.size(), get_effective_capacity())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return

	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return

	if event.is_action_pressed("use_held_item"):
		use_active_item()
		get_viewport().set_input_as_handled()


func can_carry_item() -> bool:
	return carried_items.size() < get_effective_capacity()


func try_add_item(item: CarryableEvidence) -> bool:
	if not item or not is_instance_valid(item):
		return false

	if item in carried_items:
		return false

	if not can_carry_item():
		pickup_failed.emit("Inventory Full. Dispose of evidence in the trashcan at the front entrance.")
		return false

	if not held_item_anchor:
		push_error("CarryInventory requires a HeldItemAnchor.")
		return false

	carried_items.append(item)
	item.move_to_inventory(held_item_anchor)
	update_visible_item()

	inventory_changed.emit(carried_items.size(), get_effective_capacity())
	return true


func use_active_item() -> void:
	var active_item := get_active_item()

	if not active_item:
		return

	if active_item is DrugEvidence:
		var drug := active_item as DrugEvidence
		drug.consume(self)


func consume_item(item: CarryableEvidence, result_message: String) -> void:
	if not item or item not in carried_items:
		return

	carried_items.erase(item)
	update_visible_item()

	CleanupManager.complete_evidence(item)

	inventory_changed.emit(carried_items.size(), get_effective_capacity())
	item_used.emit(result_message)


func clear_inventory() -> int:
	if carried_items.is_empty():
		return 0

	var items_to_dispose := carried_items.duplicate()
	var disposed_count := items_to_dispose.size()

	carried_items.clear()
	active_item_changed.emit(null)

	for item in items_to_dispose:
		if item and is_instance_valid(item):
			CleanupManager.complete_evidence(item)

	inventory_changed.emit(0, get_effective_capacity())
	inventory_cleared.emit(disposed_count)

	return disposed_count


func update_visible_item() -> void:
	for index in carried_items.size():
		var item := carried_items[index]
		var should_be_visible := index == carried_items.size() - 1

		if item and is_instance_valid(item):
			item.set_held_item_visible(should_be_visible)

	active_item_changed.emit(get_active_item())


func get_active_item() -> CarryableEvidence:
	if carried_items.is_empty():
		return null

	return carried_items.back()


func set_capacity_bonus(value: int) -> void:
	capacity_bonus = max(value, 0)
	inventory_changed.emit(carried_items.size(), get_effective_capacity())


func get_effective_capacity() -> int:
	return capacity + capacity_bonus


func get_item_count() -> int:
	return carried_items.size()


func is_empty() -> bool:
	return carried_items.is_empty()
