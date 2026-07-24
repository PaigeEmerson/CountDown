extends CharacterBody3D

@export_group("Movement")
@export var walk_speed := 5.0
@export var sprint_speed := 8.0
@export var acceleration := 20.0
@export var air_acceleration := 6.0
@export var jump_velocity := 5.0

@export_group("Mouse Look")
@export var mouse_sensitivity := 0.002
@export_range(1.0, 89.0, 1.0) var maximum_look_angle := 89.0

@onready var head: Node3D = $Head

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var movement_enabled := true
var camera_look_enabled := true
var cleanup_active := false



func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	CleanupManager.cleanup_started.connect(_on_cleanup_started)
	CleanupManager.cleanup_ended.connect(_on_cleanup_ended)
	RunManager.run_escaped.connect(_on_run_escaped)
	CampaignManager.campaign_ended.connect(_on_campaign_ended)
	

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and camera_look_enabled:
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-maximum_look_angle), deg_to_rad(maximum_look_angle))
		
	if cleanup_active:
		return
		
	if event.is_action_pressed("release_mouse"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	apply_gravity(delta)
	
	if movement_enabled:
		handle_jump()
		handle_movement(delta)
	else:
		stop_horizontal_movement(delta)
		
	move_and_slide()
	
	
func apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
		
		
func handle_jump() -> void:
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity
		
		
func handle_movement(delta: float) -> void:
	var input_direction := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var movement_direction := (transform.basis * Vector3(input_direction.x, 0.0, input_direction.y)).normalized()
	var target_speed := sprint_speed if Input.is_action_pressed("sprint") else walk_speed
	var current_acceleration := acceleration if is_on_floor() else air_acceleration
	
	if movement_direction:
		velocity.x = move_toward(velocity.x, movement_direction.x * target_speed, current_acceleration * delta)
		velocity.z = move_toward(velocity.z, movement_direction.z * target_speed, current_acceleration * delta)
	else:
		stop_horizontal_movement(delta)
		
func stop_horizontal_movement(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
	velocity.z = move_toward(velocity.z, 0.0, acceleration * delta)
	
	
func _on_cleanup_started(task: CleanupTask) -> void:
	cleanup_active = true
	movement_enabled = not task.lock_player_movement
	camera_look_enabled = not task.lock_camera_look
	
	
func _on_cleanup_ended() -> void:
	cleanup_active = false
	movement_enabled = true
	camera_look_enabled = true
	velocity = Vector3.ZERO
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	
func _on_run_escaped(_remaining_crimes: int, _cleaned_crimes: int) -> void:
	lock_for_results()


func _on_campaign_ended(_caught_by_police: bool) -> void:
	lock_for_results()


func lock_for_results() -> void:
	cleanup_active = true
	movement_enabled = false
	camera_look_enabled = false
	velocity = Vector3.ZERO
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
