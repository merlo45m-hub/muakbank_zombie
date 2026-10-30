extends InteractiveVehicle
class_name InteractiveServiceVehicle

## Interactable hospital service vehicle. The inherited controller registers it
## with Interactor and owns the open/closed service-access state.
signal service_access_toggled(is_open: bool)

func interact() -> void:
	if is_door_open:
		_reset_vehicle()
	else:
		open_door()
	service_access_toggled.emit(is_door_open)
