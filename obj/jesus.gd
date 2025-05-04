extends Node3D

@onready var save_light = $save_light
@onready var come_audio = $come_to_me_audio

var root
var player

func get_root():
	var test = get_parent()
	while test != null and test.name != "root": # Safer loop condition
		test = test.get_parent()
	# Check if root was actually found
	if test == null or test.name != "root":
		printerr("Could not find root node!")
		return null # Or handle error appropriately
	return(test)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	root = get_root()
	if root: # Only try to find player if root is valid
		player = root.find_child("player", true, false) # Recursive, non-owned search
		if not player:
			printerr("Could not find player node under root!")
	else:
		printerr("Root node not found, cannot find player.")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if root.exclude != []:
		save_light.visible = true
		if not come_audio.playing:
			come_audio.play()
	else:
		save_light.visible = false
	# Ensure player node is valid before trying to use it
	if not is_instance_valid(player):
		return # Do nothing if player doesn't exist or was freed

	# Get the player's global position
	var target_position: Vector3 = player.global_position

	# Create a new target position that is horizontally aligned with this node
	# by setting its Y coordinate to this node's Y coordinate.
	var look_at_position: Vector3 = Vector3(target_position.x, global_position.y, target_position.z)

	# Now, use look_at with the adjusted position.
	# Since the target Y is the same as this node's Y, it will only rotate around the Y axis.
	# Exception: If the player is directly above/below (X and Z are the same), look_at might not rotate.
	if global_position.distance_squared_to(look_at_position) > 0.0001: # Avoid look_at on self
		look_at(look_at_position, Vector3.UP) # Specify UP vector for stability


func _on_yo_saved_body_entered(body: Node3D) -> void:
	# Check if the body has the method before calling it (safer)
	if body.has_method("im_saved"):
		body.im_saved()
	# Original check (less safe if 'im_saved' isn't a method but a variable):
	# if "im_saved" in body:
	#	 body.im_saved()
