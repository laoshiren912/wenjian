extends SceneTree

const POOL = preload("res://scripts/v41_card_pool.gd")
var checks := 0
var failures := 0

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", label)

func _initialize() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var counts: Array[int] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
	for slot in range(3):
		check(not POOL.eligible(7 + slot, counts), "upgrade requires move")
	var first := POOL.draw(counts, rng)
	check(first.size() == 3 and 4 in first and 5 in first and 6 in first, "all empty slots")
	counts[4] = 1
	check(POOL.eligible(7, counts), "unlocked move enables upgrade")
	for i in range(100):
		var options := POOL.draw(counts, rng)
		check(options.size() == 3 and 5 in options and 6 in options and 4 not in options, "empty slots first")
		check(options[0] != options[1] and options[1] != options[2] and options[0] != options[2], "no duplicates")
	counts[5] = 1
	counts[6] = 1
	counts[1] = 1
	counts[3] = 1
	for i in range(100):
		var options := POOL.draw(counts, rng)
		check(options.any(func(card): return card >= 7), "force new")
		check(not 1 in options and not 3 in options, "single old cards excluded")
	counts[7] = 1
	counts[8] = 1
	counts[9] = 1
	check(POOL.draw(counts, rng).size() == 2, "only repeatable cards remain")
	print("Card pool: %d / %d passed" % [checks - failures, checks])
	quit(1 if failures else 0)
