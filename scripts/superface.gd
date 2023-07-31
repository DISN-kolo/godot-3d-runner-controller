extends Control

func _ready():
	$Label.text = 'initializing label...'

func indicator_visibility(vis):
	$Sprite2D.visible = vis

func text_display(text):
	$Label.text = str(text) 
