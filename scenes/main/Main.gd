extends Control

const MAIN_CONTROLLER_SCRIPT := preload("res://scripts/ui/Main.gd")

var _controller: MvpMainController

func _ready() -> void:
	_controller = MAIN_CONTROLLER_SCRIPT.new(self)
	_controller.ready()

func _notification(what: int) -> void:
	if _controller != null:
		_controller.handle_notification(what)

func get_mvp_controller() -> MvpMainController:
	return _controller
