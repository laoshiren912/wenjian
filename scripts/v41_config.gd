extends RefCounted

# Each integer describes an existing enemy: ordinary melee / ranged / fast thrust.
const MELEE := 0
const RANGED := 1
const THRUST := 2
const WAVES: Array[Array] = [
	[[MELEE, MELEE, MELEE, MELEE]],
	[[MELEE, MELEE, RANGED], [MELEE, MELEE, RANGED]],
	[[MELEE, MELEE, RANGED], [MELEE, THRUST, MELEE, RANGED]],
	[[MELEE, MELEE, THRUST], [MELEE, THRUST, RANGED], [MELEE, MELEE, RANGED]],
	[[MELEE, THRUST, RANGED], [MELEE, MELEE, THRUST], [MELEE, RANGED, RANGED]],
	[[MELEE, MELEE, THRUST], [MELEE, THRUST, RANGED], [MELEE, MELEE, THRUST, RANGED]],
]
const BOSS_ROOM := 6
const FLOATING_RUINS_ROOM := 4
const RUN_ROOMS := BOSS_ROOM + 1
const ENEMY_STATS: Array[Dictionary] = [
	{"health": 215.0, "damage": 15.0, "speed": 242.0},
	{"health": 145.0, "damage": 14.0, "speed": 158.0},
	{"health": 195.0, "damage": 19.0, "speed": 285.0},
]
const ROOM_SCALES: Array[float] = [1.0, 1.2, 1.4, 1.2, 1.3, 1.4]
const ATTACK_LIMIT := 3
const PAIR_SIZE := 2
const PAIR_APPROACH_TIMEOUT := 1.65
const WAITING_RADIUS := 132.0
const SIGHT_RANGE := 650.0
const RANGED_REACH := 415.0
const RANGED_RETREAT := 205.0
const RANGED_RECOVERY := 1.05
const MELEE_RECOVERY := 0.50
const MELEE_FACING_RECOVERY := 0.22
const GUARD_DAMAGE_FACTOR := 0.25
const GUARD_ARC_DOT := 0.34
const GUARD_HOLD := 0.16
const GUARD_COOLDOWN := 0.72
const HEAVY_BASE_BREAK := 0.85
const SWORD_TIMINGS := [Vector3(0.08, 0.10, 0.14), Vector3(0.10, 0.12, 0.16), Vector3(0.085, 0.14, 0.20)]
# Per slot: windup / active / recovery in game seconds at 1x attack speed.
const COMBO_INPUT_BUFFER := 0.30
const COMBO_CHAIN_WINDOW := 0.30
const COMBO_ASSIST_DEGREES := 15.0
const COMBO_TARGET_RADIUS := 17.0
const COMBO_SOUND_GAP_MS := 50
const COMBO_SHAKE_GAP_MS := 80
const COMBO_HITSTOP_GAP_MS := 100
const THIRD_IMPACT_PROGRESS := 0.22
const BREAK_STUN := 0.65
const THIRD_MOB_PUSH := 90.0
const THIRD_GRIP_LIFT := 20.0
const THIRD_TIP_LIFT := 52.0
const THIRD_HITSTOP := 0.060
const THIRD_HITSTOP_SCALE := 0.12
const LIGHT_HITSTOP := 0.018
const LIGHT_HITSTOP_SCALE := 0.18
const GUARD_BREAK_HITSTOP := 0.068
const RAIN_HITSTOP := 0.055
const THIRD_SHAKE := 5.5
const THIRD_SHAKE_TIME := 0.18
const GUARD_DISPLAY := 0.42 # Display only; GUARD_HOLD still controls AI.
const GUARD_SPARK_TIME := 0.24
const BREAK_SPARK_TIME := 0.36
const GUARD_SOUND_DB := -16.0
const ROOM1_SPAWN := Vector2(640, 550)
const ROOM1_RETURN := Vector2(640, 305)
# Coordinates use the full 1280x720 room artwork, indexed by room_index.
const ROOM_ENTRY_POINTS: Array[Vector2] = [
	ROOM1_SPAWN,
	Vector2(640, 492),
	Vector2(346, 365),
	Vector2(280, 363),
	Vector2(280, 419),
	Vector2(640, 539),
	Vector2(640, 552),
]
# Room one uses its gate rectangle; the terminal room has no exit.
const ROOM_EXIT_POINTS: Array[Vector2] = [
	Vector2.ZERO,
	Vector2(640, 277), # Foot of the mountain stair
	Vector2(988, 242), # Front of northeast wooden bridgehead
	Vector2(640, 268), # Center plaza directly in front of the giant sword
	Vector2(948, 248), # Front of northeast pavilion stairs
	Vector2(640, 272), # Central heaven gate
]
const ROOM_EXIT_LABELS: Array[String] = [
	"北侧山门", "北侧石阶", "东北栈道", "中央巨剑前", "右上亭前石阶", "北侧天门",
]
const ROOM_NAMES: Array[String] = [
	"山门竹林", "山道石阶", "峭壁栈道", "山顶殿前", "悬空遗迹", "北侧天门", "凌霄仙庭",
]
const BOSS_NAME := "心魔"
const ROOM2_SPAWN_POINTS: Array[Vector2] = [Vector2(560, 375), Vector2(650, 285), Vector2(845, 410), Vector2(970, 490), Vector2(450, 470), Vector2(770, 310)]
const REWARD_POINT := Vector2(640, 420)
const SPAWN_POINTS: Array[Vector2] = [Vector2(535, 365), Vector2(540, 485), Vector2(690, 345), Vector2(680, 490), Vector2(780, 365), Vector2(905, 375)]
const COMBO_FIRST_TWO_MOVE_FACTOR := 0.9
const SPAWN_CLEARANCE := 36.0
const REWARD_RADIUS := 40.0
const SWORD_BONUS := 0.30
const DASH_SWORD_FACTOR := 2.0
const KILL_HEAL := 5.0
const HEAVY_PUSH := 420.0
const GUARD_BREAK_TIME := 1.5
const STAMINA_MAX := 100.0
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

const CULTIVATION_NAMES := ["凡剑期", "御气期", "仙术期"]
const CULTIVATION_KILLS := [0, 8, 18]
const CLEAR_CELEBRATION_TIME := 2.0
const CLEAR_BANNER_DELAY := 0.15
const BOSS_CLEAR_CELEBRATION_TIME := 2.15
const SWORD_EXTENSION := [0.0, 28.0, 54.0]
const DASH_DISTANCE := [156.0, 202.0, 246.0]
const DASH_DAMAGE := [65.0, 72.0, 80.0]
const DASH_MARK_DAMAGE := [0.0, 18.0, 30.0]
const DASH_WIDTH := [18.0, 22.0, 26.0]
const DASH_MARK_WIDTH := [0.0, 23.0, 30.0]
const DASH_COST := 20.0
const DASH_COOLDOWN := 1.55
const DASH_COOLDOWN_BUFFER := 0.30
const DASH_INTERRUPT_COOLDOWN := 0.55
const DASH_WINDUP := 0.10
const DASH_TRAVEL := 0.18
const DASH_RECOVERY := 0.16
const DASH_RECOVERY_CANCEL := 0.11
const DASH_RECOVERY_MOVE_FACTOR := 0.82
const DASH_CHAIN_WINDOW := 0.42
const DASH_MARK_DELAY := 0.24
const DASH_MARK_INTERVAL := 0.085
const THROW_COST := 8.0
const THROW_COOLDOWN := 1.50
const THROW_MIN_DISTANCE := 42.0
const THROW_DISTANCE := [156.0, 184.0, 214.0]
const THROW_SPIN_TIME := [0.30, 0.34, 0.38]
const THROW_SPIN_TICKS := [3, 3, 4]
const THROW_RADIUS := [34.0, 42.0, 50.0]
const THROW_OUT_DAMAGE := [28.0, 31.0, 34.0]
const THROW_SPIN_DAMAGE := [10.0, 12.0, 12.0] # 每段高频切割伤害（总计 3~4 段：30/36/48）
const THROW_RETURN_DAMAGE := [20.0, 22.0, 24.0]
const THROW_OUT_SPEED := 1060.0
const THROW_RETURN_SPEED := 1240.0
const THROW_PULL_STRENGTH := 74.0
const THROW_SLOW_DURATION := 0.36
const SWORD_RAIN_COST := 18.0
const SWORD_RAIN_COOLDOWN := 3.5
const SWORD_RAIN_CAST_RANGE := 320.0
const SWORD_RAIN_ZONE_RADIUS := 78.0
const SWORD_RAIN_CAST_TIME := 0.30
const SWORD_RAIN_ORBIT_TIME := 0.38
const SWORD_RAIN_ASCEND_TIME := 0.24
const SWORD_RAIN_FALL_STEP := 0.022
const SWORD_RAIN_DROP_TIME := 0.13
const SWORD_RAIN_CAST_MOVE_FACTOR := 0.28
const SWORD_RAIN_COUNT := [5, 7, 9]
const SWORD_RAIN_CARD_EXTRA := 2
const SWORD_RAIN_DAMAGE := [20.0, 24.0, 28.0]
const SWORD_RAIN_IMPACT_RADIUS := 36.0
const WAVE_PAUSE_TIME := 0.25
const WAVE_SUMMON_TIME := 0.55
const WAVE_LANDING_GRACE := 0.25

static func reward_names() -> Array[String]:
	return [
		"剑伤害 +%.0f%% · 万剑归宗" % (SWORD_BONUS * 100.0),
		"冲刺后下一剑伤害翻倍 · 雷霆残影",
		"击杀回复 %.0f 生命 · 破阵嗜血" % KILL_HEAL,
		"第三段破防延长至1.5秒 · 双星旋刃",
	]

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
