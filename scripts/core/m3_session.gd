extends Node
## M3-6 lightweight global OS lifecycle bridge.
## Activated when the player first opens the M3 management screen; continues
## listening for OS background/foreground while navigating M1/M2 scenes.
## It does not mint stage rewards, trust edited save files, or poll per-frame.
signal application_resumed

var _model: RefCounted

func attach(model: RefCounted) -> void:
	_model = model

func _notification(what: int) -> void:
	if _model == null:
		return
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_WM_GO_BACK_REQUEST]:
		var epoch: int = int(floor(Time.get_unix_time_from_system()))
		var operation: Dictionary = _model.call("mark_background", epoch)
		if not bool(operation.get("ok", false)) and str(operation.get("reason", "")) != "unchanged_checkpoint":
			print("M3_SESSION_CHECKPOINT_FAILED: " + str(operation.get("reason", "")))
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		application_resumed.emit()
