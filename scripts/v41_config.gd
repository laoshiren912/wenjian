extends RefCounted

# Each integer describes an existing enemy: ordinary melee / ranged / fast thrust.
const MELEE := 0
const RANGED := 1
const THRUST := 2
const WAVES: Array[Array] = [
	[[MELEE, MELEE, MELEE, MELEE]],
	[[MELEE, MELEE, RANGED], [MELEE, MELEE, RANGED]],
	[[MELEE, MELEE, RANGED, RANGED], [MELEE, MELEE, THRUST, MELEE, RANGED]],
	[[MELEE, MELEE, THRUST, MELEE], [MELEE, MELEE, RANGED]],
	[[THRUST, MELEE, RANGED, RANGED], [MELEE, MELEE, RANGED]],
	[[MELEE, THRUST, RANGED, RANGED], [THRUST, MELEE, MELEE, MELEE, RANGED]],
]
const BOSS_ROOM := 6
const RUN_ROOMS := BOSS_ROOM + 1
const ENEMY_STATS: Array[Dictionary] = [
	{"health": 215.0, "damage": 12.0, "speed": 222.0},
	{"health": 145.0, "damage": 11.0, "speed": 145.0},
	{"health": 195.0, "damage": 15.0, "speed": 265.0},
]
const ROOM_SCALES: Array[float] = [1.0, 1.2, 1.4, 1.2, 1.3, 1.4]
const ATTACK_LIMIT := 3
const PAIR_SIZE := 2
const PAIR_APPROACH_TIMEOUT := 1.65
const WAITING_RADIUS := 132.0
const SIGHT_RANGE := 650.0
const RANGED_REACH := 415.0
const RANGED_RETREAT := 205.0
const RANGED_RECOVERY := 1.25
const MELEE_RECOVERY := 0.62
const MELEE_FACING_RECOVERY := 0.22
const GUARD_DAMAGE_FACTOR := 0.25
const GUARD_ARC_DOT := 0.34
const GUARD_HOLD := 0.16
const GUARD_COOLDOWN := 0.72
const HEAVY_BASE_BREAK := 0.85
const ENTRY_POINT := Vector2(340, 370)
const EXIT_POINT := Vector2(960, 370)
const REWARD_POINT := Vector2(640, 420)
const SPAWN_POINTS: Array[Vector2] = [Vector2(535, 365), Vector2(540, 485), Vector2(690, 345), Vector2(680, 490), Vector2(780, 365), Vector2(905, 375)]
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
	return ["剑伤害 +%.0f%%" % (SWORD_BONUS * 100.0), "翻滚后下一剑伤害翻倍", "击杀回复 %.0f 生命" % KILL_HEAL, "第三段破防延长至1.5秒（普通近战不击退，压制0.65秒）"]

static func room_total(index: int) -> int:
	var count := 0
	for wave in WAVES[index]:
		count += wave.size()
	return count

static func run_total() -> int:
	var count := 1 # Final-room boss.
	for i in range(BOSS_ROOM):
		count += room_total(i)
	return count
