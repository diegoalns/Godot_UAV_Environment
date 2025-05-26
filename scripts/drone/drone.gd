class_name Drone
extends Node

var drone_id: String
var current_position: Vector3
var destination: Vector3
var speed: float = 10.0
var completed: bool = false

func initialize(id: String, start: Vector3, end: Vector3):
	drone_id = id
	current_position = start
	destination = end

func update(delta: float):
	if completed:
		return
	
	var direction = (destination - current_position).normalized()
	current_position += direction * speed * delta
	print("Drone %s at position %s" % [drone_id, str(current_position)])
	
	if current_position.distance_to(destination) < 10.0:
		completed = true
		print("Drone %s completed flight" % drone_id)
