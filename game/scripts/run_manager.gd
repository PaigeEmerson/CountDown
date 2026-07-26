extends Node

signal run_started(starting_crimes: int)
signal time_changed(time_remaining: float)
signal evidence_count_changed(remaining: int, cleaned: int)
signal crime_counts_changed(counts: Dictionary)
signal all_crimes_cleaned
signal notification_requested(message: String, display_duration: float)
signal run_escaped(remaining_crimes: int, cleaned_crimes: int)
signal police_arrived

@export_group("Notifications")
@export var time_warning_thresholds: Array[float] = [60.0, 30.0, 10.0]
@export var notification_duration := 3.5
@export var critical_time_threshold := 30.0

var run_duration := 15.0
var time_remaining := 0.0
var starting_crime_count := 0
var run_active := false
var player_escaped := false

var tracked_crime_types: Array[CrimeTypeData] = []
var triggered_time_warnings: Array[float] = []
var all_cleaned_announced := false

var case_counts: Array[Dictionary] = []
var evidence_count_lookup: Dictionary = {}


func _ready() -> void:
	CleanupManager.cleanup_completed.connect(_on_cleanup_completed)


func _process(delta: float) -> void:
	if not run_active or CampaignManager.game_over:
		return

	var previous_time := time_remaining
	time_remaining = max(time_remaining - delta, 0.0)

	check_time_warnings(previous_time, time_remaining)
	time_changed.emit(time_remaining)

	if time_remaining <= 0.0:
		handle_police_arrival()


func start_run(duration: float) -> void:
	if CampaignManager.game_over:
		return
		
	print("RunManager.start_run called")

	run_duration = duration
	time_remaining = run_duration
	run_active = true
	player_escaped = false
	all_cleaned_announced = false
	triggered_time_warnings.clear()

	collect_crime_types()
	create_case_count_records()
	starting_crime_count = get_remaining_crime_count()

	run_started.emit(starting_crime_count)
	time_changed.emit(time_remaining)
	update_evidence_count(false)


func collect_crime_types() -> void:
	tracked_crime_types.clear()

	for node in get_tree().get_nodes_in_group("crime_evidence"):
		var evidence := node as Evidence

		if not evidence or not evidence.crime_type:
			continue

		if not tracked_crime_types.has(evidence.crime_type):
			tracked_crime_types.append(evidence.crime_type)


func escape_apartment() -> void:
	if not run_active or player_escaped:
		return

	player_escaped = true
	run_active = false

	var remaining_crimes := get_remaining_crime_count()
	var cleaned_crimes: int = max(starting_crime_count - remaining_crimes, 0)

	CampaignManager.add_convictions(remaining_crimes)
	
	print("CASE DISPOSITION")

	for record in case_counts:
		var disposition := "DISMISSED" if record["dismissed"] else "CONVICTION ENTERED"

		print(
			"COUNT ", record["count_number"],
			" | ", record["charge_name"],
			" | ", record["evidence_name"],
			" | ", disposition
		)
	
	run_escaped.emit(remaining_crimes, cleaned_crimes)


func handle_police_arrival() -> void:
	if not run_active:
		return

	run_active = false
	time_remaining = 0.0

	time_changed.emit(time_remaining)
	police_arrived.emit()
	CampaignManager.end_campaign(true)


func get_remaining_crime_count() -> int:
	return get_tree().get_nodes_in_group("crime_evidence").size()


func get_cleaned_crime_count() -> int:
	return max(starting_crime_count - get_remaining_crime_count(), 0)


func get_remaining_crime_counts() -> Dictionary:
	var counts := {}

	for crime_type in tracked_crime_types:
		counts[crime_type] = 0

	for node in get_tree().get_nodes_in_group("crime_evidence"):
		var evidence := node as Evidence

		if not evidence or not evidence.crime_type:
			continue

		if not counts.has(evidence.crime_type):
			counts[evidence.crime_type] = 0

		counts[evidence.crime_type] += 1

	return counts


func update_evidence_count(allow_completion_notification := true) -> void:
	var remaining := get_remaining_crime_count()
	var cleaned: int = max(starting_crime_count - remaining, 0)
	var counts := get_remaining_crime_counts()

	evidence_count_changed.emit(remaining, cleaned)
	crime_counts_changed.emit(counts)

	if allow_completion_notification and remaining == 0 and not all_cleaned_announced:
		all_cleaned_announced = true
		all_crimes_cleaned.emit()
		notification_requested.emit("All crimes cleaned. Return to the exit.", notification_duration)


func check_time_warnings(previous_time: float, current_time: float) -> void:
	for threshold in time_warning_thresholds:
		if triggered_time_warnings.has(threshold):
			continue

		if previous_time > threshold and current_time <= threshold:
			triggered_time_warnings.append(threshold)

			var seconds := int(ceil(threshold))
			var message := "Police arrive in %d seconds. Return to the exit." % seconds
			notification_requested.emit(message, notification_duration)


func _on_cleanup_completed(evidence: Evidence) -> void:
	dismiss_case_count(evidence)
	update_evidence_count()


func dismiss_case_count(evidence: Evidence) -> void:
	if not evidence:
		return

	var evidence_id := evidence.get_instance_id()

	if not evidence_count_lookup.has(evidence_id):
		push_warning("Completed evidence has no corresponding case count: %s" % evidence.evidence_name)
		return

	var record_index: int = evidence_count_lookup[evidence_id]
	var record: Dictionary = case_counts[record_index]
	record["dismissed"] = true
	case_counts[record_index] = record
	
	
func create_case_count_records() -> void:
	case_counts.clear()
	evidence_count_lookup.clear()

	var grouped_nodes := get_tree().get_nodes_in_group("crime_evidence")
	print("Creating case records. Evidence group size: ", grouped_nodes.size())

	var evidence_items: Array[Evidence] = []

	for node in grouped_nodes:
		print(
			"Found grouped node: ", node.name,
			" | Script: ", node.get_script(),
			" | Is Evidence: ", node is Evidence
		)

		var evidence := node as Evidence

		if evidence:
			evidence_items.append(evidence)

	print("Valid Evidence objects: ", evidence_items.size())

	evidence_items.sort_custom(sort_evidence_for_case)

	for evidence in evidence_items:
		var charge_name := "Unspecified Criminal Offense"

		if evidence.crime_type:
			charge_name = evidence.crime_type.legal_charge_name

		var record := {
			"count_number": case_counts.size() + 1,
			"evidence_id": evidence.get_instance_id(),
			"evidence_name": evidence.evidence_name,
			"crime_type": evidence.crime_type,
			"charge_name": charge_name,
			"dismissed": false
		}

		case_counts.append(record)
		evidence_count_lookup[evidence.get_instance_id()] = case_counts.size() - 1

	print("Final case record count: ", case_counts.size())


func sort_evidence_for_case(a: Evidence, b: Evidence) -> bool:
	var a_order := 999
	var b_order := 999

	if a.crime_type:
		a_order = a.crime_type.display_order

	if b.crime_type:
		b_order = b.crime_type.display_order

	if a_order == b_order:
		return a.evidence_name.naturalnocasecmp_to(b.evidence_name) < 0

	return a_order < b_order
	
	
func get_case_counts() -> Array[Dictionary]:
	return case_counts.duplicate(true)


func get_dismissed_count() -> int:
	var total := 0

	for record in case_counts:
		if record["dismissed"]:
			total += 1

	return total


func get_conviction_count_for_run() -> int:
	return case_counts.size() - get_dismissed_count()
