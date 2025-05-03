extends CharacterBody3D

# Export variables for easy adjustment in the editor
@export_group("Camera Control")
@export var mouse_sensitivity: float = 0.002 # Controls how fast the camera moves with the mouse
@export var min_cam_angle: float = -70.0 # Minimum vertical camera angle (degrees)
@export var max_cam_angle: float = 70.0 # Maximum vertical camera angle (degrees)

@export_group("Camera Zoom")
@export var zoom_speed: float = 35 # How fast the camera zooms in/out (using is_action_pressed)
@export var min_zoom: float = 1.0 # Minimum spring arm length (closest zoom)
@export var max_zoom: float = 10.0 # Maximum spring arm length (farthest zoom)

@export_group("Movement")
@export var rotation_speed: float = 10.0 # How fast the character mesh rotates to face movement direction

@export_group("Fishing Target")
# @export var water_level: float = -0.5 # The Y-coordinate of the water surface <-- REMOVED/COMMENTED OUT
@export var target_ray_length: float = 100.0 # How far the camera ray checks for a target <-- NEW VARIABLE

@export_group("Throwing")
# Duration for the thrown object's arc animation (in seconds)
@export var throw_duration: float = 1.5
# Path to the scene file for your chuckable object (MUST have Area3D root with chuckable_area.gd script)
const CHUCKABLE_SCENE = preload("res://obj/chuckable.tscn")

# Node references
@onready var mesh: Node3D = $fishman # Reference to the visual mesh node
@onready var cam_piv: Node3D = $piv # The node that rotates horizontally (left/right)
@onready var cam_arm: SpringArm3D = $piv/SpringArm3D # The node that rotates vertically (up/down) and controls zoom distance
@onready var cam: Camera3D = $piv/SpringArm3D/Camera3D # The actual camera node
@onready var target: Node3D = $target # The Area3D used as the fishing target (or a MeshInstance, Sprite3D, etc.)
@onready var hand: Node3D = $fishman/pull_piv
@onready var shoot_from = $fishman/pull_piv/pull/shoot_from # The point from where the object is thrown

# Movement constants
const SPEED: float = 5.0
const JUMP_VELOCITY: float = 4.5
var root
var water_body

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	root = get_parent()
	water_body = root.find_child("water").find_child("water_body")
	# Hide and capture the mouse cursor to enable camera control
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	# Ensure initial zoom is within limits
	cam_arm.spring_length = clamp(cam_arm.spring_length, min_zoom, max_zoom)


# Called during the physics processing step of the main loop.
func _physics_process(delta: float) -> void:
	# --- Gravity ---
	if not is_on_floor():
		# Apply gravity if the character is not on the floor
		velocity += get_gravity() * delta

	# --- Jumping ---
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# --- Camera Zoom ---
	var zoom_input: float = 0.0
	if Input.is_action_just_pressed("zoom_in"):
		zoom_input -= 1.0 # Zooming in decreases spring length
	if Input.is_action_just_pressed("zoom_out"):
		zoom_input += 1.0 # Zooming out increases spring length

	if zoom_input != 0.0:
		cam_arm.spring_length += zoom_input * zoom_speed * delta
		cam_arm.spring_length = clamp(cam_arm.spring_length, min_zoom, max_zoom)

	# --- Movement ---
	var input_dir := Input.get_vector("left", "right", "forward", "backward")
	var direction := (cam_piv.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
		var target_basis := Basis.looking_at(direction, Vector3.UP)
		# Apply correction if mesh isn't facing +Z by default
		# Check your mesh orientation. Remove or adjust PI/2.0 if needed.
		target_basis = target_basis.rotated(Vector3.UP, -PI/2.0)
		mesh.basis = mesh.basis.slerp(target_basis, rotation_speed * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	# --- Update Target Position ---
	update_target_position() # <-- CALLS THE MODIFIED FUNCTION

	# --- Throwing ---
	# Check if the "chuck" action was just pressed
	if Input.is_action_just_pressed("chuck"):
		chuck_object() # Call the function to handle throwing

	# Execute the movement based on velocity
	move_and_slide()


# Called when an input event occurs.
func _input(event: InputEvent) -> void:
	# Check if the input event is mouse motion and the mouse is captured
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		cam_piv.rotate_y(-event.relative.x * mouse_sensitivity)
		cam_arm.rotate_x(-event.relative.y * mouse_sensitivity)
		cam_arm.rotation.x = clamp(cam_arm.rotation.x, deg_to_rad(min_cam_angle), deg_to_rad(max_cam_angle))

	# Allow releasing/recapturing the mouse cursor by pressing Escape
	if Input.is_action_just_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


# Calculates and updates the position of the fishing target marker using Raycasting
func update_target_position() -> void:
	# Get the physics space state to perform queries
	var space_state = get_world_3d().direct_space_state
	# Ensure space state is valid (it should be during _physics_process)
	if not space_state:
		printerr("Unable to get physics space state.")
		return

	# Get camera's global transform
	var cam_transform: Transform3D = cam.global_transform
	# Ray origin is the camera's position
	var ray_origin: Vector3 = cam_transform.origin
	# Ray direction is the camera's forward vector (negative Z)
	var cam_forward: Vector3 = -cam_transform.basis.z
	# Calculate the ray's end point based on the defined length
	var ray_end: Vector3 = ray_origin + cam_forward * target_ray_length

	# Create physics query parameters
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	# Exclude the player character itself so the ray doesn't hit it
	query.exclude = [self]
	# Optional: You could set a collision_mask here to only hit certain physics layers
	# query.collision_mask = 1 # Example: only hit layer 1

	# Perform the raycast
	var result: Dictionary = space_state.intersect_ray(query)

	# Check if the ray hit anything
	if result:
		# If it hit, place the target at the collision point
		target.global_position = result.position
		# Optional: You could also use result.normal for effects or placement adjustments
	else:
		# If the ray didn't hit anything within its length (e.g., aimed at the sky),
		# place the target at the maximum ray distance.
		target.global_position = ray_end
		# Alternative: You could hide the target or keep it at the last valid position
		# target.visible = false # Example: hide target if nothing is hit
		# pass # Keep target where it was


func chuck_object() -> void:
	# Ensure the scene resource loaded correctly
	if not CHUCKABLE_SCENE:
		printerr("Chuckable scene resource not found or failed to load! Check the path in CHUCKABLE_SCENE.")
		return

	# Instantiate the chuckable scene
	var chuckable_node = CHUCKABLE_SCENE.instantiate()

	# --- Check Instantiation and Type ---
	if not chuckable_node:
		printerr("Failed to instantiate chuckable scene. It might be invalid.")
		return
	# Ensure the root node of the instantiated scene is an Area3D
	if not chuckable_node is Area3D:
		printerr("Chuckable scene's root node is NOT an Area3D! Please ensure '%s' has an Area3D root." % CHUCKABLE_SCENE.resource_path)
		chuckable_node.queue_free() # Clean up the wrongly instantiated node
		return

	# Cast to Area3D for clarity
	var chuckable_area: Area3D = chuckable_node as Area3D

	# --- Get Start and End points for the arc ---
	if not is_node_ready(): # Ensure nodes like shoot_from are ready
		printerr("Player node not ready, cannot get shoot_from position.")
		chuckable_area.queue_free() # Clean up
		return
	# Check if shoot_from node is valid before accessing position
	if not shoot_from or not is_instance_valid(shoot_from):
		printerr("shoot_from node is not valid!")
		chuckable_area.queue_free()
		return
	var start_pos: Vector3 = shoot_from.global_position

	# Check if target node is valid before accessing position
	if not target or not is_instance_valid(target):
		printerr("target node is not valid!")
		chuckable_area.queue_free()
		return
	var end_pos: Vector3 = target.global_position # Target position from raycast

	# --- Spawn the object ---
	# Position will be set precisely within the Area3D's launch function,
	# but setting it here ensures it appears at the start immediately.
	chuckable_area.global_position = start_pos

	# Add the instantiated object to the scene tree (using 'root' assigned in _ready)
	if root and is_instance_valid(root):
		root.add_child(chuckable_area)
	else:
		printerr("Cannot add chuckable to scene, 'root' node is not valid or assigned! Trying get_parent().")
		var parent = get_parent()
		if parent:
			parent.add_child(chuckable_area)
		else:
			printerr("Cannot find suitable parent to add chuckable node.")
			chuckable_area.queue_free() # Clean up if it can't be added
			return

	# --- Launch the Area3D by calling its script function ---
	# Check if the attached script has the required 'launch' method
	if chuckable_area.has_method("launch"):
		# Pass the start position, target position, and the desired animation duration
		chuckable_area.launch(start_pos, end_pos)
	else:
		# Error if the correct script isn't attached to the Area3D in chuckable.tscn
		printerr("Chuckable Area3D node does not have the required 'launch(start, end, duration)' method! Check its attached script.")
		chuckable_area.queue_free() # Clean up if it can't be launched properly
		return

	# --- SpringArm Collision Exclusion ---
	# Prevent the camera boom from colliding with the thrown object
	if cam_arm and is_instance_valid(cam_arm):
		cam_arm.add_excluded_object(chuckable_area)

	print("Launched Arc for Area3D from: %s to: %s over %s seconds" % [start_pos, end_pos, throw_duration])
