extends RefCounted

func run() -> bool:
	var cache := NPCMemoryCache.new()
	cache.remember("player", "save", "base:dungeon/npc/bandit_0001", {"memory_id": "a", "content": "secret"})
	cache.remember("player", "save", "base:dungeon/npc/bandit_0002", {"memory_id": "b", "content": "other"})
	return cache.memories_for("player", "save", "base:dungeon/npc/bandit_0001").size() == 1 and cache.memories_for("player", "save", "base:dungeon/npc/bandit_0002").size() == 1
