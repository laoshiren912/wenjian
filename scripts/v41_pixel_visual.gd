extends ActorVisual

const S_IDLE = preload("res://assets/characters/Swordsman/Swordsman_Idle_Sheet_780x1440.png")
const S_WALK = preload("res://assets/characters/Swordsman/Swordsman_Walk_Sheet_1404x1440.png")
const S_ATTACK = preload("res://assets/characters/Swordsman/Swordsman_Attack_Sheet_1404x1440.png")
const S_DEATH = preload("res://assets/characters/Swordsman/Swordsman_Death_Sheet_1404x540.png")
const B_IDLE = preload("res://assets/characters/Bandit/Bandit_Idle_Sheet_780x1312.png")
const B_WALK = preload("res://assets/characters/Bandit/Bandit_Walk_Sheet_1404x1312.png")
const B_ATTACK = preload("res://assets/characters/Bandit/Bandit_Attack_Sheet_1404x656.png")
const B_DEATH = preload("res://assets/characters/Bandit/Bandit_Death_Sheet_1404x328.png")
const ART_SCALE := 0.55

var look_direction := Vector2.DOWN
var animation_clock := 0.0
var player_death := false
var player_death_age := 0.0

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if get_parent() is SurvivorPlayer:
		process_mode = Node.PROCESS_MODE_ALWAYS
		get_parent().died.connect(_player_died)

func _player_died() -> void:
	player_death = true
	player_death_age = 0.0
	queue_redraw()

func _process(delta: float) -> void:
	if player_death:
		player_death_age += delta
		queue_redraw()

func update_pose(actual_motion: Vector2, look: Vector2, color: Color, leg_look: Vector2 = Vector2.ZERO) -> void:
	if look.length_squared() > 0.01:
		look_direction = look.normalized()
	super.update_pose(actual_motion, look, color, leg_look)

func _physics_process(delta: float) -> void:
	if not get_tree().paused:
		animation_clock += delta
		super._physics_process(delta)

func _direction_index(direction: Vector2) -> int:
	return posmod(roundi((direction.angle() + PI / 2.0) / (PI / 4.0)), 8)

func _draw() -> void:
	var is_player := get_parent() is SurvivorPlayer or player_death
	var direction := attack_direction if attack_time > 0.0 and attack_weapon == 0 else look_direction
	var index := _direction_index(direction)
	var size := Vector2(156, 180 if is_player else 164)
	var pivot := Vector2(79, 135) if is_player else Vector2(78, 126)
	var sheet: Texture2D = S_IDLE if is_player else B_IDLE
	var frame := int(animation_clock * 6.0) % 5
	var row := index
	var flip := false
	var enemy = get_parent() if not is_player and not dying else null
	var enemy_attacking: bool = enemy != null and (enemy.windup > 0.0 or enemy.lunge_time > 0.0)
	if dying or player_death:
		sheet = S_DEATH if is_player else B_DEATH
		var age: float = player_death_age if player_death else death_age
		frame = mini(8, int(age / (0.9 if player_death else DEATH_DURATION) * 9.0))
		if is_player:
			row = 0 if index in [0, 1, 2, 7] else (2 if index in [5, 6] else 1)
		else:
			row = 1 if index in [5, 6, 7] else 0
	elif attack_time > 0.0 and attack_weapon == 0 or enemy_attacking:
		sheet = S_ATTACK if is_player else B_ATTACK
		var progress: float = 1.0 - attack_time / attack_duration if is_player else (1.0 - enemy.windup / maxf(enemy.attack_duration, 0.001) if enemy.windup > 0.0 else 0.8)
		frame = clampi(int(progress * 9.0), 0, 8)
		if not is_player:
			var rows := [0, 0, 1, 1, 2, 3, 3, 0]
			row = rows[index]
			flip = index in [6, 7]
	elif motion.length_squared() >= 1.0 and roll_time <= 0.0:
		sheet = S_WALK if is_player else B_WALK
		frame = int(animation_clock * 8.0) % 9
	elif not charge_aim.is_zero_approx():
		index = _direction_index(charge_aim)
		row = index
	var destination := Rect2(-pivot * ART_SCALE + Vector2(0, 15), size * ART_SCALE)
	var source := Rect2(Vector2(frame * size.x, row * size.y), size)
	var color := Color(2.0, 2.0, 2.0, 1.0) if hurt_time > 0.0 else Color.WHITE
	if flip:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1, 1))
	draw_texture_rect_region(sheet, destination, source, color)
	if flip:
		draw_set_transform(Vector2.ZERO)
