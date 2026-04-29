extends RefCounted
class_name UiAssetPaths

const TABLE_MAIN := "res://assets/battle/table/table_main.png"

# Current background composition already owns the Boss silhouette layer.
# Enable only after replacing the battle background with a no-character plate.
const USE_SEPARATE_BOSS_PORTRAIT := false

const BOSS_DEFAULT_IDLE := "res://assets/battle/boss/boss_default_idle.png"
const BOSS_DEFAULT_PRESSURE := "res://assets/battle/boss/boss_default_pressure.png"
const BOSS_DEFAULT_HIT := "res://assets/battle/boss/boss_default_hit.png"
const BOSS_DEFAULT_LOW := "res://assets/battle/boss/boss_default_low.png"
const BOSS_TEAM_LEAD_SILHOUETTE := "res://assets/battle/boss/team_lead/boss_team_lead_silhouette.png"

const BUTTON_PRIMARY := "res://assets/ui/buttons/button_primary.png"
const BUTTON_HOVER := "res://assets/ui/buttons/button_hover.png"
const BUTTON_PRESSED := "res://assets/ui/buttons/button_pressed.png"
const BUTTON_DISABLED := "res://assets/ui/buttons/button_disabled.png"
const BUTTON_SECONDARY := "res://assets/ui/buttons/button_secondary.png"

const PANEL_DARK := "res://assets/ui/panels/panel_dark.png"

const BADGE_HP := "res://assets/ui/badges/badge_hp.png"
const BADGE_BOD := "res://assets/ui/badges/badge_bod.png"
const BADGE_SPR := "res://assets/ui/badges/badge_spr.png"
const BADGE_REP := "res://assets/ui/badges/badge_rep.png"
const BADGE_LIFE := "res://assets/ui/badges/badge_life.png"

const BROADCAST_BASE := "res://assets/ui/broadcast/broadcast_base.png"

const FRAME_AGGRESSION := "res://assets/battle/cards/frames/frame_aggression.png"
const FRAME_DEFENSE := "res://assets/battle/cards/frames/frame_defense.png"
const FRAME_PRESSURE := "res://assets/battle/cards/frames/frame_pressure.png"
const FRAME_BET := "res://assets/battle/cards/frames/frame_bet.png"

const OVERLAY_HOVER := "res://assets/battle/cards/overlays/overlay_hover.png"
const OVERLAY_SELECTED := "res://assets/battle/cards/overlays/overlay_selected.png"
const OVERLAY_USED := "res://assets/battle/cards/overlays/overlay_used.png"
const OVERLAY_LOCKED := "res://assets/battle/cards/overlays/overlay_locked.png"

const CARD_AGGRESSION_01 := "res://assets/battle/cards/portraits/card_aggression_01.png"
const CARD_DEFENSE_01 := "res://assets/battle/cards/portraits/card_defense_01.png"
const CARD_PRESSURE_01 := "res://assets/battle/cards/portraits/card_pressure_01.png"
const BET_PROBE_01 := "res://assets/battle/cards/portraits/bet_probe_01.png"

const CARD_BACK_DEFAULT := "res://assets/battle/cards/backs/card_back_default.png"

const BOSS_STATE_TEXTURES := {
	"idle": BOSS_DEFAULT_IDLE,
	"pressure": BOSS_DEFAULT_PRESSURE,
	"hit": BOSS_DEFAULT_HIT,
	"low": BOSS_DEFAULT_LOW,
}

const CARD_FRAMES := {
	"aggression": FRAME_AGGRESSION,
	"defense": FRAME_DEFENSE,
	"pressure": FRAME_PRESSURE,
	"bet": FRAME_BET,
}

const CARD_PORTRAITS := {
	"aggression": CARD_AGGRESSION_01,
	"defense": CARD_DEFENSE_01,
	"pressure": CARD_PRESSURE_01,
	"bet": BET_PROBE_01,
}

const CARD_OVERLAYS := {
	"hover": OVERLAY_HOVER,
	"selected": OVERLAY_SELECTED,
	"used": OVERLAY_USED,
	"locked": OVERLAY_LOCKED,
}

const STATUS_BADGES := {
	"hp": BADGE_HP,
	"bod": BADGE_BOD,
	"spr": BADGE_SPR,
	"rep": BADGE_REP,
	"life": BADGE_LIFE,
}

static func boss_state_texture_path(state: String) -> String:
	return str(BOSS_STATE_TEXTURES.get(state, BOSS_DEFAULT_IDLE))

static func default_boss_portrait_path() -> String:
	return BOSS_TEAM_LEAD_SILHOUETTE
