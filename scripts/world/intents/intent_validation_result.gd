class_name IntentValidationResult
extends RefCounted
## Validator/executor result with a stable machine-readable reason code.

var is_valid: bool = false
var code: StringName = &"rejected"
var message: String = ""


static func allow(p_code: StringName = &"valid", p_message: String = "") -> IntentValidationResult:
	var result := IntentValidationResult.new()
	result.is_valid = true
	result.code = p_code
	result.message = p_message
	return result


static func reject(p_code: StringName, p_message: String = "") -> IntentValidationResult:
	var result := IntentValidationResult.new()
	result.is_valid = false
	result.code = p_code
	result.message = p_message
	return result
