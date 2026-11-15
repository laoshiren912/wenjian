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
const SWORD_TIMINGS := [Vector3(0.08, 0.10, 0.14), Vector3(0.10, 0.12, 0.16), Vector3(0.12, 0.14, 0.20)]
const BREAK_STUN := 0.65
const THIRD_MOB_PUSH := 90.0
const THIRD_GRIP_LIFT := 20.0
const THIRD_TIP_LIFT := 52.0
const THIRD_HITSTOP := 0.06
const THIRD_HITSTOP_SCALE := 0.01
const THIRD_SHAKE := 5.0
const THIRD_SHAKE_TIME := 0.18
const GUARD_DISPLAY := 0.42 # Display only; GUARD_HOLD still controls AI.
const GUARD_SPARK_TIME := 0.24
const BREAK_SPARK_TIME := 0.36
const GUARD_SOUND_DB := -16.0
const ENTRY_POINT := Vector2(340, 370)
const EXIT_POINT := Vector2(960, 370)
const ROOM2_EXIT_POINT := Vector2(1010, 385)
const ROOM2_SPAWN_POINTS: Array[Vector2] = [Vector2(560, 375), Vector2(650, 285), Vector2(845, 410), Vector2(970, 490), Vector2(450, 470), Vector2(770, 310)]
const REWARD_POINT := Vector2(640, 420)
const SPAWN_POINTS: Array[Vector2] = [Vector2(535, 365), Vector2(540, 485), Vector2(690, 345), Vector2(680, 490), Vector2(780, 365), Vector2(905, 375)]
const HOLD_THRESHOLD := 0.22
const COMBO_FIRST_RECOVERY := 0.14
const COMBO_SECOND_RECOVERY := 0.16
const COMBO_THIRD_WINDUP := 0.12
const COMBO_THIRD_RECOVERY := 0.20
const COMBO_FIRST_TWO_MOVE_FACTOR := 0.9
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
const FORCE_NEW_CARD := true
const STAMINA_MAX := 100.0
const ROLL_STAMINA_COST := 15.0
const STAMINA_REGEN := 16.0
const STAMINA_REGEN_DELAY := 0.9
const BODY_WIDTH := 30.0
const ENERGY_DISTANCE := BODY_WIDTH * 8.0
const ENERGY_EXTRA_DISTANCE := BODY_WIDTH
const ENERGY_SPEED := 700.0
const ENERGY_HALF_WIDTH := 22.0
const ENERGY_DAMAGE_FACTOR := 0.85
const ECHO_DELAY := 0.35
const ECHO_DAMAGE := 55.0
const ECHO_RADIUS := 100.0
const ECHO_UPGRADED_RADIUS := 135.0

static func reward_names() -> Array[String]:
	return ["剑伤害 +%.0f%%" % (SWORD_BONUS * 100.0), "翻滚后下一剑伤害翻倍", "击杀回复 %.0f 生命" % KILL_HEAL, "第三段破防延长至1.5秒", "剑气斩 · 满蓄释放穿透剑气", "残影步 · 翻滚起点延时爆炸", "", "剑气斩强化 · 射程增加一个身位", "残影步强化 · 爆炸半径扩大", ""]

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
