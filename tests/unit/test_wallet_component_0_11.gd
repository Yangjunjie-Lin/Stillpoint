extends RefCounted


func run() -> bool:
	var first := WalletComponent.new()
	var second := WalletComponent.new()
	var ok: bool = first.restore_balance(40)
	ok = ok and second.restore_balance(7)
	ok = ok and first.get_balance() == 40 and second.get_balance() == 7
	ok = ok and first.can_spend(40) and not first.can_spend(41)
	ok = ok and first.debit(15, {"actor_id": "npc:a", "reason": "purchase", "proposal_id": "p1"})
	ok = ok and first.get_balance() == 25 and second.get_balance() == 7
	ok = ok and not first.debit(26) and first.get_balance() == 25
	ok = ok and not first.debit(0) and not first.credit(-1)
	ok = ok and first.credit(5, {"actor_id": "npc:a", "reason": "wage", "worksite_id": "smithy"})
	var history := first.get_recent_transactions()
	ok = ok and first.get_balance() == 30 and history.size() == 2
	ok = ok and history[0].get("actor_id", "") == "npc:a"
	ok = ok and history[1].get("reason", "") == "wage"
	var restored := WalletComponent.new()
	ok = restored.from_dict(first.to_dict()) and ok
	ok = ok and restored.get_balance() == 30 and restored.get_recent_transactions().size() == 2
	first.free()
	second.free()
	restored.free()
	if not ok:
		push_error("WalletComponent credit/debit/provenance/serialization/isolation failed")
	return ok
