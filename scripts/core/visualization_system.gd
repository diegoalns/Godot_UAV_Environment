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
var camera_offset = Vector3(0, 5, 0)  # Offset from balloon position - slightly above center for better view
var mouse_captured = false

# Camera settings
var camera_fov = 90.0  # Field of view in degrees - adjustable for different viewing preferences (size: 1 float, range typically 30-120 degrees)
var camera_near_plane = 0.1  # Near clipping plane distance - objects closer than this won't render (size: 1 float in meters)
var camera_far_plane = 100000.0  # Far clipping plane distance - objects farther than this won't render (size: 1 float in meters)

# Environment settings
var sky_color_top = Color(0.4, 0.6, 1.0)  # Light blue color for top of sky (size: Color with RGBA values)
var sky_color_horizon = Color(0.7, 0.8, 1.0)  # Lighter blue for horizon (size: Color with RGBA values)
var ground_color = Color(0.4, 0.3, 0.2)  # Brown color for ground (size: Color with RGBA values)
var sun_elevation_degrees = 90.0  # Sun elevation angle in degrees above horizon - 90° = apogee (directly overhead) (size: 1 float, 0-90 degrees)
var sun_azimuth_degrees = 0.0  # Sun azimuth angle in degrees - not relevant when sun is at apogee (size: 1 float, 0-360 degrees)

# Visualization scale factor
var visual_scale = 1  # Adjust this to make the area more compact

# align_drone_to_route: bool - whether to rotate the drone visual to face its next waypoint (size: 1 boolean)
var align_drone_to_route: bool = true

# model_yaw_offset_degrees: float - additional yaw angle to correct the model's intrinsic forward axis if it is not -Z (size: 1 scalar in degrees)
var model_yaw_offset_degrees: float = 0.0

func set_enabled(enable: bool):
	enabled = enable
	visible = enable

func set_camera_fov(fov_degrees: float):
	"""
	Set the camera field of view in degrees
	@param fov_degrees: float - Field of view in degrees (typically 30-120 degrees)
	"""
	# Clamp FOV to reasonable range to prevent visual distortion
	camera_fov = clamp(fov_degrees, 30.0, 150.0)
	
	# Update the camera if it exists
	if balloon_ref and balloon_ref.get_child_count() > 0:
		# Find the camera child node
		for child in balloon_ref.get_children():
			if child is Camera3D:
				var camera = child as Camera3D
				camera.fov = camera_fov
				print("Camera FOV updated to: %s degrees" % camera_fov)
				break

func set_camera_clipping_planes(near_distance: float, far_distance: float):
	"""
	Set the camera clipping planes to handle different viewing distances
	@param near_distance: float - Near clipping plane distance in meters
	@param far_distance: float - Far clipping plane distance in meters
	"""
	# Update the stored values with reasonable limits
	camera_near_plane = clamp(near_distance, 0.01, 10.0)  # Near plane shouldn't be too close or too far
	camera_far_plane = clamp(far_distance, 100.0, 1000000.0)  # Far plane should handle large distances
	
	# Update the camera if it exists
	if balloon_ref and balloon_ref.get_child_count() > 0:
		# Find the camera child node
		for child in balloon_ref.get_children():
			if child is Camera3D:
				var camera = child as Camera3D
				camera.near = camera_near_plane
				camera.far = camera_far_plane
				print("Camera clipping planes updated - Near: %s, Far: %s" % [camera_near_plane, camera_far_plane])
				break

func _ready():
	setup_balloon()
	setup_camera()
	setup_environment()
	setup_lighting()
	setup_ground()
	setup_terrain()
	
	# Set up input processing
	set_process_input(true)
	set_process(true)

func setup_camera():
	# camera: Camera3D - main camera node for the visualization system (size: one Camera3D reference)
	var camera = Camera3D.new()
	# Set camera position with scaled offset from balloon center
	camera.position = camera_offset * visual_scale  # Set the local offset, scaled
	# Set field of view using the configurable camera_fov variable
	camera.fov = camera_fov  # Use configurable field of view setting
	# Configure clipping planes to handle large distances and prevent rendering issues
	camera.near = camera_near_plane  # Set near clipping plane for close objects
	camera.far = camera_far_plane   # Set far clipping plane for distant terrain and objects
	# Reset camera rotation to look forward (default orientation looks down the -Z axis)
	camera.rotation = Vector3.ZERO  # Ensure camera looks forward, not down
	# Make this the active camera
	camera.current = true
	# Attach camera as child of balloon so it moves with the balloon
	balloon_ref.add_child(camera)    # Attach camera to the balloon

func setup_environment():
	"""
	Set up the sky environment with blue gradient background
	Creates a sky dome with proper colors for realistic aerial simulation
	"""
	print("VisualizationSystem: Setting up sky environment...")
	
	# Create environment resource for the scene
	var environment = Environment.new()
	
	# Set background mode to sky
	environment.background_mode = Environment.BG_SKY
	
	# Create sky resource
	var sky = Sky.new()
	
	# Create procedural sky material with proper configuration
	var sky_material = ProceduralSkyMaterial.new()
	
	# Configure sky colors for realistic aerial view
	sky_material.sky_top_color = sky_color_top  # Deep blue at zenith
	sky_material.sky_horizon_color = sky_color_horizon  # Lighter blue at horizon
	sky_material.ground_bottom_color = ground_color  # Brown ground color
	sky_material.ground_horizon_color = ground_color.lightened(0.3)  # Slightly lighter brown at horizon
	
	# Configure sky gradient curves for proper visibility (valid ProceduralSkyMaterial properties)
	sky_material.sky_curve = 0.25  # Sky gradient curve - controls how quickly sky color changes with altitude
	sky_material.ground_curve = 0.02  # Ground gradient curve - controls ground color blending
	
	# Set sun parameters for apogee (90-degree elevation - directly overhead)
	sky_material.sun_angle_max = 60.0  # Sun disk size in degrees
	sky_material.sun_curve = 0.15  # Sun intensity curve
	# Sun position is controlled by the directional light orientation, not sky material properties
	
	# Apply the sky material to the sky resource
	sky.sky_material = sky_material
	
	# Apply the sky to the environment
	environment.sky = sky
	
	# Set ambient lighting from sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.3  # Moderate ambient lighting
	
	# Sky brightness is controlled by the sky material itself and ambient lighting
	
	# Apply environment to the scene using WorldEnvironment node (proper Godot 4 method)
	var world_environment = WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	world_environment.environment = environment
	add_child(world_environment)
	
	print("VisualizationSystem: Sky environment setup complete - Sky colors: top=%s, horizon=%s" % [sky_color_top, sky_color_horizon])

func setup_lighting():
	"""
	Set up directional lighting to simulate the sun at specified elevation and azimuth
	Creates realistic lighting for aerial simulation with proper shadows
	"""
	print("VisualizationSystem: Setting up sun lighting...")
	
	# Create directional light to simulate the sun
	var sun_light = DirectionalLight3D.new()
	sun_light.name = "SunLight"
	
	# Calculate sun position based on elevation and azimuth angles
	# elevation_rad: float - sun elevation in radians (size: 1 float)
	var elevation_rad = deg_to_rad(sun_elevation_degrees)
	# azimuth_rad: float - sun azimuth in radians (size: 1 float)  
	var azimuth_rad = deg_to_rad(sun_azimuth_degrees)
	
	# For apogee (90° elevation), sun is directly overhead pointing straight down
	# sun_direction: Vector3 - normalized direction vector pointing toward sun (size: 3 floats)
	var sun_direction: Vector3
	
	if sun_elevation_degrees >= 89.0:
		# Sun at apogee - directly overhead, pointing straight down
		sun_direction = Vector3(0, 1, 0)  # Pointing straight up (sun position)
	else:
		# Calculate sun direction from spherical coordinates for other elevations
		sun_direction = Vector3(
			cos(elevation_rad) * sin(azimuth_rad),  # X component
			sin(elevation_rad),                     # Y component (elevation)
			cos(elevation_rad) * cos(azimuth_rad)   # Z component
		)
	
	# Position the light high above the scene
	sun_light.position = Vector3(0, 10000, 0) * visual_scale
	
	# Orient the light to shine straight down from apogee
	if sun_elevation_degrees >= 89.0:
		# Point straight down for overhead sun
		sun_light.look_at(Vector3(0, 0, 0), Vector3.FORWARD)
	else:
		# Orient the light to shine from the calculated sun direction
		sun_light.look_at(sun_light.position - sun_direction * 1000, Vector3.UP)
	
	# Configure light properties for realistic sun lighting
	sun_light.light_energy = 1.2  # Bright sun intensity
	sun_light.light_color = Color(1.0, 0.95, 0.8)  # Slightly warm sunlight color
	
	# Enable shadows for realistic terrain and object shading
	sun_light.shadow_enabled = true
	sun_light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun_light.directional_shadow_max_distance = 50000.0 * visual_scale  # Long shadow distance for aerial view
	
	# Add the sun light to the scene
	add_child(sun_light)
	
	print("VisualizationSystem: Sun positioned at %s° elevation, %s° azimuth" % [sun_elevation_degrees, sun_azimuth_degrees])

func setup_ground():
	"""
	Create a large brown ground plane to serve as the base terrain
	Provides a consistent brown surface beneath the detailed terrain data
	"""
	print("VisualizationSystem: Setting up ground plane...")
	
	# Create a large ground plane mesh
	var ground_mesh_instance = MeshInstance3D.new()
	ground_mesh_instance.name = "GroundPlane"
	
	# Create a large plane mesh for the ground (size in meters scaled by visual_scale)
	var plane_mesh = PlaneMesh.new()
	plane_mesh.size = Vector2(200000, 200000) * visual_scale  # Very large ground plane (200km x 200km)
	plane_mesh.subdivide_width = 10  # Some subdivision for potential detail
	plane_mesh.subdivide_depth = 10
	
	# Create brown material for the ground
	var ground_material = StandardMaterial3D.new()
	ground_material.albedo_color = ground_color  # Brown color
	ground_material.roughness = 0.8  # Rough surface like dirt/soil
	ground_material.metallic = 0.0   # Non-metallic surface
	
	# Apply material and mesh to the instance
	ground_mesh_instance.mesh = plane_mesh
	ground_mesh_instance.material_override = ground_material
	
	# Position the ground plane at ground level (Y=0)
	ground_mesh_instance.position = Vector3(0, 0, 0)
	
	# Add to the scene
	add_child(ground_mesh_instance)
	
	print("VisualizationSystem: Ground plane setup complete")

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
		
		# WASD movement: W=forward(-Z), S=backward(+Z), A=left(-X), D=right(+X)
		if Input.is_key_pressed(KEY_W):
			input_dir.z -= 1  # Move forward (negative Z direction)
		if Input.is_key_pressed(KEY_S):
			input_dir.z += 1  # Move backward (positive Z direction)
		if Input.is_key_pressed(KEY_A):
			input_dir.x -= 1  # Move left (negative X direction)
		if Input.is_key_pressed(KEY_D):
			input_dir.x += 1  # Move right (positive X direction)
		# Vertical movement: C=up(+Y), SHIFT=down(-Y)
		if Input.is_key_pressed(KEY_C):
			input_dir.y += 1  # Move up (positive Y direction)
		if Input.is_key_pressed(KEY_SHIFT):
			input_dir.y -= 1  # Move down (negative Y direction)
			
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
