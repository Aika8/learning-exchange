extends GutTest


func _draft(side: String, type: String, price: String, qty: String) -> OrderDraft:
	var d := OrderDraft.new()
	d.side = side
	d.type = type
	d.price_text = price
	d.qty_text = qty
	return d


func test_limit_request_matches_contract() -> void:
	var req := _draft("BUY", "LIMIT", "90.00", "3").to_request()
	assert_eq(req, {"instrument": "SILK-SPARK", "side": "BUY", "type": "LIMIT", "qty": 3, "price": 9000})


func test_market_request_has_no_price() -> void:
	var req := _draft("SELL", "MARKET", "", "2").to_request()
	assert_eq(req, {"instrument": "SILK-SPARK", "side": "SELL", "type": "MARKET", "qty": 2})


func test_invalid_inputs() -> void:
	assert_true(_draft("BUY", "LIMIT", "", "3").to_request().is_empty(), "limit needs a price")
	assert_true(_draft("BUY", "LIMIT", "90", "0").to_request().is_empty(), "qty must be positive")
	assert_true(_draft("BUY", "LIMIT", "90", "1.5").to_request().is_empty(), "SILK has qtyScale 0")


func test_notional() -> void:
	assert_eq(_draft("BUY", "LIMIT", "90.00", "3").notional(), 27000)
	assert_eq(_draft("BUY", "MARKET", "", "3").notional(), -1)
