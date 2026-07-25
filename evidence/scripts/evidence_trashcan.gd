class_name EvidenceTrashCan
extends Interactable

@export var empty_prompt := "Trash can is empty"
@export var dispose_prompt := "Dispose carried evidence"


func _ready() -> void:
	interaction_prompt = dispose_prompt


func get_interaction_prompt() -> String:
	var inventory := get_player_inventory()

	if not inventory or inventory.is_empty():
		return empty_prompt

	return "%s (%d)" % [dispose_prompt, inventory.get_item_count()]


func interact() -> void:
	if not can_interact():
		return

	var inventory := get_player_inventory()

	if not inventory or inventory.is_empty():
		return

	var disposed_count := inventory.clear_inventory()

	if disposed_count > 0:
		interacted.emit(self)


func get_player_inventory() -> CarryInventory:
	return get_tree().get_first_node_in_group("player_inventory") as CarryInventory
