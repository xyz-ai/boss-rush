extends RefCounted
class_name CardVisualMapper

const ASSET_PATHS := preload("res://scripts/ui/UiAssetPaths.gd")

static func frame_path_for_card(card_data: Dictionary) -> String:
	var card_type := _visual_type(card_data)
	return str(ASSET_PATHS.CARD_FRAMES.get(card_type, ASSET_PATHS.FRAME_AGGRESSION))

static func portrait_path_for_card(card_data: Dictionary) -> String:
	if str(card_data.get("id", "")).begins_with("bet_") or str(card_data.get("type", "")) == "bet":
		return ASSET_PATHS.BET_PROBE_01
	var card_type := _visual_type(card_data)
	return str(ASSET_PATHS.CARD_PORTRAITS.get(card_type, ASSET_PATHS.CARD_BACK_DEFAULT))

static func overlay_path_for_state(view_state: String) -> String:
	return str(ASSET_PATHS.CARD_OVERLAYS.get(view_state, ""))

static func hidden_texture_path() -> String:
	return ASSET_PATHS.CARD_BACK_DEFAULT

static func _visual_type(card_data: Dictionary) -> String:
	var card_type := str(card_data.get("type", "aggression"))
	if card_type == "bet":
		return "bet"
	if card_type in ASSET_PATHS.CARD_FRAMES:
		return card_type
	return "aggression"
