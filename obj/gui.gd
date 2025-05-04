extends Node2D

@onready var power_label_na = $power_label_na
@onready var power_label_good = $power_label_good
@onready var power_label_bad = $power_label_bad


var good
var bad
var karma


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func update_counts():
	bad = int($bad_count.text)
	good = int($good_count.text)
	if good > bad:
		power_label_na.visible = false
		power_label_bad.visible = false
		power_label_good.visible = true
	elif bad > good:
		power_label_na.visible = false
		power_label_bad.visible = true
		power_label_good.visible = false
	else:
		power_label_na.visible = true
		power_label_bad.visible = false
		power_label_good.visible = false
	$karma_count.text = str(abs(-bad + good))

func _on_bad_count_draw() -> void:
	update_counts()


func _on_good_count_draw() -> void:
	update_counts()
