extends Node

# Simple test script to verify terrain system functionality
# This can be attached to a test node to validate the GridMap terrain loading

func test_terrain_system():
	"""
	Test function to validate terrain system functionality
	Call this from _ready() or manually to test the system
	"""
	print("=== Terrain System Test ===")
	
	# Wait a moment for the terrain system to initialize
	await get_tree().create_timer(2.0).timeout
	
	# Find the simulation engine in the scene
	var simulation_engine = get_tree().get_first_node_in_group("simulation_engine")
	if not simulation_engine:
		# Try to find it by class name
		simulation_engine = get_node("/root/Main")
		if not simulation_engine or not simulation_engine is SimulationEngine:
			print("ERROR: Could not find SimulationEngine node")
			return
	
	print("Found SimulationEngine node")
	
	# Test terrain info retrieval
	var terrain_info = simulation_engine.get_terrain_info()
	if terrain_info.is_empty():
		print("WARNING: Terrain info is empty - terrain may not be ready yet")
	else:
		print("Terrain Info:")
		print("  Data points: ", terrain_info.get("data_points", "unknown"))
		print("  Approach: ", terrain_info.get("approach", "unknown"))
		print("  Tile size (meters): ", terrain_info.get("tile_size_meters", "unknown"))
		var bounds = terrain_info.get("coordinate_bounds", {})
		if not bounds.is_empty():
			print("  Coordinate bounds:")
			print("    Lat: [%.6f, %.6f]" % [bounds.get("min_lat", 0), bounds.get("max_lat", 0)])
			print("    Lon: [%.6f, %.6f]" % [bounds.get("min_lon", 0), bounds.get("max_lon", 0)])
		var origin = terrain_info.get("origin_reference", {})
		if not origin.is_empty():
			print("  Origin reference: [%.6f, %.6f]" % [origin.get("lat", 0), origin.get("lon", 0)])
	
	# Test visualization system terrain access directly
	var vis_system = simulation_engine.visualization_system
	if vis_system and vis_system.is_terrain_ready():
		print("✓ Terrain system is ready in visualization system")
		print("✓ GridMap node exists: ", vis_system.terrain_gridmap != null)
		print("✓ GridMapManager exists: ", vis_system.gridmap_manager != null)
	else:
		print("✗ Terrain system not ready in visualization system")
	
	# Test altitude queries at various positions
	print("\nTesting altitude queries:")
	var test_positions = [
		Vector3(0, 0, 0),
		Vector3(1000, 0, 1000),
		Vector3(5000, 0, 5000),
		Vector3(-1000, 0, -1000)
	]
	
	for pos in test_positions:
		var altitude = simulation_engine.get_terrain_altitude_at_position(pos)
		print("  Position %s -> Altitude: %f" % [pos, altitude])
	
	print("=== Terrain System Test Complete ===")

func _ready():
	# Automatically run test when this node is ready
	print("Terrain Test Node: Ready - starting test in 3 seconds...")
	await get_tree().create_timer(3.0).timeout
	test_terrain_system()
