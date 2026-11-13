extends RefCounted

# 0–3: existing rewards; 4–6: moves; 7–9: matching upgrades.
const MOVE_FIRST := 4
const UPGRADE_FIRST := 7
const SLOT_COUNT := 3

static func eligible(card: int, counts: Array[int]) -> bool:
	if card < 0 or card >= 10 or card in [6, 9] or counts.size() < 10:
		return false
	if card in [0, 2]:
		return true
	if counts[card] > 0:
		return false
	if card >= UPGRADE_FIRST:
		return counts[card - SLOT_COUNT] > 0
	return true

static func draw(counts: Array[int], rng: RandomNumberGenerator, force_new: bool = true) -> Array[int]:
	var result: Array[int] = []
	var upgrades: Array[int] = []
	var old: Array[int] = []
	for slot in range(2):
		var move := MOVE_FIRST + slot
		var upgrade := UPGRADE_FIRST + slot
		if eligible(move, counts):
			result.append(move)
		elif eligible(upgrade, counts):
			upgrades.append(upgrade)
	for card in range(4):
		if eligible(card, counts):
			old.append(card)
	_shuffle(result, rng)
	_shuffle(upgrades, rng)
	_shuffle(old, rng)
	# Filling from distinct unoccupied slots is mandatory; further choices are random.
	var candidates: Array[int] = upgrades + old
	_shuffle(candidates, rng)
	while result.size() < 3 and not candidates.is_empty():
		result.append(candidates.pop_back())
	if force_new and not upgrades.is_empty() and result.all(func(card): return card < MOVE_FIRST):
		result[2] = upgrades[0]
	_shuffle(result, rng)
	return result

static func _shuffle(cards: Array[int], rng: RandomNumberGenerator) -> void:
	for i in range(cards.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var previous := cards[i]
		cards[i] = cards[j]
		cards[j] = previous
