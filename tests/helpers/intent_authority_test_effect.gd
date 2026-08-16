extends WorldEffect
## Test-only trusted Effect used to exercise post-authorization failure paths.

enum Mode {
	MOVE_ACTOR,
	CREDIT_WALLET,
	FAIL,
}

var mode: Mode = Mode.FAIL
var actor: Node3D
var wallet: PropertyBankService
var amount: int = 0
var move_offset: Vector3 = Vector3.ZERO
var applications: int = 0


func apply(_context: WorldEffectContext) -> EffectResult:
	applications += 1
	match mode:
		Mode.MOVE_ACTOR:
			if actor == null:
				return EffectResult.fail("test actor unavailable")
			actor.global_position += move_offset
			return EffectResult.ok()
		Mode.CREDIT_WALLET:
			if wallet == null:
				return EffectResult.fail("test wallet unavailable")
			wallet.credit_wallet(amount)
			return EffectResult.ok()
		_:
			return EffectResult.fail("deterministic test failure")
