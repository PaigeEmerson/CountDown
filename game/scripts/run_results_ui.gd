class_name RunResultsUI
extends CanvasLayer

@onready var background: Control = $Background
@onready var title_label: Label = $Background/CenterContainer/ResultsPanel/MarginContainer/VBoxContainer/TitleLabel
@onready var result_label: Label = $Background/CenterContainer/ResultsPanel/MarginContainer/VBoxContainer/ResultLabel
@onready var crime_label: Label = $Background/CenterContainer/ResultsPanel/MarginContainer/VBoxContainer/CrimeLabel
@onready var conviction_label: Label = $Background/CenterContainer/ResultsPanel/MarginContainer/VBoxContainer/ConvictionLabel
@onready var continue_button: Button = $Background/CenterContainer/ResultsPanel/MarginContainer/VBoxContainer/ContinueButton

var campaign_has_ended := false


func _ready() -> void:
	background.hide()
	
	RunManager.run_escaped.connect(_on_run_escaped)
	CampaignManager.campaign_ended.connect(_on_campaign_ended)
	continue_button.pressed.connect(_on_continue_pressed)


func _on_run_escaped(remaining_crimes: int, cleaned_crimes: int) -> void:
	if CampaignManager.game_over:
		return
		
	campaign_has_ended = false
	title_label.text = "Escaped"
	
	if remaining_crimes == 0:
		result_label.text = "No evidence was left behind."
	else:
		result_label.text = "%d new conviction(s) were added." % remaining_crimes
		
	crime_label.text = "Cleaned: %d | Left behind: %d" % [cleaned_crimes, remaining_crimes]
	conviction_label.text = "Total convictions: %d / %d" % [CampaignManager.total_convictions, CampaignManager.conviction_limit]
	continue_button.text = "Continue"
	
	show_results()
	
	
func _on_campaign_ended(caught_by_police: bool) -> void:
	campaign_has_ended = true
	
	if caught_by_police:
		title_label.text = "Caught by Police"
		result_label.text = "You failed to leave the apartment before the police arrived."
		crime_label.text = "The cleanup operation is over."
	else:
		title_label.text = "Too Many Convictions"
		result_label.text = "The apartment owner reached the maximum number of convictions."
		crime_label.text = "Final conviction count: %d" % CampaignManager.total_convictions
		
	conviction_label.text = "Convictions: %d / %d" % [CampaignManager.total_convictions, CampaignManager.conviction_limit]
	continue_button.text = "Continue"
	
	show_results()
	

func show_results() -> void:
	background.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	continue_button.grab_focus()
	
	
func _on_continue_pressed() -> void:
	if campaign_has_ended:
		CampaignManager.reset_campaign()

	get_tree().reload_current_scene()
