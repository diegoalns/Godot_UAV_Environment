class_name VisualizationSystem
extends Node3D

var drone_meshes: Dictionary = {}
var enabled: bool = true
var balloon_ref: CharacterBody3D = null  # Reference to the balloon

# Terrain system components
var terrain_gridmap: GridMap = null  # GridMap node for terrain visualization
var gridmap_manager: GridMapManager = null  # Manager for terrain data and population

# Movement and control variables
var move_speed = 20000.0  # Speed for movement
var rotation_speed = 0.001  # Speed of rotation with mouse
var mouse_sensitivity = 0.001
var camera_offset = Vector3(0, 10, 30)  # Offset from balloon position
var mouse_captured = false

# Visualization scale factor
var visual_scale = 1  # Adjust this to make the area more compact

# align_drone_to_route: bool - whether to rotate the drone visual to face its next waypoint (size: 1 boolean)
var align_drone_to_route: bool = true

# model_yaw_offset_degrees: float - additional yaw angle to correct the model's intrinsic forward axis if it is not -Z (size: 1 scalar in degrees)
var model_yaw_offset_degrees: float = 0.0

func set_enabled(enable: bool):
	enabled = enable
	visible = enable

func _ready():
	setup_balloon()
	setup_camera()
	setup_lighting()
	setup_terrain()
	
	# Set up input processing
	set_process_input(true)
	set_process(true)

func setup_camera():
	var camera = Camera3D.new()
	camera.position = camera_offset * visual_scale  # Set the local offset, scaled
	camera.current = true
	balloon_ref.add_child(camera)    # Attach camera to the balloon

func setup_lighting():
	var light = DirectionalLight3D.new()
	light.position = Vector3(0, 100, 41700)
	add_child(light)
	light.look_at(Vector3(0, 0, 41000), Vector3.DOWN)

func setup_terrain():
	"""
	Initialize the terrain GridMap system within the visualization system
	Creates GridMap and GridMapManager, loads terrain data, and scales appropriately
	"""
	print("VisualizationSystem: Setting up terrain system...")
	
	# Create GridMap node for terrain visualization
	terrain_gridmap = GridMap.new()
	terrain_gridmap.name = "TerrainGridMap"
	
	# Load the mesh library resource
	var mesh_library = load("res://resources/Meshs/cell_library.meshlib")
	if not mesh_library:
		push_error("VisualizationSystem: Failed to load cell_library.meshlib")
		return
	
	# Configure GridMap with mesh library and proper cell size
	terrain_gridmap.mesh_library = mesh_library
	# Apply visual scale to cell size - each cell represents 702m x 927m x 1m in world space
	# Height dimension is 1m per grid unit to match CSV altitude values (0-400m range)
	terrain_gridmap.cell_size = Vector3(702.0 * visual_scale, 1.0 * visual_scale, 927.0 * visual_scale)
	
	# Add GridMap to the visualization system
	add_child(terrain_gridmap)
	
	# Create and initialize GridMapManager
	gridmap_manager = GridMapManager.new()
	add_child(gridmap_manager)
	
	# Initialize the manager with our GridMap
	gridmap_manager.initialize_gridmap(terrain_gridmap)
	
	# Load terrain data and populate the GridMap
	if gridmap_manager.load_terrain_data():
		if gridmap_manager.populate_gridmap():
			print("VisualizationSystem: Terrain system initialized successfully")
		else:
			push_error("VisualizationSystem: Failed to populate terrain GridMap")
	else:
		push_error("VisualizationSystem: Failed to load terrain data")

func setup_balloon():
	balloon_ref = CharacterBody3D.new()
	add_child(balloon_ref)
	
	# Set motion mode to floating (space-like movement)
	balloon_ref.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	
	# Add collision shape
	var collision = CollisionShape3D.new()
	var shape = SphereShape3D.new()
	shape.radius = 5.0 * visual_scale
	collision.shape = shape
	balloon_ref.add_child(collision)
	
	# Set initial position at grid origin (0, 100, 0)
	balloon_ref.global_position = Vector3(10262.88, 300, 8095.922) * visual_scale

func _input(event):
	# Toggle mouse capture with Escape key
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if mouse_captured:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			mouse_captured = false
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			mouse_captured = true
	
	# Handle mouse rotation when captured
	if mouse_captured and event is InputEventMouseMotion:
		# Rotate balloon based on mouse movement
		var rotation_y = -event.relative.x * mouse_sensitivity
		var rotation_x = -event.relative.y * mouse_sensitivity
		
		# Apply rotation to balloon - rotate around global Y axis for left/right
		balloon_ref.rotate(Vector3.UP, rotation_y)
		
		# For up/down, rotate around local X axis
		var local_x = balloon_ref.global_transform.basis.x
		balloon_ref.rotate(local_x, rotation_x)

	# Add roll control with Q and E keys
	if mouse_captured and event is InputEventKey and event.pressed:
		if event.keycode == KEY_Q:
			# Roll left
			balloon_ref.rotate(balloon_ref.global_transform.basis.z, 0.05)
		elif event.keycode == KEY_E:
			# Roll right
			balloon_ref.rotate(balloon_ref.global_transform.basis.z, -0.05)

func _process(delta):
	pass

func _physics_process(delta):
	if balloon_ref and mouse_captured:
		# Get input direction
		var input_dir = Vector3.ZERO
		
		# WASD movement
		if Input.is_key_pressed(KEY_W):
			input_dir.z -= 1
		if Input.is_key_pressed(KEY_S):
			input_dir.z += 1
		if Input.is_key_pressed(KEY_A):
			input_dir.x -= 1
		if Input.is_key_pressed(KEY_D):
			input_dir.x += 1
		if Input.is_key_pressed(KEY_SPACE):
			input_dir.y += 1
		if Input.is_key_pressed(KEY_SHIFT):
			input_dir.y -= 1
			
		# Convert input direction to global space relative to balloon's orientation
		var direction = balloon_ref.global_transform.basis * input_dir
		
		# Set velocity directly instead of applying forces
		if direction.length() > 0:
			balloon_ref.velocity = direction.normalized() * move_speed * delta
		else:
			# Optional: add some dampening when no input is given
			balloon_ref.velocity = balloon_ref.velocity.lerp(Vector3.ZERO, 0.1)
		
		# Move the character body
		balloon_ref.move_and_slide()

func add_drone(drone: Drone):
	if not enabled:
		return
	
	# drone_node: Node3D - the visual representation of the drone
	var drone_node: Node3D = null
	# lrvtol_scene: PackedScene - LRVTOL model from resources
	var lrvtol_scene: PackedScene = load("res://resources/LRVTOL_UAV.glb")

	# If the model loads, instance it; otherwise use a simple box as fallback
	if lrvtol_scene:
		# instance: Node - instantiated GLB root
		var instance = lrvtol_scene.instantiate()
		if instance is Node3D:
			drone_node = instance
			# Scale down to match map visual scale
			drone_node.scale = Vector3(1, 1, 1) * visual_scale
		else:
			# Wrap non-Node3D roots under a Node3D so it can be positioned
			drone_node = Node3D.new()
			drone_node.add_child(instance)
			drone_node.scale = Vector3(1, 1, 1) * visual_scale
	else:
		# Fallback: simple colored box
		var fallback = MeshInstance3D.new()
		var box_mesh = BoxMesh.new()
		box_mesh.size = Vector3(100, 10, 100) * visual_scale
		fallback.mesh = box_mesh
		var material = StandardMaterial3D.new()
		material.albedo_color = Color(randf(), randf(), randf())
		box_mesh.material = material
		drone_node = fallback

	add_child(drone_node)
	drone_meshes[drone.drone_id] = drone_node

	print("Added visualization for drone %s" % drone.drone_id)

func update_drone_position(drone: Drone):
	if not enabled:
		return
		
	if drone.drone_id in drone_meshes:
		# node: Node3D - visual node associated with this drone (size: one node reference)
		var node: Node3D = drone_meshes[drone.drone_id]

		# Update position: multiply by visual_scale to convert world meters to visualization units (size: Vector3 of 3 floats)
		node.position = drone.current_position * visual_scale

		# Optionally orient the drone to face its next waypoint so its longitudinal axis follows the route
		if align_drone_to_route:
			# target_pos_world: Vector3 - the next waypoint position in visualization units (size: 3 floats)
			var target_pos_world: Vector3 = drone.target_position * visual_scale

			# dir_to_target: Vector3 - direction vector from current node position to next waypoint (size: 3 floats)
			var dir_to_target: Vector3 = target_pos_world - node.position

			# Only orient when the direction vector has meaningful magnitude to avoid zero-length look_at
			if dir_to_target.length() > 0.0001:
				# Rotate the node so its -Z axis points toward the waypoint using global up vector
				node.look_at(target_pos_world, Vector3.UP)

				# Apply extra yaw offset if the model forward axis needs correction relative to -Z
				if model_yaw_offset_degrees != 0.0:
					node.rotate_y(deg_to_rad(model_yaw_offset_degrees))

				# Ensure the visual forward actually faces the waypoint. If after applying the yaw offset
				# the model's forward points away (dot < 0), flip 180 degrees around Y to correct.
				# forward_world: Vector3 - world-space forward direction assuming -Z is forward (size: 3 floats)
				var forward_world: Vector3 = (node.global_transform.basis.z).normalized()
				# dir_norm: Vector3 - normalized desired direction towards the next waypoint (size: 3 floats)
				var dir_norm: Vector3 = dir_to_target.normalized()
				if forward_world.dot(dir_norm) < 0.0:
					node.rotate_y(PI)

func add_drone_port(dp_position: Vector3, port_id: String):
	var mesh_instance = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(500, 2, 500) * visual_scale

	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0, 0, 0)  # Black
	box_mesh.material = material
	mesh_instance.mesh = box_mesh

	mesh_instance.position = dp_position * visual_scale
	add_child(mesh_instance)
	print("drone port %s added added at %s" % [port_id, dp_position])

func move_balloon_to_port(port_position: Vector3):
	# Optionally apply scale_factor if you use one
	balloon_ref.global_position = port_position * visual_scale
	# Optionally reset orientation or camera offset here

func get_terrain_altitude_at_position(world_pos: Vector3) -> float:
	"""
	Get terrain altitude at a specific world position
	@param world_pos: Vector3 - World position to query (in world coordinates)
	@return float - Altitude value at that position, or -1 if terrain not ready
	"""
	if gridmap_manager:
		return gridmap_manager.get_terrain_altitude_at_position(world_pos)
	return -1.0

func get_terrain_info() -> Dictionary:
	"""
	Get terrain system information for debugging/display purposes
	@return Dictionary - Terrain information or empty dict if not ready
	"""
	if gridmap_manager:
		return gridmap_manager.get_grid_info()
	return {}

func is_terrain_ready() -> bool:
	"""
	Check if the terrain system is fully initialized and ready for use
	@return bool - True if terrain is ready, false otherwise
	"""
	return terrain_gridmap != null and gridmap_manager != null
