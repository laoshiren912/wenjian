extends "res://scripts/v41_room_decoration.gd"

const SHADOW_SPEED := 12.0
const CLOUD_SPEED := 24.0
const CLOUD_BAND_HEIGHT := 240.0
const CLOUD_ENTRY_STEP := 83.0
const ROOM_WIDTH := 1280.0
const WRAP_PADDING := 24.0
const SHADOW_LARGE = preload("res://assets/vfx/torr-penn-cloud-shadows/shadow-mask-0.png")
const SHADOW_MEDIUM = preload("res://assets/vfx/torr-penn-cloud-shadows/shadow-mask-3.png")
const SHADOW_SMALL = preload("res://assets/vfx/torr-penn-cloud-shadows/shadow-mask-5.png")
const CLOUD_LARGE = preload("res://assets/vfx/torr-penn-cloud-shadows/original_cloud_0.png")
const CLOUD_MEDIUM = preload("res://assets/vfx/torr-penn-cloud-shadows/original_cloud_3.png")
# Combat feedback is at Z 20 with labels up to relative Z 3. HUD uses a CanvasLayer.
const FOREGROUND_CLOUD_Z := 24

@export var cloud_shadows_enabled := true
var cloud_shadows: Node2D

func _ready() -> void:
	super._ready()
	set_process(false)

func set_cloud_shadows_active(in_first_room: bool) -> void:
	if not in_first_room or not cloud_shadows_enabled:
		set_process(false)
		if is_instance_valid(cloud_shadows):
			cloud_shadows.free()
			cloud_shadows = null
		return
	if is_instance_valid(cloud_shadows):
		return

	cloud_shadows = Node2D.new()
	cloud_shadows.name = "GroundCloudShadows"
	add_child(cloud_shadows)
	var large_point := Vector2(260, 205)
	var medium_point := Vector2(765, 417)
	_add_cloud_sprite(SHADOW_LARGE, large_point, 2.55, 0.34)
	_add_cloud_sprite(SHADOW_MEDIUM, medium_point, 2.15, 0.42)
	_add_cloud_sprite(SHADOW_SMALL, Vector2(1135, 550), 1.95, 0.32)
	_add_cloud_sprite(CLOUD_LARGE, Vector2(260, 135), 2.55, 0.5, true)
	_add_cloud_sprite(CLOUD_MEDIUM, Vector2(855, 347), 2.15, 0.5, true)
	_add_cloud_sprite(CLOUD_MEDIUM, Vector2(530, 584), 1.95, 0.5, true)
	set_process(true)

func _add_cloud_sprite(texture: Texture2D, point: Vector2, magnification: float, opacity: float, foreground := false) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.position = point
	sprite.scale = Vector2.ONE * magnification
	sprite.self_modulate.a = opacity
	if foreground:
		sprite.z_as_relative = false
		sprite.z_index = FOREGROUND_CLOUD_Z
	cloud_shadows.add_child(sprite)

func _process(delta: float) -> void:
	for sprite: Sprite2D in cloud_shadows.get_children():
		# Wrap only after the entire texture has cleared the room on either side.
		var margin := sprite.texture.get_width() * sprite.scale.x * 0.5 + WRAP_PADDING
		var span := ROOM_WIDTH + 2.0 * margin
		var is_foreground := not sprite.z_as_relative
		var speed := CLOUD_SPEED if is_foreground else SHADOW_SPEED
		var travel := sprite.position.x + margin + speed * delta
		sprite.position.x = fposmod(travel, span) - margin
		if is_foreground and travel >= span:
			# Shift the entry height within its band while the cloud is offscreen.
			var band_start := floorf(sprite.position.y / CLOUD_BAND_HEIGHT) * CLOUD_BAND_HEIGHT
			var laps := floorf(travel / span)
			sprite.position.y = band_start + fposmod(sprite.position.y - band_start + laps * CLOUD_ENTRY_STEP, CLOUD_BAND_HEIGHT)

func _draw() -> void:
	paint_room(false)
