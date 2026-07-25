class_name HUD
extends CanvasLayer

@export var crime_entry_scene: PackedScene

@onready var crime_list: VBoxContainer = $CrimePanel/CrimeList
@onready var inventory_panel: MarginContainer = $InventoryPanel
@onready var inventory_label: Label = $InventoryPanel/InventoryLabel
@onready var notification_panel: MarginContainer = $NotificationPanel
@onready var notification_label: Label = $NotificationPanel/NotificationLabel
@onready var use_item_prompt: MarginContainer = $UseItemPrompt
@onready var use_item_label: Label = $UseItemPrompt/UseItemLabel

var crime_entries := {}
var notification_queue: Array[Dictionary] = []
var notification_active := false
var player_inventory: CarryInventory
var current_notification_message := ""


func _ready() -> void:
	notification_panel.hide()
	inventory_panel.hide()
	use_item_prompt.hide()

	RunManager.crime_counts_changed.connect(_on_crime_counts_changed)
	RunManager.notification_requested.connect(_on_notification_requested)

	call_deferred("_connect_to_player_inventory")


func _connect_to_player_inventory() -> void:
	player_inventory = get_tree().get_first_node_in_group("player_inventory") as CarryInventory

	if not player_inventory:
		push_warning("HUD could not find the player's CarryInventory.")
		return

	player_inventory.inventory_changed.connect(_on_inventory_changed)
	player_inventory.pickup_failed.connect(_on_inventory_pickup_failed)
	player_inventory.inventory_cleared.connect(_on_inventory_cleared)
	player_inventory.active_item_changed.connect(_on_active_item_changed)
	player_inventory.item_used.connect(_on_inventory_item_used)

	_on_inventory_changed(player_inventory.get_item_count(), player_inventory.capacity)
	_on_inventory_changed(player_inventory.get_item_count(), player_inventory.get_effective_capacity())
	_on_active_item_changed(player_inventory.get_active_item())


func _on_inventory_changed(current_count: int, maximum_count: int) -> void:
	inventory_label.text = "Carrying: %d / %d" % [current_count, maximum_count]

	if current_count > 0:
		inventory_panel.show()
	else:
		inventory_panel.hide()


func _on_inventory_pickup_failed(message: String) -> void:
	_on_notification_requested(message, 1.5)


func _on_inventory_cleared(disposed_count: int) -> void:
	var noun := "item" if disposed_count == 1 else "items"
	var message := "Disposed of %d evidence %s" % [disposed_count, noun]
	_on_notification_requested(message, 2.0)


func _on_crime_counts_changed(counts: Dictionary) -> void:
	var crime_types: Array[CrimeTypeData] = []

	for crime_type in counts.keys():
		if crime_type is CrimeTypeData:
			crime_types.append(crime_type)

	crime_types.sort_custom(sort_crime_types)

	for crime_type in crime_types:
		if not crime_entries.has(crime_type):
			create_crime_entry(crime_type)

		var entry := crime_entries[crime_type] as CrimeListEntry
		entry.update_count(counts[crime_type])

	reorder_entries(crime_types)


func create_crime_entry(crime_type: CrimeTypeData) -> void:
	if not crime_entry_scene:
		push_error("HUD requires a CrimeListEntry scene.")
		return

	var entry := crime_entry_scene.instantiate() as CrimeListEntry

	if not entry:
		push_error("Crime entry scene must use CrimeListEntry.")
		return

	crime_list.add_child(entry)
	entry.setup(crime_type)
	crime_entries[crime_type] = entry


func reorder_entries(crime_types: Array[CrimeTypeData]) -> void:
	for index in range(crime_types.size()):
		var entry := crime_entries[crime_types[index]] as CrimeListEntry
		crime_list.move_child(entry, index)


func sort_crime_types(a: CrimeTypeData, b: CrimeTypeData) -> bool:
	return a.display_order < b.display_order


func _on_notification_requested(message: String, display_duration: float) -> void:
	if message == current_notification_message:
		return

	for queued_notification in notification_queue:
		if queued_notification["message"] == message:
			return

	notification_queue.append({
		"message": message,
		"duration": display_duration
	})

	if not notification_active:
		show_next_notification()
		

func show_next_notification() -> void:
	if notification_queue.is_empty():
		notification_active = false
		current_notification_message = ""
		notification_panel.hide()
		return

	notification_active = true

	var notification: Dictionary = notification_queue.pop_front()
	current_notification_message = notification["message"]
	notification_label.text = current_notification_message
	notification_panel.modulate.a = 0.0
	notification_panel.show()

	var fade_in := create_tween()
	fade_in.tween_property(notification_panel, "modulate:a", 1.0, 0.2)
	await fade_in.finished

	await get_tree().create_timer(notification["duration"]).timeout

	var fade_out := create_tween()
	fade_out.tween_property(notification_panel, "modulate:a", 0.0, 0.3)
	await fade_out.finished

	current_notification_message = ""
	show_next_notification()
	
	
func _on_active_item_changed(item: CarryableEvidence) -> void:
	if item is DrugEvidence:
		use_item_label.text = "[F] Use %s" % item.evidence_name
		use_item_prompt.show()
	else:
		use_item_prompt.hide()


func _on_inventory_item_used(message: String) -> void:
	_on_notification_requested(message, 2.5)
