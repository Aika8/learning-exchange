## Pattern: Observer over a WebSocket (autoload service) — scenes subscribe to signals, never to the socket.
## Channels and messages: api/asyncapi.yaml. See docs/adr/0011-game-engine-godot.md
extends Node

signal book_received(book: BookModel)
signal trades_received(trades: Array)
signal account_changed(reasons: Array)
signal connection_changed(live: bool)

var url: String = "ws://localhost:8080/ws"
var _ws: WebSocketPeer = null
var _channels: Array[String] = []
var _sent: Array[String] = []
var _live := false


func open(token: String, channels: Array[String]) -> void:
	close()
	_channels = channels
	_sent.clear()
	_ws = WebSocketPeer.new()
	_ws.inbound_buffer_size = 1 << 20
	var err := _ws.connect_to_url(url + ("?token=" + token if not token.is_empty() else ""))
	if err != OK:
		_ws = null
		_set_live(false)


func close() -> void:
	if _ws != null:
		_ws.close()
	_ws = null
	_set_live(false)


func _process(_delta: float) -> void:
	if _ws == null:
		return
	_ws.poll()
	match _ws.get_ready_state():
		WebSocketPeer.STATE_OPEN:
			_set_live(true)
			for ch in _channels:
				if ch not in _sent:
					_ws.send_text(JSON.stringify({"op": "subscribe", "channel": ch}))
					_sent.append(ch)
			while _ws.get_available_packet_count() > 0:
				dispatch(parse_message(_ws.get_packet().get_string_from_utf8()))
		WebSocketPeer.STATE_CLOSED:
			_ws = null
			_set_live(false)


func _set_live(v: bool) -> void:
	if v != _live:
		_live = v
		connection_changed.emit(v)


func is_live() -> bool:
	return _live


## Classifies a server message: {kind: book|trades|account|clock|error|unknown, data}.
static func parse_message(text: String) -> Dictionary:
	var json := JSON.new()
	var msg: Variant = json.data if json.parse(text) == OK else null
	if not (msg is Dictionary) or not msg.has("channel"):
		return {"kind": "unknown", "data": null}
	var ch: String = msg["channel"]
	if msg.has("error"):
		return {"kind": "error", "data": msg["error"]}
	var kind := "unknown"
	if ch.begins_with("market.") and ch.ends_with(".book"):
		kind = "book"
	elif ch.begins_with("market.") and ch.ends_with(".trades"):
		kind = "trades"
	elif ch.begins_with("account."):
		kind = "account"
	elif ch == "clock":
		kind = "clock"
	return {"kind": kind, "data": msg.get("data")}


func dispatch(m: Dictionary) -> void:
	match m["kind"]:
		"book":
			book_received.emit(BookModel.from_snapshot(m["data"]))
		"trades":
			trades_received.emit(m["data"])
		"account":
			account_changed.emit(m["data"].get("reasons", []))
		"error":
			push_warning("stream error: %s" % str(m["data"]))
