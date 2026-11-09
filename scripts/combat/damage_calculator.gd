extends RefCounted
## Deterministic damage formula. Crit and variance rolls happen before this function.

static func calculate(attack: float, coefficient: float, defense: float, element: float = 1.0, critical: float = 1.0, variance: float = 1.0) -> int:
	var defense_factor := 100.0 / (100.0 + maxf(0.0, defense))
	var result := maxf(0.0, attack) * maxf(0.0, coefficient) * defense_factor * maxf(0.0, element) * maxf(0.0, critical) * maxf(0.0, variance)
	return maxi(1, int(floor(result)))
