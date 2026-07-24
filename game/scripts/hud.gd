class_name HUD
extends CanvasLayer

@onready var timer_label: Label = $MarginContainer/VBoxContainer/TimerLabel
@onready var evidence_label: Label = $MarginContainer/VBoxContainer/EvidenceLabel
@onready var conviction_label: Label = $MarginContainer/VBoxContainer/ConvictionLabel


func _ready() -> void:
	RunManager.time_changed.connect(_on_time_changed)
	RunManager.evidence_count_changed.connect(_on_evidence_count_changed)
	CampaignManager.convictions_changed.connect(_on_convictions_changed)
	
	_on_time_changed(RunManager.time_remaining)
	_on_evidence_count_changed(RunManager.get_remaining_crime_count(), RunManager.get_cleaned_crime_count())
	_on_convictions_changed(CampaignManager.total_convictions, CampaignManager.conviction_limit)


func _on_time_changed(seconds_remaing: float) -> void:
	var total_seconds := int(ceil(seconds_remaing))
	var minutes := total_seconds / 60
	var seconds := total_seconds % 60
	timer_label.text = "Police ETA: %02d:%02d" % [minutes, seconds]
	
	
func _on_evidence_count_changed(remaining: int, cleaned: int) -> void:
	evidence_label.text = "Crimes remaining: %d | Cleaned: %d" %[remaining, cleaned]
	

func _on_convictions_changed(current: int, maximum: int) -> void:
	conviction_label.text = "Convictions: %d / %d" % [current, maximum]
