extends GutTest


func _book() -> BookModel:
	return BookModel.from_snapshot({"instrument": "SILK-SPARK", "lastPrice": 10180.0, "ts": 1.0,
		"bids": [{"price": 10174.0, "qty": 9.0, "orders": 1.0}, {"price": 10167.0, "qty": 18.0, "orders": 2.0}],
		"asks": [{"price": 10180.0, "qty": 2.0, "orders": 1.0}]})


func test_rows_are_asks_spread_bids_with_fixed_height() -> void:
	var rows := BoardLayout.rows(_book(), 3, 2, 0, "ru")
	assert_eq(rows.size(), 7)
	assert_eq(rows[0]["price"], "", "empty ask slots on top")
	assert_eq(rows[2]["kind"], "ask")
	assert_eq(rows[2]["price"], "101,80")
	assert_eq(rows[3]["kind"], "spread")
	assert_eq(rows[3]["price"], "0,06")
	assert_eq(rows[4]["price"], "101,74", "best bid right under the spread")
	assert_eq(rows[5]["qty"], "18")
	assert_eq(rows[6]["price"], "")


func test_bars_are_relative_to_the_largest_level() -> void:
	var rows := BoardLayout.rows(_book(), 3, 2, 0, "en")
	assert_eq(rows[5]["bar"], 1.0)
	assert_almost_eq(float(rows[4]["bar"]), 0.5, 0.001)


func test_empty_book_shows_a_dash_for_spread() -> void:
	var rows := BoardLayout.rows(BookModel.new(), 2, 2, 0, "en")
	assert_eq(rows.size(), 5)
	assert_eq(rows[2]["price"], "—")
