extends RefCounted


func run() -> bool:
	var definition := ResourceRegistry.get_skill(&"soilworking")
	var component := SkillComponent.new()
	var context := {
		"day": 1,
		"location_id": "base:farmland@0,0",
		"tool_id": "field_pick",
		"activity_id": "till_soil",
	}
	var first := component.practice(&"soilworking", context)
	var ok := definition != null and bool(definition.is_valid())
	ok = ok and str(first.get("outcome", "")) == "gained"
	ok = ok and is_equal_approx(float(first.get("gain_multiplier", 0.0)), 1.0)
	var saw_diminishing := false
	var saw_overtraining := false
	var before_loss := component.get_points(&"soilworking")
	for _index in 18:
		before_loss = component.get_points(&"soilworking")
		var result := component.practice(&"soilworking", context)
		if float(result.get("gain_multiplier", 1.0)) < 1.0:
			saw_diminishing = true
		if str(result.get("outcome", "")) == "overtrained":
			saw_overtraining = true
			ok = ok and float(result.get("delta", 0.0)) < 0.0
			ok = ok and component.get_points(&"soilworking") < before_loss
			break
	ok = ok and saw_diminishing and saw_overtraining

	var recovered_context := context.duplicate(true)
	recovered_context["day"] = 3
	var recovered := component.practice(&"soilworking", recovered_context)
	ok = ok and str(recovered.get("outcome", "")) == "gained"
	ok = ok and is_equal_approx(float(recovered.get("gain_multiplier", 0.0)), 1.0)

	var cap_component := SkillComponent.new()
	var last: Dictionary = {}
	for index in 24:
		last = cap_component.practice(&"crop_cultivation", {
			"day": 1,
			"location_id": "base:farmland@%d,0" % index,
			"tool_id": "seed_batch_%d" % index,
			"activity_id": "plant_seed",
		})
	var cap_state := cap_component.get_state(&"crop_cultivation", 1)
	ok = ok and float(cap_state.get("gained_today", 999.0)) <= 8.0001
	ok = ok and str(last.get("outcome", "")) == "daily_cap"

	var saved := component.to_dict()
	var restored := SkillComponent.new()
	restored.from_dict(saved)
	ok = ok and is_equal_approx(
		restored.get_points(&"soilworking"),
		component.get_points(&"soilworking"),
	)
	ok = ok and restored.get_level(&"soilworking") == component.get_level(&"soilworking")
	var corrupt_contexts: Dictionary = {}
	for index in 60:
		corrupt_contexts["location:bad_%d" % index] = {
			"load": 99999.0,
			"last_day": -50,
			"last_outcome": "x".repeat(200),
		}
	restored.from_dict({
		"proficiencies": {"soilworking": 99999.0, "unknown": 50.0},
		"daily_progress": {"soilworking": {"day": -1, "gained": 999.0, "lost": -4.0}},
		"context_exposure": {"soilworking": corrupt_contexts},
	})
	var sanitized := restored.to_dict()
	var sanitized_daily: Dictionary = sanitized.get("daily_progress", {}).get("soilworking", {})
	var sanitized_contexts: Dictionary = sanitized.get("context_exposure", {}).get("soilworking", {})
	ok = ok and is_equal_approx(restored.get_points(&"soilworking"), 100.0)
	ok = ok and not (sanitized.get("proficiencies", {}) as Dictionary).has("unknown")
	ok = ok and is_equal_approx(float(sanitized_daily.get("gained", 0.0)), 9.0)
	ok = ok and sanitized_contexts.size() == 48
	for entry: Dictionary in sanitized_contexts.values():
		ok = ok and float(entry.get("load", 999.0)) <= 32.0
		ok = ok and int(entry.get("last_day", 0)) >= 1
	var mastered_overload := restored.practice(&"soilworking", {
		"day": 1,
		"location_id": "bad_0",
		"activity_id": "till_soil",
	})
	ok = ok and str(mastered_overload.get("outcome", "")) == "overtrained"
	ok = ok and restored.get_points(&"soilworking") < 100.0
	component.free()
	cap_component.free()
	restored.free()
	if not ok:
		push_error("Skill proficiency cap, repetition, recovery, overtraining, or persistence failed")
	return ok
