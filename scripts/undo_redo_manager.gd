class_name UndoRedoManager
extends RefCounted

const MAX_HISTORY := 50

var _history: Array[Dictionary] = []
var _current_index := -1

func push_state(state: Dictionary) -> void:
	if _current_index < _history.size() - 1:
		_history.resize(_current_index + 1)
	_history.append(state.duplicate(true))
	if _history.size() > MAX_HISTORY:
		_history.remove_at(0)
	_current_index = _history.size() - 1

func can_undo() -> bool:
	return _current_index > 0

func can_redo() -> bool:
	return _current_index < _history.size() - 1

func undo() -> Dictionary:
	if not can_undo():
		return {}
	_current_index -= 1
	return _history[_current_index].duplicate(true)

func redo() -> Dictionary:
	if not can_redo():
		return {}
	_current_index += 1
	return _history[_current_index].duplicate(true)

func clear() -> void:
	_history.clear()
	_current_index = -1
