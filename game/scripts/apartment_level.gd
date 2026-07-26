class_name ApartmentLevel
extends Node3D

@export var run_duration := 180.0

@onready var apartment_generator: ApartmentGenerator = $ApartmentGenerator

var generated_room_count := 0
var player: CharacterBody3D


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	NewspaperInterface.show()
	NewspaperInterface.set_state_immediately(
		NewspaperUI.NewspaperState.LOADING
	)
	NewspaperInterface.set_loading_message("Assembling apartment...")

	apartment_generator.room_placed.connect(_on_room_placed)

	var generation_succeeded := await apartment_generator.generate_apartment()

	if generation_succeeded:
		await finish_loading()
	else:
		await handle_generation_failure()


func _on_room_placed(_room: RoomModule) -> void:
	generated_room_count += 1

	NewspaperInterface.set_loading_message(
		"Assembling apartment... %d rooms placed" % generated_room_count
	)

	if not player:
		find_and_disable_player()


func find_and_disable_player() -> void:
	player = get_tree().get_first_node_in_group("player") as CharacterBody3D

	if not player:
		return

	player.process_mode = Node.PROCESS_MODE_DISABLED
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func finish_loading() -> void:
	if not player:
		player = get_tree().get_first_node_in_group("player") as CharacterBody3D

	if not player:
		push_error("Apartment generation completed without creating a Player.")
		await handle_generation_failure()
		return

	await get_tree().process_frame

	var evidence_count := get_tree().get_nodes_in_group("crime_evidence").size()
	print("Evidence before starting run: ", evidence_count)

	if evidence_count == 0:
		push_error("The apartment generated without registering any evidence.")
		await handle_generation_failure()
		return

	NewspaperInterface.set_loading_message("Apartment ready")

	await get_tree().create_timer(0.35).timeout
	await NewspaperInterface.hide_to_game(true)

	player.process_mode = Node.PROCESS_MODE_INHERIT
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	RunManager.start_run(run_duration)


func handle_generation_failure() -> void:
	push_error("The apartment run could not start because generation failed.")

	NewspaperInterface.set_loading_message(
		"Apartment generation failed. Returning to the main menu..."
	)

	await get_tree().create_timer(2.0).timeout
	await NewspaperInterface.move_to_state(
		NewspaperUI.NewspaperState.MAIN_MENU
	)

	NewspaperInterface.enable_main_menu_buttons()
	get_tree().change_scene_to_file("res://game/scenes/main_menu.tscn")
