extends CharacterBody2D
@export var speed := 300.0
@export var ground_acceleration := 1800.0
@export var ground_deceleration := 2200.0
@export var air_acceleration := 1200.0
@export var air_deceleration := 500.0
@export_range(0.0, 89.0) var max_slope_degrees := 45.0
@export var jump_velocity := -500.0
@export var coyote_time := 0.1              
@export var jump_buffer_time := 0.12        
@export var jump_cut_multiplier := 0.45   
@export var fall_gravity_multiplier := 1.6  
@export var apex_gravity_multiplier := 0.5  
@export var apex_threshold := 60.0
@export var max_fall_speed := 900.0
@export var roll_radius := 16.0             
@export var jump_stretch := Vector2(0.75, 1.3)
@export var land_squash := Vector2(1.35, 0.7)
@export var squash_recovery_speed := 12.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D

var visual: Node2D
var visual_base_position := Vector2.ZERO
var coyote_timer := 0.0
var jump_buffer_timer := 0.0
var was_on_floor := false


func _ready() -> void:
	floor_max_angle = deg_to_rad(max_slope_degrees + 1.0) 
	floor_snap_length = 12.0   
	floor_constant_speed = true  
	floor_stop_on_slope = true  
	var circle := collision.shape as CircleShape2D
	if circle:
		roll_radius = circle.radius * absf(collision.scale.x)

	visual = Node2D.new()
	visual.name = "Visual"
	add_child(visual)
	visual.position = sprite.position
	visual_base_position = visual.position
	sprite.reparent(visual)


func _physics_process(delta: float) -> void:
	var on_floor := is_on_floor()

	if on_floor:
		coyote_timer = coyote_time
	else:
		coyote_timer -= delta

	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = jump_buffer_time
	else:
		jump_buffer_timer -= delta

	if not on_floor:
		var gravity := get_gravity()
		if absf(velocity.y) < apex_threshold and Input.is_action_pressed("jump"):
			gravity *= apex_gravity_multiplier
		elif velocity.y > 0.0:
			gravity *= fall_gravity_multiplier
		velocity += gravity * delta
		velocity.y = minf(velocity.y, max_fall_speed)

	if jump_buffer_timer > 0.0 and coyote_timer > 0.0:
		velocity.y = jump_velocity
		jump_buffer_timer = 0.0
		coyote_timer = 0.0
		visual.scale = jump_stretch

	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= jump_cut_multiplier

	var direction := Input.get_axis("left", "right")
	var accel: float
	if direction != 0.0:
		accel = ground_acceleration if on_floor else air_acceleration
	else:
		accel = ground_deceleration if on_floor else air_deceleration
	velocity.x = move_toward(velocity.x, direction * speed, accel * delta)

	var fall_speed := velocity.y
	move_and_slide()

	if is_on_floor() and not was_on_floor:
		var impact := clampf(fall_speed / max_fall_speed, 0.3, 1.0)
		visual.scale = Vector2.ONE.lerp(land_squash, impact)
	was_on_floor = is_on_floor()

	_update_roll(delta)
	_update_squash(delta)


func _update_roll(delta: float) -> void:
	var roll_speed := velocity.x
	if is_on_floor():
		var n := get_floor_normal()
		var along_floor := Vector2(-n.y, n.x)
		roll_speed = get_real_velocity().dot(along_floor)

	sprite.rotation = wrapf(sprite.rotation + roll_speed / roll_radius * delta, -PI, PI)


func _update_squash(delta: float) -> void:
	visual.scale = visual.scale.lerp(Vector2.ONE, 1.0 - exp(-squash_recovery_speed * delta))
	visual.position.y = visual_base_position.y + roll_radius * (1.0 - visual.scale.y)
