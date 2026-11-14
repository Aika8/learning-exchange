## Pattern: Gateway (autoload service) — the only place that speaks REST to the exchange (api/openapi.yaml).
## See docs/adr/0011-game-engine-godot.md, docs/adr/0003-contract-first-api.md
extends Node

signal logged_in(account: Dictionary)
signal account_updated(details: Dictionary)
signal orders_updated(orders: Array)

var base_url: String = "http://localhost:8080/api/v1"
var token: String = ""
var account: Dictionary = {}  ## {accountId, name}
var instruments: Array = []


## Every call resolves to {ok: bool, status: int, data: Variant, code: String}; `code` is a Problem code or NETWORK.
func call_api(method: HTTPClient.Method, path: String, body: Variant = null, extra: PackedStringArray = []) -> Dictionary:
	var http := HTTPRequest.new()
	add_child(http)
	var headers := PackedStringArray(["Content-Type: application/json", "Accept: application/json"])
	if not token.is_empty():
		headers.append("Authorization: Bearer " + token)
	headers.append_array(extra)
	var payload := JSON.stringify(body) if body != null else ""
	var err := http.request(base_url + path, headers, method, payload)
	if err != OK:
		http.queue_free()
		return {"ok": false, "status": 0, "data": null, "code": "NETWORK"}
	var res: Array = await http.request_completed
	http.queue_free()
	return parse_response(res[0], res[1], (res[3] as PackedByteArray).get_string_from_utf8())


static func parse_response(result: int, status: int, text: String) -> Dictionary:
	if result != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "status": 0, "data": null, "code": "NETWORK"}
	var json := JSON.new()
	var data: Variant = json.data if json.parse(text) == OK else null
	var ok := status >= 200 and status < 300
	var code := ""
	if not ok:
		code = str(data.get("code", "BAD_REQUEST")) if data is Dictionary else "BAD_REQUEST"
	return {"ok": ok, "status": status, "data": data, "code": code}


func login(player_name: String) -> Dictionary:
	var r := await call_api(HTTPClient.METHOD_POST, "/auth/dev-login", {"name": player_name})
	if r["ok"]:
		token = r["data"]["token"]
		account = r["data"]["account"]
		var ins := await call_api(HTTPClient.METHOD_GET, "/instruments")
		instruments = ins["data"] if ins["ok"] else []
		logged_in.emit(account)
	return r


func instrument(id: String) -> Dictionary:
	for i: Dictionary in instruments:
		if i["id"] == id:
			return i
	return {"id": id, "base": "SILK", "quote": "SPARK", "feeBps": 10, "priceScale": 2, "qtyScale": 0}


func refresh_account() -> void:
	var me := await call_api(HTTPClient.METHOD_GET, "/me")
	if me["ok"]:
		account_updated.emit(me["data"])
	var orders := await call_api(HTTPClient.METHOD_GET, "/orders?limit=8")
	if orders["ok"]:
		orders_updated.emit(orders["data"])


func place_order(request: Dictionary) -> Dictionary:
	var key := "game-%d-%d" % [Time.get_ticks_usec(), randi()]
	return await call_api(HTTPClient.METHOD_POST, "/orders", request, PackedStringArray(["Idempotency-Key: " + key]))
