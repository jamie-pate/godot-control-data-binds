extends GutTest

const MutationEvent := preload("res://addons/DataBindControls/MutationEvent.gd")
const DeepMutationEvent := preload("res://addons/DataBindControls/DeepMutationEvent.gd")
const DataModel := preload("res://addons/DataBindControls/DataModel.gd")
const ArrayModel := preload("res://addons/DataBindControls/ArrayModel.gd")
const Subscriber := preload("./Subscriber.gd")

var util = preload("./TestUtil.gd").new(self)


func test_model_prop_changed():
	var ss = double(Subscriber).new()
	var m = DataModel.new({value = 1})
	assert_eq(m.value, 1)
	var err = m.connect("mutated", ss, "_on1")
	assert_eq(err, OK)
	m.value = 2
	assert_eq(m.value, 2)
	util.assert_called(ss, "_on1", [MutationEvent.new(m, "value", false)])


func test_array_mutated():
	var ss = double(Subscriber).new()
	var a = ArrayModel.new([1])
	assert_eq(a.get_i(0), 1)
	assert_eq(a.size(), 1)
	var err = a.connect("mutated", ss, "_on1")
	assert_eq(err, OK)
	a.set_i(0, 2)
	assert_eq(a.get_i(0), 2)
	util.assert_called(ss, "_on1", [MutationEvent.new(a, 0, false)])


func test_model_deep_mutated():
	var spy = gut.get_spy()
	var ss = double(Subscriber).new()
	var m = DataModel.new({value1 = DataModel.new({value2 = 1})})
	assert_eq(m.value1.value2, 1)
	var err = m.connect("deep_mutated", ss, "_on1")
	assert_eq(err, OK)
	m.value1.value2 = 2
	assert_eq(m.value1.value2, 2)
	util.assert_called(
		ss, "_on1", [DeepMutationEvent.new(m, "value1", ["value1", "value2"], false)]
	)


func test_model_deep_mutated_deep():
	var ss = double(Subscriber).new()
	var m3 = DataModel.new({value3 = 1})
	var m2 = DataModel.new({value2 = m3})
	var m = DataModel.new({value1 = m2})
	assert_eq(m.value1.value2.value3, 1)
	var err = m.connect("deep_mutated", ss, "_on1")
	assert_eq(err, OK)
	m.value1.value2.value3 = 2
	assert_eq(m.value1.value2.value3, 2)
	util.assert_called(
		ss, "_on1", [DeepMutationEvent.new(m, "value1", ["value1", "value2", "value3"], false)]
	)


func test_array_deep_mutated():
	var ss = double(Subscriber).new()
	var a = ArrayModel.new([ArrayModel.new([1])])
	assert_eq(a.get_i(0).get_i(0), 1)
	var err = a.connect("deep_mutated", ss, "_on1")
	assert_eq(err, OK)
	err = a.connect("mutated", ss, "_on1")
	assert_eq(err, OK)
	a.get_i(0).set_i(0, 2)
	assert_eq(a.get_i(0).get_i(0), 2)
	util.assert_called(ss, "_on1", [DeepMutationEvent.new(a, 0, [0, 0], false)])
	a.append(ArrayModel.new([0, 1, 3]))
	util.assert_called(ss, "_on1", [MutationEvent.new(a, 1, false)])
	assert_eq(a.get_i(1).get_i(2), 3)
	a.get_i(1).set_i(2, 4)
	util.assert_called(ss, "_on1", [DeepMutationEvent.new(a, 1, [1, 2], false)])


func test_array_deep_mutated_deep():
	var ss = double(Subscriber).new()
	var a3 = ArrayModel.new([1, 2, 3])
	var a2 = ArrayModel.new([0, a3])
	var a = ArrayModel.new([a2])
	assert_eq(a.get_i(0).get_i(1).get_i(2), 3)
	var err = a.connect("deep_mutated", ss, "_on1")
	assert_eq(err, OK)
	a.get_i(0).get_i(1).set_i(2, -1)
	assert_eq(a.get_i(0).get_i(1).get_i(2), -1)
	util.assert_called(ss, "_on1", [DeepMutationEvent.new(a, 0, [0, 1, 2], false)])


func test_model_array_deep_mutated():
	var ss = double(Subscriber).new()
	var m = DataModel.new({value = ArrayModel.new([0])})
	assert_eq(m.value.get_i(0), 0)
	var err = m.connect("deep_mutated", ss, "_on1")
	assert_eq(err, OK)
	m.value.set_i(0, -1)
	assert_eq(m.value.get_i(0), -1)
	util.assert_called(ss, "_on1", [DeepMutationEvent.new(m, "value", ["value", 0], false)])


func test_array_model_deep_mutated():
	var ss = double(Subscriber).new()
	var a = ArrayModel.new([DataModel.new({value = 0})])
	assert_eq(a.get_i(0).value, 0)
	var err = a.connect("deep_mutated", ss, "_on1")
	assert_eq(err, OK)
	a.get_i(0).value = -1
	assert_eq(a.get_i(0).value, -1)
	util.assert_called(ss, "_on1", [DeepMutationEvent.new(a, 0, [0, "value"], false)])
