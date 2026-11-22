extends RefCounted

enum Card { LOTUS, THUNDER, BLOOD, SPLIT, WIDE, CRITICAL, REFRESH, RAIN, FAN, CHAIN }

const TITLES: Array[String] = ["青莲剑气", "雷霆残影", "破阵嗜血", "御剑穿云·裂", "剑气纵横", "背水剑意", "踏雪无痕", "万剑归宗·极", "惊鸿三叠·极", "九霄雷剑"]
const DESCRIPTIONS: Array[String] = [
	"惊鸿三叠第三击放出一道穿透剑气\n再习提高剑气伤害",
	"穿阵起落留影，0.4 秒后炸裂\n范围伤害并震碎格挡\n再习提高炸裂伤害",
	"击杀回复 5 气血和 14 体力\n破盾额外回 10 体力，可再习",
	"御剑穿云首次命中时\n分裂 2 道追踪小飞剑",
	"第三击剑气更宽、更远\n附带青色拖尾\n独学也可发出剑气",
	"穿阵后下一次武器攻击\n必暴击并迸发大范围横斩",
	"破盾或背击斩杀时\n立即刷新穿阵冷却",
	"飞剑翻倍，命中吸 2 气血\n每名敌人减 1.5 秒冷却\n总冷却最低 3.5 秒",
	"惊鸿三叠第三击\n齐射 3 道扇形大剑气\n穿透敌群并震碎格挡",
	"御剑穿云命中或残影炸裂\n引动青金雷弧\n弹射附近 2～3 名敌人",
]
const TIERS: Array[Array] = [[Card.LOTUS, Card.THUNDER, Card.BLOOD], [Card.SPLIT, Card.WIDE, Card.CRITICAL, Card.REFRESH], [Card.RAIN, Card.FAN, Card.CHAIN]]

static func tier(card: int) -> int:
	return 0 if card < Card.SPLIT else (1 if card < Card.RAIN else 2)

static func eligible(card: int, counts: Array[int], rank: int) -> bool:
	return card >= 0 and card < TITLES.size() and card < counts.size() and tier(card) <= rank and counts[card] < (2 if tier(card) == 0 else 1)

static func draw(counts: Array[int], rng: RandomNumberGenerator, rank: int) -> Array[int]:
	var options: Array[int] = []
	for grade in range(clampi(rank, 0, 2), -1, -1):
		var cards: Array[int] = []
		cards.assign(TIERS[grade].filter(func(card): return eligible(card, counts, rank)))
		while not cards.is_empty() and options.size() < 3:
			var index := rng.randi_range(0, cards.size() - 1)
			options.append(cards[index])
			cards.remove_at(index)
		if options.size() == 3:
			break
	return options
