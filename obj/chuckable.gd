# chuckable_area.gd
extends Area3D


@onready var splash = $splash
@onready var kill_splash = $kill_splash

@onready var kill_zone = $kill_zone
# --- Path Definition Variables ---
# These define the *shape* of the curve, not the timing anymore
var start_position: Vector3 = Vector3.ZERO
var target_position: Vector3 = Vector3.ZERO
var control_point: Vector3 = Vector3.ZERO   # Control point for the Bezier arc

# --- Movement Control ---
@export var speed: float = 10.0             # Desired constant speed (units/second)
var elapsed_distance: float = 0.0           # Total distance traveled along the arc
var total_arc_length: float = 0.0           # Pre-calculated total length of the arc
var is_moving: bool = false                 # Flag to control movement


var has_splashed = false
var splash_down = Vector3(0,0,0)
# --- Arc Shape ---
# Determines how high the arc is, relative to the distance. 0.25 means height is 1/4th of distance.
@export var arc_height_factor: float = 0.25

# --- Pre-calculated Path Data ---
# Store points along the curve and cumulative distance to allow constant speed movement
@export var path_resolution: int = 100      # How many segments to sample the curve into. More = smoother speed.
var sampled_points: PackedVector3Array = []
var cumulative_distances: PackedFloat32Array = []

# --- Optional: Collision ---
signal hit_something(body_or_area)

var root

func get_root():
	var test = get_parent()
	while test.name != "root":
		test = test.get_parent()
	return(test)
	
# --- Initialization Function (called by Player) ---
# Sets up the path, pre-calculates arc length, and starts the movement
func launch(p_start_pos: Vector3, p_target_pos: Vector3) -> void:
	start_position = p_start_pos
	target_position = p_target_pos
	elapsed_distance = 0.0
	is_moving = false # Ensure it's stopped before calculating

	# --- Calculate the control point for the arc shape ---
	var midpoint: Vector3 = start_position.lerp(target_position, 0.5)
	var distance: float = start_position.distance_to(target_position)
	var arc_height: float = distance * arc_height_factor
	control_point = midpoint + Vector3.UP * arc_height

	# --- Pre-calculate path points and arc length ---
	_calculate_path()

	# Check if path calculation resulted in a valid length
	if total_arc_length <= 0.001:
		printerr("Chuckable Area: Invalid path length, cannot launch.")
		# Optionally teleport to target and finish immediately
		# global_position = target_position
		queue_free()
		return

	# --- Set initial state and start moving ---
	global_position = start_position
	is_moving = true

	# Optional: Make the object look towards its target initially
	if start_position.distance_squared_to(target_position) > 0.001:
		look_at(target_position, Vector3.UP)


func _calculate_path() -> void:
	# Clear previous data
	sampled_points.clear()
	cumulative_distances.clear()
	total_arc_length = 0.0

	if path_resolution <= 1:
		printerr("Chuckable Area: path_resolution must be greater than 1.")
		path_resolution = 2 # Minimum sensible value

	# Add the starting point
	sampled_points.append(start_position)
	cumulative_distances.append(0.0)

	# Sample points along the Bezier curve
	var prev_point = start_position
	for i in range(1, path_resolution + 1):
		var t: float = float(i) / path_resolution
		var current_point: Vector3 = _get_bezier_point(t)
		
		# Calculate distance from the previous point and add to total length
		var segment_length: float = prev_point.distance_to(current_point)
		total_arc_length += segment_length

		# Store the point and the cumulative distance up to this point
		sampled_points.append(current_point)
		cumulative_distances.append(total_arc_length)
		
		prev_point = current_point
	
	# Ensure the very last sampled point is exactly the target position
	# This corrects potential floating point inaccuracies in the Bezier calculation at t=1
	if sampled_points.size() > 0:
		# Adjust the distance calculation for the last segment if we snap the point
		if sampled_points.size() > 1:
			var length_before_last = cumulative_distances[sampled_points.size() - 2]
			var last_segment_corrected_length = sampled_points[sampled_points.size() - 2].distance_to(target_position)
			total_arc_length = length_before_last + last_segment_corrected_length
			cumulative_distances[sampled_points.size() - 1] = total_arc_length
		else: # Only one segment (start to target)
			total_arc_length = start_position.distance_to(target_position)
			cumulative_distances[0] = total_arc_length # Should be cumulative_distances[1] if size > 1? Check indices. Needs careful check. Let's adjust logic slightly.
			# Okay, let's restart the logic slightly for clarity on the end point:
			
	# --- Re-calculate path logic slightly simplified ---
	sampled_points.clear()
	cumulative_distances.clear()
	total_arc_length = 0.0

	if path_resolution < 1: path_resolution = 1 # Minimum 1 segment (direct line)
		
	sampled_points.append(start_position)
	cumulative_distances.append(0.0)
	
	var prev_p = start_position
	for i in range(1, path_resolution): # Loop up to path_resolution - 1
		var t = float(i) / path_resolution
		var p = _get_bezier_point(t)
		total_arc_length += prev_p.distance_to(p)
		sampled_points.append(p)
		cumulative_distances.append(total_arc_length)
		prev_p = p
		
	# Add the final target point explicitly
	total_arc_length += prev_p.distance_to(target_position)
	sampled_points.append(target_position)
	cumulative_distances.append(total_arc_length)

	# print("Calculated path. Points: ", sampled_points.size(), " Total Length: ", total_arc_length)


# Helper function to calculate point on the quadratic Bezier curve
func _get_bezier_point(t: float) -> Vector3:
	t = clamp(t, 0.0, 1.0) # Ensure t is within [0, 1]
	var one_minus_t: float = 1.0 - t
	var term1: Vector3 = one_minus_t * one_minus_t * start_position
	var term2: Vector3 = 2.0 * one_minus_t * t * control_point
	var term3: Vector3 = t * t * target_position
	return term1 + term2 + term3


func _ready():
	root = get_root()
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
	if not is_moving:
		return # Only move after being launched and path calculated
	
	if has_splashed:
		splash.global_position = splash_down
	# Increase the distance traveled based on speed and time
	elapsed_distance += speed * delta

	# --- Check if we reached or passed the target distance ---
	if elapsed_distance >= total_arc_length and (splash.emitting == false and kill_splash.emitting == false):
		if not splash_down:
			splash_here()
			return
		is_moving = false # Stop processing
		# Ensure it lands *exactly* on the target
		global_position = target_position
		print("Chuckable Area reached target: ", target_position)
		# Optional: Add slight delay before queue_free if needed for effects/sound
		queue_free() # Remove the object
		return

	# --- Find the current position along the pre-calculated path ---
	# Find the segment where our elapsed_distance falls
	for i in range(1, sampled_points.size()):
		if cumulative_distances[i] >= elapsed_distance:
			# We are between point i-1 and point i
			var dist_prev: float = cumulative_distances[i-1]
			var dist_curr: float = cumulative_distances[i]
			var point_prev: Vector3 = sampled_points[i-1]
			var point_curr: Vector3 = sampled_points[i]

			# Calculate how far we are *into* this specific segment (0.0 to 1.0)
			var segment_len: float = dist_curr - dist_prev
			var segment_t: float = 0.0 # Default to start of segment if length is zero
			if segment_len > 0.0001: # Avoid division by zero
				segment_t = (elapsed_distance - dist_prev) / segment_len
			
			# Interpolate position linearly between the two sampled points
			global_position = point_prev.lerp(point_curr, segment_t)

			# --- Optional: Make object face travel direction ---
			var direction = point_curr - point_prev
			if direction.length_squared() > 0.001: # Avoid looking at zero vector
				look_at(global_position + direction.normalized(), Vector3.UP)
			
			# We found the position for this frame, exit the loop
			break


# --- Optional: Collision/Overlap Handling ---
# These still work as the Area3D moves through space
func _on_body_entered(body: Node3D) -> void:
	if not has_splashed:
		if "hit" in body:
			body.hit()
			kill_here()
	# Optional: Destroy immediately on hit, even before reaching target
	# queue_free()
	# is_moving = false # Stop moving if you free it

func bite():
	for killable in kill_zone.get_overlapping_areas():
		if "hit" in killable:
			killable.hit()

func splash_here():
	if not has_splashed:
		$splash_sound.play()
		print("SPLASH")
		splash.emitting = true
		splash_down = global_position
		has_splashed = true
		bite()

func kill_here():
	if not has_splashed:
		print("SPLASH")
		$pop_sound.play()
		kill_splash.emitting = true
		splash_down = global_position
		has_splashed = true
		root.bad_counter.text = str(int(root.bad_counter.text) + 1)
		bite()

func _on_area_entered(area: Area3D) -> void:
	if area.name == "kill_zone" or area.name == "target":
		return
	if not is_moving: return
	print("Chuckable Area hit Area during arc: %s" % area.name)
	emit_signal("hit_something", area)
	splash_here()
	
	# Optional: Destroy immediately on hit
	# queue_free()
	# is_moving = false # Stop moving if you free it
