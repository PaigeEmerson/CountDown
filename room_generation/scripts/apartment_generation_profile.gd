class_name ApartmentGenerationProfile
extends Resource

@export_group("Total Rooms")
@export_range(2, 500, 1) var minimum_rooms := 6
@export_range(2, 500, 1) var maximum_rooms := 9

@export_group("Minimum Requirements")
@export var minimum_small_rooms := 2
@export var minimum_medium_rooms := 1
@export var minimum_large_rooms := 1
@export var minimum_hallways := 1

@export_group("Maximum Limits")
@export var maximum_small_rooms := 5
@export var maximum_medium_rooms := 4
@export var maximum_large_rooms := 2
@export var maximum_hallways := 2

@export_group("Layout")
@export var minimum_layout_depth := 3
@export var maximum_consecutive_hallways := 1
@export_range(1, 50, 1) var maximum_generation_retries := 10
