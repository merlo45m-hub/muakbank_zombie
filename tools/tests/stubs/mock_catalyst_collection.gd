## mock_catalyst_collection.gd — Test double for CollectionManager (issue #86).
## Mirrors CollectionManager.record_item() / consume_item() / get_items()
## around cure catalyst custody, without /root/Save or WorldProgression wiring.
## Driven by tools/tests/boss_catalyst_probe.gd via load()/call() duck typing.
extends Node

var _items: Dictionary = {}

func record_item(asset_id: String, quantity: int = 1) -> void:
	if asset_id.is_empty():
		return
	_items[asset_id] = int(_items.get(asset_id, 0)) + quantity

func consume_item(asset_id: String, qty: int = 1) -> bool:
	if asset_id.is_empty() or qty <= 0:
		return false
	var current: int = int(_items.get(asset_id, 0))
	if current < qty:
		return false
	_items[asset_id] = current - qty
	if _items[asset_id] <= 0:
		_items.erase(asset_id)
	return true

func get_items() -> Dictionary:
	return _items.duplicate(true)

func clear() -> void:
	_items.clear()
