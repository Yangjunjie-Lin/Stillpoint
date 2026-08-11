extends RefCounted


func run() -> bool:
	var launcher := FileAccess.get_file_as_string(
		"res://tools/windows/run_interactive_e2e.ps1"
	)
	var stopper := FileAccess.get_file_as_string(
		"res://tools/windows/stop_interactive_e2e.ps1"
	)
	var process_helpers := FileAccess.get_file_as_string(
		"res://tools/windows/interactive_e2e_processes.ps1"
	)
	var ok := (
		FileAccess.file_exists("res://artifacts/.gdignore")
		and "Invoke-GodotImport" in launcher
		and "--editor" in launcher
		and "--quit" in launcher
		and "Assert-InteractiveE2EAvailable" in launcher
		and "$postgresStarted" in launcher
		and "Stop-StillpointInteractiveSession" in stopper
		and "Test-StillpointBackendHealth" in process_helpers
		and "stillpoint-npc-mind" in process_helpers
	)
	if not ok:
		push_error("Windows launcher clean-start and orphan cleanup contract is incomplete")
	return ok
