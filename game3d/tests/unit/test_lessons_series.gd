## Field guide A13: losses compound like gains, and fees compound too.
extends GutTest


func test_minus_ten_then_plus_ten_is_not_zero() -> void:
	var v := Lessons.series_after(100000, [-1000, 1000], 0)
	assert_eq(v, 99000, "0.9 × 1.1 = 0.99")
	assert_lt(v, 100000)
	assert_eq(Lessons.series_after(100000, [1000, -1000], 0), 99000, "the order does not matter")


func test_half_lost_needs_double() -> void:
	assert_eq(Lessons.needed_to_recover_bps(5000), 10000)
	assert_eq(Lessons.series_after(100000, [-5000, Lessons.needed_to_recover_bps(5000)], 0), 100000)
	assert_eq(Lessons.needed_to_recover_bps(1000), 1111, "11.11…% rounded down")
	assert_eq(Lessons.needed_to_recover_bps(0), 0)
	assert_eq(Lessons.needed_to_recover_bps(10000), -1, "a full loss cannot be recovered")


func test_fee_per_round_trip_shrinks_a_winning_series() -> void:
	var moves := [500, 500, 500]
	var gross := Lessons.series_after(100000, moves, 0)
	var net := Lessons.series_after(100000, moves, 30)
	assert_gt(gross, 100000)
	assert_lt(net, gross)
	assert_eq(Lessons.series_after(100000, [], 30), 100000, "no trades, no fee")


func test_rounding_is_down() -> void:
	# 333 × 1.0001 = 333.0333 → 333; then fee 0.01% of 333 = 0.0333 → 333 × 0.9999 = 332.9667 → 332
	assert_eq(Lessons.series_after(333, [1], 0), 333)
	assert_eq(Lessons.series_after(333, [0], 1), 332)


func test_total_loss_stays_at_zero() -> void:
	assert_eq(Lessons.series_after(100000, [-10000, 5000], 0), 0)
	assert_eq(Lessons.series_after(100000, [-12000], 0), 0)
