extends CharacterBody2D
class_name Player

@export var max_health = 100
@export var health = 100
@export var speed = 150.0
@export var jump_speed = 400.0
@export var data: PlayerData

@export_group("Levitate")
@export var levitate_max_speed = 200.0
@export var levitate_acceleration = 2000.0
@export var levitate_amount_max = 1.0

@export_group("Attack")
@export var cooldown_millis = 500
@export var spread_deg = 0
@export var multishot_spread_deg = 5

@onready var levitate_particles: GPUParticles2D = $LevitateParticles

var projectile_scene: PackedScene = preload("res://Projectile/projectile.tscn")
var next_attack_timestamp = 0.0

var levitating = false
var levitate_amount = 0.0

func _physics_process(delta: float) -> void:
	handle_movement(delta)
	handle_attacking()
	levitate_particles.emitting = levitating

func handle_movement(delta: float) -> void:
	# Add the gravity
	if not is_on_floor():
		velocity += get_gravity() * delta
		velocity.y = min(Globals.terminal_velocity, velocity.y)

	if is_on_floor():
		levitate_amount = 0.0

	# Handle jump
	if Input.is_action_pressed("Jump"):
		if is_on_floor():
			velocity.y = -jump_speed
		else:
			# Handle levitation
			if not levitating and levitate_amount < levitate_amount_max:
				levitating = true
			if levitating:
				if velocity.y > -levitate_max_speed:
					velocity.y = maxf(-levitate_max_speed, velocity.y - (levitate_acceleration * delta))
					levitate_amount += delta
				if levitate_amount >= levitate_amount_max:
					levitating = false
	else:
		levitating = false

	# Handle horizontal movement
	if Input.is_action_pressed("Left"):
		velocity.x = -speed
	elif Input.is_action_pressed("Right"):
		velocity.x = speed
	else:
		velocity.x = 0

	move_and_slide()

func handle_attacking() -> void:
	var time = Time.get_ticks_msec()
	if time >= next_attack_timestamp:
		if Input.is_action_pressed("Left Click"):
			next_attack_timestamp = time + cooldown_millis - data.modifiers_left.cooldown
			shoot(data.modifiers_left)
		elif Input.is_action_pressed("Right Click"):
			next_attack_timestamp = time + cooldown_millis - data.modifiers_right.cooldown
			shoot(data.modifiers_right)

func shoot(modifier_collection: ModifierCollection) -> void:
	var mouse_pos = get_global_mouse_position()
	var look_vec = (mouse_pos - self.global_position).normalized()
	var multishot = modifier_collection.multishot + 1
	var multishot_rotation_max = -((multishot - 1) * multishot_spread_deg)
	multishot_rotation_max /= 2
	for m in multishot:
		var instance: Node2D = projectile_scene.instantiate()
		instance.global_position = self.global_position + (look_vec * 15)
		instance.look_at(mouse_pos)
		var multishot_rotation = multishot_rotation_max + (m * multishot_spread_deg)
		instance.rotate(deg_to_rad(multishot_rotation))
		apply_projectile_modifiers(instance, modifier_collection)
		add_sibling(instance)

func apply_projectile_modifiers(projectile: Node2D, modifier_collection: ModifierCollection) -> void:
	projectile.attributes = modifier_collection.create_projectile_attributes()
	if spread_deg > 0:
		var rotation_offset = (randf() * spread_deg) - (spread_deg / 2.0)
		projectile.rotate(deg_to_rad(rotation_offset))
