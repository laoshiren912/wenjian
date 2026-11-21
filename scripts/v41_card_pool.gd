extends RefCounted

static func eligible(card: int, counts: Array[int]) -> bool:
	return card >= 0 and card < 4 and card < counts.size() and (card in [0, 2] or counts[card] == 0)

static func draw(counts: Array[int], rng: RandomNumberGenerator) -> Array[int]:
	var cards: Array[int] = []
	for card in range(4):
		if eligible(card, counts):
			cards.append(card)
	for i in range(cards.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var previous := cards[i]
		cards[i] = cards[j]
		cards[j] = previous
	return cards.slice(0, 3)
