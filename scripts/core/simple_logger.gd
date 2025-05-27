class_name SimpleLogger
extends Node

var log_file: FileAccess
var log_interval: float = 10.0  # Log every second
var time_since_log: float = 0.0

func _ready():
	create_log_file()

func create_log_file():
	var dir = DirAccess.open("res://")
	if not dir.dir_exists("logs"):
		dir.make_dir("logs")
	
	var datetime = Time.get_datetime_dict_from_system()
	var filename = "res://logs/simple_log_%d%02d%02d_%02d%02d%02d.csv" % [
		datetime.year, datetime.month, datetime.day,
		datetime.hour, datetime.minute, datetime.second
	]
	
	log_file = FileAccess.open(filename, FileAccess.WRITE)
	if log_file:
		log_file.store_csv_line(["Time", "DroneID", "X", "Y", "Z", "Completed"])
		print("Log file created: %s" % filename)

func update(time_step: float, sim_time: float, drones: Dictionary):
	time_since_log += time_step
	
	if time_since_log >= log_interval:
		log_drone_states(sim_time, drones)
		time_since_log = 0.0

func log_drone_states(sim_time: float, drones: Dictionary):
	if not log_file:
		return
	
	for drone in drones.values():
		log_file.store_csv_line([
			"%.2f" % sim_time,
			drone.drone_id,
			"%.2f" % drone.current_position.x,
			"%.2f" % drone.current_position.y,
			"%.2f" % drone.current_position.z,
			str(drone.completed)
		])

func close_log():
	if log_file:
		log_file.close()

func _exit_tree():
	close_log()
