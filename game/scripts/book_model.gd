## Pure view model of the order book: turns a contract `BookSnapshot` into rows the Ladder draws.
## JSON numbers arrive as floats in Godot; they are converted to int at this boundary (exact below 2^53).
class_name BookModel
extends RefCounted

var instrument: String = ""
var bids: Array[Dictionary] = []  ## {price:int, qty:int, orders:int}, highest first
var asks: Array[Dictionary] = []  ## lowest first
var last_price: int = -1  ## -1 = no trades yet
var ts: int = 0


static func from_snapshot(data: Dictionary) -> BookModel:
	var m := BookModel.new()
	m.instrument = str(data.get("instrument", ""))
	m.bids = _levels(data.get("bids", []))
	m.asks = _levels(data.get("asks", []))
	var lp: Variant = data.get("lastPrice")
	m.last_price = int(lp) if lp != null else -1
	m.ts = int(data.get("ts", 0))
	return m


static func _levels(raw: Variant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if raw is Array:
		for l: Variant in raw:
			if l is Dictionary:
				out.append({"price": int(l["price"]), "qty": int(l["qty"]), "orders": int(l["orders"])})
	return out


func best_bid() -> int:
	return bids[0]["price"] if not bids.is_empty() else -1


func best_ask() -> int:
	return asks[0]["price"] if not asks.is_empty() else -1


## Spread in minor units, -1 when one side is empty.
func spread() -> int:
	if bids.is_empty() or asks.is_empty():
		return -1
	return best_ask() - best_bid()


## Asks top-down as the Ladder shows them: highest of the shown levels first, best ask right above the spread.
func asks_top_down(depth: int) -> Array[Dictionary]:
	var shown := asks.slice(0, depth)
	shown.reverse()
	return shown


## Largest quantity among shown levels, for depth bars.
func max_qty(depth: int) -> int:
	var m := 1
	for l in bids.slice(0, depth) + asks.slice(0, depth):
		m = maxi(m, l["qty"])
	return m
