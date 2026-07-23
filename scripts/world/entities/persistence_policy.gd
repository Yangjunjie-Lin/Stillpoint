class_name PersistencePolicyUtil
extends RefCounted
## Helpers for WorldEntityIdentity.PersistencePolicy.

static func should_persist_across_regions(policy: int) -> bool:
	return policy == WorldEntityIdentity.PersistencePolicy.GLOBAL \
		or policy == WorldEntityIdentity.PersistencePolicy.SESSION
