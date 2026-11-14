extends GutTest


func test_classifies_stream_messages() -> void:
	assert_eq(MarketStream.parse_message('{"channel":"market.SILK-SPARK.book","data":{}}')["kind"], "book")
	assert_eq(MarketStream.parse_message('{"channel":"market.SILK-SPARK.trades","data":[]}')["kind"], "trades")
	assert_eq(MarketStream.parse_message('{"channel":"account.acc-x","data":{"reasons":["ORDER"]}}')["kind"], "account")
	assert_eq(MarketStream.parse_message('{"channel":"clock","data":{}}')["kind"], "clock")
	assert_eq(MarketStream.parse_message('{"channel":"x","error":{"code":"BAD_REQUEST","message":""}}')["kind"], "error")
	assert_eq(MarketStream.parse_message("not json")["kind"], "unknown")


func test_rest_problem_code_is_kept_for_translation() -> void:
	var r := ExchangeApi.parse_response(HTTPRequest.RESULT_SUCCESS, 422, '{"code":"INSUFFICIENT_FUNDS","message":"x"}')
	assert_false(r["ok"])
	assert_eq(r["code"], "INSUFFICIENT_FUNDS")
	assert_eq(ExchangeApi.parse_response(HTTPRequest.RESULT_CANT_CONNECT, 0, "")["code"], "NETWORK")
	assert_true(ExchangeApi.parse_response(HTTPRequest.RESULT_SUCCESS, 201, '{"orderId":1}')["ok"])
