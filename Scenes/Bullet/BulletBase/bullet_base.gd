class_name BulletBase
extends Area2D

var velocity: Vector2 = Vector2.ZERO
var speed: float = 0.0
var damage: int = 1

var _owner_layer: BulletLayer
var _active: bool = false


func _ready() -> void:
	_connect_debug_draw_signals()
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)


func setup(owner_layer: BulletLayer, spawn_position: Vector2, init_data: Dictionary = {}) -> void:
	_owner_layer = owner_layer
	global_position = spawn_position

	velocity = init_data.get("velocity", Vector2.UP)
	speed = init_data.get("speed", 600.0)
	damage = init_data.get("damage", 1)
	collision_layer = init_data.get("collision_layer", collision_layer)
	collision_mask = init_data.get("collision_mask", collision_mask)

	_active = true
	visible = true
	set_process(true)
	set_physics_process(true)
	monitoring = true
	monitorable = true


func recycle() -> void:
	if not _active:
		return

	_active = false
	visible = false
	set_process(false)
	set_physics_process(false)
	call_deferred("_do_recycle")
	#monitoring = false
	#monitorable = false
#
	#if _owner_layer != null:
		#_owner_layer.recycle_bullet(self)


func _do_recycle() ->void:
	monitoring = false
	monitorable = false

	if _owner_layer != null:
		_owner_layer.recycle_bullet(self)

func _process(delta: float) -> void:
	global_position += velocity.normalized() * speed * delta


func _on_area_entered(area: Area2D) -> void:
	if area.has_method("take_damage"):
		area.take_damage(damage)
		recycle()


func _on_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage)
		recycle()

func _connect_debug_draw_signals() -> void:
	DebugState.debug_enabled_changed.connect(_on_debug_draw_changed)
	DebugState.options_changed.connect(_on_debug_draw_options_changed)


func _on_debug_draw_changed(_enabled: bool) -> void:
	queue_redraw()


func _on_debug_draw_options_changed() -> void:
	queue_redraw()


func _draw() -> void:
	_draw_debug_collision_shape()


func _draw_debug_collision_shape() -> void:
	if not DebugState.debug_enabled or not DebugState.show_collision_shapes:
		return

	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null or shape_node.shape == null:
		return

	if shape_node.shape is CircleShape2D:
		var circle_shape := shape_node.shape as CircleShape2D
		var radius_scale = max(abs(shape_node.scale.x), abs(shape_node.scale.y))
		var radius :float = circle_shape.radius * radius_scale
		var color := _get_debug_collision_color()
		var fill_color := Color(color.r, color.g, color.b, 0.14)
		var line_color := Color(color.r, color.g, color.b, 0.95)
		draw_circle(shape_node.position, radius, fill_color)
		draw_arc(shape_node.position, radius, 0.0, TAU, 48, line_color, 1.5)


func _get_debug_collision_color() -> Color:
	if (collision_layer & CollisionLayers.PLAYER) != 0:
		return Color(0.2, 1.0, 0.35, 1.0)
	if (collision_layer & CollisionLayers.PLAYER_BULLET) != 0:
		return Color(0.25, 0.85, 1.0, 1.0)
	if (collision_layer & CollisionLayers.ENEMY) != 0:
		return Color(1.0, 0.25, 0.25, 1.0)
	if (collision_layer & CollisionLayers.ENEMY_BULLET) != 0:
		return Color(1.0, 0.65, 0.15, 1.0)
	return Color(1.0, 1.0, 1.0, 1.0)
