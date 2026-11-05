extends "res://scripts/sword_orbit.gd"

const CONFIG = preload("res://scripts/v41_config.gd")
var roll_reward := false
var heavy_reward := false
var roll_armed := false
var swing_bonus := 1.0

func attack(direction: Vector2) -> bool:
	if not super.attack(direction):
		return false
	swing_bonus = CONFIG.ROLL_SWORD_FACTOR if roll_reward and roll_armed else 1.0
	roll_armed = false
	return true

func _release_charge(direction: Vector2) -> void:
	swing_bonus = CONFIG.ROLL_SWORD_FACTOR if roll_reward and roll_armed else 1.0
	roll_armed = false
	super._release_charge(direction)

func _deal_hit(target: Node2D, damage: float, push: Vector2) -> void:
	var break_guard := heavy_reward and stage == 2 and not charged_swing
	if break_guard:
		target.guard_time = 0.0
		target.guard_cooldown = maxf(target.guard_cooldown, CONFIG.GUARD_BREAK_TIME)
		push = swing_direction * CONFIG.HEAVY_PUSH
	target.take_damage(damage * swing_bonus, push, break_guard)
