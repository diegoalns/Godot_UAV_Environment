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

# Response waiting state
var waiting_for_route_response: bool = false
var route_response_timer: Timer

# Collision detection system
var collision_radius: float = 15.0  # Collision detection radius in meters - creates a 60m diameter safety zone
var is_colliding: bool = false      # Boolean flag indicating if drone is currently in collision state
var collision_partners: Array = []  # Array of drone IDs currently in collision with this drone
var collision_manager_ref: Node = null  # Reference to collision manager for accessing other drones


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
	
	# Set up response timeout timer
	route_response_timer = Timer.new()
	route_response_timer.one_shot = true
	route_response_timer.wait_time = 10.0  # 10 second timeout
	route_response_timer.timeout.connect(_on_route_response_timeout)
	add_child(route_response_timer)
	
	# Create a dictionary with the data to include in the message
	var message_data = {
		"type": "request_route",
		"drone_id": drone_id,
		"model": model,
		"start_position": {
			"x": start.x,
			"y": start.z, # in godot y is z
			"z": start.y # in godot z is y
		},
		"end_position": {
			"x": end.x, 
			"y": end.z, # in godot y is z
			"z": end.y # in godot z is y
		},
		"battery_percentage": get_battery_percentage(),
		"max_speed": max_speed,
		"max_range": max_range
	}

	# Convert the dictionary to a JSON string
	var message = JSON.stringify(message_data)

	# Connect to response signal before sending
	if not WebSocketManager.data_received.is_connected(_on_route_response_received):
		WebSocketManager.data_received.connect(_on_route_response_received)

	# Send the JSON-formatted message
	WebSocketManager.send_message(message)
	
	# Start waiting for response with timeout
	waiting_for_route_response = true
	route_response_timer.start()
	
	# Wait for response instead of creating default route immediately
	print("Drone %s waiting for route response from server..." % drone_id)
	
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
	var _direction = (end - start).normalized()  # Prefix with underscore to indicate intentionally unused
	
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
			return 50.0    # High altitude for efficiency
		"Light Quadcopter":
			return 50.0    # Lower altitude for regulations
		"Heavy Quadcopter":
			return 50.0    # Medium altitude for cargo operations
		_:
			return 50.0    # Default altitude

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
	if completed or waiting_for_route_response:
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
	
	# Perform collision detection if we have access to other drones
	if collision_manager_ref and collision_manager_ref.has_method("get_all_drones"):
		var all_drones: Dictionary = collision_manager_ref.get_all_drones()
		check_collision_with_other_drones(all_drones)

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

# Collision detection functions
func check_collision_with_other_drones(other_drones: Dictionary):
	"""
	Check for collisions with other drones in the simulation
	
	Args:
		other_drones: Dictionary of all active drones keyed by drone_id
	"""
	var previous_collision_state = is_colliding  # Store previous collision state to detect changes
	var current_collision_partners: Array = []  # Array to track which drones this drone is colliding with
	
	# Reset collision state for this frame
	is_colliding = false
	
	# Check distance to all other drones
	for other_drone_id in other_drones.keys():
		if other_drone_id == drone_id:
			continue  # Skip self-comparison
		
		var other_drone: Drone = other_drones[other_drone_id]
		
		# Skip completed drones as they're not actively flying
		if other_drone.completed:
			continue
		
		# Calculate 3D distance between drone centers
		var distance_between_drones: float = current_position.distance_to(other_drone.current_position)
		
		# Check if collision spheres overlap (sum of both radii)
		var collision_threshold: float = collision_radius + other_drone.collision_radius
		
		if distance_between_drones < collision_threshold:
			# Collision detected
			is_colliding = true
			current_collision_partners.append(other_drone_id)
			
			# Log collision event if this is a new collision
			if not collision_partners.has(other_drone_id):
				_handle_collision_event(other_drone, distance_between_drones)
	
	# Update collision partners list
	collision_partners = current_collision_partners
	
	# Handle collision state changes
	if previous_collision_state != is_colliding:
		_handle_collision_state_change(previous_collision_state, is_colliding)

func _handle_collision_event(other_drone: Drone, distance: float):
	"""
	Handle a new collision event between this drone and another
	
	Args:
		other_drone: The Drone object this drone is colliding with
		distance: The actual distance between the two drone centers in meters
	"""
	var collision_severity = "CRITICAL"  # All collisions within 30m radius are critical
	
	print("COLLISION DETECTED: Drone %s colliding with Drone %s at distance %.2f meters (threshold: %.2f meters) - %s" % [
		drone_id, 
		other_drone.drone_id, 
		distance, 
		collision_radius + other_drone.collision_radius,
		collision_severity
	])
	
	# Log detailed collision information
	print("  - Drone %s position: %s, speed: %.2f m/s" % [drone_id, str(current_position), current_speed])
	print("  - Drone %s position: %s, speed: %.2f m/s" % [other_drone.drone_id, str(other_drone.current_position), other_drone.current_speed])
	
	# Note: Only logging collision, no behavioral response implemented

func _handle_collision_state_change(previous_state: bool, new_state: bool):
	"""
	Handle transitions between collision and non-collision states
	
	Args:
		previous_state: Previous collision state (bool)
		new_state: New collision state (bool)
	"""
	if not previous_state and new_state:
		# Entering collision state
		print("Drone %s ENTERING collision state with %d other drones" % [drone_id, collision_partners.size()])
	elif previous_state and not new_state:
		# Exiting collision state
		print("Drone %s EXITING collision state - all clear" % drone_id)

func _execute_collision_response(_other_drone: Drone):
	"""
	Execute collision avoidance response behavior
	
	Args:
		_other_drone: The drone we're colliding with (prefixed with underscore as currently unused)
	"""
	# No collision response behavior - only detection and logging
	# This function is kept for future extensibility if collision response is needed
	pass

func set_collision_manager_reference(manager_ref: Node):
	"""
	Set reference to collision manager for accessing other drones
	
	Args:
		manager_ref: Reference to the node managing all drones (typically DroneManager)
	"""
	collision_manager_ref = manager_ref

func get_collision_info() -> Dictionary:
	"""
	Get current collision status information
	
	Returns:
		Dictionary containing collision state, partners, and radius
	"""
	return {
		"is_colliding": is_colliding,
		"collision_partners": collision_partners.duplicate(),  # Return copy to prevent external modification
		"collision_radius": collision_radius,
		"collision_partner_count": collision_partners.size()
	}

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

func _on_route_response_received(data):
	"""
	Handle response from WebSocket server for route requests
	
	Args:
		data: PackedByteArray containing the server response
	"""
	var response_text = data.get_string_from_utf8()
	print("Drone %s received response: %s" % [drone_id, response_text])
	
	# Parse JSON response
	var json = JSON.new()
	var parse_result = json.parse(response_text)
	
	if parse_result != OK:
		print("Failed to parse JSON response for drone %s" % drone_id)
		# Fall back to default route
		_create_default_route(origin_position, destination_position)
		_finalize_route_setup()
		return
	
	var response_data = json.data
	
	# Check if this response is for our drone
	if response_data.has("drone_id") and response_data.drone_id == drone_id:
		# Stop the timeout timer
		if route_response_timer and not route_response_timer.is_stopped():
			route_response_timer.stop()
		
		# Disconnect from signal to avoid receiving other drones' responses
		if WebSocketManager.data_received.is_connected(_on_route_response_received):
			WebSocketManager.data_received.disconnect(_on_route_response_received)
		
		if response_data.has("route") and response_data.route is Array:
			# Use server-provided route
			_process_server_route(response_data.route)
		else:
			print("No valid route in response, using default route for drone %s" % drone_id)
			# Fall back to default route
			_create_default_route(origin_position, destination_position)
		
		_finalize_route_setup()

func _process_server_route(server_route: Array):
	"""
	Process route data received from server
	
	Args:
		server_route: Array of waypoint data from server
	"""
	route.clear()
	
	for waypoint_data in server_route:
		if waypoint_data is Dictionary:
			var waypoint = {
				"position": Vector3(
					waypoint_data.get("x", 0.0),
					waypoint_data.get("y", 10.0),  # Default altitude
					waypoint_data.get("z", 0.0)
				),
				"altitude": waypoint_data.get("altitude", 10.0),
				"speed": waypoint_data.get("speed", max_speed * 0.8),
				"description": waypoint_data.get("description", "Server waypoint")
			}
			route.append(waypoint)
	
	print("Drone %s loaded %d waypoints from server" % [drone_id, route.size()])

func _finalize_route_setup():
	"""
	Complete the route setup after receiving response (or timeout)
	"""
	waiting_for_route_response = false
	
	# Set initial target if we have waypoints
	if route.size() > 0:
		_set_current_target()
		print("Drone %s route finalized, starting mission" % drone_id)
	else:
		print("Warning: Drone %s has no valid route!" % drone_id)
		completed = true

func _on_route_response_timeout():
	"""
	Handle timeout when no response is received from server
	"""
	print("Timeout waiting for route response for drone %s, using default route" % drone_id)
	
	# Disconnect from signal to avoid processing late responses
	if WebSocketManager.data_received.is_connected(_on_route_response_received):
		WebSocketManager.data_received.disconnect(_on_route_response_received)
	
	# Create default route as fallback
	_create_default_route(origin_position, destination_position)
	_finalize_route_setup()
