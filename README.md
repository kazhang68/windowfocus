# WindowFocus

WindowFocus is a lightweight AutoHotkey v2 script for temporarily centering a designated "main" window on an ultrawide Windows desktop, then restoring the original layout exactly.

This repository is currently at Phase 3. It implements main-window focus, hold-to-peek with Caps Lock, persistent XButton2 comparison, and full restore.

## Requirements

- Windows 11.
- [AutoHotkey v2](https://www.autohotkey.com/) installed.
- Separate Windows windows for separate work areas. Two browser tabs inside one browser window are still one Windows window.

AutoHotkey v1 will not run this script.

## Launch

1. Install AutoHotkey v2 if it is not already installed.
2. Double-click `WindowFocus.ahk`.
3. The script runs in the Windows system tray.

To stop or reload the script, right-click the AutoHotkey tray icon and choose `Exit` or `Reload Script`.

## Controls

### Ctrl + Alt + A

Designates the currently active normal application window as the main window and moves it to the centered focus layout.

The script saves the window's original X/Y position, size, and minimized/maximized state the first time it manages that window. If another window was previously designated as main, that previous main window is restored before the newly active window is centered.

Pressing `Ctrl + Alt + A` again while the same main window is active reapplies the centered layout.

### Ctrl + Alt + R

Restores every managed window to its saved original state, then clears all WindowFocus state.

This is the full reset command. Pressing it again when there is nothing to restore is safe.

### Hold Caps Lock

Works only while WindowFocus is in focus mode.

Hover the mouse over a different visible application window, then press and hold `Caps Lock`. The hovered window becomes the temporary secondary window and stays on the same side of the monitor it was closest to before peeking. A left-side secondary moves to the left edge; a right-side secondary moves to the right edge. The designated main window uses the remaining side. The secondary window is activated so it can be clicked, typed in, scrolled, and otherwise used normally.

Release `Caps Lock` to restore the secondary window to its pre-peek position, return the main window to the centered focus layout, and reactivate the main window.

When WindowFocus is not in focus mode, `Caps Lock` keeps its normal Windows behavior.

### XButton2

Works while WindowFocus is in focus mode.

Hover the mouse over a different visible application window, then press the mouse forward-side button, `XButton2`. The hovered window becomes the persistent secondary window and stays on the same side of the monitor it was closest to before comparison. The designated main window uses the remaining side.

Once comparison mode is active, both windows remain fully interactive. You can click, type, scroll, switch tabs, and use either window without changing which window is designated as main.

Press `XButton2` again from anywhere to exit comparison mode. The secondary window returns to its pre-comparison position, the main window returns to the centered focus layout, and the main window is activated.

When WindowFocus is not active, `XButton2` keeps its normal browser Forward behavior.

### Escape

Works only while persistent comparison mode is active.

Press `Escape` to exit comparison mode and return to the centered main-window layout. `Escape` is not intercepted during normal mode, focus mode, or temporary peek.

## Modes

### normal

No main window is currently designated, and no saved layout state is active.

### focus

One designated main window is centered on the monitor that contains it. The script does not resize unrelated windows and does not make the main window always-on-top.

### temporaryPeek

The designated main window and a temporary secondary window are arranged side by side. Releasing `Caps Lock` returns to focus mode.

### comparison

The designated main window and a persistent secondary window are arranged side by side. The secondary window stays on its original side at about 38% of the work area, and the main window uses the other side at about 62%. Pressing `XButton2` again or pressing `Escape` returns to focus mode.

## Layout Settings

The main settings are near the top of `WindowFocus.ahk`:

```ahk
FOCUS_WIDTH_RATIO := 0.68
FOCUS_HEIGHT_RATIO := 1.00
SECONDARY_COMPARE_RATIO := 0.38
MAIN_COMPARE_RATIO := 0.62
LAYOUT_GAP := 12
SHOW_TOOLTIPS := true
ENABLE_ANIMATION := false
```

For focus mode, `FOCUS_WIDTH_RATIO` and `FOCUS_HEIGHT_RATIO` control the centered main-window layout. For temporary peek and comparison modes, `SECONDARY_COMPARE_RATIO`, `MAIN_COMPARE_RATIO`, and `LAYOUT_GAP` control the side-by-side split. The script calculates geometry from the current monitor work area, so the Windows taskbar is excluded and one exact resolution is not hard-coded.

After editing settings, right-click the tray icon and choose `Reload Script`.

## Manual Phase 1 Test

Use two separate Edge windows snapped approximately 50/50.

Test 1:

1. Click the right Edge window.
2. Press `Ctrl + Alt + A`.

Expected: the right window becomes the designated main window, moves to the center, uses about 68% of the monitor width, uses the work-area height, and the left window is not resized.

Test 2:

1. While the first window is centered, click the other Edge window.
2. Press `Ctrl + Alt + A`.

Expected: the previous main window returns to its original position, the newly selected window becomes main, and the newly selected window moves to the center.

Test 3:

1. Press `Ctrl + Alt + R`.
2. Press `Ctrl + Alt + R` again.

Expected: all managed windows return to their original 50/50 arrangement, saved state is cleared, and the second restore does not error.

Test 4:

1. Enter focus mode.
2. Close the designated main window.
3. Press `Ctrl + Alt + R`.

Expected: the script handles the missing window safely without crashing or showing repeated error dialogs.

## Manual Phase 2 Test

Start with two separate Edge windows snapped approximately 50/50, then enter focus mode with `Ctrl + Alt + A`.

Test 1:

1. Move the mouse over the visible part of the other Edge window.
2. Press and hold `Caps Lock`.

Expected: if the hovered window started on the left side, it becomes visible on the left and the main window moves to the right. If it started on the right side, it becomes visible on the right and the main window moves to the left. The hovered window becomes active either way.

Test 2:

1. Keep holding `Caps Lock`.
2. Click, scroll, type, switch tabs, or interact with a page control in the secondary window.

Expected: the secondary window remains fully interactive, and the designated main window is not replaced.

Test 3:

1. Release `Caps Lock`.

Expected: the secondary window returns to its pre-peek position, the main window returns to the centered focus layout, and the main window is active again.

Test 4:

1. Enter a temporary peek with a window that starts on the opposite side of the monitor from the first test.
2. Keep holding `Caps Lock`.

Expected: the secondary window stays on its original side during the peek instead of jumping across the monitor.

Test 5:

1. Press `Caps Lock` while WindowFocus is in normal mode.

Expected: Caps Lock keeps its normal Windows behavior.

## Manual Phase 3 Test

Start with two separate Edge windows snapped approximately 50/50, then enter focus mode with `Ctrl + Alt + A`.

Test 1:

1. Move the mouse over the visible part of the other Edge window.
2. Press `XButton2`.

Expected: if the hovered window started on the left side, it becomes the secondary window on the left and the main window moves to the right. If it started on the right side, it becomes the secondary window on the right and the main window moves to the left. Both windows are readable.

Test 2:

1. Click, scroll, type, or switch tabs in either window.

Expected: both windows remain fully interactive, and clicking the secondary window does not promote it to main.

Test 3:

1. Press `XButton2` again from anywhere.

Expected: the secondary window returns to its pre-comparison position, the main window returns to the centered focus layout, and the main window is active again.

Test 4:

1. Enter comparison mode with a window that starts on the opposite side of the monitor from the first test.
2. Confirm the secondary stays on its original side.
3. Press `Escape`.

Expected: comparison uses the secondary window's original side, then exits the same way as `XButton2`, returning to centered focus mode.

Test 5:

1. Press `XButton2` while WindowFocus is in normal mode.

Expected: the button keeps its normal browser Forward behavior.

## Known Limitations

- Escape is intercepted only while persistent comparison mode is active.
- Some elevated/admin windows may not be movable by a non-elevated AutoHotkey script.
- Exact restoration depends on Windows accepting the requested window geometry. Some applications enforce minimum sizes or custom window behavior.
- Maximized windows are restored by re-maximizing them, not by preserving a separate pre-maximize restore rectangle.

## Startup

WindowFocus does not modify Windows Startup automatically.

Later, after the controls are stable, you can add it manually by placing a shortcut to `WindowFocus.ahk` in the Windows Startup folder:

```text
shell:startup
```

Open that path from the Windows Run dialog, then add a shortcut to the script.

## Roadmap

- Phase 1: centered main-window focus and full restore.
- Phase 2: temporary interactive Caps Lock peek.
- Phase 3: persistent XButton2 comparison layout.
- Phase 4: polish, tray menu, improved monitor/DPI handling, startup instructions, and optional animation.
