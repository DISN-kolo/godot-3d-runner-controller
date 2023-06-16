@tool
extends EditorScript


func _run():
	var children : Array = get_editor_interface().get_selection().get_selected_nodes()[0].get_children()
	for child in children:
		if child is MeshInstance3D:
#			var body : StaticBody = StaticBody.new()
			var childObject : MeshInstance3D = child
#			childObject.add_child(body)
#			body.set_owner(childObject.get_tree().get_edited_scene_root())
			childObject.create_trimesh_collision()
