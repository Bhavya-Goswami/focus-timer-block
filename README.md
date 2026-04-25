# FocusOverlay

FocusOverlay is a lightweight macOS menu bar app for cutting off distracting apps during focus sessions.

It keeps a searchable list of installed applications, lets you mark any of them as blocked, and throws a full-screen overlay on top of blocked apps when they become frontmost. The overlay also shows a built-in pomodoro timer so the "why am I doing this?" reminder stays visible right when you need it.

## What it does

- Runs as a menu bar extra instead of a normal dock app
- Indexes apps from `/Applications`, `/System/Applications`, `/System/Applications/Utilities`, and `~/Applications`
- Lets you search, filter, block, unblock, and bulk-update visible apps
- Persists blocked bundle IDs in `UserDefaults`
- Includes a configurable pomodoro timer with focus, short break, and long break phases
- Shows a full-screen overlay on every connected display when a blocked app becomes active
- Lets you quit the blocked app or jump back to the previously active app from the overlay

## Requirements

- macOS 14+
- Swift 5.10+
- Xcode Command Line Tools or Xcode with Swift toolchain installed

## Run locally

Build and launch the menu bar app:

```bash
./run_focus_overlay.sh
```

Stop it:

```bash
./stop_focus_overlay.sh
```

You can also build manually with SwiftPM:

```bash
swift build
./.build/debug/FocusOverlay
```

## Build a clickable `.app`

To package the debug build into a local app bundle:

```bash
./build_clickable_app.sh
```

This creates:

```text
FocusOverlay.app
```

The generated bundle is configured as an agent app (`LSUIElement`), so it lives in the menu bar and does not appear as a normal Dock app.

## How to use it

1. Launch `FocusOverlay`.
2. Open the menu bar icon.
3. Search for an app by name or bundle ID.
4. Toggle apps into the blocked list, or use the bulk block/unblock controls.
5. Start the pomodoro timer if you want the timer reflected in the blocking overlay.
6. Switch into a blocked app to trigger the overlay.

## Project structure

```text
Package.swift
Sources/FocusOverlay/
  AppCatalog.swift         App discovery
  AppModel.swift           App-level composition
  BlockedAppsStore.swift   Persistent blocked app state
  FocusOverlayApp.swift    App entry point and menu bar scene
  MenuContentView.swift    Main menu UI
  OverlayManager.swift     App activation monitoring and overlay windows
  OverlayView.swift        Full-screen blocking UI
  PomodoroTimer.swift      Focus timer logic and persistence
  Resources/               Bundled font asset
```

## Implementation notes

- Blocked apps are identified by bundle ID.
- The installed-app index scans top-level `.app` bundles in the standard application folders listed above.
- Timer settings and progress are stored in `UserDefaults`, along with the blocked app list.
- The overlay uses borderless windows at `.screenSaver` level so it can sit above regular app windows.
- If there is no previous app to return to, the overlay falls back to activating Finder.

## Current behavior and limitations

- This project focuses on interruption, not hard system-level enforcement. A blocked app can still be reopened unless you keep it on the blocked list and let the overlay catch it again.
- App discovery currently scans only the top level of each configured applications directory.
- The packaged `.app` built by the helper script is intended for local use and debugging, not signed distribution.

## Development

Standard SwiftPM commands work:

```bash
swift build
swift run FocusOverlay
```

If you want to iterate on the bundled app form, rebuild with `./build_clickable_app.sh` after code changes.
