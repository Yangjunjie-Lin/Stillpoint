class_name PetMotionPlanner
extends RefCounted
## Stable, program-authoritative waypoint planner for autonomous pet motion.
##
## World code owns every candidate coordinate and its reachability/hazard
## facts. Provider output can only nudge allowlisted motif weights and pacing;
## it cannot introduce an action, coordinate, target, or candidate.

const MOTIFS := PetMotionProfile.MOTIF_IDS
const SECTION_VERSION := 1
const MAX_ADVISORY_INFLUENCE := 0.25
const MAX_SAFE_HAZARD := 0.92
const HASH_MASK := 0x7fffffff
const RNG_DENOMINATOR := 2147483647.0
const MAX_DECISION_COUNTER := 2147483647
const ADVISORY_FIELDS := [
	"assessment_id", "request_id", "context_revision", "motif_weights",
	"pace", "roam", "confidence", "degraded",
]

var _profile := PetMotionProfile.new()
var _seed: int = 1
var _rng_state: int = 1
var _decision_counter: int = 0
var _current_plan: Dictionary = {}
var _plan_remaining: float = 0.0
var _mood_band: StringName = &""
var _scene_signature := ""
var _context_revision: int = 0
var _advisory: Dictionary = {}


func setup(definition: Variant, persistent_id: StringName) -> void:
	_profile.setup(definition, persistent_id)
	_seed = stable_seed_for(persistent_id)
	_rng_state = _seed
	_decision_counter = 0
	_current_plan.clear()
	_plan_remaining = 0.0
	_mood_band = &""
	_scene_signature = ""
	_context_revision = 0
	_advisory.clear()


func advance(delta: float) -> void:
	_plan_remaining = maxf(0.0, _plan_remaining - maxf(0.0, delta))


func observe_context(mood: Variant, scene_context: Dictionary) -> bool:
	var next_mood := mood_band_for(mood)
	var next_scene := scene_signature_for(scene_context)
	if next_mood == _mood_band and next_scene == _scene_signature:
		return false
	_mood_band = next_mood
	_scene_signature = next_scene
	_context_revision += 1
	_current_plan.clear()
	_plan_remaining = 0.0
	# Assessments are revision-scoped. A mood band or scene change makes the old
	# provider advice stale even when its values would otherwise look valid.
	_advisory.clear()
	return true


func plan(
	activity: StringName,
	candidates: Array,
	actor_position: Vector3,
	mood: Variant,
	scene_context: Dictionary = {},
) -> Dictionary:
	observe_context(mood, scene_context)
	var safe_candidates := _sanitize_candidates(
		candidates,
		str(scene_context.get(
			"current_region_id", scene_context.get("region_id", "")
		)),
	)
	if safe_candidates.is_empty():
		_current_plan.clear()
		_plan_remaining = 0.0
		return {}
	if _can_reuse_plan(activity, safe_candidates):
		var reused := _current_plan.duplicate(true)
		reused["remaining_seconds"] = _plan_remaining
		return reused

	var region_type := StringName(str(scene_context.get("region_type", "outdoor")).to_lower())
	var region_tags := _safe_tags(scene_context.get("region_tags", []))
	var motif_weights := _effective_motif_weights(region_type, region_tags)
	var scored: Array[Dictionary] = []
	var total := 0.0
	for candidate in safe_candidates:
		var score := _candidate_score(
			candidate, activity, actor_position, motif_weights, region_tags
		)
		if score <= 0.0:
			continue
		scored.append({"candidate": candidate, "score": score})
		total += score
	if scored.is_empty() or total <= 0.0:
		_current_plan.clear()
		_plan_remaining = 0.0
		return {}

	# Consume the deterministic RNG exactly once for each newly created plan.
	# Candidate selection and linger variance derive from the same decision roll,
	# which keeps Save/Continue sequences stable and auditable.
	var decision_roll := _next_unit()
	var roll := decision_roll * total
	var cumulative := 0.0
	var selected: Dictionary = scored.back().candidate
	for entry in scored:
		cumulative += float(entry.score)
		if roll <= cumulative:
			selected = entry.candidate
			break
	var motif := _preferred_motif(selected.tags, activity, motif_weights)
	var pace := _effective_pace()
	var linger := _linger_seconds(pace, decision_roll)
	_current_plan = {
		"candidate_id": String(selected.id),
		"destination": selected.position,
		"activity": String(activity),
		"motif": String(motif),
		"speed_scale": lerpf(0.86, 1.14, pace),
		"scene_signature": _scene_signature,
		"mood_band": String(_mood_band),
		"decision_index": _decision_counter,
		"duration_seconds": linger,
	}
	_plan_remaining = linger
	var result := _current_plan.duplicate(true)
	result["remaining_seconds"] = _plan_remaining
	return result


func apply_advisory(payload: Dictionary) -> bool:
	var sanitized := sanitize_advisory(payload)
	if sanitized.is_empty() or int(sanitized.context_revision) != _context_revision:
		return false
	_advisory = sanitized
	# A newly validated assessment may affect the next soft motion decision. It
	# never interrupts follow/combat because those bypass this planner.
	_current_plan.clear()
	_plan_remaining = 0.0
	return true


func invalidate_plan() -> void:
	_current_plan.clear()
	_plan_remaining = 0.0


func clear_advisory() -> void:
	if _advisory.is_empty():
		return
	_advisory.clear()
	# Re-evaluate the next soft movement decision using only local authority.
	invalidate_plan()


func get_profile() -> PetMotionProfile:
	return _profile


func get_individual_traits() -> Dictionary:
	var result := _profile.get_individual_traits()
	result["energy"] = _profile.energy()
	return result


func get_current_plan() -> Dictionary:
	var result := _current_plan.duplicate(true)
	if not result.is_empty():
		result["remaining_seconds"] = _plan_remaining
	return result


func get_context_revision() -> int:
	return _context_revision


func get_decision_counter() -> int:
	return _decision_counter


func get_seed() -> int:
	return _seed


func get_advisory_snapshot() -> Dictionary:
	return _advisory.duplicate(true)


func capture_state() -> Dictionary:
	return {
		"section_version": SECTION_VERSION,
		"seed": _seed,
		"rng_state": _rng_state,
		"decision_counter": _decision_counter,
		"plan_remaining": _plan_remaining,
		"current_plan": _serialize_plan(_current_plan),
		"mood_band": String(_mood_band),
		"scene_signature": _scene_signature,
		"context_revision": _context_revision,
	}


func restore_state(data: Dictionary) -> bool:
	if data.is_empty():
		return false
	var section_version := int(data.get("section_version", 0))
	if section_version < 0 or section_version > SECTION_VERSION:
		return false
	var saved_seed := int(data.get("seed", _seed)) & HASH_MASK
	_seed = saved_seed if saved_seed != 0 else _seed
	var saved_rng := int(data.get("rng_state", _seed)) & HASH_MASK
	_rng_state = saved_rng if saved_rng != 0 else _seed
	_decision_counter = clampi(
		int(data.get("decision_counter", 0)), 0, MAX_DECISION_COUNTER
	)
	_plan_remaining = clampf(float(data.get("plan_remaining", 0.0)), 0.0, 3600.0)
	_mood_band = StringName(str(data.get("mood_band", "")))
	_scene_signature = str(data.get("scene_signature", "")).left(512)
	_context_revision = maxi(0, int(data.get("context_revision", 0)))
	_current_plan = _deserialize_plan(data.get("current_plan", {}))
	_advisory.clear()
	if _current_plan.is_empty():
		_plan_remaining = 0.0
	return true


static func mood_band_for(mood: Variant) -> StringName:
	if mood is int or mood is float:
		var score := clampf(float(mood), 0.0, 100.0)
		if score >= 80.0:
			return &"happy"
		if score >= 55.0:
			return &"content"
		if score >= 30.0:
			return &"anxious"
		return &"sad"
	var named := StringName(str(mood).strip_edges().to_lower())
	if named in [&"happy", &"excited", &"playful", &"confident"]:
		return &"happy"
	if named in [&"anxious", &"afraid", &"fearful", &"tired"]:
		return &"anxious"
	if named in [&"sad", &"angry", &"exhausted"]:
		return &"sad"
	return &"content"


static func scene_signature_for(context: Dictionary) -> String:
	var explicit := str(context.get("scene_signature", "")).strip_edges()
	if not explicit.is_empty():
		return explicit.left(512)
	var tags: Array[String] = []
	var raw_tags: Variant = context.get("region_tags", [])
	if raw_tags is Array:
		for raw in raw_tags as Array:
			var tag := str(raw).strip_edges().to_lower().left(64)
			if not tag.is_empty() and not tags.has(tag):
				tags.append(tag)
	tags.sort()
	return "%s|%s|%s|%s" % [
		str(context.get("current_region_id", context.get("region_id", ""))).left(160),
		str(context.get("region_type", "outdoor")).to_lower().left(64),
		",".join(tags),
		str(context.get("lifestyle_id", "")).to_lower().left(64),
	]


static func stable_seed_for(persistent_id: StringName) -> int:
	var seed := int(("stillpoint:pet-motion:%s" % String(persistent_id)).hash()) \
		& HASH_MASK
	return seed if seed != 0 else 1


static func sanitize_advisory(payload: Dictionary) -> Dictionary:
	if not _has_only_fields(payload, ADVISORY_FIELDS):
		return {}
	if not payload.get("motif_weights", {}) is Dictionary:
		return {}
	var safe_weights: Dictionary = {}
	var raw_weights := payload.get("motif_weights", {}) as Dictionary
	if not _has_only_fields(raw_weights, MOTIFS):
		return {}
	for motif_id in MOTIFS:
		var key := String(motif_id)
		if not raw_weights.has(key):
			continue
		var raw: Variant = raw_weights[key]
		if not (raw is int or raw is float) or not is_finite(float(raw)):
			continue
		safe_weights[key] = clampf(float(raw), 0.0, 1.0)
	if safe_weights.is_empty():
		return {}
	return {
		"assessment_id": str(payload.get("assessment_id", "")).left(200),
		"request_id": str(payload.get("request_id", "")).left(200),
		"context_revision": maxi(0, int(payload.get("context_revision", 0))),
		"motif_weights": safe_weights,
		"pace": _finite_clamped(payload.get("pace", 0.5), 0.5),
		"roam": _finite_clamped(payload.get("roam", 0.5), 0.5),
		"confidence": _finite_clamped(payload.get("confidence", 0.0), 0.0),
		"degraded": bool(payload.get("degraded", false)),
	}


func _effective_motif_weights(
	region_type: StringName,
	region_tags: Array[StringName],
) -> Dictionary:
	var result := _profile.motif_weights_for(_mood_band, region_type, region_tags)
	if _advisory.is_empty():
		return result
	var influence := MAX_ADVISORY_INFLUENCE * float(_advisory.confidence)
	if bool(_advisory.degraded):
		influence *= 0.25
	var advised: Dictionary = _advisory.motif_weights
	for motif_id in MOTIFS:
		var key := String(motif_id)
		if advised.has(key):
			result[key] = clampf(lerpf(
				float(result.get(key, 0.1)), float(advised[key]), influence
			), 0.02, 1.0)
	return result


func _effective_pace() -> float:
	var base := clampf(0.2 + _profile.energy() * 0.65, 0.0, 1.0)
	if _mood_band == &"sad":
		base *= 0.72
	elif _mood_band == &"happy":
		base = minf(1.0, base + 0.12)
	if _advisory.is_empty():
		return base
	var influence := MAX_ADVISORY_INFLUENCE * float(_advisory.confidence)
	if bool(_advisory.degraded):
		influence *= 0.25
	return clampf(lerpf(base, float(_advisory.pace), influence), 0.0, 1.0)


func _effective_roam() -> float:
	var traits := _profile.get_individual_traits()
	var base := clampf(
		float(traits.get("curiosity", 0.5)) * 0.55
		+ float(traits.get("independence", 0.5)) * 0.45,
		0.0,
		1.0,
	)
	if _mood_band in [&"sad", &"anxious"]:
		base *= 0.7
	if _advisory.is_empty():
		return base
	var influence := MAX_ADVISORY_INFLUENCE * float(_advisory.confidence)
	if bool(_advisory.degraded):
		influence *= 0.25
	return clampf(lerpf(base, float(_advisory.roam), influence), 0.0, 1.0)


func _candidate_score(
	candidate: Dictionary,
	activity: StringName,
	actor_position: Vector3,
	motif_weights: Dictionary,
	region_tags: Array[StringName],
) -> float:
	var tags: Array[StringName] = candidate.tags
	var motifs := _candidate_motifs(tags, activity)
	var score := 0.08
	for motif_id in motifs:
		score += float(motif_weights.get(String(motif_id), 0.1))
	if _tags_match_activity(tags, activity):
		score += 0.55
	score += _profile.habitat_affinity(tags, region_tags)
	var hazard := float(candidate.hazard)
	var courage := float(_profile.individual_traits.get("courage", 0.5))
	score *= clampf(1.0 - hazard * lerpf(0.92, 0.48, courage), 0.05, 1.0)
	var distance := actor_position.distance_to(candidate.position)
	var roam := _effective_roam()
	var preferred_distance := lerpf(2.0, 9.0, roam)
	var distance_fit := 1.0 / (1.0 + absf(distance - preferred_distance) * 0.12)
	score *= lerpf(0.72, 1.0, distance_fit)
	# Stable candidate jitter breaks perfect ties without depending on input order
	# or consuming the global/random planner sequence.
	var jitter := _stable_candidate_unit(String(candidate.id))
	return maxf(0.001, score * lerpf(0.94, 1.06, jitter))


func _candidate_motifs(tags: Array[StringName], activity: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	for motif_id in MOTIFS:
		if tags.has(motif_id):
			result.append(motif_id)
	if _has_any(tags, [&"perch", &"high", &"observe"]):
		_append_unique(result, &"perch_observe")
	if _has_any(tags, [&"shelter", &"sheltered", &"rest", &"sleep", &"home"]):
		_append_unique(result, &"rest_sheltered")
	if _has_any(tags, [&"play", &"loop", &"toy"]):
		_append_unique(result, &"playful_loop")
	if _has_any(tags, [&"social", &"owner", &"companion"]):
		_append_unique(result, &"social_approach")
	if _has_any(tags, [&"patrol", &"guard", &"watch"]):
		_append_unique(result, &"cautious_patrol")
	if _has_any(tags, [&"explore", &"forage", &"wilderness", &"scent"]):
		_append_unique(result, &"curious_explore")
	if result.is_empty():
		match activity:
			&"explore", &"forage": result.append(&"curious_explore")
			&"guard", &"train": result.append(&"cautious_patrol")
			&"rest": result.append(&"rest_sheltered")
			_: result.append(&"idle_near_anchor")
	return result


func _preferred_motif(
	tags: Array[StringName],
	activity: StringName,
	weights: Dictionary,
) -> StringName:
	var best := &"idle_near_anchor"
	var best_weight := -1.0
	for motif_id in _candidate_motifs(tags, activity):
		var weight := float(weights.get(String(motif_id), 0.0))
		if weight > best_weight:
			best = motif_id
			best_weight = weight
	return best


func _tags_match_activity(tags: Array[StringName], activity: StringName) -> bool:
	if tags.has(activity):
		return true
	match activity:
		&"explore": return _has_any(tags, [&"explore", &"wilderness", &"perch", &"play"])
		&"forage": return _has_any(tags, [&"forage", &"food", &"wilderness"])
		&"guard": return _has_any(tags, [&"guard", &"patrol", &"watch", &"owner"])
		&"train": return _has_any(tags, [&"train", &"play", &"patrol"])
		&"rest": return _has_any(tags, [&"rest", &"shelter", &"home", &"perch"])
		_: return true


func _sanitize_candidates(candidates: Array, current_region_id: String = "") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var seen: Dictionary = {}
	for value in candidates:
		if not value is Dictionary:
			continue
		var raw := value as Dictionary
		var candidate_id := str(raw.get("id", raw.get("anchor_id", ""))).strip_edges().left(160)
		var position: Variant = raw.get("position")
		if candidate_id.is_empty() or seen.has(candidate_id) or not position is Vector3:
			continue
		var destination := position as Vector3
		var candidate_region := str(raw.get("region_id", "")).strip_edges().left(160)
		var hazard_value: Variant = raw.get("hazard", 0.0)
		var hazard := float(hazard_value) if hazard_value is int or hazard_value is float else 1.0
		if not destination.is_finite() or not bool(raw.get("reachable", false)) \
				or not is_finite(hazard) or hazard > MAX_SAFE_HAZARD:
			continue
		if not current_region_id.is_empty() and candidate_region != current_region_id:
			continue
		seen[candidate_id] = true
		result.append({
			"id": candidate_id,
			"position": destination,
			"tags": _safe_tags(raw.get("tags", raw.get("behavior_tags", []))),
			"reachable": true,
			"hazard": clampf(hazard, 0.0, 1.0),
			"region_id": candidate_region,
		})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.id).naturalnocasecmp_to(String(b.id)) < 0
	)
	return result


func _can_reuse_plan(activity: StringName, candidates: Array[Dictionary]) -> bool:
	if _current_plan.is_empty() or _plan_remaining <= 0.0 \
			or StringName(str(_current_plan.get("activity", ""))) != activity \
			or str(_current_plan.get("scene_signature", "")) != _scene_signature \
			or StringName(str(_current_plan.get("mood_band", ""))) != _mood_band:
		return false
	var selected_id := str(_current_plan.get("candidate_id", ""))
	for candidate in candidates:
		if str(candidate.id) == selected_id:
			# Saved coordinates are never authoritative. Refresh the destination from
			# the currently loaded, program-owned scene candidate before reuse.
			_current_plan["destination"] = candidate.position
			return true
	return false


func _linger_seconds(pace: float, decision_roll: float) -> float:
	var patience := float(_profile.individual_traits.get("patience", 0.5))
	var base := lerpf(4.0, 11.0, patience) * lerpf(1.18, 0.78, pace)
	return clampf(base * lerpf(0.88, 1.12, decision_roll), 2.5, 14.0)


func _next_unit() -> float:
	_rng_state = int((_rng_state * 1103515245 + 12345) & HASH_MASK)
	if _rng_state == 0:
		_rng_state = _seed
	_decision_counter = mini(_decision_counter + 1, MAX_DECISION_COUNTER)
	return float(_rng_state) / RNG_DENOMINATOR


func _stable_candidate_unit(candidate_id: String) -> float:
	var value := int(("%d|%d|%s" % [
		_seed, _decision_counter, candidate_id,
	]).hash()) & HASH_MASK
	return float(value) / RNG_DENOMINATOR


func _serialize_plan(plan_value: Dictionary) -> Dictionary:
	if plan_value.is_empty() or not plan_value.get("destination") is Vector3:
		return {}
	var result := plan_value.duplicate(true)
	var destination: Vector3 = plan_value.destination
	result["destination"] = {
		"x": destination.x,
		"y": destination.y,
		"z": destination.z,
	}
	return result


func _deserialize_plan(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {}
	var result := (value as Dictionary).duplicate(true)
	var destination: Variant = result.get("destination", {})
	if not destination is Dictionary:
		return {}
	var vector := Vector3(
		float(destination.get("x", NAN)),
		float(destination.get("y", NAN)),
		float(destination.get("z", NAN)),
	)
	if not vector.is_finite() or str(result.get("candidate_id", "")).is_empty():
		return {}
	result["destination"] = vector
	result["candidate_id"] = str(result.candidate_id).left(160)
	result["activity"] = str(result.get("activity", "")).left(64)
	result["motif"] = str(result.get("motif", "")).left(64)
	result["scene_signature"] = str(result.get("scene_signature", "")).left(512)
	result["mood_band"] = str(result.get("mood_band", "")).left(32)
	result["speed_scale"] = clampf(float(result.get("speed_scale", 1.0)), 0.5, 1.5)
	return result


func _safe_tags(value: Variant) -> Array[StringName]:
	var result: Array[StringName] = []
	if not value is Array:
		return result
	for raw in value as Array:
		var tag := StringName(str(raw).strip_edges().to_lower().left(64))
		if tag != &"" and not result.has(tag):
			result.append(tag)
		if result.size() >= 24:
			break
	return result


func _has_any(haystack: Array[StringName], needles: Array) -> bool:
	for needle in needles:
		if haystack.has(StringName(str(needle))):
			return true
	return false


static func _has_only_fields(value: Dictionary, allowed: Array) -> bool:
	for key in value:
		if StringName(str(key)) not in allowed and str(key) not in allowed:
			return false
	return true


func _append_unique(values: Array[StringName], value: StringName) -> void:
	if not values.has(value):
		values.append(value)


static func _finite_clamped(value: Variant, fallback: float) -> float:
	if not (value is int or value is float) or not is_finite(float(value)):
		return fallback
	return clampf(float(value), 0.0, 1.0)
