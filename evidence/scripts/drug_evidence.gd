class_name DrugEvidence
extends CarryableEvidence

enum DrugEffectType {
	SPEED_BOOST,
	WARPED_VISION,
	CARRY_CAPACITY
}

@export_group("Possible Effects")
@export_flags("Speed Boost", "Warped Vision", "Carry Capacity") var possible_effects := 7

@export_group("Effect Settings")
@export_range(1.0, 60.0, 0.5) var effect_duration := 12.0
@export_range(1.0, 3.0, 0.1) var speed_multiplier := 1.5
@export_range(0.1, 3.0, 0.1) var vision_warp_strength := 1.0
@export_range(1, 5, 1) var additional_capacity := 2

var random := RandomNumberGenerator.new()


func _ready() -> void:
	super._ready()
	random.randomize()


func consume(source_inventory: CarryInventory) -> void:
	if not source_inventory:
		return

	var status_effects := get_tree().get_first_node_in_group("player_status_effects") as PlayerStatusEffects

	if not status_effects:
		push_error("Could not find PlayerStatusEffects.")
		return

	var available_effects := get_available_effects()

	if available_effects.is_empty():
		push_warning("%s has no possible drug effects enabled." % name)
		return

	var selected_index := random.randi_range(0, available_effects.size() - 1)
	var selected_effect: DrugEffectType = available_effects[selected_index]
	var result_message := ""

	match selected_effect:
		DrugEffectType.SPEED_BOOST:
			status_effects.apply_speed_boost(speed_multiplier, effect_duration)
			result_message = "Speed Increased"

		DrugEffectType.WARPED_VISION:
			status_effects.apply_warped_vision(vision_warp_strength, effect_duration)
			result_message = "You don't feel well"

		DrugEffectType.CARRY_CAPACITY:
			status_effects.apply_capacity_boost(additional_capacity, effect_duration)
			result_message = "Carry Capacity +%d" % additional_capacity

	source_inventory.consume_item(self, result_message)


func get_available_effects() -> Array[DrugEffectType]:
	var effects: Array[DrugEffectType] = []

	if possible_effects & (1 << DrugEffectType.SPEED_BOOST):
		effects.append(DrugEffectType.SPEED_BOOST)

	if possible_effects & (1 << DrugEffectType.WARPED_VISION):
		effects.append(DrugEffectType.WARPED_VISION)

	if possible_effects & (1 << DrugEffectType.CARRY_CAPACITY):
		effects.append(DrugEffectType.CARRY_CAPACITY)

	return effects
