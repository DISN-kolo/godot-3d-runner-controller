extends MeshInstance3D
var oldpos
var contador

# Called when the node enters the scene tree for the first time.
func _ready():
	oldpos = self.position.z
	contador = 0.0
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	contador += delta/10
	if contador == 1:
		contador = 0.0
	self.position.z = oldpos + sin(contador*PI)*10
	pass
