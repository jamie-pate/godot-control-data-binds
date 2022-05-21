extends Reference

var test


func _init(_test):
	test = _test


func assert_called(variant, method, args):
	var spy = test.gut.get_spy()
	var call_count = spy.call_count(variant, method)
	var str_args = str(args)
	for i in range(call_count):
		var call = spy.get_call_parameters(variant, method, i)
		var str_call = str(call)
		if str_args == str_call:
			test.assert_eq(str_args, str_call)
			return
	test.assert_called(variant, method, args)
