class_name VisualizationSystem
extends Node3D

var drone_meshes: Dictionary = {}

func _ready():
	setup_camera()
	setup_lighting()

func setup_camera():
	var camera = Camera3D.new()
	camera.position = Vector3(-74000, 100, 41000)
	add_child(camera)  # ✅ Add to tree first
	camera.look_at(Vector3(-74000, 0, 40700), Vector3.UP)  # ✅ Now it works

func setup_lighting():
	var light = DirectionalLight3D.new()
	light.position = Vector3(-73000, 100, 41700)
	add_child(light)  # ✅ Add to tree first
	light.look_at(Vector3(-74000, 0, 41000), Vector3.UP)  # ✅ Now it works

func add_drone(drone: Drone):
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
	if drone.drone_id in drone_meshes:
		drone_meshes[drone.drone_id].position = drone.current_position
