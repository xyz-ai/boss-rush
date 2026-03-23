extends Button
class_name ShopItemView

signal offer_pressed(offer_id: String)

var offer_data: Dictionary = {}

func _ready() -> void:
	pressed.connect(_on_pressed)

func setup(offer: Dictionary, affordable: bool) -> void:
	offer_data = offer
	text = "%s\nLIFE %d\n%s" % [
		offer.get("title", offer.get("id", "商品")),
		int(offer.get("cost_life", 0)),
		offer.get("description", ""),
	]
	if offer.get("purchased", false):
		text += "\n[已售]"
	disabled = offer.get("purchased", false) or not affordable

func _on_pressed() -> void:
	emit_signal("offer_pressed", str(offer_data.get("id", "")))
