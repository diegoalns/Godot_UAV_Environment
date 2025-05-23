class_name SimpleUI
extends Control

signal start_requested
signal pause_requested
signal speed_changed(multiplier: float)

@onready var start_button = Button.new()
@onready var speed_slider = HSlider.new()
@onready var status_label = Label.new()

var is_running = false

func _ready():
	setup_ui()

func setup_ui():
	# Layout
	var vbox = VBoxContainer.new()
	add_child(vbox)
	
	# Start/Pause button
	start_button.text = "Start"
	start_button.pressed.connect(_on_start_pressed)
	vbox.add_child(start_button)
	
	# Speed control
	var speed_label = Label.new()
	speed_label.text = "Speed: "
	vbox.add_child(speed_label)
	
	speed_slider.min_value = 0.1
	speed_slider.max_value = 5.0
	speed_slider.value = 1.0
	speed_slider.value_changed.connect(_on_speed_changed)
	vbox.add_child(speed_slider)
	
	# Status
	status_label.text = "Ready"
	vbox.add_child(status_label)

func _on_start_pressed():
	is_running = !is_running
	if is_running:
		start_button.text = "Pause"
		emit_signal("start_requested")
	else:
		start_button.text = "Start"
		emit_signal("pause_requested")

func _on_speed_changed(value: float):
	emit_signal("speed_changed", value)

func update_status(text: String):
	status_label.text = text
