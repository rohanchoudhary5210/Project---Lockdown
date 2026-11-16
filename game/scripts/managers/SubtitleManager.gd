class_name SubtitleManager
extends Node

## Project: Lockdown - Subtitle Manager (Milestone 7)
## Manages on-screen subtitles, radio intel, and dialogue queues.
## Reusable across story events, radio chatter, and teammate rescue.

signal subtitle_started(speaker: String, text: String, duration: float)
signal subtitle_cleared()

class SubtitleEntry:
	var speaker: String
	var text: String
	var duration: float
	
	func _init(s: String, t: String, d: float) -> void:
		speaker = s
		text = t
		duration = d

var _queue: Array[SubtitleEntry] = []
var _current_entry: SubtitleEntry = null
var _timer: float = 0.0
var _is_displaying: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	if not _is_displaying:
		return
	
	_timer -= delta
	if _timer <= 0.0:
		_show_next_subtitle()

## Queues a subtitle line to be displayed
func play_subtitle(speaker: String, text: String, duration: float = 3.5) -> void:
	var entry = SubtitleEntry.new(speaker, text, duration)
	_queue.append(entry)
	if not _is_displaying:
		_show_next_subtitle()

func _show_next_subtitle() -> void:
	if _queue.is_empty():
		_is_displaying = false
		_current_entry = null
		subtitle_cleared.emit()
		return
	
	_is_displaying = true
	_current_entry = _queue.pop_front()
	_timer = _current_entry.duration
	subtitle_started.emit(_current_entry.speaker, _current_entry.text, _current_entry.duration)

## Clears all queued and active subtitles immediately
func clear_all() -> void:
	_queue.clear()
	_is_displaying = false
	_current_entry = null
	_timer = 0.0
	subtitle_cleared.emit()
