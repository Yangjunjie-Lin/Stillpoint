class_name KnowledgeActionLibrary
extends RefCounted
## Authored, reusable presentation actions derived from graph relation classes.
## These are visual/context motions only; they never execute gameplay intents.

const RELATION_CATEGORIES := {
	"IS_INSTANCE_OF": "identity",
	"KNOWS": "social",
	"BELIEVES": "belief",
	"DOUBTS": "belief",
	"HAS_SKILL": "capability",
	"MEMBER_OF": "affiliation",
	"LIVES_IN": "spatial",
	"WORKS_AT": "vocation",
	"OWNS": "possession",
	"LIKES": "preference",
	"DISLIKES": "preference",
	"TRUSTS": "social",
	"FEARS": "preference",
	"RELATED_TO": "knowledge",
	"WITNESSED": "memory_event",
	"EXPERIENCED": "memory_event",
	"PROMISED": "exchange",
	"GAVE": "exchange",
	"RECEIVED": "exchange",
	"ATTACKED": "conflict",
	"HELPED": "social",
	"KNOWS_ABOUT": "knowledge",
	"LOCATED_IN": "spatial",
	"CONTAINS": "spatial",
	"CONNECTED_TO": "spatial",
	"PORTAL_TO": "spatial",
	"HAS_SEED": "cultivation",
	"PRODUCES": "cultivation",
	"GROWS_IN": "cultivation",
	"OPENED_BY": "capability",
	"HAS_DEPTH": "spatial",
	"HAS_BOSS": "conflict",
	"GUARDED_BY": "affiliation",
	"REQUIRES_LEVEL": "capability",
	"RESPAWNS_AFTER": "memory_event",
	"BELONGS_TO": "identity",
	"PRACTICED_WITH": "capability",
	"PRACTICED_BY": "capability",
	"SYNERGIZES_WITH": "capability",
	"RECOVERS_AFTER": "memory_event",
}

const CATEGORY_DEFINITIONS := {
	"identity": {"label": "Identity", "color": "#7f8c8d", "actions": ["acknowledge"]},
	"social": {"label": "Social", "color": "#e67e9a", "actions": ["converse", "reassure", "thank"]},
	"belief": {"label": "Belief", "color": "#9b59b6", "actions": ["explain", "recall"]},
	"capability": {"label": "Capability", "color": "#3498db", "actions": ["demonstrate"]},
	"affiliation": {"label": "Affiliation", "color": "#3f77b5", "actions": ["salute"]},
	"spatial": {"label": "Spatial", "color": "#2ecc71", "actions": ["point_route", "inspect"]},
	"vocation": {"label": "Vocation", "color": "#d6a84b", "actions": ["work", "explain"]},
	"possession": {"label": "Possession", "color": "#f39c12", "actions": ["present_item"]},
	"preference": {"label": "Preference", "color": "#e05666", "actions": ["reassure", "avoid"]},
	"knowledge": {"label": "Knowledge", "color": "#16a085", "actions": ["explain", "recall"]},
	"memory_event": {"label": "Memory/Event", "color": "#8e6e53", "actions": ["recall", "react_guard"]},
	"exchange": {"label": "Exchange", "color": "#f1c40f", "actions": ["present_item", "thank"]},
	"conflict": {"label": "Conflict", "color": "#c0392b", "actions": ["react_guard", "threaten"]},
	"cultivation": {"label": "Cultivation", "color": "#6b9b45", "actions": ["work", "inspect", "present_item"]},
}

const ACTION_DEFINITIONS := {
	"acknowledge": {"motion_state": "talk", "duration": 1.4, "trigger_terms": []},
	"converse": {"motion_state": "talk", "duration": 1.8, "trigger_terms": []},
	"reassure": {"motion_state": "reassure", "duration": 1.8, "trigger_terms": ["trust", "safe", "相信", "安全", "放心"]},
	"thank": {"motion_state": "thank", "duration": 1.7, "trigger_terms": ["thank", "help", "谢谢", "感谢", "帮助"]},
	"explain": {"motion_state": "explain", "duration": 2.0, "trigger_terms": ["know", "explain", "what", "why", "知道", "解释", "什么", "为什么"]},
	"recall": {"motion_state": "recall", "duration": 1.9, "trigger_terms": ["remember", "recall", "memory", "记得", "记忆", "想起"]},
	"demonstrate": {"motion_state": "work", "duration": 2.0, "trigger_terms": ["skill", "show", "能力", "技能", "展示"]},
	"salute": {"motion_state": "salute", "duration": 1.6, "trigger_terms": ["faction", "guard", "阵营", "守卫", "组织"]},
	"point_route": {"motion_state": "point", "duration": 2.0, "trigger_terms": ["where", "route", "location", "house", "在哪里", "哪里", "怎么走", "路线", "房子", "地点"]},
	"inspect": {"motion_state": "inspect", "duration": 1.8, "trigger_terms": ["look", "inspect", "看看", "检查", "观察"]},
	"work": {"motion_state": "work", "duration": 2.2, "trigger_terms": ["work", "job", "shop", "trade", "工作", "职业", "商店", "生意"]},
	"present_item": {"motion_state": "present", "duration": 2.0, "trigger_terms": ["item", "own", "give", "gift", "物品", "拥有", "给", "礼物"]},
	"avoid": {"motion_state": "avoid", "duration": 1.5, "trigger_terms": ["fear", "dislike", "害怕", "讨厌", "远离"]},
	"react_guard": {"motion_state": "guard", "duration": 1.8, "trigger_terms": ["attack", "hurt", "fight", "攻击", "伤害", "打架"]},
	"threaten": {"motion_state": "threaten", "duration": 1.8, "trigger_terms": ["threat", "enemy", "威胁", "敌人", "战斗"]},
}


static func catalog() -> Dictionary:
	return {
		"schema_version": 1,
		"predicate_categories": RELATION_CATEGORIES.duplicate(true),
		"categories": CATEGORY_DEFINITIONS.duplicate(true),
		"actions": ACTION_DEFINITIONS.duplicate(true),
	}


static func resolve_motion(action_or_motion: StringName) -> StringName:
	var key := String(action_or_motion)
	var action: Dictionary = ACTION_DEFINITIONS.get(key, {})
	if not action.is_empty():
		return StringName(str(action.get("motion_state", "talk")))
	for definition: Dictionary in ACTION_DEFINITIONS.values():
		if str(definition.get("motion_state", "")) == key:
			return action_or_motion
	return &"talk"


static func action_duration(action_or_motion: StringName) -> float:
	var action: Dictionary = ACTION_DEFINITIONS.get(String(action_or_motion), {})
	if not action.is_empty():
		return float(action.get("duration", 1.8))
	return 1.8
