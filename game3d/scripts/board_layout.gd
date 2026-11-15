## Pure layout of the 3D order-book board: which rows to light and with what text, from a `BookModel`.
## Asks on top (highest first), the spread row, bids below — the same reading order as the 2D Ladder.
class_name BoardLayout
extends RefCounted


## Rows: {kind: "ask"|"spread"|"bid", price: String, qty: String, orders: String, bar: float 0..1}.
static func rows(book: BookModel, depth: int, price_scale: int, qty_scale: int, locale: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var top := book.max_qty(depth)
	var asks := book.asks_top_down(depth)
	for i in depth - asks.size():
		out.append(_empty("ask"))
	for l in asks:
		out.append(_row("ask", l, top, price_scale, qty_scale, locale))
	var spread := book.spread()
	out.append({"kind": "spread", "price": Money.format(spread, price_scale, locale) if spread >= 0 else "—",
		"qty": "", "orders": "", "bar": 0.0})
	for l in book.bids.slice(0, depth):
		out.append(_row("bid", l, top, price_scale, qty_scale, locale))
	while out.size() < depth * 2 + 1:
		out.append(_empty("bid"))
	return out


static func _row(kind: String, l: Dictionary, top: int, ps: int, qs: int, locale: String) -> Dictionary:
	return {"kind": kind, "price": Money.format(l["price"], ps, locale), "qty": Money.format(l["qty"], qs, locale),
		"orders": str(l["orders"]), "bar": clampf(float(l["qty"]) / float(maxi(top, 1)), 0.0, 1.0)}


static func _empty(kind: String) -> Dictionary:
	return {"kind": kind, "price": "", "qty": "", "orders": "", "bar": 0.0}
