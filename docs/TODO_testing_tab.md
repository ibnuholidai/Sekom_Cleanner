# TODO - Testing Tab Feature

Goal: Add a new "Testing" tab with laptop tests. First milestone: Keyboard Test using https://en.key-test.ru/ embedded via Windows WebView.

## Scope (Milestone 1 - Implemented)
- [x] Add dependency webview_windows in pubspec.yaml
- [x] Create TestingScreen with:
  - [x] Keyboard Test section embedding https://en.key-test.ru/ using WebView (Windows only)
  - [x] Reload button and "Open in Browser" fallback using url_launcher
  - [x] Fallback info for non-Windows or failed initialization (WebView2 not installed)
  - [x] Placeholders for Sound L/R Test and RGB Screen Test
- [x] Add "Testing" tab to the main TabBar and wire TabBarView
- [x] flutter pub get

## Next Steps (Milestone 2 - Pending)
- [ ] Verify on Windows desktop build (ensure Microsoft Edge WebView2 Runtime is installed)
  - [ ] Run: `flutter run -d windows`
  - [ ] Confirm the WebView loads https://en.key-test.ru/
  - [ ] Confirm Reload works
  - [ ] Confirm "Open in Browser" opens default browser
- [ ] Implement Sound Test (Left/Right)
  - [ ] Add simple audio test UI with left/right channel playback
  - [ ] Provide test tones and channels switching
- [ ] Implement RGB Screen Test
  - [ ] Fullscreen color cycling (R/G/B/White/Black)
  - [ ] Escape/Back to exit
- [ ] Add settings/help/tooltips for each test section
- [ ] Add basic error handling and UX improvements

## Notes
- WebView embedding is only available on Windows via webview_windows.
- If WebView2 Runtime is missing, the screen shows an error with retry and fallback to open in external browser.
- url_launcher is already included for fallback open.
- This change does not alter existing features.

## Files Touched
- pubspec.yaml (add webview_windows)
- lib/screens/testing_screen.dart (new)
- lib/screens/main_screen.dart (add Testing tab)

## Verification Checklist
- [ ] App builds and runs on Windows
- [ ] New "Testing" tab appears beside existing tabs
- [ ] Keyboard Test card renders:
  - [ ] On Windows with WebView2 installed: page is embedded and interactive
  - [ ] Reload button refreshes the page
  - [ ] "Buka di Browser" opens external browser
  - [ ] On non-Windows: info message + external open works
