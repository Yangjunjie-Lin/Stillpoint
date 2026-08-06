class_name SaveSectionProviderRegistry
extends RefCounted

var _providers: Dictionary = {}

func register(provider: SaveSectionProvider) -> bool:
	if provider == null or provider.get_section_id() == &"": return false
	if _providers.has(provider.get_section_id()): return false
	_providers[provider.get_section_id()] = provider
	return true

func get_provider(section_id: StringName) -> SaveSectionProvider:
	return _providers.get(section_id) as SaveSectionProvider

func providers() -> Array[SaveSectionProvider]:
	var result: Array[SaveSectionProvider] = []
	for provider in _providers.values():
		result.append(provider as SaveSectionProvider)
	return result
