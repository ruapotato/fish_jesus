extends CharacterBody3D

var speed = 5.0
const ACCELERATION = 10.0 # For stopping if player disappears
# Epsilon threshold to prevent rotation jitter when almost stopped
const MIN_MOVE_SPEED_SQR = 0.01 # Square of minimum speed to trigger rotation

# Variable to hold the reference to the player node
var player: Node3D = null

@onready var mesh = $Humanoid # Assuming Humanoid is a MeshInstance3D

var root
var run_time = 5
# --- Engine Functions ---

func get_root():
	var test = get_parent()
	while test.name != "root":
		test = test.get_parent()
	return(test)

func _ready() -> void:
	root = get_root()
	print(root.name)
	# --- Get Player Node ---
	# Attempt to find player recursively under the parent
	player = root.find_child("player", true, false)

func _physics_process(delta: float) -> void:
	run_time -= delta
	if run_time < 0:
		root._spawn_fish_human(global_position.x, global_position.z)
		hit()


	# 1. Apply Gravity
	if not is_on_floor():
		velocity += get_gravity() * delta

	# 2. Calculate the horizontal direction *away from the player*
	var direction_away = global_position - player.global_position
	direction_away.y = 0 # Keep movement horizontal

	# 3. Set horizontal velocity based on direction
	if direction_away.length_squared() > 0.001: # Check length before normalizing
		direction_away = direction_away.normalized()
		velocity.x = direction_away.x * speed
		velocity.z = direction_away.z * speed
	else:
		# Stop horizontal movement (using speed for a quick stop like original)
		velocity.x = move_toward(velocity.x, 0, speed * delta) # Corrected: use delta with move_toward
		velocity.z = move_toward(velocity.z, 0, speed * delta) # Corrected: use delta with move_toward

	# 4. Apply the final velocity
	move_and_slide()

	# --- Update Mesh Rotation ---
	# Ensure mesh reference is still valid (paranoid check, but good practice)
	if not is_instance_valid(mesh):
		return

	# 5. Rotate the mesh to face the horizontal movement direction
	var horizontal_velocity = Vector3(velocity.x, 0, velocity.z)

	# Only rotate if the character is moving horizontally above a small threshold
	if horizontal_velocity.length_squared() > MIN_MOVE_SPEED_SQR:
		# Calculate the point to look at in world space, based on current position and velocity direction
		var look_target_point = global_position + horizontal_velocity
		# Use look_at. Aligns the mesh's local -Z axis with the target direction.
		# Vector3.UP is the standard up direction.
		mesh.look_at(look_target_point, Vector3.UP)

		# --- Optional Correction ---
		# If your mesh model faces a different direction by default (e.g., +X instead of -Z),
		# you might need to apply an additional rotation after look_at.

		mesh.rotate_y(deg_to_rad(-130))

		# Example: If mesh's forward is +Z (appears rotated 180deg after look_at):
		# mesh.rotate_y(deg_to_rad(180))

func hit():
	print("I'm Dead!")
	if self in root.exclude:
		root.exclude.erase(self)
	queue_free()

func im_saved():
	root.good_counter.text = str(int(root.good_counter.text) + 1)
	speed = 0
	$saved.play()


func _on_audio_stream_player_3d_finished() -> void:
	$AudioStreamPlayer3D.play()


func _on_saved_finished() -> void:
	hit()
