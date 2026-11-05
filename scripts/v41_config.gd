extends RefCounted

# Each integer describes an existing enemy: ordinary melee / ranged / fast thrust.
const MELEE := 0
const RANGED := 1
const THRUST := 2
const WAVES: Array[Array] = [
	[[MELEE, MELEE, MELEE, MELEE]],
	[[MELEE, MELEE, RANGED], [MELEE, MELEE, RANGED]],
	[[MELEE, MELEE, RANGED, RANGED], [MELEE, MELEE, THRUST, RANGED]],
]
const ENEMY_STATS: Array[Dictionary] = [
	{"health": 180.0, "damage": 12.0},
	{"health": 120.0, "damage": 10.0},
	{"health": 180.0, "damage": 12.0},
]
const ROOM_SCALES: Array[float] = [1.0, 1.2, 1.4]
const ATTACK_LIMIT := 3
const PAIR_SIZE := 2
const PAIR_APPROACH_TIMEOUT := 2.5
const WAITING_RADIUS := 125.0
const ENTRY_POINT := Vector2(340, 370)
const EXIT_POINT := Vector2(960, 370)
const REWARD_POINT := Vector2(640, 420)
const SPAWN_POINTS: Array[Vector2] = [Vector2(740, 360), Vector2(815, 390), Vector2(690, 305), Vector2(900, 355), Vector2(680, 490), Vector2(535, 365)]
const HOLD_THRESHOLD := 0.22
const CHARGE_DURATION := 0.60
const CHARGE_MIN := 65.0
const CHARGE_MAX := 95.0
const CHARGE_REACH := 140.0
const CHARGE_ANGLE := 120.0
const SPAWN_CLEARANCE := 36.0
const REWARD_RADIUS := 40.0
const SWORD_BONUS := 0.30
const ROLL_SWORD_FACTOR := 2.0
const KILL_HEAL := 5.0
const HEAVY_PUSH := 420.0
const GUARD_BREAK_TIME := 1.5

static func reward_names() -> Array[String]:
	return ["剑伤害 +%.0f%%" % (SWORD_BONUS * 100.0), "翻滚后下一剑伤害翻倍", "击杀回复 %.0f 生命" % KILL_HEAL, "第三段重劈加强击退并破防"]

static func room_total(index: int) -> int:
	var count := 0
	for wave in WAVES[index]:
		count += wave.size()
	return count

static func run_total() -> int:
	var count := 0
	for i in range(WAVES.size()):
		count += room_total(i)
	return count
