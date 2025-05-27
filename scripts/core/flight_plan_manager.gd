class_name FlightPlanManager
extends Node

var flight_plans: Array = []

func _ready():
	load_flight_plans()

func load_flight_plans():
	var file = FileAccess.open("res://data/DP1_DP2_DP3_flight_plans_head.csv", FileAccess.READ)
	if not file:
		print("Error: Could not open flight plans file")
		return
	
	# Skip header
	file.get_csv_line()
	
	while not file.eof_reached():
		var data = file.get_csv_line()
		if data.size() > 7:
			var flight_plan = {
				"id": data[0],
				"port": data[1],
				"etd_seconds": float(data[3]),
				"origin_lat": float(data[4]),
				"origin_lon": float(data[5]),
				"dest_lat": float(data[6]),
				"dest_lon": float(data[7]),
				"model": data[8],
				"created": false
			}
			flight_plans.append(flight_plan)
	
	file.close()
	print("Loaded %d flight plans" % flight_plans.size())
	print(flight_plans)

func get_flight_plans() -> Array:
	return flight_plans

# Simple lat/lon to position conversion
func latlon_to_position(lat: float, lon: float) -> Vector3:
	return Vector3(lon * 1000, 0, lat * 1000)
