class_name RunResultsUI
extends Node

var campaign_has_ended := false
var handling_continue := false


func _ready() -> void:
	RunManager.run_escaped.connect(_on_run_escaped)
	CampaignManager.campaign_ended.connect(_on_campaign_ended)
	NewspaperInterface.results_continue_requested.connect(_on_continue_pressed)


func _on_run_escaped(remaining_crimes: int, cleaned_crimes: int) -> void:
	if CampaignManager.game_over:
		return

	campaign_has_ended = false

	var headline := ""
	var subheadline := ""

	if remaining_crimes == 0:
		headline = "ALL COUNTS DISMISSED"
		subheadline = "Prosecution left without evidence"
	else:
		headline = "MULTIPLE COUNTS SECURE CONVICTION"
		subheadline = "%d count(s) survive cleanup operation" % remaining_crimes

	var summary := create_summary(
		RunManager.starting_crime_count,
		cleaned_crimes,
		remaining_crimes
	)

	NewspaperInterface.display_case_results(
		headline,
		subheadline,
		RunManager.get_case_counts(),
		summary,
		"CONVICTION ENTERED",
		"NEXT CASE"
	)


func _on_campaign_ended(caught_by_police: bool) -> void:
	campaign_has_ended = true

	var remaining := RunManager.get_conviction_count_for_run()
	var dismissed := RunManager.get_dismissed_count()
	var headline := ""
	var subheadline := ""
	var unresolved_disposition := ""

	if caught_by_police:
		headline = "CLEANUP SUSPECT CAUGHT IN THE ACT"
		subheadline = "Police interrupt evidence-removal operation"
		unresolved_disposition = "REFERRED FOR PROSECUTION"
	else:
		headline = "FINAL COUNT ENDS THE CASE"
		subheadline = "Repeat offender reaches conviction limit"
		unresolved_disposition = "CONVICTION ENTERED"

	var summary := create_summary(
		RunManager.starting_crime_count,
		dismissed,
		remaining
	)

	NewspaperInterface.display_case_results(
		headline,
		subheadline,
		RunManager.get_case_counts(),
		summary,
		unresolved_disposition,
		"NEW RECORD"
	)


func create_summary(total: int, dismissed: int, convictions: int) -> String:
	return (
		"COUNTS FILED: %d\n"
		+ "COUNTS DISMISSED: %d\n"
		+ "CONVICTIONS ENTERED: %d\n\n"
		+ "CRIMINAL RECORD: %d / %d CONVICTIONS"
	) % [
		total,
		dismissed,
		convictions,
		CampaignManager.total_convictions,
		CampaignManager.conviction_limit
	]


func _on_continue_pressed() -> void:
	if handling_continue:
		return

	if NewspaperInterface.current_state != NewspaperUI.NewspaperState.RESULTS:
		return

	handling_continue = true

	if campaign_has_ended:
		CampaignManager.reset_campaign()

	await NewspaperInterface.move_to_state(
		NewspaperUI.NewspaperState.LOADING
	)

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	var error := get_tree().change_scene_to_file(
		"res://game/scenes/game_scene.tscn"
	)

	if error != OK:
		handling_continue = false
		push_error("Could not load the next apartment. Error: %s" % error)
