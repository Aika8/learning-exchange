extends GutTest

# JSON from the contract: Godot parses numbers as floats, the model must hand out ints.
const SNAPSHOT := """{"instrument":"SILK-SPARK","bids":[{"price":10180,"qty":8,"orders":1},{"price":10176,"qty":5,"orders":2}],
"asks":[{"price":10200,"qty":9,"orders":1},{"price":10203,"qty":4,"orders":1},{"price":10206,"qty":12,"orders":3}],
"lastPrice":10180,"ts":1794679214553}"""


func _book() -> BookModel:
	return BookModel.from_snapshot(JSON.parse_string(SNAPSHOT))


func test_parses_levels_as_ints() -> void:
	var b := _book()
	assert_eq(b.instrument, "SILK-SPARK")
	assert_eq(b.bids.size(), 2)
	assert_typeof(b.bids[0]["price"], TYPE_INT)
	assert_eq(b.ts, 1794679214553)
	assert_eq(b.last_price, 10180)


func test_spread_and_best_prices() -> void:
	var b := _book()
	assert_eq(b.best_bid(), 10180)
	assert_eq(b.best_ask(), 10200)
	assert_eq(b.spread(), 20)


func test_asks_top_down_put_best_ask_next_to_spread() -> void:
	var shown := _book().asks_top_down(2)
	assert_eq(shown.size(), 2)
	assert_eq(shown[0]["price"], 10203)
	assert_eq(shown[1]["price"], 10200)


func test_empty_side_and_no_trades() -> void:
	var b := BookModel.from_snapshot({"instrument": "X", "bids": [], "asks": [], "lastPrice": null, "ts": 0})
	assert_eq(b.spread(), -1)
	assert_eq(b.last_price, -1)
	assert_eq(b.max_qty(10), 1)


func test_max_qty() -> void:
	assert_eq(_book().max_qty(10), 12)
