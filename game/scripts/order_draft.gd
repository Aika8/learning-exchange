## Pure order-form logic: validates what the player typed and builds a contract `PlaceOrderRequest`.
class_name OrderDraft
extends RefCounted

var instrument: String = "SILK-SPARK"
var side: String = "BUY"  ## BUY | SELL
var type: String = "LIMIT"  ## LIMIT | MARKET
var price_text: String = ""
var qty_text: String = ""
var price_scale: int = 2
var qty_scale: int = 0


func price_minor() -> int:
	return Money.parse(price_text, price_scale)


func qty() -> int:
	return Money.parse(qty_text, qty_scale)


func is_valid() -> bool:
	if qty() <= 0:
		return false
	return type == "MARKET" or price_minor() > 0


## Empty dictionary when invalid.
func to_request() -> Dictionary:
	if not is_valid():
		return {}
	var body := {"instrument": instrument, "side": side, "type": type, "qty": qty()}
	if type == "LIMIT":
		body["price"] = price_minor()
	return body


## Notional of a limit order in quote minor units (-1 for market or invalid).
func notional() -> int:
	if type != "LIMIT" or not is_valid():
		return -1
	return price_minor() * qty()
