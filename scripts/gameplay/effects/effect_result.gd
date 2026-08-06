class_name EffectResult
extends RefCounted

var success: bool = true
var message: String = ""


static func ok(msg: String = "") -> EffectResult:
	var r := EffectResult.new()
	r.success = true
	r.message = msg
	return r


static func fail(msg: String = "") -> EffectResult:
	var r := EffectResult.new()
	r.success = false
	r.message = msg
	return r
