extends Node
## Mock WorldHopManager for secret transport trigger tests.

var calls: Array[int] = []

func request_secret_hop(to_region: int) -> void:
	calls.append(to_region)
