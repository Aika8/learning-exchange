extends GutTest


func test_format_ru_and_en() -> void:
	assert_eq(Money.format(1234567, 2, "ru"), "12 345,67")
	assert_eq(Money.format(1234567, 2, "en"), "12,345.67")
	assert_eq(Money.format(5, 2, "en"), "0.05")
	assert_eq(Money.format(-10050, 2, "en"), "−100.50")
	assert_eq(Money.format(1000, 0, "ru"), "1 000")


func test_parse_without_floats() -> void:
	assert_eq(Money.parse("100.5", 2), 10050)
	assert_eq(Money.parse("100,50", 2), 10050)
	assert_eq(Money.parse(" 1 000 ", 0), 1000)
	assert_eq(Money.parse("0.1", 2), 10)
	assert_eq(Money.parse("1.005", 2), -1, "more decimals than the scale")
	assert_eq(Money.parse("0", 2), -1)
	assert_eq(Money.parse("-3", 2), -1)
	assert_eq(Money.parse("abc", 2), -1)


func test_parse_format_round_trip() -> void:
	for minor: int in [1, 99, 100, 10050, 123456789]:
		assert_eq(Money.parse(Money.format(minor, 2, "en").replace(",", ""), 2), minor)


func test_fee_rounds_down_like_engine() -> void:
	assert_eq(Money.fee(27000, 10), 27)
	assert_eq(Money.fee(10199, 10), 10)
