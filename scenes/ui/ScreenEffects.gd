extends Control
class_name ScreenEffects

var _target: Control
var _base_position: Vector2 = Vector2.ZERO
var _profile: Dictionary = {}
var _time: float = 0.0

@onready var _desat_overlay: ColorRect = $DesatOverlay
@onready var _crack_overlay: Label = $CrackOverlay

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func bind_target(target: Control) -> void:
	_target = target
	_base_position = target.position

func apply_profile(profile: Dictionary) -> void:
	_profile = profile.duplicate(true)
	_desat_overlay.color = Color(0.70, 0.72, 0.75, float(_profile.get("desaturation", 0.0)))
	_crack_overlay.modulate = Color(0.86, 0.89, 0.92, float(_profile.get("crack_alpha", 0.0)))
	SignalBus.emit_signal("effect_profile_changed", _profile)

func _process(delta: float) -> void:
	_time += delta
	if _target == null:
		return
	var shake = float(_profile.get("shake", 0.0))
	var panel_drop = float(_profile.get("panel_drop", 0.0))
	var offset = Vector2.ZERO
	if shake > 0.01:
		offset.x = sin(_time * 13.0) * shake * 0.45
		offset.y = cos(_time * 17.0) * shake * 0.25
	offset.y += panel_drop
	_target.position = _base_position + offset
