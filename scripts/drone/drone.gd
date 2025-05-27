class_name Drone
extends Node

# Core identification and position
var drone_id: String
var current_position: Vector3
var completed: bool = false

# Model type - matches CSV data
var model: String = ""

# Performance attributes - vary by model (simplified for holonomic movement)
var max_speed: float = 0.0          # Maximum velocity in m/s
var current_speed: float = 0.0      # Current velocity in m/s
var max_range: float = 0.0          # Maximum flight range in meters
var battery_capacity: float = 0.0   # Battery capacity in Wh (Watt-hours)
var power_consumption: float = 0.0  # Power consumption in W (Watts)
var payload_capacity: float = 0.0   # Maximum payload in kg

# Runtime state
var remaining_battery: float = 0.0  # Remaining battery in Wh
var distance_traveled: float = 0.0  # Total distance traveled in meters
var flight_time: float = 0.0        # Total flight time in seconds

# Route and waypoint system
var route: Array = []               # Array of waypoint dictionaries
var current_waypoint_index: int = 0 # Index of current target waypoint
var returning: bool = false         # Whether drone is on return journey
var origin_position: Vector3        # Starting position for return journey
var destination_position: Vector3   # Final destination position

# Movement state (holonomic - no physics constraints)
var target_position: Vector3        # Current target position
var target_speed: float = 0.0       # Target speed for current segment


func initialize(id: String, start: Vector3, end: Vector3, drone_model: String):
	"""
	Initialize drone with position, destination and model-specific attributes
	
	Args:
		id: Unique identifier for the drone
		start: Starting position in 3D space
		end: Destination position in 3D space
		drone_model: Type of drone (Long Range FWVTOL, Light Quadcopter, Heavy Quadcopter)
	"""
	drone_id = id
	current_position = start
	origin_position = start
	destination_position = end
	model = drone_model
	
	# Set model-specific attributes
	_set_model_attributes()
	
	# Initialize runtime state
	remaining_battery = battery_capacity
	distance_traveled = 0.0
	flight_time = 0.0
	current_speed = 0.0
	returning = false
	current_waypoint_index = 0
	
	# Create default route (direct flight with altitude variation)
	_create_default_route(start, end)
	
	# Set initial target
	if route.size() > 0:
		_set_current_target()

func _set_model_attributes():
	"""
	Set performance attributes based on drone model
	
	References used for realistic values:
	- DJI M300 RTK (Heavy Quadcopter): 15m/s max speed, 55min flight time, 2.7kg payload
	- DJI Mini 3 Pro (Light Quadcopter): 16m/s max speed, 34min flight time, 0.249kg weight
	- Boeing MQ-25 Stingray (FWVTOL): 185 km/h (51.4 m/s), long range capabilities
	- NASA UAM studies for urban air mobility
	- FAA Part 107 regulations for commercial drones
	"""
	match model:
		"Long Range FWVTOL":
			# Fixed-wing VTOL optimized for long range and efficiency
			max_speed = 55.0              # m/s (~200 km/h) - high cruise speed
			max_range = 150000.0          # meters (150km) - excellent range
			battery_capacity = 2000.0     # Wh - large battery for long missions
			power_consumption = 800.0     # W - efficient at cruise speed
			payload_capacity = 5.0        # kg - substantial cargo capacity
			
		"Light Quadcopter":
			# Small, agile quadcopter for short-range missions
			max_speed = 18.0              # m/s (~65 km/h) - moderate speed
			max_range = 8000.0            # meters (8km) - limited range
			battery_capacity = 250.0      # Wh - small battery
			power_consumption = 150.0     # W - efficient for size
			payload_capacity = 0.5        # kg - minimal payload
			
		"Heavy Quadcopter":
			# Industrial quadcopter for heavy payloads
			max_speed = 25.0              # m/s (~90 km/h) - good speed despite weight
			max_range = 15000.0           # meters (15km) - moderate range
			battery_capacity = 800.0      # Wh - large battery for power needs
			power_consumption = 400.0     # W - high power for heavy lifting
			payload_capacity = 8.0        # kg - excellent payload capacity
			
		_:
			# Default to Long Range FWVTOL if unknown model
			print("Warning: Unknown drone model '%s', using Long Range FWVTOL defaults" % model)
			model = "Long Range FWVTOL"
			_set_model_attributes()

func _create_default_route(start: Vector3, end: Vector3):
	"""
	Create a default route with waypoints between start and destination
	
	Includes altitude variations and speed adjustments for realistic flight path
	
	Args:
		start: Starting position
		end: Destination position
	"""
	route.clear()
	
	# Calculate route parameters
	var total_distance = start.distance_to(end)
	var direction = (end - start).normalized()
	
	# Determine cruise altitude based on drone model and distance
	var cruise_altitude = _get_cruise_altitude_for_model()
	
	# Create waypoint sequence
	# 1. Takeoff waypoint - climb to cruise altitude
	var takeoff_pos = Vector3(start.x, cruise_altitude, start.z)
	route.append({
		"position": takeoff_pos,
		"altitude": cruise_altitude,
		"speed": max_speed * 0.6,  # Slower speed for takeoff
		"description": "Takeoff and climb"
	})
	
	# 2. Cruise waypoints - add intermediate points for longer flights
	if total_distance > 5000:  # Add waypoints for flights over 5km
		var num_waypoints = int(total_distance / 10000) + 1  # One waypoint per 10km
		for i in range(1, num_waypoints):
			var progress = float(i) / float(num_waypoints)
			var waypoint_pos = start.lerp(end, progress)
			waypoint_pos.y = cruise_altitude
			
			route.append({
				"position": waypoint_pos,
				"altitude": cruise_altitude,
				"speed": max_speed,  # Full cruise speed
				"description": "Cruise waypoint %d" % i
			})
	
	# 3. Approach waypoint - maintain altitude but reduce speed
	var approach_pos = Vector3(end.x, cruise_altitude, end.z)
	route.append({
		"position": approach_pos,
		"altitude": cruise_altitude,
		"speed": max_speed * 0.7,  # Reduced speed for approach
		"description": "Approach"
	})
	
	# 4. Landing waypoint - descend to destination
	route.append({
		"position": end,
		"altitude": end.y,
		"speed": max_speed * 0.4,  # Slow speed for landing
		"description": "Landing"
	})
	
	print("Created route for drone %s with %d waypoints" % [drone_id, route.size()])

func _get_cruise_altitude_for_model() -> float:
	"""
	Get appropriate cruise altitude based on drone model
	
	Returns:
		float: Cruise altitude in meters
	"""
	match model:
		"Long Range FWVTOL":
			return 10.0    # High altitude for efficiency
		"Light Quadcopter":
			return 10.0    # Lower altitude for regulations
		"Heavy Quadcopter":
			return 10.0    # Medium altitude for cargo operations
		_:
			return 10.0    # Default altitude

func _set_current_target():
	"""
	Set the current target position and speed based on current waypoint
	"""
	if current_waypoint_index < route.size():
		var waypoint = route[current_waypoint_index]
		target_position = waypoint.position
		target_speed = min(waypoint.speed, max_speed)  # Respect model max speed
	else:
		# No more waypoints - we've completed this leg
		if not returning:
			# Start return journey
			_start_return_journey()
		else:
			# Completed full round trip
			completed = true
			print("Drone %s completed full round trip mission" % drone_id)

func _start_return_journey():
	"""
	Initialize return journey using the same route in reverse
	"""
	returning = true
	current_waypoint_index = 0
	
	# Reverse the route waypoints but keep the same structure
	var return_route: Array = []
	
	# Start from current position (destination) back to origin
	for i in range(route.size() - 1, -1, -1):
		var original_waypoint = route[i]
		var return_waypoint = {
			"position": _mirror_position_for_return(original_waypoint.position),
			"altitude": original_waypoint.altitude,
			"speed": original_waypoint.speed,
			"description": "Return: " + original_waypoint.description
		}
		return_route.append(return_waypoint)
	
	# Update route to return route
	route = return_route
	
	# Set first return target
	if route.size() > 0:
		_set_current_target()
	
	print("Drone %s starting return journey with %d waypoints" % [drone_id, route.size()])

func _mirror_position_for_return(original_pos: Vector3) -> Vector3:
	"""
	Convert an outbound waypoint position to its return equivalent
	
	Args:
		original_pos: Position from outbound journey
		
	Returns:
		Vector3: Corresponding position for return journey
	"""
	# For return journey, we mirror positions relative to destination/origin swap
	# This creates the reverse path with same altitude profile
	var outbound_progress = origin_position.distance_to(original_pos) / origin_position.distance_to(destination_position)
	var return_progress = 1.0 - outbound_progress
	
	var return_pos = destination_position.lerp(origin_position, return_progress)
	return_pos.y = original_pos.y  # Keep same altitude
	
	return return_pos

func update(delta: float):
	"""
	Update drone state with holonomic movement along waypoint route
	
	Args:
		delta: Time step in seconds since last update
	"""
	if completed:
		return
	
	# Update flight time
	flight_time += delta
	
	# Holonomic movement - direct movement toward target without physics constraints
	_update_holonomic_movement(delta)
	
	# Update battery consumption
	_update_battery(delta)
	
	# Check if we've reached current waypoint
	_check_waypoint_reached()
	
	# Check completion conditions (battery, range limits)
	_check_completion_conditions()

func _update_holonomic_movement(delta: float):
	"""
	Update position using direct holonomic movement (no physics constraints)
	
	Args:
		delta: Time step in seconds
	"""
	if current_waypoint_index >= route.size():
		return
	
	# Calculate movement toward target
	var direction_to_target = (target_position - current_position).normalized()
	var distance_to_target = current_position.distance_to(target_position)
	
	# Calculate movement distance this frame
	var movement_distance = target_speed * delta
	
	# Clamp movement to not overshoot target
	if movement_distance >= distance_to_target:
		# Reach target exactly
		current_position = target_position
		current_speed = 0.0
	else:
		# Move toward target
		current_position += direction_to_target * movement_distance
		current_speed = target_speed
	
	# Update distance traveled
	distance_traveled += movement_distance

func _check_waypoint_reached():
	"""
	Check if current waypoint has been reached and advance to next waypoint
	"""
	var distance_to_target = current_position.distance_to(target_position)
	var arrival_threshold = 5.0  # 5 meter arrival threshold
	
	if distance_to_target < arrival_threshold:
		# Reached current waypoint
		var waypoint = route[current_waypoint_index]
		print("Drone %s reached waypoint %d: %s" % [drone_id, current_waypoint_index, waypoint.description])
		
		# Advance to next waypoint
		current_waypoint_index += 1
		_set_current_target()

func _update_battery(delta: float):
	"""
	Update battery state based on power consumption
	
	Args:
		delta: Time step in seconds
	"""
	# Simple power consumption based on current speed
	var speed_factor = 1.0 + (current_speed / max_speed) * 0.5  # Higher speed = more power
	var power_used = power_consumption * speed_factor * (delta / 3600.0)  # Convert to Wh
	
	remaining_battery = max(0.0, remaining_battery - power_used)

func _check_completion_conditions():
	"""
	Check various conditions that could complete or abort the flight
	"""
	if remaining_battery <= 0:
		completed = true
		print("Drone %s ran out of battery at position %s" % [drone_id, str(current_position)])
		
	elif distance_traveled > max_range:
		completed = true
		print("Drone %s exceeded maximum range" % drone_id)

# Getter functions for accessing drone state
func get_battery_percentage() -> float:
	"""Returns remaining battery as percentage (0-100)"""
	return (remaining_battery / battery_capacity) * 100.0

func get_current_waypoint_info() -> Dictionary:
	"""Returns information about current waypoint target"""
	if current_waypoint_index < route.size():
		var waypoint = route[current_waypoint_index]
		return {
			"index": current_waypoint_index,
			"total_waypoints": route.size(),
			"description": waypoint.description,
			"target_position": waypoint.position,
			"target_speed": waypoint.speed,
			"distance_to_waypoint": current_position.distance_to(waypoint.position),
			"returning": returning
		}
	else:
		return {"completed": true}

func get_route_info() -> Dictionary:
	"""Returns complete route information"""
	return {
		"total_waypoints": route.size(),
		"current_waypoint": current_waypoint_index,
		"returning": returning,
		"route_waypoints": route
	}

func add_custom_waypoint(position: Vector3, altitude: float, speed: float, description: String = "Custom waypoint"):
	"""
	Add a custom waypoint to the current route
	
	Args:
		position: 3D position of waypoint
		altitude: Target altitude at waypoint
		speed: Target speed to/at waypoint
		description: Description of waypoint purpose
	"""
	var waypoint = {
		"position": Vector3(position.x, altitude, position.z),
		"altitude": altitude,
		"speed": min(speed, max_speed),
		"description": description
	}
	
	# Insert waypoint at current position in route
	route.insert(current_waypoint_index + 1, waypoint)
	
	print("Added custom waypoint to drone %s route: %s" % [drone_id, description])
