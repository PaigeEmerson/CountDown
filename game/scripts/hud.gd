class_name HUD
extends CanvasLayer

@export var crime_entry_scene: PackedScene

@export_group("Timer Colors")
@export var timer_normal_color := Color.WHITE
@export var timer_warning_color := Color(1.0, 0.65, 0.15)
@export var timer_critical_color := Color(0.9, 0.1, 0.1)
@export var timer_warning_threshold := 60.0
@export var timer_critical_threshold := 15.0

@onready var timer_panel: MarginContainer = $TimerPanel
@onready var timer_label: Label = $TimerPanel/TimerLabel

@onready var crime_list: VBoxContainer = $CrimePanel/CrimeList
@onready var inventory_panel: MarginContainer = $InventoryPanel
@onready var inventory_label: Label = $InventoryPanel/InventoryLabel
@onready var notification_panel: MarginContainer = $NotificationPanel
@onready var notification_label: Label = $NotificationPanel/NotificationLabel
@onready var use_item_prompt: MarginContainer = $UseItemPrompt
@onready var use_item_label: Label = $UseItemPrompt/UseItemLabel
@onready var timer_warning_audio: AudioStreamPlayer = $TimerWarningAudio

var critical_timer_warning_played := false

var crime_entries := {}
var notification_queue: Array[Dictionary] = []
var notification_active := false
var player_inventory: CarryInventory
var current_notification_message := ""


func _ready() -> void:
	notification_panel.hide()
	inventory_panel.hide()
	use_item_prompt.hide()
	timer_panel.hide()

	RunManager.crime_counts_changed.connect(_on_crime_counts_changed)
	RunManager.notification_requested.connect(_on_notification_requested)

	RunManager.run_started.connect(_on_run_started)
	RunManager.time_changed.connect(_on_time_changed)
	RunManager.run_escaped.connect(_on_run_escaped)
	CampaignManager.campaign_ended.connect(_on_campaign_ended)

	get_tree().node_added.connect(_on_scene_node_added)
	_connect_to_existing_inventory()


func _connect_to_existing_inventory() -> void:
	var existing_inventory := get_tree().get_first_node_in_group("player_inventory") as CarryInventory

	if existing_inventory:
		connect_to_inventory(existing_inventory)


func _on_scene_node_added(node: Node) -> void:
	if node is CarryInventory:
		connect_to_inventory(node as CarryInventory)


func connect_to_inventory(new_inventory: CarryInventory) -> void:
	if not new_inventory:
		return

	if new_inventory == player_inventory:
		return

	disconnect_from_current_inventory()
	player_inventory = new_inventory

	player_inventory.inventory_changed.connect(_on_inventory_changed)
	player_inventory.pickup_failed.connect(_on_inventory_pickup_failed)
	player_inventory.inventory_cleared.connect(_on_inventory_cleared)
	player_inventory.active_item_changed.connect(_on_active_item_changed)
	player_inventory.item_used.connect(_on_inventory_item_used)

	_on_inventory_changed(
		player_inventory.get_item_count(),
		player_inventory.get_effective_capacity()
	)

	_on_active_item_changed(player_inventory.get_active_item())


func disconnect_from_current_inventory() -> void:
	if not player_inventory or not is_instance_valid(player_inventory):
		player_inventory = null
		return

	if player_inventory.inventory_changed.is_connected(_on_inventory_changed):
		player_inventory.inventory_changed.disconnect(_on_inventory_changed)

	if player_inventory.pickup_failed.is_connected(_on_inventory_pickup_failed):
		player_inventory.pickup_failed.disconnect(_on_inventory_pickup_failed)

	if player_inventory.inventory_cleared.is_connected(_on_inventory_cleared):
		player_inventory.inventory_cleared.disconnect(_on_inventory_cleared)

	if player_inventory.active_item_changed.is_connected(_on_active_item_changed):
		player_inventory.active_item_changed.disconnect(_on_active_item_changed)

	if player_inventory.item_used.is_connected(_on_inventory_item_used):
		player_inventory.item_used.disconnect(_on_inventory_item_used)

	player_inventory = null


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
	
	
func _on_run_started(_starting_crimes: int) -> void:
	critical_timer_warning_played = false
	timer_warning_audio.stop()
	timer_panel.show()

	update_timer_display(RunManager.time_remaining)


func _on_time_changed(time_remaining: float) -> void:
	update_timer_display(time_remaining)


func update_timer_display(time_remaining: float) -> void:
	var total_seconds := int(ceil(max(time_remaining, 0.0)))
	var minutes := total_seconds / 60
	var seconds := total_seconds % 60

	timer_label.text = "POLICE ETA  %02d:%02d" % [minutes, seconds]

	if time_remaining <= RunManager.critical_time_threshold:
		timer_label.add_theme_color_override(
			"font_color",
			timer_critical_color
		)

		if not critical_timer_warning_played:
			critical_timer_warning_played = true
			timer_warning_audio.play()

	elif time_remaining <= timer_warning_threshold:
		timer_label.add_theme_color_override(
			"font_color",
			timer_warning_color
		)
	else:
		timer_label.add_theme_color_override(
			"font_color",
			timer_normal_color
		)


func _on_run_escaped(_remaining_crimes: int, _cleaned_crimes: int) -> void:
	timer_warning_audio.stop()
	timer_panel.hide()


func _on_campaign_ended(_caught_by_police: bool) -> void:
	timer_warning_audio.stop()
	timer_panel.hide()
