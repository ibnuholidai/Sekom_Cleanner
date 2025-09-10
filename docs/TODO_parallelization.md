<!--  --># System Cleaner: Timeout Removal and Parallelization - Tracking

Purpose:
- Remove UI timeouts that caused "Timeout" statuses on slower/lain laptop.
- Execute checks and cleaning operations in parallel (not sequential) to finish faster.

Changes Implemented (2025-09-09):
- lib/screens/main_screen.dart
  - Check All:
    - Removed all `.timeout(...)` wrappers on:
      - SystemService.checkWindowsDefender()
      - SystemService.checkWindowsUpdate()
      - SystemService.checkDrivers()
      - SystemService.checkWindowsActivation()
      - SystemService.checkOfficeActivation()
    - Still executed concurrently via `Future.wait`, but without time limits.
  - Cleaning:
    - Switched to parallel execution. All selected tasks are started and awaited together:
      - SystemService.cleanBrowsers(...)
      - SystemService.cleanSystemFolders(...)
      - SystemService.clearRecentFiles()
      - SystemService.clearRecycleBin()
    - Status message updated to indicate parallel run.

Notes:
- lib/services/system_service.dart already has `noTimeouts = true`, so internal process timeouts are bypassed unless explicitly forced; UI timeouts were the main issue.
- Folder size previews still use fast methods; they run in background and won&#39;t block UI.

Validation Plan:
1. Build and run Windows app on different laptops (especially where timeouts occurred).
2. System Cleaner > Press &#34;🔍 Check All&#34;:
   - Expect no &#34;Timeout&#34; statuses. Checks may take longer but will finish when the system responds.
3. Select multiple cleaning options and press &#34;🧹 Bersihkan&#34;:
   - Observe that cleaning steps run together (not one-by-one) and finish faster overall.
4. Confirm UI remains responsive; progress bar shows during operations; final results dialog appears.

Risks & Mitigations:
- Long operations (e.g., activation checks) may extend overall waiting time.
  - Acceptable per request to remove time limits.
  - If needed later, we can add a &#34;Cancel/Abort&#34; button and per-task progress.
- If one of the futures throws, the group wait throws:
  - Currently caught by outer try/catch and shown as error. If necessary, enhance by wrapping each Future with `catchError` to return a safe `SystemStatus`/bool.

Checklist:
- [x] Remove UI timeouts in _checkAllStatus
- [x] Run cleaning tasks in parallel via Future.wait
- [ ] Manual QA across multiple machines
- [ ] Optional: Add Cancel/Abort capability and per-task progress aggregation
- [ ] Optional: Per-future error isolation (map errors to statuses without failing the whole batch)
