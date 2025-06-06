class_name DroneManager
extends Node

var drones: Dictionary = {}
var visualization_system: VisualizationSystem

func set_visualization_system(vis_system: VisualizationSystem):
	visualization_system = vis_system

func create_test_drone(id: String, start: Vector3, end: Vector3, model: String) -> Drone:
	var drone = Drone.new()
	drone.initialize(id, start, end, model)
	drones[id] = drone
	add_child(drone)
	
	# Add to visualization
	if visualization_system:
		visualization_system.add_drone(drone)
	
	return drone

func update_all(delta: float):
	for drone in drones.values():
		drone.update(delta)
		
		# Update visualization
		if visualization_system:
			visualization_system.update_drone_position(drone)

func remove_completed_drones():
	var to_remove = []
	for id in drones.keys():
		if drones[id].completed:
			to_remove.append(id)
	for id in to_remove:
		var drone = drones[id]
		drone.queue_free()  # Remove from scene
		drones.erase(id)    # Remove from dictionary
