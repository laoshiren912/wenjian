extends RefCounted

# V4 tuning only. V3.3 combat defaults remain unchanged.
const ROOMS: Array[Array] = [[1, 1, 1], [1, 1, 1, 2], [1, 1, 1, 1, 2]]
const SPAWN_CELLS: Array[Vector2i] = [Vector2i(22, 14), Vector2i(24, 15), Vector2i(25, 13), Vector2i(26, 16), Vector2i(26, 14)]
const REWARD_CELL := Vector2i(20, 14)
const REWARD_RADIUS := 40.0
const SWORD_BONUS := 0.15
const HEALTH_BONUS := 20.0
const ROLL_FACTOR := 0.85

static func reward_names() -> Array[String]:
	return ["剑伤害 +%.0f%%" % (SWORD_BONUS * 100.0), "最大生命 +%.0f" % HEALTH_BONUS, "翻滚冷却 -%.0f%%" % ((1.0 - ROLL_FACTOR) * 100.0)]
