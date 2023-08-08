extends CharacterBody3D

var speed = 0.0

const JUMP_VELOCITY = 7
const SENSITIVITY = 0.003
const WALK_SPEED = 2.0 
const SPRINT_SPEED = 4.0

#allows for after-ledge jumps
var floorer = 1.0
var first_jump = true
var fresh_jump = 1.0 #prevent climb-jumps

##bob moment
#const BOB_FREQ = 2.0
#const BOB_AMP = 0.02
#var t_bob = 0.0

#fov
const FOV_BASE = 90
const FOV_CHANGE = 1
const FOV_ZOOM = 35.0
var movement_multiplier = 1.0 # for crouching


var gravity = 18

@onready var head = $HeadNode
@onready var camera = $HeadNode/Camera3D
@onready var frontnode = $Frontnode
@onready var one_frontal_raycast = $Frontnode/FrontalRaycast
#@onready var upper_raycasts = $UpperRaycasts
@onready var hud = $HeadNode/CanvasLayer/interface
@onready var collision = $ColliderCapsule
@onready var mesh = $MeshCapsule
@onready var topcheck = $TopCheck/RayCast3D
@onready var hands = $HeadNode/uv_HAAANZ
@onready var areascan = $AreaScan

var is_climbing = false
var is_sliding = false
var is_sprinting = false
var climb_angle_ok = false
var is_crouching = false
var climb_point : Vector3
var old_point : Vector3
var old_head_pos_relative : Vector3
var frontal_collision_normal : Vector3
var input_dir
var direction
var slide_jump_allowed = false
#var kill_slide_tween = false
var tween_slide : Tween
var slide_jump = false

func _ready():
#	Engine.time_scale = 0.5
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event):
	if event is InputEventMouseMotion:
		head.rotate_y(-event.relative.x * SENSITIVITY)
		one_frontal_raycast.rotate_y(-event.relative.x * SENSITIVITY)
#		upper_raycasts.rotate_y(-event.relative.x * SENSITIVITY)
		camera.rotate_x(-event.relative.y * SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, -PI/2, PI/2)
		hands.rotation.x = -camera.rotation.x/1.1

func _physics_process(delta):
	
	var space = get_viewport().world_3d.direct_space_state
	
	if Input.is_action_just_pressed("ui_end"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else: Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# crouching and sliding
	if Input.is_action_just_pressed("crouch") and not is_climbing and not is_sliding:
		topcheck.force_raycast_update()
		if is_crouching and not topcheck.is_colliding():
			is_crouching = false
		elif not is_crouching:
			if is_sprinting:
				is_sliding = true
				tween_slide = create_tween() 
				slide_jump_allowed=false
				tween_slide.tween_callback(func(): make_me_crouch(true))
				tween_slide.tween_callback(func(): movement_multiplier=2.2)
				tween_slide.tween_property(self, "movement_multiplier", 1.95, 0.2)
				tween_slide.tween_callback(func(): slide_jump_allowed=true)
				tween_slide.tween_property(self, "movement_multiplier", 1.8, 0.6)
				tween_slide.tween_property(self, "movement_multiplier", 0.5, 0.2)
				tween_slide.tween_callback(func(): is_crouching=true)
				tween_slide.tween_callback(func(): is_sliding=false)
				is_sprinting = false
			else:
				is_crouching = true
#		tween_slide.kill()
#		tween_slide.tween_property(self, "input_dir", Vector2(0, 1), 0)
		if not topcheck.is_colliding():
			make_me_crouch(is_crouching)
	if not is_sliding:
		if Input.is_action_just_pressed("zoom"):
			movement_multiplier /= 1.5
		if Input.is_action_just_released("zoom"):
			movement_multiplier *= 1.5
	# add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta
		floorer = lerp(floorer, 0.0, 30.0*delta) #leniency vvv
	else:
		first_jump = true
		floorer = 1.0
		# handle sprint. ground shift only
		if Input.is_action_pressed("sprint") and not is_crouching and not is_sliding:
			speed = SPRINT_SPEED * delta * 100 * movement_multiplier
			is_sprinting = true
		else:
			speed = WALK_SPEED * delta * 100 * movement_multiplier
			is_sprinting = false
#	if kill_slide_tween:
#		print("yeah i know dude")
#		tween_slide.stop()
#		tween_slide.kill()
#		is_sliding = false
#		topcheck.force_raycast_update()
#		if is_crouching and not topcheck.is_colliding():
#			is_crouching = false
#			make_me_crouch(false)
#			kill_slide_tween = false
	# handle jump and climb
	hud.indicator_visibility(can_climb() or is_climbing)
	if Input.is_action_pressed("ui_accept") and ((not is_sliding) or slide_jump_allowed):
		if is_sliding:
			print("hey! you're supposed to be killing the slide tween")
#			kill_slide_tween = true
			print("yeah i know dude")
			tween_slide.stop()
			tween_slide.kill()
			is_sliding = false
			topcheck.force_raycast_update()
			if not topcheck.is_colliding():
				is_crouching = false
				make_me_crouch(false)
				slide_jump = true
			else:
				is_crouching = true
				make_me_crouch(true)
#				kill_slide_tween = false
				
		one_frontal_raycast.position.y = 1.9 - 0.9*int(is_crouching)
		if can_climb() and not is_climbing:
			is_climbing = true 
			var colpoint : Vector3
			var results : Dictionary
			for i in range(190-90*int(is_crouching), 100-60*int(is_crouching), -1):
				one_frontal_raycast.position.y = i/100.0
				one_frontal_raycast.force_raycast_update()
				if one_frontal_raycast.is_colliding():
					colpoint = one_frontal_raycast.get_collision_point()
					frontal_collision_normal = one_frontal_raycast.get_collision_normal()
					if frontal_collision_normal.angle_to(Vector3.UP) < PI/2-0.2:
						continue
					results = space.intersect_ray(
						PhysicsRayQueryParameters3D.create(
							colpoint +
							Vector3(0, 1.1, -0.1).rotated(Vector3.UP, one_frontal_raycast.rotation.y),
							colpoint +
							Vector3(0, -0.1, -0.1).rotated(Vector3.UP, one_frontal_raycast.rotation.y)
						)
					)
					break
			if results.is_empty():
				print("empty results")
				is_climbing = false
				if first_jump and floorer > 0.001: #leniency = = = 
					first_jump = false
					velocity.y = JUMP_VELOCITY
			else:
				climb_point = results["position"]
				old_head_pos_relative = head.position
				old_point = self.global_position
				head.position -= (climb_point-old_point)
				self.global_position = climb_point
				var tween_climb = create_tween().parallel()
				tween_climb.tween_property(head, "position", old_head_pos_relative, 0.5).set_trans(Tween.TRANS_EXPO)
				tween_climb.tween_callback(func(): is_climbing = false)
				self.velocity = Vector3.ZERO
				fresh_jump = 0.0
				tween_climb.tween_property(self, "fresh_jump", 1.0, 0.05)
	#			tween_climb.tween_callback(func(): print("finished climb!"))
	if Input.is_action_just_pressed("ui_accept"):
		if first_jump and floorer > 0.001 and not (can_climb() and not is_climbing) and not is_sliding and fresh_jump >= 0.95: #leniency ^^^
			first_jump = false
			if is_crouching:
				velocity.y = JUMP_VELOCITY * sqrt(movement_multiplier)
			else:
				if slide_jump:
					velocity.y = JUMP_VELOCITY * 1.1
				else:
					velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	if is_sliding:
		input_dir = Vector2(0, -1)
	else:
		input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		direction = (head.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if is_on_floor():
		if not is_climbing:
			if direction:
				if slide_jump:
					speed *= 1.4
					slide_jump = false
				velocity.x = direction.x * speed
				velocity.z = direction.z * speed
			else:
				velocity.x = 0
				velocity.z = 0
				velocity.x = lerp(velocity.x, direction.x * speed, 5.0 * delta)
				velocity.z = lerp(velocity.z, direction.z * speed, 5.0 * delta)
	else:
		slide_jump = false
		velocity.x = lerp(velocity.x, direction.x * speed, 3.0 * delta)
		velocity.z = lerp(velocity.z, direction.z * speed, 3.0 * delta)
	$AnimationTree.set("parameters/conditions/walk", is_on_floor() and not is_climbing and direction)
	$AnimationTree.set("parameters/conditions/reset", not(is_on_floor() and not is_climbing and direction))
	
	move_and_slide()
	$AnimationTree.set("parameters/walk/TimeScale/scale", (Vector2(velocity.x, velocity.z).length()/WALK_SPEED)/2)
	hud.text_display(str(velocity) + '\n' +
					'movement multiplier: ' + str(movement_multiplier) + '\n' +
					str(velocity.length()) + '\n' +
					'is on floor: ' + str(is_on_floor()) + '\n' +
					'collision normal angle: ' + str(frontal_collision_normal.angle_to(Vector3.UP)) + '\n' +
					'is crouching: ' + str(is_crouching) + '\n' +
					'is climbing: ' + str(is_climbing) + '\n' +
					'is sliding: ' + str(is_sliding) + '\n' +
					'is sprinting: ' + str(is_sprinting) + '\n' +
					'(not is_sliding) or slide_jump_allowed: ' + str(((not is_sliding) or slide_jump_allowed)))
	
	# camera fov
	var fov_velocity_clamped = clamp(Vector2(velocity.x, velocity.z).length(), 0, SPRINT_SPEED * 2)
	var fov_target = FOV_BASE + FOV_CHANGE * fov_velocity_clamped
	if Input.is_action_pressed("zoom"): #zoomy zooms
		fov_target = FOV_ZOOM
	camera.fov = lerp(camera.fov, fov_target, 20.0 * delta)

func make_me_crouch(yes:bool):
	if yes:
		print("beginning crouch")
		$AreaScan/CollisionShape3D.scale.y = 0.4
		$AreaScan/CollisionShape3D.position.y = 0.55
		$AreaScan/MeshInstance3D.scale.y = 0.4
		$AreaScan/MeshInstance3D.position.y = 0.55
		movement_multiplier = 0.5
		collision.scale.y = 0.5
		collision.position.y = 0.5001
		mesh.scale.y = 0.5
		mesh.position.y = 0.5
		head.position.y = 1.0
#		upper_raycasts.position.y = -1.05
		frontnode.scale.y = 0.5
		hands.position = Vector3(0, 0.05, 0.1)
	else:
		print("ending crouch")
		$AreaScan/CollisionShape3D.scale.y = 0.9
		$AreaScan/CollisionShape3D.position.y = 1.05
		$AreaScan/MeshInstance3D.scale.y = 0.9
		$AreaScan/MeshInstance3D.position.y = 1.05
		movement_multiplier = 1.0
		collision.scale.y = 1.0
		collision.position.y = 1.0001
		mesh.scale.y = 1.0
		mesh.position.y = 1.05
		head.position.y = 1.51
#		upper_raycasts.position.y = 0.0
		frontnode.scale.y = 1.0
		hands.position = Vector3(0, -0.05, 0.1)

func can_climb():
	var can_climb_var = false
	var results_checker
	var colpoint_checker
	var space_checker = get_viewport().world_3d.direct_space_state
	for i in range(190-90*int(is_crouching), 100-60*int(is_crouching), -1):
		one_frontal_raycast.position.y = i/100.0
		one_frontal_raycast.force_raycast_update()
		if one_frontal_raycast.is_colliding():
			if one_frontal_raycast.get_collision_normal().angle_to(Vector3.UP) < PI/2-0.2:
				continue
			colpoint_checker = one_frontal_raycast.get_collision_point()
			results_checker = space_checker.intersect_ray(PhysicsRayQueryParameters3D.create(
					colpoint_checker +
					Vector3(0, 1.1, -0.1).rotated(Vector3.UP, one_frontal_raycast.rotation.y),
					colpoint_checker +
					Vector3(0, -0.1, -0.1).rotated(Vector3.UP, one_frontal_raycast.rotation.y)
				)
			)
			if results_checker.is_empty():
#				print("somehow, the checked results are empty")
				can_climb_var = false
			else:
				areascan.global_position = results_checker["position"]+Vector3(0, 0.1, 0)
				if areascan.get_overlapping_bodies().is_empty():
					can_climb_var = true
	topcheck.force_raycast_update()
	if topcheck.is_colliding():
		can_climb_var = false
	return can_climb_var
