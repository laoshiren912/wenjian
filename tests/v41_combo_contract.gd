extends SceneTree
const CONFIG = preload("res://scripts/v41_config.gd")
var failures := 0
var checks := 0
var events: Array[String] = []
func _initialize(): run.call_deferred()
func check(ok: bool, label: String):
 checks += 1
 if not ok:
  failures += 1
  printerr("FAIL ",label)
func run():
 var game = load("res://scenes/main_v41.tscn").instantiate()
 root.add_child(game)
 current_scene = game
 await physics_frame
 game.start_room()
 var player = game.player
 player.position = Vector2(620,420)
 var es = get_nodes_in_group("enemies")
 for e in es:
  e.set_physics_process(false)
  e.position = Vector2(1000,600)
  e.guard_cooldown = 10.0
 var sword = player.combo
 sword.combo_event.connect(func(kind, _slot, _point, _target): events.append(kind))
 var enemy = es[0]
 for slot in range(3):
  for rank in range(3):
   player.cultivation = rank
   sword.swing_rank = rank
   sword.stage = slot
   var reach: float = sword.current_data().reach + CONFIG.SWORD_EXTENSION[rank]
   for i in range(8):
    var dir = Vector2.from_angle(i * TAU / 8)
    enemy.position = player.position + dir.rotated(deg_to_rad(10.0)) * (reach + 5.0)
    var aim: Vector2 = sword._sword_assist(dir)
    check(aim.is_equal_approx(dir), "nearby enemy cannot bend slot/rank/direction %d/%d/%d" % [slot,rank,i])
    sword.swing_direction = aim
    var edge: Vector2 = sword.blade_segment(1.0)[1]
    check(edge.dot(aim) > 0, "edge forward")
   enemy.position = player.position + Vector2.RIGHT.rotated(deg_to_rad(16.0)) * 65.0
   check(sword._sword_assist(Vector2.RIGHT).is_equal_approx(Vector2.RIGHT), "outside cone")
 enemy.position = Vector2(1100,600)
 sword.reset_chain()
 check(sword.attack(Vector2.RIGHT), "miss attack starts")
 for i in range(30): await physics_frame
 check(events.count("miss") == 1, "exactly one miss")
 sword.swing_time = 0
 enemy.position = player.position + Vector2(45,0)
 enemy.guard_time = 0
 enemy.guard_cooldown = 10
 enemy.health = 1000
 sword.stage = 0
 sword.swing_direction = Vector2.RIGHT
 events.clear()
 sword._deal_hit(enemy, 32, Vector2.RIGHT * 115)
 check(events.has("hit") and not events.has("blocked"), "normal hit")
 enemy.guard_time = 1
 enemy.guard_direction = Vector2.LEFT
 events.clear()
 sword._deal_hit(enemy, 32, Vector2.RIGHT * 115)
 check(events.has("blocked"), "blocked")
 enemy.guard_time = 1
 enemy.guard_cooldown = 10
 sword.stage = 2
 events.clear()
 sword._deal_hit(enemy, 60, Vector2.RIGHT * 115)
 check(events.has("guard_break"), "guard break")
 enemy.health = 1
 enemy.guard_time = 0
 enemy.guard_cooldown = 10
 sword.stage = 0
 events.clear()
 sword._deal_hit(enemy, 32, Vector2.RIGHT * 115)
 check(events.has("kill"), "kill")
 check(is_equal_approx(sword.click_buffer, 0.30) and is_equal_approx(sword.chain_window,0.30), "buffer values")
 game._end_hitstop()
 game.last_combo_impact_ms = -10000
 game.last_combo_shake_ms = -10000
 game._third_impact(Vector2.ZERO)
 var generation: int = game.hitstop_generation
 var first_shake: int = game.last_combo_shake_ms
 game._third_impact(Vector2.ZERO)
 check(game.hitstop_generation == generation and game.last_combo_shake_ms == first_shake, "repeat impact does not stack hitstop or shake")
 game._end_hitstop()
 game.feedback.reset_sword_cues()
 check(game.feedback._cue_ready("contact", CONFIG.COMBO_SOUND_GAP_MS), "first contact sound allowed")
 check(not game.feedback._cue_ready("contact", CONFIG.COMBO_SOUND_GAP_MS), "repeated contact sound limited")
 print("COMBO CONTRACT ",checks - failures,"/",checks)
 game.free()
 await process_frame
 quit(1 if failures else 0)
