class_name VisualizationSystem
extends Node3D

var drone_meshes: Dictionary = {}
var enabled: bool = true
var balloon_ref: CharacterBody3D = null  # Reference to the balloon

# Movement and control variables
var move_speed = 5000.0  # Speed for movement
var rotation_speed = 0.001  # Speed of rotation with mouse
var mouse_sensitivity = 0.001
var camera_offset = Vector3(0, 10, 30)  # Offset from balloon position
var mouse_captured = false


func set_enabled(enable: bool):
	enabled = enable
	visible = enable

func _ready():
	setup_balloon()
	setup_camera()
	setup_lighting()
	
	# Set up input processing
	set_process_input(true)
	set_process(true)

func setup_camera():
	var camera = Camera3D.new()
	camera.position = camera_offset  # Set the local offset
	camera.current = true
	balloon_ref.add_child(camera)    # Attach camera to the balloon

func setup_lighting():
	var light = DirectionalLight3D.new()
	light.position = Vector3(-73000, 500, 41700)
	add_child(light)
	light.look_at(Vector3(-74000, 0, 41000), Vector3.UP)

func setup_balloon():
	balloon_ref = CharacterBody3D.new()
	add_child(balloon_ref)
	
	# Set motion mode to floating (space-like movement)
	balloon_ref.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	
	# Add collision shape
	var collision = CollisionShape3D.new()
	var shape = SphereShape3D.new()
	shape.radius = 5.0
	collision.shape = shape
	balloon_ref.add_child(collision)
	
	# Set initial position at grid origin (0, 100, 0)
	balloon_ref.global_position = Vector3(10262.88, 300, 8095.922)

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
	
	var mesh_instance = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(8, 1, 12)
	mesh_instance.mesh = box_mesh
	
	# Different colors for different drones
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(randf(), randf(), randf())
	box_mesh.material = material  # Assign material to the mesh itself
	mesh_instance.mesh = box_mesh
	
	add_child(mesh_instance)
	drone_meshes[drone.drone_id] = mesh_instance
	
	print("Added visualization for drone %s" % drone.drone_id)

func update_drone_position(drone: Drone):
	if not enabled:
		return
		
	if drone.drone_id in drone_meshes:
		drone_meshes[drone.drone_id].position = drone.current_position
