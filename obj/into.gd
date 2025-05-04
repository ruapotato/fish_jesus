extends Node2D

@onready var game = preload("res://main.tscn")
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_video_stream_player_finished() -> void:
	var new_game = game.instantiate()
	add_child(new_game)
	visible = false
