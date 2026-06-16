# Changelog

## Phase 3 - 2026-06-15

- Added `XButton2` persistent comparison toggle while focus mode is active.
- Added comparison entry from the top-level window under the mouse cursor.
- Added persistent comparison layout that keeps the secondary window on its original side and puts the main window on the other side.
- Added comparison exit with `XButton2` from anywhere while comparison mode is active.
- Added `Escape` handling only for persistent comparison mode.
- Added pre-comparison secondary-window restoration when comparison mode exits.
- Preserved normal `XButton2` browser Forward behavior outside WindowFocus focus/comparison modes.

## Phase 2 - 2026-06-15

- Added hold-to-peek with `Caps Lock` while focus mode is active.
- Added secondary-window detection from the top-level window under the mouse cursor.
- Added temporary side-by-side peek layout using the existing 38/62 ratio settings and configurable gap.
- Updated temporary peek so the secondary window remains on its original side of the monitor.
- Added pre-peek secondary-window restoration when `Caps Lock` is released.
- Removed `Escape` handling from temporary peek; releasing `Caps Lock` is the only Phase 2 end-peek control.
- Preserved normal `Caps Lock` behavior outside WindowFocus focus mode.
## Phase 1 - 2026-06-15

- Created the initial AutoHotkey v2 project files.
- Added `Ctrl + Alt + A` to designate or promote the active manageable window as the centered main window.
- Added original geometry/state capture keyed by HWND.
- Added centered focus layout based on the containing monitor's work area.
- Added `Ctrl + Alt + R` to restore all managed windows and clear state.
- Added defensive handling for closed, minimized, maximized, shell, tray, and invalid windows while allowing normal File Explorer windows.
- Added optional basic tooltips.

## Planned Phase 4

- Add polish such as a tray menu, improved monitor/DPI behavior, optional startup instructions, and optional animation.
