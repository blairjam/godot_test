extends KinematicBody

const MAX_X_AXIS_ROTATION := 90
const MAX_Y_AXIS_ROTATION := 360
const MAX_JUMPS := 2

export var gravity = -20
export var jump_acceleration = 10
export var walk_speed = 3
export var look_sensitivity_vert = 0.2
export var look_sensitivity_horiz = 0.2
 
var velocity := Vector3()
var last_jump_time := OS.get_unix_time()
var jumps_remaining := MAX_JUMPS

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event):
	if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		return
	if event is InputEventMouseMotion:
		_third_person_camera_input(event)

# Moving the mouse up/down will correspond to rotation around the horizontal axis.
# Moving mouse left/right will correspond to rotation around the vertical axis.
# If the middle mouse button is pressed, the vertical rotation will be applied to the camera pivot.
# Otherwise, the vertical rotation will be applied to the player.
func _third_person_camera_input(event):
	var vertical_offset := Basis(Vector3.UP, deg2rad(-event.relative.x * look_sensitivity_vert))
	var horizontal_offset := Basis(Vector3.RIGHT, deg2rad(-event.relative.y * look_sensitivity_horiz))
	
	var camera_offset = horizontal_offset

	if not Input.is_mouse_button_pressed(BUTTON_MIDDLE):
		self.global_transform.basis = _rotate_basis(self.global_transform.basis, vertical_offset)
	else:
		camera_offset = (camera_offset * vertical_offset).orthonormalized()
	
	$camera_pivot.transform.basis = _rotate_basis($camera_pivot.transform.basis, camera_offset)
	
	# Clamp the camera_pivot's rotation to sane values.
	# Set z axis to 0 so our camera is always oriented correctly.
	$camera_pivot.rotation_degrees = _clamp_rotation($camera_pivot.rotation_degrees)

	var self_rotation = self.rotation_degrees
	self.rotation_degrees = _clamp_rotation(self_rotation, {x = self_rotation.x, z = self_rotation.z})
	
func _clamp_rotation(origin: Vector3, values: Dictionary = {}):
	var clamped := Vector3.ZERO
	clamped.x = _clamp_x(origin.x) if not values.has("x") else values.x
	clamped.y = _clamp_y(origin.y) if not values.has("y") else values.y
	clamped.z = 0 if not values.has("z") else values.z
	return clamped

func _clamp_y(angle: float):
	return clamp(angle, -MAX_Y_AXIS_ROTATION, MAX_Y_AXIS_ROTATION)
	
func _clamp_x(angle: float):
	return clamp(angle, -MAX_X_AXIS_ROTATION, MAX_X_AXIS_ROTATION)

func _rotate_basis(origin: Basis, offset: Basis, distance = 0.5):
	return origin.slerp(origin * offset, distance).orthonormalized()

func _process(delta):
	if Input.is_action_just_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			
	if not Input.is_mouse_button_pressed(BUTTON_MIDDLE):
		_handle_mouse_middle_button_released()
		
func _handle_mouse_middle_button_released():
	# Move the camera directly behind the player by setting y axis rotation to 0.
	# The effect is to keep the camera looking in the same direction.	
	var current_rotation = $camera_pivot.transform.basis.get_rotation_quat()
	var target_rotation = Quat(Vector3.UP, 0) * Quat(Vector3.RIGHT, $camera_pivot.rotation.x)
	
	var rotation = current_rotation.slerp(target_rotation, 0.05)
	
	$camera_pivot.transform.basis = Basis(rotation.normalized())

func _physics_process(delta):
	# Reset input and movement vectors
	var input_movement := Vector2()
	var movement_direction := Vector3()
	
	# Check keyboard input
	if Input.is_action_pressed("move_forward"):
		input_movement.y += 1
	if Input.is_action_pressed("move_backward"):
		input_movement.y -= 1
	if Input.is_action_pressed("move_left"):
		input_movement.x -= 1
	if Input.is_action_pressed("move_right"):
		input_movement.x += 1
	if Input.is_action_pressed("move_jump") and is_on_floor():
		velocity.y += jump_acceleration

	# Update movement_direction vector
	var self_basis = self.global_transform.basis
	movement_direction += -self_basis.z * input_movement.y
	movement_direction += self_basis.x * input_movement.x

	# Normalize movement direction
	movement_direction = movement_direction.normalized()
	
	# Add effect of gravity
	velocity.y += gravity * delta
	
	# Add effect of walk speed
	movement_direction *= walk_speed
	
	velocity.x = movement_direction.x
	velocity.z = movement_direction.z
	velocity = move_and_slide(velocity, Vector3.UP)
