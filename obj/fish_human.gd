extends Area3D # Or CharacterBody3D/Node3D depending on your fish_human scene root

# Export the speed variable so it can be set from the spawner or inspector
@export var speed: float = 3.0
# Export the desired depth below the water surface (use a small positive value)
@export var depth_offset: float = 0.1
# Export the Z coordinate for de-spawning
@export var de_spawn_global_z: float = 100.0

# Store a reference to the water plane Node3D
var water_plane: Node3D = null

# Optional: Reference to the visual mesh if you need to rotate it
# @onready var mesh: Node3D = $MeshInstance3D # Adjust path as needed

func _ready() -> void:
	# It's often safer to wait one frame to ensure the node is fully
	# initialized and positioned within the scene tree by the spawner.
	await get_tree().process_frame

	var parent = get_parent()
	if parent is Node3D:
		water_plane = parent
		# --- Initial Position Adjustment ---
		# Set the fish's LOCAL Y position relative to the parent (water plane).
		# This places it directly on the plane (local y=0) minus the offset.
		# We preserve the local X and Z coordinates possibly set by the spawner.
		position.y = -depth_offset
	else:
		push_error("Fish (%s) must be a child of a Node3D representing the water plane." % name)
		# Disable processing if the setup is wrong to prevent errors.
		set_process(false)
		# Consider queue_free() if the fish cannot function without the plane.
		# queue_free()

	# Optional: Initial orientation if needed (e.g., face global forward)
	# look_at(global_position + Vector3.FORWARD, Vector3.UP)


func _process(delta: float) -> void:
	if water_plane == null:
		return # Stop processing if setup failed in _ready()

	# --- Movement Projected onto the Water Plane ---

	# 1. Determine the desired movement direction. Let's use the fish's
	#    local forward vector (positive Z).
	#    Alternatively, you could define a different direction vector if needed.
	var move_direction_local: Vector3 = Vector3.BACK

	# 2. Convert this local direction to a global direction.
	var move_direction_global: Vector3 = global_transform.basis * move_direction_local

	# 3. We want to move *within* the parent's (water_plane's) coordinate system,
	#    specifically on its local XZ plane to maintain the constant local Y offset.
	#    Convert the desired GLOBAL movement direction into the PARENT'S LOCAL space.
	var parent_global_transform: Transform3D = water_plane.global_transform
	var move_direction_parent_local: Vector3 = parent_global_transform.basis.inverse() * move_direction_global

	# 4. Project this direction onto the parent's XZ plane (zero out the Y component
	#    in the parent's local space) and normalize it to ensure constant speed.
	var move_on_plane_parent_local: Vector3 = Vector3(move_direction_parent_local.x, 0.0, move_direction_parent_local.z)

	# Avoid normalizing a zero vector if the fish points straight up/down relative to the plane
	if move_on_plane_parent_local.length_squared() > 0.0001:
		move_on_plane_parent_local = move_on_plane_parent_local.normalized()
	else:
		move_on_plane_parent_local = Vector3.ZERO # Don't move if facing perpendicular to plane

	# 5. Calculate the movement step in the parent's local space.
	var movement_step_parent_local: Vector3 = move_on_plane_parent_local * speed * delta

	# 6. Apply this movement to the fish's LOCAL position.
	#    Since movement_step_parent_local.y is 0, the fish's 'position.y'
	#    (which is relative to the parent) will remain at -depth_offset.
	position += movement_step_parent_local

	# --- De-spawning ---
	# Keep the original global Z check. Be aware this might feel counter-intuitive
	# if the water plane is heavily rotated, as "forward" movement won't strictly
	# increase global Z. You might want to despawn based on distance travelled
	# or distance from the origin projected onto the plane instead.
	if global_position.z > de_spawn_global_z:
		queue_free()
