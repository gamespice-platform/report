class_name DotReportOutbox
extends RefCounted

## Reports that passed the checks and have not been delivered yet. A player who reports while offline loses nothing: the game takes a batch, tries to send it, and acknowledges what arrived. The whole box is an Array of Dictionaries, so GameSpice Save (or any file) can keep it between sessions with [method to_array] and [method load_array]. Refusing when full is deliberate: a silent drop would lose a report the player thinks was sent.

## Most reports held; 0 is unlimited.
var capacity: int = 100:
	set(value):
		capacity = maxi(0, value)
		_items.capacity = capacity

# The storage is the shared DotBoundedBuffer, set to refuse rather than drop: see the class comment.
var _items := DotBoundedBuffer.new(0, DotBoundedBuffer.Policy.REFUSE)


func _init(p_capacity: int = 100) -> void:
	capacity = p_capacity


func size() -> int:
	return _items.size()


## Adds [param report]. Fails with a quota error when the box is full.
func push(report: Dictionary) -> DotResult:
	if not _items.push(report):
		return DotResult.fail(DotError.CODE_QUOTA, "report outbox is full (%d); deliver or clear some first" % capacity)
	return DotResult.success(_items.size())


## Up to [param count] oldest reports (0 takes all), not removed until [method ack].
func peek(count: int = 0) -> Array:
	return _items.peek(count)


## Removes the [param count] oldest reports once they were delivered.
func ack(count: int) -> void:
	if count > 0:
		_items.discard(count)


func clear() -> void:
	_items.clear()


func to_array() -> Array:
	return _items.to_array().duplicate(true)


## Replaces the contents with [param data]; entries that are not Dictionaries with an id are skipped and counted in the value. A box over capacity keeps everything it was given (it is a restore, not a new report) and only refuses new pushes.
func load_array(data: Array) -> DotResult:
	var kept: Array = []
	var skipped := 0
	for e in data:
		if e is Dictionary and (e as Dictionary).has("id"):
			kept.append((e as Dictionary).duplicate(true))
		else:
			skipped += 1
	_items.capacity = 0
	_items.load_array(kept)
	_items.capacity = capacity
	return DotResult.success(skipped)
