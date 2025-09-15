class_name SimpleLogger
extends Node

# FileAccess objects for different log files
var log_file: FileAccess  # Main drone states log
var distance_log_file: FileAccess  # Mean distance log
var log_interval: float = 10.0  # Log every 10 seconds
var time_since_log: float = 0.0

func _ready():
	create_log_file()

func create_log_file():
	# Create logs directory if it doesn't exist
	var dir = DirAccess.open("res://")
	if not dir.dir_exists("logs"):
		dir.make_dir("logs")
	
	# Create main drone states log file
	var filename = "res://logs/simple_log.csv"
	log_file = FileAccess.open(filename, FileAccess.WRITE)
	if log_file:
		log_file.store_csv_line(["Time", "DroneID", "X", "Y", "Z", "Target position", "Target Speed", "Origin Lat", "Origin Lon", "Destination Lat", "Destination Lon", "Completed"])
		print("Log file created: %s" % filename)
	
	# Create mean distance log file
	var distance_filename = "res://logs/mean_distances.csv"
	distance_log_file = FileAccess.open(distance_filename, FileAccess.WRITE)
	if distance_log_file:
		distance_log_file.store_csv_line(["Time", "Mean_Distance"])
		print("Mean distance log file created: %s" % distance_filename)

func update(time_step: float, sim_time: float, drones: Dictionary):
	time_since_log += time_step
	
	if time_since_log >= log_interval:
		log_drone_states(sim_time, drones)
		log_mean_distance(sim_time, drones)
		time_since_log = 0.0

func log_drone_states(sim_time: float, drones: Dictionary):
	if not log_file:
		return
	
	for drone in drones.values():
		log_file.store_csv_line([
			"%.2f" % sim_time,
			#drone.port_id,
			drone.drone_id,
			"%.2f" % drone.current_position.x,
			"%.2f" % drone.current_position.y,
			"%.2f" % drone.current_position.z,
			drone.target_position,
			drone.target_speed,
			drone.origin_position.x,
			drone.origin_position.z,
			drone.destination_position.x,
			drone.destination_position.z,
			str(drone.completed)
		])

func log_mean_distance(sim_time: float, drones: Dictionary):
	# Check if distance log file is available
	if not distance_log_file:
		return
	
	# Get all active drones as an array for easier processing
	var drone_list = drones.values()
	var drone_count = drone_list.size()
	
	# Handle edge cases: need at least 2 drones to calculate distance
	if drone_count < 2:
		return
	
	# Calculate all pairwise distances using Vector3.distance_to()
	var total_distance: float = 0.0
	var pair_count: int = 0
	
	# Iterate through all unique pairs (i < j to avoid duplicates)
	for i in range(drone_count):
		for j in range(i + 1, drone_count):
			var drone1 = drone_list[i]
			var drone2 = drone_list[j]
			
			# Calculate distance between current positions using Vector3.distance_to()
			var distance = drone1.current_position.distance_to(drone2.current_position)
			total_distance += distance
			pair_count += 1
	
	# Calculate mean distance
	var mean_distance = total_distance / pair_count
	
	# Log the simulation time and mean distance to CSV
	distance_log_file.store_csv_line([
		"%.2f" % sim_time,
		"%.2f" % mean_distance
	])

func close_log():
	# Close main drone states log file
	if log_file:
		log_file.close()
	
	# Close mean distance log file
	if distance_log_file:
		distance_log_file.close()

func _exit_tree():
	close_log()
