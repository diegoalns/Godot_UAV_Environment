class_name SimulationEngine
extends Node

@onready var drone_manager = DroneManager.new()
@onready var flight_plan_manager = FlightPlanManager.new()
@onready var visualization_system = VisualizationSystem.new()
@onready var logger = SimpleLogger.new()

var simulation_time: float = 0.0
var running: bool = false
var speed_multiplier: float = 1.0
var time_step: float = 1.0
var real_runtime: float = 0.0
var headless_mode: bool = false
var plans: Array = [] 



func _ready():
	add_child(visualization_system)
	add_child(drone_manager)
	add_child(flight_plan_manager)
	add_child(logger)

	# Connect systems
	drone_manager.set_visualization_system(visualization_system)
	
	flight_plan_manager.load_flight_plans()

	await get_tree().process_frame
	
	plans = flight_plan_manager.get_flight_plans()
	
	# Add UI
	var canvas_layer = CanvasLayer.new()
	var ui = SimpleUI.new()
	canvas_layer.add_child(ui)
	add_child(canvas_layer)
	
	# Connect UI signals
	ui.start_requested.connect(_on_start_requested)
	ui.pause_requested.connect(_on_pause_requested)
	ui.speed_changed.connect(_on_speed_changed)
	ui.headless_mode_changed.connect(_on_headless_mode_changed)

func _on_start_requested():
	running = true

func _on_pause_requested():
	running = false

func _on_speed_changed(multiplier: float):
	speed_multiplier = multiplier

func _on_headless_mode_changed(enabled: bool):
	headless_mode = enabled
	visualization_system.set_enabled(!enabled)
	
func _physics_process(delta: float):
	Engine.physics_ticks_per_second = 30  # Set to 120 physics FPS
	if not running:
		return
		
	# Simulation time and real runtime calculation
	simulation_time += time_step * speed_multiplier
	real_runtime += delta
	
	# Launch the drones when ETD
	for plan in plans:
		if plan.etd_seconds == simulation_time and plan.created == false:
			plan.created = true
			var origin = flight_plan_manager.latlon_to_position(plan.origin_lat, plan.origin_lon)
			var destination = flight_plan_manager.latlon_to_position(plan.dest_lat, plan.dest_lon)
			drone_manager.create_test_drone(plan.id, origin, destination, plan.model)
			print("Created drone %s from %s to %s" % [plan.id, origin, destination])
	
	# Update all created drones
	drone_manager.update_all(time_step * speed_multiplier)
	# Remove completed drones from memory
	drone_manager.remove_completed_drones()
	
	# Log data
	logger.update(time_step, simulation_time, drone_manager.drones)
	
	#if int(simulation_time) % 3 == 0 and simulation_time - delta < int(simulation_time):
	print("Simulation time: %.5f seconds" % simulation_time)
	print("Real runtime: %.5f seconds" % real_runtime)
