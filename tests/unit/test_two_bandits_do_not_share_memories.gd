extends RefCounted

func run() -> bool:
	var cache := NPCMemoryCache.new()
	cache.remember("player", "save", "bandit_0001", {"memory_id": "secret", "content": "blue"})
	return cache.memories_for("player", "save", "bandit_0002").is_empty()
