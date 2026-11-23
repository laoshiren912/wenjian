extends RefCounted

# One wave owns one scheduler. Each selected pair gets one attack per survivor,
# then hands off after recovery. This is a round-robin queue, not an attack cap.
var groups: Array[Array] = []
var current := -1
var started: Dictionary = {}
var elapsed := 0.0
var pair_size := 2
var approach_timeout := 2.5
var handoffs := 0
var history: Array[int] = []

func configure(enemies: Array, size: int, timeout: float) -> void:
	groups.clear()
	current = -1
	started.clear()
	elapsed = 0.0
	pair_size = maxi(1, size)
	approach_timeout = timeout
	for enemy in enemies:
		if groups.is_empty() or groups.back().size() >= pair_size:
			groups.append([])
		groups.back().append(enemy)
		enemy.pair_scheduler = self
	_select_next()

func alive(enemy) -> bool:
	return is_instance_valid(enemy) and not enemy.dead and not enemy.is_queued_for_deletion()

func _select_next() -> void:
	if groups.is_empty():
		return
	for step in range(1, groups.size() + 1):
		var index := (current + step) % groups.size()
		if groups[index].any(alive):
			current = index
			started.clear()
			elapsed = 0.0
			handoffs += 1
			history.append(current)
			return
	current = -1

func owns_turn(enemy) -> bool:
	return current >= 0 and enemy in groups[current]

func can_start(enemy) -> bool:
	return owns_turn(enemy) and not started.has(enemy.get_instance_id())

func attack_started(enemy) -> void:
	started[enemy.get_instance_id()] = true

func tick(delta: float) -> void:
	if current < 0:
		return
	elapsed += delta
	var pending := false
	var recovering := false
	for enemy in groups[current]:
		if not alive(enemy):
			continue
		if started.has(enemy.get_instance_id()):
			recovering = recovering or enemy.windup > 0.0 or enemy.lunge_time > 0.0 or enemy.attack_cooldown > 0.0
		elif elapsed < approach_timeout:
			pending = true
	if not pending and not recovering:
		_select_next()
