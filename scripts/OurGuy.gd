extends CharacterBody3D

var speed = 0.0

const JUMP_VELOCITY = 7
const SENSITIVITY = 0.003
const WALK_SPEED = 2.0 
const SPRINT_SPEED = 4.0

#allows for after-ledge jumps
var floorer = 1.0
var first_jump = true

#bob moment
const BOB_FREQ = 2.0
const BOB_AMP = 0.08
var t_bob = 0.0

#fov
const FOV_BASE = 90
const FOV_CHANGE = 1


var gravity = 18

@onready var head = $Node3D
@onready var camera = $Node3D/Camera3D
@onready var frontal_raycasts = $Frontnode
@onready var upper_raycasts = $Headnode
#@onready var   floor_checker = $Downernode/FloorChecker

var is_climbing = false
var climb_point : Vector3

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event):
	if event is InputEventMouseMotion:
		head.rotate_y(-event.relative.x * SENSITIVITY)
		frontal_raycasts.rotate_y(-event.relative.x * SENSITIVITY)
		upper_raycasts.rotate_y(-event.relative.x * SENSITIVITY)
		camera.rotate_x(-event.relative.y * SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, -PI/2, PI/2)

func _physics_process(delta):
	
	var space = get_viewport().world_3d.direct_space_state
	
	if Input.is_action_just_pressed("ui_end"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else: Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		
	# Add the gravity.
	if not is_on_floor():
#		if not can_climb():
			velocity.y -= gravity * delta
			floorer = lerp(floorer, 0.0, 30.0*delta) #leniency vvv
	else:
		first_jump = true
		floorer = 1.0
		# handle sprint. ground shift only
		if Input.is_action_pressed("sprint"):
			speed = SPRINT_SPEED * delta * 100
		else:
			speed = WALK_SPEED * delta * 100

	# Handle Jump.
	if Input.is_action_just_pressed("ui_accept"):
		if can_climb() and not is_climbing:
			is_climbing = true 
##			print(frontal_raycast.get_global_position())
##			print(frontal_raycast.get_collision_point() - frontal_raycast.get_global_position())
#			floor_checker.set_global_position(frontal_raycast.get_collision_point() + Vector3(0, 1, 0))
#			floor_checker.force_raycast_update()
#			if not floor_checker.is_colliding():
#				print("climb can't be initiated")
#			climb_point = floor_checker.get_collision_point()
#			print(floor_checker.get_global_position())
#			print(climb_point)
			var colpoint : Vector3
			var frontal_raycast_children = frontal_raycasts.get_children()
			var results : Dictionary
			for i in range(3):
				print(frontal_raycast_children[i].name)
				if frontal_raycast_children[i].is_colliding():
#					print(frontal_raycast_children[i].get_collision_point() + Vector3(0.1, 1.1, 0).rotated(Vector3.UP, frontal_raycasts.rotation_degrees.y))
#					print(frontal_raycast_children[i].get_collision_point() + Vector3(0.1, -0.1, 0).rotated(Vector3.UP, frontal_raycasts.rotation_degrees.y))
					results = space.intersect_ray(
						PhysicsRayQueryParameters3D.create(
							frontal_raycast_children[i].get_collision_point() +
							Vector3(0, 1.1, -0.15).rotated(Vector3.UP, frontal_raycasts.rotation.y),
							frontal_raycast_children[i].get_collision_point() +
							Vector3(0, -0.1, -0.15).rotated(Vector3.UP, frontal_raycasts.rotation.y)
						)
					)
					print(frontal_raycasts.rotation_degrees.y)
					print(results)
					break
			if results.is_empty():
				is_climbing = false
				if first_jump and floorer > 0.001: #leniency = = = 
					first_jump = false
					velocity.y = JUMP_VELOCITY
				return
			climb_point = results["position"]
			var tween = create_tween().parallel()
			tween.tween_property(self, "position", climb_point, 0.7).set_trans(Tween.TRANS_EXPO)
			tween.tween_callback(func(): is_climbing = false)
			tween.tween_callback(func(): print("finished climb!"))
#			is_climbing = false
#			print("climbing module reached \"false\"")
		elif first_jump and floorer > 0.001: #leniency ^^^
			first_jump = false
			velocity.y = JUMP_VELOCITY

	
		# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction = (head.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if is_on_floor():
		if direction:
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
		else:
			velocity.x = 0
			velocity.z = 0
			velocity.x = lerp(velocity.x, direction.x * speed, 5.0 * delta)
			velocity.z = lerp(velocity.z, direction.z * speed, 5.0 * delta)
	else:
		velocity.x = lerp(velocity.x, direction.x * speed, 3.0 * delta)
		velocity.z = lerp(velocity.z, direction.z * speed, 3.0 * delta)
	
	move_and_slide()
	
	# camera fov
	var fov_velocity_clamped = clamp(Vector2(velocity.x, velocity.z).length(), 0, SPRINT_SPEED * 2)
	var fov_target = FOV_BASE + FOV_CHANGE * fov_velocity_clamped
	camera.fov = lerp(camera.fov, fov_target, 20.0 * delta)
	
	# camera bob
	if Vector2(velocity.x, velocity.z).length() < 0.001 or not(is_on_floor()):
		camera.transform.origin = lerp(camera.transform.origin, Vector3.ZERO, 4.0 * delta)
		t_bob = 4.5/BOB_FREQ*PI
	else:
		t_bob += delta * velocity.length() * float(is_on_floor())
		camera.transform.origin = _headbob(t_bob)


func _headbob(time) -> Vector3:
	var pos = Vector3.ZERO
	pos.y = sin(time * BOB_FREQ) * BOB_AMP - BOB_AMP
	pos.x = cos(time * BOB_FREQ/3) * BOB_AMP
	return pos

func can_climb():
	var collided_fronts = 0
	for frontalcast in frontal_raycasts.get_children():
		if frontalcast.is_colliding():
			collided_fronts+=1
	if collided_fronts <1:
		return false
	for oneraycast in upper_raycasts.get_children():
		if oneraycast.is_colliding():
			return false
#	if not floor_checker.is_colliding():
#		return false
	return true
