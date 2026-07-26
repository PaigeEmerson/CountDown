class_name CaseCountEntry
extends MarginContainer

@onready var count_label: Label = $VBoxContainer/CountLabel
@onready var charge_label: RichTextLabel = $VBoxContainer/ChargeLabel
@onready var evidence_label: Label = $VBoxContainer/EvidenceLabel
@onready var disposition_label: Label = $VBoxContainer/DispositionLabel


func setup(record: Dictionary, unresolved_disposition: String) -> void:
	var count_number: int = record["count_number"]
	var charge_name: String = record["charge_name"]
	var evidence_name: String = record["evidence_name"]
	var dismissed: bool = record["dismissed"]

	count_label.text = "COUNT %s" % number_to_roman(count_number)
	evidence_label.text = "Supporting exhibit: %s" % evidence_name

	if dismissed:
		charge_label.text = "[color=#7A1717][s]%s[/s][/color]" % charge_name.to_upper()
		disposition_label.text = "DISMISSED — INSUFFICIENT EVIDENCE"
		#modulate = Color(0.5, 0.5, 0.5, 1.0)
	else:
		charge_label.text = charge_name.to_upper()
		disposition_label.text = unresolved_disposition
		modulate = Color.WHITE


func number_to_roman(value: int) -> String:
	var number := value
	var result := ""

	var values: Array[int] = [
		1000, 900, 500, 400,
		100, 90, 50, 40,
		10, 9, 5, 4, 1
	]

	var symbols: Array[String] = [
		"M", "CM", "D", "CD",
		"C", "XC", "L", "XL",
		"X", "IX", "V", "IV", "I"
	]

	for index in values.size():
		while number >= values[index]:
			number -= values[index]
			result += symbols[index]

	return result
