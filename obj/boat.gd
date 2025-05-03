extends RigidBody3D

## Script to make a RigidBody3D rock vigorously like a boat while staying in place.

# Export variables to allow tweaking the rocking motion in the Inspector
@export_group("Rocking Motion")
@export var rocking_enabled : bool = true

# --- Increased Amplitudes and Speeds for More Rocking ---
@export_group("Pitch (X-axis Rotation)")
# Increased amplitude for much larger pitching motion
@export var pitch_amplitude : float = 6.0  # Max angle deviation in degrees for pitch (WAS 1.5)
# Slightly increased speed for faster pitching
@export var pitch_speed : float = 0.8    # Speed/frequency of the pitch rocking (WAS 0.6)

@export_group("Roll (Z-axis Rotation)")
# Increased amplitude for much larger rolling motion
@export var roll_amplitude : float = 8.0   # Max angle deviation in degrees for roll (WAS 2.0)
# Slightly increased speed for faster rolling
@export var roll_speed : float = 0.6     # Speed/frequency of the roll rocking (WAS 0.4)

@export_group("Physics Control")
# Might need adjustment if the rocking becomes too wild or sluggish with new amplitudes
@export var corrective_strength : float = 25.0 # How strongly the boat tries to reach the target rocking angle. (Slightly increased from 20.0)


# Store the initial position to ensure it doesn't drift (optional extra safety)
# var initial_position : Vector3

func _ready() -> void:
	# Ensure the body mode allows for physics simulation but we control movement
	# MODE_RIGID is default and correct.

	# --- Freeze Linear Movement ---
	# This prevents the Rigidbody from moving from its spot due to gravity or external forces.
	axis_lock_linear_x = true
	axis_lock_linear_y = true
	axis_lock_linear_z = true

	# Store initial position if you want to strictly enforce it later (usually axis lock is enough)
	# initial_position = global_transform.origin

	# --- Crucial for gentle rocking ---
	# Set Angular Damp mode to ensure damping applies correctly
	angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE # Or COMBINE, depending on desired effect
	# Set Angular Damp value IN THE INSPECTOR for the RigidBody3D node.
	# A value between 1.0 and 5.0 is usually good to start.
	# Higher values make the rocking stop faster / feel heavier / resist the motion more.
	# Lower values let it rock more freely. Adjust this to get the desired feel.
	# If angular_damp is 0, the rocking might become too strong or unstable.
	if angular_damp <= 0.1:
		push_warning("Angular Damp on the RigidBody3D is low or zero. Consider increasing it in the Inspector (e.g., to 1.0-5.0) for more stable rocking, especially with high amplitudes.")


func _physics_process(delta: float) -> void:
	if not rocking_enabled:
		# If rocking is disabled, potentially apply torque to bring it back to zero rotation
		# Or just return if you want it to freeze wherever it stopped.
		# Example: apply_central_torque(-angular_velocity * mass * 0.1) # Simple damping torque
		return

	# --- Calculate Target Rocking Angles ---
	var time = Time.get_ticks_msec() / 1000.0 # Get time in seconds

	# Calculate target angles using sine/cosine for smooth oscillation
	# Convert degrees to radians as physics functions use radians
	var target_pitch_rad = deg_to_rad(sin(time * pitch_speed) * pitch_amplitude)
	# Use cosine or a phase shift for roll to make it less uniform than pitch
	var target_roll_rad = deg_to_rad(cos(time * roll_speed) * roll_amplitude)

	# --- Apply Corrective Torque ---
	# Get the current rotation in radians
	var current_rotation_rad = rotation

	# Calculate the difference (error) between current and target rotation for pitch and roll
	var pitch_error = target_pitch_rad - current_rotation_rad.x
	var roll_error = target_roll_rad - current_rotation_rad.z
	# We ignore the Y-axis (yaw) for simple boat rocking

	# Calculate the torque needed to correct the error.
	# The torque is proportional to the error, making it stronger the further away it is.
	var corrective_torque = Vector3(pitch_error, 0, roll_error) * corrective_strength

	# Apply the torque around the body's center of mass
	apply_torque(corrective_torque)


	# Optional: Strictly enforce position if axis lock isn't sufficient (rarely needed)
	# global_transform.origin = initial_position
	# linear_velocity = Vector3.ZERO # Force stop any residual velocity
