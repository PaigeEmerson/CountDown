class_name NewspaperUI
extends CanvasLayer

enum NewspaperState {
	MAIN_MENU,
	LOADING,
	PAUSE,
	RESULTS
}

@export_group("Newspaper Regions")
@export var main_menu_region := Rect2(0.0, 0.0, 1924.0, 1110.0)
@export var loading_region := Rect2(0.0, 1110.0, 1924.0, 1110.0)
@export var pause_region := Rect2(1924.0, 1110.0, 1925.0, 1110.0)
@export var results_region := Rect2(1924.0, 0.0, 1925.0, 1110.0)

@export_group("Animation")
@export var slide_duration := 0.65
@export var pan_duration := 0.75

@onready var screen_mask: Control = $ScreenMask
@onready var newspaper_canvas: Control = $ScreenMask/NewspaperCanvas
@onready var main_menu_controls: Control = $ScreenMask/NewspaperCanvas/MainMenuControls
@onready var loading_controls: Control = $ScreenMask/NewspaperCanvas/LoadingControls
@onready var pause_controls: Control = $ScreenMask/NewspaperCanvas/PauseControls
@onready var results_controls: Control = $ScreenMask/NewspaperCanvas/ResultsControls
@onready var start_button: Button = $ScreenMask/NewspaperCanvas/MainMenuControls/VBoxContainer/StartButton
@onready var main_quit_button: Button = $ScreenMask/NewspaperCanvas/MainMenuControls/VBoxContainer/QuitButton
@onready var loading_label: Label = $ScreenMask/NewspaperCanvas/LoadingControls/LoadingLabel
@onready var resume_button: Button = $ScreenMask/NewspaperCanvas/PauseControls/VBoxContainer/ResumeButton
@onready var restart_button: Button = $ScreenMask/NewspaperCanvas/PauseControls/VBoxContainer/RestartButton
@onready var pause_main_menu_button: Button = $ScreenMask/NewspaperCanvas/PauseControls/VBoxContainer/MainMenuButton
@onready var pause_quit_button: Button = $ScreenMask/NewspaperCanvas/PauseControls/VBoxContainer/QuitButton
@onready var tape_audio: AudioStreamPlayer = $PhoneCallPlayer

var tape_pending_for_game_start := true

signal results_continue_requested

@export var case_count_entry_scene: PackedScene

@onready var results_headline: Label = $ScreenMask/NewspaperCanvas/ResultsControls/VBoxContainer/HeadlineLabel
@onready var results_subheadline: Label = $ScreenMask/NewspaperCanvas/ResultsControls/VBoxContainer/SubheadlineLabel
@onready var count_list: VBoxContainer = $ScreenMask/NewspaperCanvas/ResultsControls/VBoxContainer/CaseScroll/CountList
@onready var results_summary: Label = $ScreenMask/NewspaperCanvas/ResultsControls/VBoxContainer/SummaryLabel
@onready var results_continue_button: Button = $ScreenMask/NewspaperCanvas/ResultsControls/VBoxContainer/ContinueButton
@onready var menu_click_audio: AudioStreamPlayer = $MenuClickAudio

var current_state := NewspaperState.MAIN_MENU
var active_tween: Tween
var is_open := false
var is_animating := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_controls_enabled(false)

	connect_menu_button_sounds()

	start_button.pressed.connect(_on_start_pressed)
	main_quit_button.pressed.connect(_on_quit_pressed)

	resume_button.pressed.connect(_on_resume_pressed)
	restart_button.pressed.connect(_on_restart_pressed)
	pause_main_menu_button.pressed.connect(_on_pause_main_menu_pressed)
	pause_quit_button.pressed.connect(_on_quit_pressed)

	results_continue_button.pressed.connect(_on_results_continue_pressed)

	await get_tree().process_frame

	set_state_immediately(NewspaperState.MAIN_MENU)
	is_open = true
	

func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return

	if not event.is_action_pressed("release_mouse"):
		return

	if get_tree().current_scene == null:
		return

	if get_tree().current_scene.scene_file_path != "res://game/scenes/game_scene.tscn":
		return

	if is_animating:
		return

	if CleanupManager.has_active_task():
		return

	if not RunManager.run_active:
		return

	get_viewport().set_input_as_handled()

	if is_open and current_state == NewspaperState.PAUSE:
		resume_game()
	else:
		pause_game()


func set_state_immediately(state: NewspaperState) -> void:
	current_state = state
	update_newspaper_scale()

	var target_position := get_canvas_position_for_state(state)
	newspaper_canvas.position = target_position

	set_controls_enabled(true)
	set_active_controls(state)


func show_from_game(state: NewspaperState) -> void:
	if is_animating:
		return

	show()
	current_state = state
	is_open = true
	is_animating = true

	update_newspaper_scale()
	set_controls_enabled(false)
	set_active_controls(state)

	var target_position := get_canvas_position_for_state(state)
	var viewport_height := get_viewport().get_visible_rect().size.y

	newspaper_canvas.position = target_position + Vector2(0.0, viewport_height)

	kill_active_tween()
	active_tween = create_tween()
	active_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	active_tween.set_trans(Tween.TRANS_QUART)
	active_tween.set_ease(Tween.EASE_OUT)
	active_tween.tween_property(newspaper_canvas, "position", target_position, slide_duration)

	await active_tween.finished

	is_animating = false
	set_controls_enabled(true)


func hide_to_game(play_pending_tape := false) -> void:
	if is_animating or not is_open:
		return

	is_animating = true
	set_controls_enabled(false)

	var viewport_height := get_viewport().get_visible_rect().size.y
	var hidden_position := newspaper_canvas.position + Vector2(
		0.0,
		viewport_height
	)

	kill_active_tween()
	active_tween = create_tween()
	active_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	active_tween.set_trans(Tween.TRANS_QUART)
	active_tween.set_ease(Tween.EASE_IN)
	active_tween.tween_property(
		newspaper_canvas,
		"position",
		hidden_position,
		slide_duration
	)

	if play_pending_tape and tape_pending_for_game_start:
		tape_pending_for_game_start = false
		play_tape()

	await active_tween.finished

	is_open = false
	is_animating = false
	hide()


func move_to_state(state: NewspaperState) -> void:
	if is_animating or state == current_state:
		return

	is_animating = true
	current_state = state
	set_controls_enabled(false)
	set_active_controls(state)

	var target_position := get_canvas_position_for_state(state)

	kill_active_tween()
	active_tween = create_tween()
	active_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	active_tween.set_trans(Tween.TRANS_QUART)
	active_tween.set_ease(Tween.EASE_IN_OUT)
	active_tween.tween_property(newspaper_canvas, "position", target_position, pan_duration)

	await active_tween.finished

	is_animating = false
	set_controls_enabled(true)


func get_canvas_position_for_state(state: NewspaperState) -> Vector2:
	var region := get_region_for_state(state)
	var viewport_size := get_viewport().get_visible_rect().size
	var scaled_region_size := region.size * newspaper_canvas.scale
	var centering_offset := (viewport_size - scaled_region_size) * 0.5

	return centering_offset - region.position * newspaper_canvas.scale


func get_region_for_state(state: NewspaperState) -> Rect2:
	match state:
		NewspaperState.MAIN_MENU:
			return main_menu_region

		NewspaperState.LOADING:
			return loading_region

		NewspaperState.PAUSE:
			return pause_region

		NewspaperState.RESULTS:
			return results_region

	return main_menu_region


func update_newspaper_scale() -> void:
	var region := get_region_for_state(current_state)
	var viewport_size := get_viewport().get_visible_rect().size

	var scale_factor: float = max(
		viewport_size.x / region.size.x,
		viewport_size.y / region.size.y
	)

	newspaper_canvas.scale = Vector2.ONE * scale_factor


func set_active_controls(state: NewspaperState) -> void:
	main_menu_controls.visible = state == NewspaperState.MAIN_MENU
	loading_controls.visible = state == NewspaperState.LOADING
	pause_controls.visible = state == NewspaperState.PAUSE
	results_controls.visible = state == NewspaperState.RESULTS


func set_controls_enabled(enabled: bool) -> void:
	main_menu_controls.mouse_filter = Control.MOUSE_FILTER_PASS if enabled else Control.MOUSE_FILTER_IGNORE
	pause_controls.mouse_filter = Control.MOUSE_FILTER_PASS if enabled else Control.MOUSE_FILTER_IGNORE
	results_controls.mouse_filter = Control.MOUSE_FILTER_PASS if enabled else Control.MOUSE_FILTER_IGNORE


func kill_active_tween() -> void:
	if active_tween and active_tween.is_valid():
		active_tween.kill()

	active_tween = null
	
	
func _on_start_pressed() -> void:
	if is_animating:
		return

	start_button.disabled = true
	main_quit_button.disabled = true

	await move_to_state(NewspaperState.LOADING)

	var error := get_tree().change_scene_to_file(
		"res://game/scenes/game_scene.tscn"
	)

	if error != OK:
		push_error("Could not load game_scene.tscn. Error: %s" % error)
		set_state_immediately(NewspaperState.MAIN_MENU)
		enable_main_menu_buttons()


func _on_quit_pressed() -> void:
	if is_animating:
		return

	await get_tree().create_timer(
		0.1,
		true,
		false,
		true
	).timeout

	get_tree().quit()


func enable_main_menu_buttons() -> void:
	start_button.disabled = false
	main_quit_button.disabled = false
	
	
func set_loading_message(message: String) -> void:
	loading_label.text = message
	
	
func pause_game() -> void:
	if is_open or is_animating:
		return

	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	await show_from_game(NewspaperState.PAUSE)

	if not is_animating:
		resume_button.grab_focus()


func resume_game() -> void:
	if not is_open or is_animating:
		return

	await hide_to_game()

	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	
func _on_resume_pressed() -> void:
	if is_animating:
		return

	resume_game()


func _on_restart_pressed() -> void:
	if is_animating:
		return

	await move_to_state(NewspaperState.LOADING)

	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	var error := get_tree().change_scene_to_file(
		"res://game/scenes/game_scene.tscn"
	)

	if error != OK:
		push_error("Could not restart the game scene. Error: %s" % error)


func _on_pause_main_menu_pressed() -> void:
	if is_animating:
		return

	await move_to_state(NewspaperState.MAIN_MENU)

	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	enable_main_menu_buttons()

	var error := get_tree().change_scene_to_file(
		"res://game/scenes/main_menu.tscn"
	)

	if error != OK:
		push_error("Could not load the main menu. Error: %s" % error)
		
		
func display_case_results(headline: String, subheadline: String, records: Array[Dictionary], summary: String, unresolved_disposition: String, button_text: String) -> void:
	clear_case_count_entries()

	results_headline.text = headline
	results_subheadline.text = subheadline
	results_summary.text = summary
	results_continue_button.text = button_text

	for record in records:
		var entry := case_count_entry_scene.instantiate() as CaseCountEntry

		if not entry:
			push_error("Case count entry scene must use CaseCountEntry.")
			continue

		count_list.add_child(entry)
		entry.setup(record, unresolved_disposition)

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if is_open:
		await move_to_state(NewspaperState.RESULTS)
	else:
		await show_from_game(NewspaperState.RESULTS)

	if not is_animating:
		results_continue_button.grab_focus()


func clear_case_count_entries() -> void:
	for child in count_list.get_children():
		child.queue_free()


func _on_results_continue_pressed() -> void:
	if is_animating:
		return

	results_continue_requested.emit()
	
	
func connect_menu_button_sounds() -> void:
	for node in newspaper_canvas.find_children("*", "BaseButton", true, false):
		var button := node as BaseButton

		if not button:
			continue

		if not button.pressed.is_connected(_play_menu_click):
			button.pressed.connect(_play_menu_click)


func _play_menu_click() -> void:
	if not menu_click_audio.stream:
		return

	menu_click_audio.play()
	
	
func play_tape() -> void:
	if not tape_audio.stream:
		push_warning("TapeAudio does not have an audio stream.")
		return

	tape_audio.stop()
	tape_audio.play()
	
	
func queue_tape_for_next_game_start() -> void:
	tape_pending_for_game_start = true
