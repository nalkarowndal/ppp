extends Node
## Tracks app lifecycle even before the player opens the progression screen.
const Model = preload("res://scripts/ui/m3_progression_controller.gd")

signal application_resumed

var _model: RefCounted

func start() -> void:
	if _model != null:
		return
	var model := Model.new()
	if bool(model.initialize()["ok"]):
		attach(model)
		_record_transition(false)

func attach(model: RefCounted) -> void:
	_model = model

func _notification(what: int) -> void:
	if _model == null:
		return
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_WM_GO_BACK_REQUEST]:
		_record_transition(true)
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		_record_transition(false)
		application_resumed.emit()

func _record_transition(background: bool) -> void:
	var epoch: int = int(floor(Time.get_unix_time_from_system()))
	var operation: Dictionary = _model.call("mark_background" if background else "mark_foreground", epoch)
	if not bool(operation["ok"]):
		push_warning("M3_SESSION_CHECKPOINT_FAILED: " + str(operation["reason"]))
