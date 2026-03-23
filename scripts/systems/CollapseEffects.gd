extends RefCounted
class_name CollapseEffects

var _config: Dictionary = {}

func _init(config: Dictionary = {}) -> void:
	_config = config.duplicate(true)

func evaluate(run_state) -> Dictionary:
	var spr_intensity = _axis_intensity(run_state.spr, _config.get("spirit", {}))
	var bod_intensity = _axis_intensity(run_state.bod, _config.get("body", {}))
	var rep_intensity = _axis_intensity(run_state.rep, _config.get("reputation", {}))

	return {
		"spr_intensity": spr_intensity,
		"bod_intensity": bod_intensity,
		"rep_intensity": rep_intensity,
		"desaturation": lerp(0.0, 0.22, spr_intensity),
		"shake": lerp(0.0, 6.0, spr_intensity),
		"hover_instability": lerp(0.0, 7.0, spr_intensity),
		"fatigue": lerp(0.0, 0.5, bod_intensity),
		"panel_drop": lerp(0.0, 12.0, bod_intensity),
		"coldness": lerp(0.0, 0.35, rep_intensity),
		"crack_alpha": lerp(0.0, 0.45, rep_intensity),
	}

func _axis_intensity(value: int, thresholds: Dictionary) -> float:
	var low = int(thresholds.get("low", 999))
	var critical = int(thresholds.get("critical", 0))
	if value > low:
		return 0.0
	if value <= critical:
		return 1.0
	if low == critical:
		return 1.0
	return clamp(1.0 - float(value - critical) / float(low - critical), 0.0, 1.0)
