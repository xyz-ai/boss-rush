extends Node

signal screen_requested(screen_name: String, payload: Dictionary)
signal run_state_changed(run_state)
signal tooltip_requested(title: String, body: String, screen_position: Vector2)
signal tooltip_hidden()
signal battle_resolved(result: Dictionary)
signal effect_profile_changed(profile: Dictionary)
