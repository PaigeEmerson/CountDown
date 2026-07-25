class_name CarryableEvidence
extends Evidence

@export_group("Carrying")
@export var held_visual: Node3D
@export var held_position := Vector3.ZERO
@export var held_rotation_degrees := Vector3.ZERO
@export var held_scale := Vector3.ONE

var is_carried := false
var inventory: CarryInventory
var original_collision_layer := 0
var original_collision_mask := 0


func _ready() -> void:
	super._ready()

	interaction_prompt = "Pick up %s" % evidence_name
	original_collision_layer = collision_layer
	original_collision_mask = collision_mask

	if not held_visual:
		push_warning("%s does not have a Held Visual assigned." % name)


func interact() -> void:
	if not can_interact():
		return

	var player_inventory := get_tree().get_first_node_in_group("player_inventory") as CarryInventory

	if not player_inventory:
		push_error("Could not find the player's CarryInventory.")
		return

	if not player_inventory.try_add_item(self):
		return

	inventory = player_inventory
	is_carried = true
	interaction_enabled = false
	interacted.emit(self)


func move_to_inventory(anchor: Marker3D) -> void:
	is_carried = true
	interaction_enabled = false

	collision_layer = 0
	collision_mask = 0
	monitoring = false
	monitorable = false

	set_collision_shapes_enabled(false)

	reparent(anchor)
	position = held_position
	rotation_degrees = held_rotation_degrees
	scale = held_scale


func set_held_item_visible(value: bool) -> void:
	if held_visual:
		held_visual.visible = value
	else:
		visible = value


func set_collision_shapes_enabled(value: bool) -> void:
	for child in find_children("*", "CollisionShape3D", true, false):
		var collision_shape := child as CollisionShape3D
		collision_shape.set_deferred("disabled", not value)
