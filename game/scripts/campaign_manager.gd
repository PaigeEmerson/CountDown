extends Node

signal convictions_changed(current: int, maximum: int)
signal campaign_ended(caught_by_police: bool)

@export var conviction_limit := 10

var total_convictions := 0
var game_over := false


func add_convictions(amount: int) -> void:
	if game_over:
		return
		
	total_convictions += max(amount, 0)
	convictions_changed.emit(total_convictions, conviction_limit)
	
	if total_convictions >= conviction_limit:
		end_campaign(false)
		

func end_campaign(caught_by_police: bool) -> void:
	if game_over:
		return
		
	game_over = true
	campaign_ended.emit(caught_by_police)
	
	
func reset_campaign() -> void:
	total_convictions = 0
	game_over = false
	convictions_changed.emit(total_convictions, conviction_limit)
	
	
func get_remaining_convictions() -> int:
	return max(conviction_limit - total_convictions, 0)
