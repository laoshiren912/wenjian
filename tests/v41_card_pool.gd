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
	var counts: Array[int] = [0, 0, 0, 0, 1, 1, 0, 1, 1, 0]
	for card in range(4, 10):
		check(not POOL.eligible(card, counts), "legacy move stays retired even with old counts")
	var offered := {}
	for i in range(32):
		var choices := POOL.draw(counts, rng)
		check(choices.size() == 3 and choices.all(func(c): return c >= 0 and c < 4), "attribute choices only")
		check(choices[0] != choices[1] and choices[1] != choices[2] and choices[0] != choices[2], "distinct options")
		for card in choices:
			offered[card] = true
	check(offered.size() == 4, "all attribute cards still offered")
	counts[1] = 1
	counts[3] = 1
	counts[0] = 2
	counts[2] = 2
	var remaining := POOL.draw(counts, rng)
	remaining.sort()
	check(remaining == [0, 2], "stacking cards remain available after unique cards are acquired")
	print("Card pool: %d / %d passed" % [checks - failures, checks])
	quit(1 if failures else 0)
