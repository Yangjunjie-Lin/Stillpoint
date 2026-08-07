# Offline tools only
#
# These scripts help bootstrap/check the Godot project.
# They are NOT required to play or export Stillpoint.
#
# Examples:
#   python tools/python/bootstrap_godot_core.py
#   python tools/python/generate_godot_scenes.py
#   python tools/python/run_npc_cognition_cross_process_e2e.py --godot <godot-binary>
#
# The real Provider smoke is intentionally outside CI. Supply OPENAI_API_KEY,
# OPENAI_TEXT_MODEL, and OPENAI_EMBEDDING_MODEL only through the process
# environment, then run:
#   python tools/python/run_npc_provider_smoke.py
