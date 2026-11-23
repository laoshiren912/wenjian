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
	for rank in range(3):
		var offered := {}
		for i in range(24):
			var choices := POOL.draw(counts, rng, rank)
			check(choices.size() == 3 and choices.all(func(c): return POOL.tier(c) == rank), "three cards of exact rank %d" % rank)
			check(choices[0] != choices[1] and choices[1] != choices[2] and choices[0] != choices[2], "distinct options")
			for card in choices:
				offered[card] = true
		check(offered.size() == POOL.TIERS[rank].size(), "all cards of that rank reachable")
	check(not POOL.eligible(POOL.Card.RAIN, counts, 1), "rank one cannot select a gold card")
	counts[POOL.Card.LOTUS] = 1
	check(POOL.draw(counts, rng, 0).has(POOL.Card.LOTUS), "basic cards can be learned twice")
	counts[POOL.Card.LOTUS] = 2
	check(not POOL.eligible(POOL.Card.LOTUS, counts, 2), "stacking cap enforced")
	counts[POOL.Card.RAIN] = 1
	var fallback := POOL.draw(counts, rng, 2)
	check(fallback.size() == 3 and POOL.tier(fallback[0]) == 2 and POOL.tier(fallback[1]) == 2 and POOL.tier(fallback[2]) == 1, "exhausted tier uses one eligible lower grade")
	print("Card pool: %d / %d passed" % [checks - failures, checks])
	quit(1 if failures else 0)
