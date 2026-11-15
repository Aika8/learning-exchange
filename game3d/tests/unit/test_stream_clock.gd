## The 3D stream extends the shared one: clock messages become SimClock, other kinds still reach the base class.
extends GutTest


func test_clock_message_emits_sim_clock() -> void:
	watch_signals(MarketStream)
	var m: Dictionary = MarketStream.parse_message('{"channel":"clock","data":{"now":5000,"paused":false,"speed":3}}')
	assert_eq(m["kind"], "clock")
	MarketStream.dispatch(m)
	assert_signal_emitted(MarketStream, "clock_received")
	var c: SimClock = get_signal_parameters(MarketStream, "clock_received")[0]
	assert_eq(c.now, 5000)
	assert_eq(c.speed, 3)


func test_book_still_dispatched_by_shared_stream() -> void:
	watch_signals(MarketStream)
	MarketStream.dispatch(MarketStream.parse_message(
		'{"channel":"market.SILK-SPARK.book","data":{"instrument":"SILK-SPARK","bids":[],"asks":[],"ts":1}}'))
	assert_signal_emitted(MarketStream, "book_received")
