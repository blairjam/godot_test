extends KinematicBody

const MAX_X_AXIS_ROTATION = 89.9999
const MAX_Y_AXIS_ROTATION = 360

export var gravity = -20
export var jump_acceleration = 10
export var walk_speed = 3
export var look_sensitivity_vert = 0.2
export var look_sensitivity_horiz = 0.2
 
var velocity = Vector3()

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event):
	if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		return
	if event is InputEventMouseButton and event.button_index == BUTTON_MIDDLE and not event.pressed:
		_handle_mouse_middle_button_released()
	if event is InputEventMouseMotion:
		_handle_mouse_motion(event)

func _handle_mouse_middle_button_released():
	# Move the camera directly behind the player by setting y axis rotation to 0.
	# The effect is to keep the camera looking in the same direction.
	var rotation_degrees = $camera_pivot.rotation_degrees
	rotation_degrees.y = 0
	$camera_pivot.rotation_degrees = rotation_degrees
	
func _handle_mouse_motion(event):
	# Quaternions representing rotations around horizontal and vertical axis.
	# Mouse movement in the x axis represents vertical rotation;
	#  movement in the y axis represents horizontal rotation.
	var input_offsets = {
		vertical = Quat(Vector3.UP, deg2rad(-event.relative.x * look_sensitivity_vert)),
		horizontal = Quat(Vector3.RIGHT, deg2rad(-event.relative.y * look_sensitivity_horiz))
	}
	
	var final_offsets = { player = Quat.IDENTITY }
	
	# Middle button pressed means the camera should rotate without the player.
	if Input.is_mouse_button_pressed(BUTTON_MIDDLE):
		var pivot_offset = input_offsets.vertical * input_offsets.horizontal
		final_offsets.camera_pivot = pivot_offset.normalized()
	else:
		final_offsets.camera_pivot = input_offsets.horizontal
		final_offsets.player = input_offsets.vertical
	
	# Rotate the camera towards the pivot offset point.
	$camera_pivot.transform.basis = _rotate($camera_pivot.transform.basis, final_offsets.camera_pivot)

	# Clamp the camera_pivot's rotation to sane values.
	# Set z axis to 0 so our camera is always oriented correctly.
	var camera_rotation = $camera_pivot.rotation_degrees
	$camera_pivot.rotation_degrees = Vector3(_clamp_x(camera_rotation.x), _clamp_y(camera_rotation.y), 0)
	
	# Rotate the player towards the player offset point.
	self.global_transform.basis = _rotate(self.global_transform.basis, final_offsets.player)
	
	var self_rotation = self.rotation_degrees
	self.rotation_degrees = Vector3(self_rotation.x, _clamp_y(self_rotation.y), self_rotation.z)

func _clamp_y(angle: float):
	return clamp(angle, -MAX_Y_AXIS_ROTATION, MAX_Y_AXIS_ROTATION)
	
func _clamp_x(angle: float):
	return clamp(angle, -MAX_X_AXIS_ROTATION, MAX_X_AXIS_ROTATION)

func _rotate(rotation: Basis, offset: Quat, distance := 0.5):
	var rot := Quat(rotation)
	var half := rot.slerp(rot * offset, distance)
	
	return Basis(half)

func _process(delta):
	if Input.is_action_just_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta):
	var movement_dir = process_input()
	process_movement(delta, movement_dir)
	
func process_input():
	# Reset input and movement vectors
	var input_movement := Vector2()
	var movement_direction := Vector3()
	
	if Input.is_action_just_pressed("move_forward"):
		_handle_player_initial_movement()
	
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
	movement_direction += -self_basis.z.normalized() * input_movement.y
	movement_direction += self_basis.x.normalized() * input_movement.x
	
	return movement_direction
	
func _handle_player_initial_movement():
	# Set the players rotation to the camera's global rotation
	self.global_transform.basis = $camera_pivot.global_transform.basis
	# Update the player's rotation to 0 on x and z axis.
	# Keep and clamp the y axis to the player looks in the direction of the camera.
	self.rotation_degrees = Vector3(0, _clamp_y(self.rotation_degrees.y), 0)
	
	# Also move the camera to be behind the player
	_handle_mouse_middle_button_released()

func process_movement(delta, movement_dir):
	# Normalize movement direction
	movement_dir = movement_dir.normalized()
	
	# Add effect of gravity
	velocity.y += gravity * delta
	
	# Add effect of walk speed
	movement_dir *= walk_speed
	
	velocity.x = movement_dir.x
	velocity.z = movement_dir.z
	velocity = move_and_slide(velocity, Vector3.UP)