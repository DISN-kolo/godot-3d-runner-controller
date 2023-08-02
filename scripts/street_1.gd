extends Node3D

@onready var player = preload("res://misc/player.tscn").instantiate()

# Called when the node enters the scene tree for the first time.
func _ready():
	self.add_child(player)
	player.set_position(Vector3(0, 1, 0))
	
func _process(delta):
	if Input.is_action_just_pressed("ui_cancel"):
		get_tree().quit()
