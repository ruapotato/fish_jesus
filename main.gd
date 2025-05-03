extends Node3D

@onready var boat = $boat

# Preload the scene for the fish human
@export var fish_human_scene: PackedScene = preload("res://obj/fish_human.tscn")

# --- Spawn Configuration ---
@export_group("Spawning")
# How often to spawn a new fish human (in seconds)
@export var spawn_interval: float = 2.0
# The Z coordinate where fish humans will spawn
@export var spawn_z_position: float = -50.0
# The Z coordinate after which fish humans will be removed
@export var despawn_z_position: float = 50.0
# The range along the X-axis where fish humans can spawn (+/- this value from X=0)
@export var spawn_x_range: float = 20.0
# The Y coordinate where fish humans will spawn (e.g., water level)
@export var spawn_y_position: float = -0.5
# How fast the fish humans move along the Z-axis
@export var fish_speed: float = 3.0

# Timer node for controlling spawn rate
@onready var spawn_timer: Timer = $SpawnTimer # Make sure you add a Timer node named "SpawnTimer" as a child!

# Group name for easy identification of spawned fish
const FISH_HUMAN_GROUP = "fish_humans"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# --- Setup Spawn Timer ---

	# Configure the timer
	spawn_timer.wait_time = spawn_interval
	spawn_timer.one_shot = false # Make the timer repeat
	# Connect the timer's "timeout" signal to the _on_spawn_timer_timeout function
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	# Start the timer
	spawn_timer.start()

	# Initial spawn call (optional, if you want one immediately)
	# _spawn_fish_human()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

# Function called when the SpawnTimer times out
func _on_spawn_timer_timeout() -> void:
	_spawn_fish_human()


# Function to handle the creation and setup of a single fish human
func _spawn_fish_human() -> void:
	# Check if the scene is loaded correctly
	if fish_human_scene == null:
		printerr("Error: fish_human_scene is not set or loaded!")
		return

	# Create an instance of the fish human scene
	var fish_instance = fish_human_scene.instantiate()

	# Check if instantiation was successful
	if fish_instance == null:
		printerr("Error: Failed to instantiate fish_human_scene!")
		return

	# --- Set Initial Position ---
	# Calculate a random X position within the defined range
	var random_x = randf_range(-spawn_x_range, spawn_x_range)
	# Set the initial global position
	fish_instance.global_position = Vector3(random_x, spawn_y_position, spawn_z_position)

	# --- Add to Scene and Group ---
	# Add the instance as a child of this node (the spawner)
	boat.add_child(fish_instance)
	# Add the instance to the designated group for tracking
	fish_instance.add_to_group(FISH_HUMAN_GROUP)
	# Add metadata to help identify these nodes in _process (safer than just group check)
	fish_instance.set_meta("is_fish_human", true)

	print("Spawned fish human at: ", fish_instance.global_position) # Optional debug print
