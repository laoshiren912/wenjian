extends SurvivorPlayer

# Reward hook only: all movement, stamina and roll timing stay in the base player.
func try_roll() -> bool:
	var succeeded := super.try_roll()
	if succeeded and combo.roll_reward:
		combo.roll_armed = true
	return succeeded
