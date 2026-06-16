#Requires AutoHotkey v2.0
#SingleInstance Force

; WindowFocus - Phase 3
; AutoHotkey v2-only Windows window-management helper.
;
; Implemented in this phase:
;   Ctrl+Alt+A - designate/promote the active window as the centered main window.
;   Hold Caps Lock - temporarily peek at and interact with another window.
;   XButton2 - toggle persistent comparison with another window.
;   Escape - exit persistent comparison mode.
;   Ctrl+Alt+R - restore every managed window to its original geometry and clear state.

; ------------------------------------------------------------------------------
; User-adjustable settings
; ------------------------------------------------------------------------------

FOCUS_WIDTH_RATIO := 0.68
FOCUS_HEIGHT_RATIO := 1.00

; Phase 2/3 defaults are kept here so future geometry stays easy to tune.
SECONDARY_COMPARE_RATIO := 0.38
MAIN_COMPARE_RATIO := 0.62

LAYOUT_GAP := 12
SHOW_TOOLTIPS := true
TOOLTIP_MS := 1400
ENABLE_ANIMATION := false

; ------------------------------------------------------------------------------
; Internal state
; ------------------------------------------------------------------------------

MODE_NORMAL := "normal"
MODE_FOCUS := "focus"
MODE_TEMPORARY_PEEK := "temporaryPeek"
MODE_COMPARISON := "comparison"

mode := MODE_NORMAL
mainHwnd := 0
secondaryHwnd := 0
peekSecondaryState := 0
comparisonSecondaryState := 0
capsLockToggleStateBeforePeek := false
capsLockToggleStateKnown := false

; Map keyed by HWND. Values are Maps with x/y/width/height/minMax.
originalWindows := Map()

; ------------------------------------------------------------------------------
; Hotkeys
; ------------------------------------------------------------------------------

^!a::DesignateOrPromoteMainWindow()
^!r::CompleteRestore()

#HotIf ShouldCaptureCapsLock()
*CapsLock::StartTemporaryPeek()
*CapsLock Up::EndTemporaryPeek()
#HotIf

#HotIf ShouldCaptureComparisonToggle()
XButton2::TogglePersistentComparison()
#HotIf

#HotIf ShouldCaptureComparisonEscape()
Esc::EndPersistentComparison()
#HotIf

; ------------------------------------------------------------------------------
; Phase 1, Phase 2, and Phase 3 behavior
; ------------------------------------------------------------------------------

DesignateOrPromoteMainWindow() {
    global mode, mainHwnd, secondaryHwnd, peekSecondaryState, comparisonSecondaryState
    global MODE_FOCUS, MODE_TEMPORARY_PEEK, MODE_COMPARISON

    activeHwnd := GetActiveManageableWindow()
    if (!activeHwnd) {
        Notify("WindowFocus: active window is not manageable.")
        return
    }

    ; If the explicit promote command is used during a peek, preserve the clicked
    ; active window as the candidate and clear temporary peek bookkeeping.
    if (mode = MODE_TEMPORARY_PEEK) {
        if (secondaryHwnd && secondaryHwnd != activeHwnd && IsObject(peekSecondaryState)) {
            RestoreWindowToState(secondaryHwnd, peekSecondaryState)
        }
        ClearTemporaryPeekState()
    } else if (mode = MODE_COMPARISON) {
        if (secondaryHwnd && secondaryHwnd != activeHwnd && IsObject(comparisonSecondaryState)) {
            RestoreWindowToState(secondaryHwnd, comparisonSecondaryState)
        }
        ClearComparisonState()
    }

    ; If a different main window was already centered, put it back before changing
    ; the designation. Failure is non-fatal, for example if the old window closed.
    if (mainHwnd && mainHwnd != activeHwnd) {
        RestoreManagedWindow(mainHwnd)
    }

    if (!SaveOriginalWindowState(activeHwnd)) {
        Notify("WindowFocus: could not save the active window.")
        return
    }

    mainHwnd := activeHwnd
    secondaryHwnd := 0

    if (!ApplyCenteredFocusLayout(mainHwnd)) {
        Notify("WindowFocus: could not apply centered layout.")
        return
    }

    mode := MODE_FOCUS
    SafeActivate(mainHwnd)
    Notify("WindowFocus: main window centered.")
}

CompleteRestore() {
    global mode, mainHwnd, secondaryHwnd, peekSecondaryState, comparisonSecondaryState, originalWindows
    global MODE_NORMAL

    restoredCount := 0
    skippedCount := 0

    ; Do not mutate originalWindows while iterating. Some windows may have closed.
    savedWindows := originalWindows.Clone()
    for hwnd, state in savedWindows {
        if (RestoreManagedWindow(hwnd)) {
            restoredCount += 1
        } else {
            skippedCount += 1
        }
    }

    originalWindows := Map()
    mainHwnd := 0
    secondaryHwnd := 0
    peekSecondaryState := 0
    comparisonSecondaryState := 0
    mode := MODE_NORMAL
    RestoreCapsLockToggleState()

    if (restoredCount || skippedCount) {
        Notify("WindowFocus: restore complete (" restoredCount " restored, " skippedCount " skipped).")
    } else {
        Notify("WindowFocus: nothing to restore.")
    }
}

StartTemporaryPeek() {
    global mode, mainHwnd, secondaryHwnd, peekSecondaryState
    global capsLockToggleStateBeforePeek, capsLockToggleStateKnown
    global MODE_FOCUS, MODE_NORMAL, MODE_TEMPORARY_PEEK

    if (mode = MODE_TEMPORARY_PEEK) {
        return
    }
    if (mode != MODE_FOCUS) {
        return
    }

    capsLockToggleStateBeforePeek := GetKeyState("CapsLock", "T")
    capsLockToggleStateKnown := true

    if (!IsManageableWindow(mainHwnd)) {
        mode := MODE_NORMAL
        mainHwnd := 0
        Notify("WindowFocus: main window is no longer available.")
        RestoreCapsLockToggleState()
        return
    }

    candidateHwnd := GetTopLevelWindowUnderCursor()
    if (!candidateHwnd || candidateHwnd = mainHwnd || !IsManageableWindow(candidateHwnd)) {
        RestoreCapsLockToggleState()
        return
    }

    if (!SaveOriginalWindowState(candidateHwnd)) {
        Notify("WindowFocus: could not save secondary window.")
        RestoreCapsLockToggleState()
        return
    }

    capturedState := CaptureWindowState(candidateHwnd)
    if (!IsObject(capturedState)) {
        Notify("WindowFocus: could not capture secondary window.")
        RestoreCapsLockToggleState()
        return
    }

    secondaryHwnd := candidateHwnd
    peekSecondaryState := capturedState

    if (!ApplyTemporaryPeekLayout(mainHwnd, secondaryHwnd, peekSecondaryState)) {
        ClearTemporaryPeekState()
        ApplyCenteredFocusLayout(mainHwnd)
        SafeActivate(mainHwnd)
        Notify("WindowFocus: could not apply peek layout.")
        RestoreCapsLockToggleState()
        return
    }

    mode := MODE_TEMPORARY_PEEK
    SafeActivate(secondaryHwnd)
    Notify("WindowFocus: temporary peek.")
}

EndTemporaryPeek() {
    global mode, mainHwnd, secondaryHwnd, peekSecondaryState
    global MODE_FOCUS, MODE_NORMAL, MODE_TEMPORARY_PEEK

    if (mode != MODE_TEMPORARY_PEEK) {
        RestoreCapsLockToggleState()
        return
    }

    if (secondaryHwnd && IsObject(peekSecondaryState) && WindowExists(secondaryHwnd)) {
        RestoreWindowToState(secondaryHwnd, peekSecondaryState)
    }

    ClearTemporaryPeekState()

    if (IsManageableWindow(mainHwnd) && ApplyCenteredFocusLayout(mainHwnd)) {
        mode := MODE_FOCUS
        SafeActivate(mainHwnd)
        Notify("WindowFocus: focus restored.")
    } else {
        mainHwnd := 0
        mode := MODE_NORMAL
        Notify("WindowFocus: peek ended; main window is unavailable.")
    }

    RestoreCapsLockToggleState()
}

TogglePersistentComparison() {
    global mode
    global MODE_FOCUS, MODE_COMPARISON

    if (mode = MODE_COMPARISON) {
        EndPersistentComparison()
        return
    }

    if (mode = MODE_FOCUS) {
        StartPersistentComparison()
    }
}

StartPersistentComparison() {
    global mode, mainHwnd, secondaryHwnd, comparisonSecondaryState
    global MODE_FOCUS, MODE_NORMAL, MODE_COMPARISON

    if (mode != MODE_FOCUS) {
        return
    }

    if (!IsManageableWindow(mainHwnd)) {
        mode := MODE_NORMAL
        mainHwnd := 0
        Notify("WindowFocus: main window is no longer available.")
        return
    }

    candidateHwnd := GetTopLevelWindowUnderCursor()
    if (!candidateHwnd || candidateHwnd = mainHwnd || !IsManageableWindow(candidateHwnd)) {
        Notify("WindowFocus: no valid comparison window under cursor.")
        return
    }

    if (!SaveOriginalWindowState(candidateHwnd)) {
        Notify("WindowFocus: could not save comparison window.")
        return
    }

    capturedState := CaptureWindowState(candidateHwnd)
    if (!IsObject(capturedState)) {
        Notify("WindowFocus: could not capture comparison window.")
        return
    }

    secondaryHwnd := candidateHwnd
    comparisonSecondaryState := capturedState

    if (!ApplyPersistentComparisonLayout(mainHwnd, secondaryHwnd, comparisonSecondaryState)) {
        ClearComparisonState()
        ApplyCenteredFocusLayout(mainHwnd)
        SafeActivate(mainHwnd)
        Notify("WindowFocus: could not apply comparison layout.")
        return
    }

    mode := MODE_COMPARISON
    SafeActivate(secondaryHwnd)
    Notify("WindowFocus: comparison mode.")
}

EndPersistentComparison() {
    global mode, mainHwnd, secondaryHwnd, comparisonSecondaryState
    global MODE_FOCUS, MODE_NORMAL, MODE_COMPARISON

    if (mode != MODE_COMPARISON) {
        return
    }

    if (secondaryHwnd && IsObject(comparisonSecondaryState) && WindowExists(secondaryHwnd)) {
        RestoreWindowToState(secondaryHwnd, comparisonSecondaryState)
    }

    ClearComparisonState()

    if (IsManageableWindow(mainHwnd) && ApplyCenteredFocusLayout(mainHwnd)) {
        mode := MODE_FOCUS
        SafeActivate(mainHwnd)
        Notify("WindowFocus: comparison ended.")
    } else {
        mainHwnd := 0
        mode := MODE_NORMAL
        Notify("WindowFocus: comparison ended; main window is unavailable.")
    }
}

ApplyCenteredFocusLayout(hwnd) {
    global FOCUS_WIDTH_RATIO, FOCUS_HEIGHT_RATIO

    if (!IsManageableWindow(hwnd)) {
        return false
    }

    workArea := GetWorkAreaForWindow(hwnd)
    if (!workArea) {
        return false
    }

    targetW := Round(workArea["width"] * FOCUS_WIDTH_RATIO)
    targetH := Round(workArea["height"] * FOCUS_HEIGHT_RATIO)
    targetW := Clamp(targetW, 100, workArea["width"])
    targetH := Clamp(targetH, 100, workArea["height"])

    targetX := workArea["left"] + Round((workArea["width"] - targetW) / 2)
    targetY := workArea["top"] + Round((workArea["height"] - targetH) / 2)

    try {
        ; A maximized or minimized window must be restored before WinMove can size it.
        if (WinGetMinMax("ahk_id " hwnd) != 0) {
            WinRestore("ahk_id " hwnd)
        }
        WinMove(targetX, targetY, targetW, targetH, "ahk_id " hwnd)
        return true
    } catch as err {
        return false
    }
}

ApplyPersistentComparisonLayout(mainWindowHwnd, secondaryWindowHwnd, secondaryPreComparisonState) {
    global SECONDARY_COMPARE_RATIO, MAIN_COMPARE_RATIO, LAYOUT_GAP

    if (!IsManageableWindow(mainWindowHwnd) || !IsManageableWindow(secondaryWindowHwnd) || !IsObject(secondaryPreComparisonState)) {
        return false
    }

    workArea := GetWorkAreaForWindow(mainWindowHwnd)
    if (!workArea) {
        return false
    }

    usableW := workArea["width"] - LAYOUT_GAP
    if (usableW < 200) {
        return false
    }

    totalRatio := SECONDARY_COMPARE_RATIO + MAIN_COMPARE_RATIO
    if (totalRatio <= 0) {
        return false
    }

    secondaryW := Round(usableW * (SECONDARY_COMPARE_RATIO / totalRatio))
    mainW := usableW - secondaryW
    targetY := workArea["top"]
    targetH := workArea["height"]

    secondaryCenterX := secondaryPreComparisonState["x"] + (secondaryPreComparisonState["width"] / 2)
    workAreaCenterX := workArea["left"] + (workArea["width"] / 2)

    if (secondaryCenterX < workAreaCenterX) {
        secondaryX := workArea["left"]
        mainX := secondaryX + secondaryW + LAYOUT_GAP
    } else {
        mainX := workArea["left"]
        secondaryX := mainX + mainW + LAYOUT_GAP
    }

    try {
        if (WinGetMinMax("ahk_id " secondaryWindowHwnd) != 0) {
            WinRestore("ahk_id " secondaryWindowHwnd)
        }
        if (WinGetMinMax("ahk_id " mainWindowHwnd) != 0) {
            WinRestore("ahk_id " mainWindowHwnd)
        }

        WinMove(mainX, targetY, mainW, targetH, "ahk_id " mainWindowHwnd)
        WinMove(secondaryX, targetY, secondaryW, targetH, "ahk_id " secondaryWindowHwnd)
        return true
    } catch as err {
        return false
    }
}

ApplyTemporaryPeekLayout(mainWindowHwnd, secondaryWindowHwnd, secondaryPrePeekState) {
    global SECONDARY_COMPARE_RATIO, MAIN_COMPARE_RATIO, LAYOUT_GAP

    if (!IsManageableWindow(mainWindowHwnd) || !IsManageableWindow(secondaryWindowHwnd) || !IsObject(secondaryPrePeekState)) {
        return false
    }

    workArea := GetWorkAreaForWindow(mainWindowHwnd)
    if (!workArea) {
        return false
    }

    usableW := workArea["width"] - LAYOUT_GAP
    if (usableW < 200) {
        return false
    }

    totalRatio := SECONDARY_COMPARE_RATIO + MAIN_COMPARE_RATIO
    if (totalRatio <= 0) {
        return false
    }

    secondaryW := Round(usableW * (SECONDARY_COMPARE_RATIO / totalRatio))
    mainW := usableW - secondaryW
    targetY := workArea["top"]
    targetH := workArea["height"]

    secondaryCenterX := secondaryPrePeekState["x"] + (secondaryPrePeekState["width"] / 2)
    workAreaCenterX := workArea["left"] + (workArea["width"] / 2)

    if (secondaryCenterX < workAreaCenterX) {
        secondaryX := workArea["left"]
        mainX := secondaryX + secondaryW + LAYOUT_GAP
    } else {
        mainX := workArea["left"]
        secondaryX := mainX + mainW + LAYOUT_GAP
    }

    try {
        if (WinGetMinMax("ahk_id " secondaryWindowHwnd) != 0) {
            WinRestore("ahk_id " secondaryWindowHwnd)
        }
        if (WinGetMinMax("ahk_id " mainWindowHwnd) != 0) {
            WinRestore("ahk_id " mainWindowHwnd)
        }

        WinMove(mainX, targetY, mainW, targetH, "ahk_id " mainWindowHwnd)
        WinMove(secondaryX, targetY, secondaryW, targetH, "ahk_id " secondaryWindowHwnd)
        return true
    } catch as err {
        return false
    }
}

SaveOriginalWindowState(hwnd) {
    global originalWindows

    if (originalWindows.Has(hwnd)) {
        return true
    }

    if (!IsManageableWindow(hwnd)) {
        return false
    }

    state := CaptureWindowState(hwnd)
    if (!IsObject(state)) {
        return false
    }

    originalWindows[hwnd] := state
    return true
}

RestoreManagedWindow(hwnd) {
    global originalWindows

    if (!originalWindows.Has(hwnd)) {
        return false
    }
    if (!WindowExists(hwnd)) {
        return false
    }

    return RestoreWindowToState(hwnd, originalWindows[hwnd])
}

CaptureWindowState(hwnd) {
    if (!IsManageableWindow(hwnd)) {
        return false
    }

    try {
        minMax := WinGetMinMax("ahk_id " hwnd)
        WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
    } catch as err {
        return false
    }

    return Map(
        "x", x,
        "y", y,
        "width", w,
        "height", h,
        "minMax", minMax
    )
}

RestoreWindowToState(hwnd, state) {
    if (!WindowExists(hwnd) || !IsObject(state)) {
        return false
    }

    try {
        currentMinMax := WinGetMinMax("ahk_id " hwnd)
        if (currentMinMax != 0) {
            WinRestore("ahk_id " hwnd)
        }

        WinMove(
            state["x"],
            state["y"],
            state["width"],
            state["height"],
            "ahk_id " hwnd
        )

        if (state["minMax"] = 1) {
            WinMaximize("ahk_id " hwnd)
        } else if (state["minMax"] = -1) {
            WinMinimize("ahk_id " hwnd)
        }

        return true
    } catch as err {
        return false
    }
}

; ------------------------------------------------------------------------------
; Window discovery and validation
; ------------------------------------------------------------------------------

GetActiveManageableWindow() {
    try {
        hwnd := WinExist("A")
    } catch as err {
        return 0
    }

    if (IsManageableWindow(hwnd)) {
        return hwnd
    }
    return 0
}

GetTopLevelWindowUnderCursor() {
    try {
        MouseGetPos(, , &hoverHwnd)
    } catch as err {
        return 0
    }

    if (!hoverHwnd) {
        return 0
    }

    try {
        rootHwnd := DllCall("GetAncestor", "Ptr", hoverHwnd, "UInt", 2, "Ptr")
        if (rootHwnd) {
            return rootHwnd
        }
    } catch as err {
        ; Fall back to the AutoHotkey-reported window.
    }

    return hoverHwnd
}

IsManageableWindow(hwnd) {
    if (!hwnd || !WindowExists(hwnd)) {
        return false
    }

    try {
        className := WinGetClass("ahk_id " hwnd)
        processName := WinGetProcessName("ahk_id " hwnd)
        style := WinGetStyle("ahk_id " hwnd)
        exStyle := WinGetExStyle("ahk_id " hwnd)
    } catch as err {
        return false
    }

    ; Must be visible and look like a normal top-level app window.
    WS_VISIBLE := 0x10000000
    WS_CAPTION := 0x00C00000
    WS_EX_TOOLWINDOW := 0x00000080

    if (!(style & WS_VISIBLE)) {
        return false
    }
    if (!(style & WS_CAPTION)) {
        return false
    }
    if (exStyle & WS_EX_TOOLWINDOW) {
        return false
    }
    if (IsCloakedWindow(hwnd)) {
        return false
    }

    blockedClasses := Map(
        "Progman", true,
        "WorkerW", true,
        "Shell_TrayWnd", true,
        "Shell_SecondaryTrayWnd", true,
        "Button", true,
        "DV2ControlHost", true,
        "Windows.UI.Core.CoreWindow", true
    )

    blockedProcesses := Map(
        "ShellExperienceHost.exe", true,
        "StartMenuExperienceHost.exe", true,
        "SearchHost.exe", true,
        "AutoHotkey.exe", true,
        "AutoHotkey32.exe", true,
        "AutoHotkey64.exe", true,
        "AutoHotkeyU32.exe", true,
        "AutoHotkeyU64.exe", true
    )

    if (blockedClasses.Has(className)) {
        return false
    }
    if (blockedProcesses.Has(processName)) {
        return false
    }

    return true
}

WindowExists(hwnd) {
    if (!hwnd) {
        return false
    }

    try {
        return WinExist("ahk_id " hwnd) = hwnd
    } catch as err {
        return false
    }
}

ShouldCaptureCapsLock() {
    global mode
    global MODE_FOCUS, MODE_TEMPORARY_PEEK

    return mode = MODE_FOCUS || mode = MODE_TEMPORARY_PEEK
}

ShouldCaptureComparisonToggle() {
    global mode
    global MODE_FOCUS, MODE_COMPARISON

    return mode = MODE_FOCUS || mode = MODE_COMPARISON
}

ShouldCaptureComparisonEscape() {
    global mode
    global MODE_COMPARISON

    return mode = MODE_COMPARISON
}

ClearTemporaryPeekState() {
    global secondaryHwnd, peekSecondaryState

    secondaryHwnd := 0
    peekSecondaryState := 0
}

ClearComparisonState() {
    global secondaryHwnd, comparisonSecondaryState

    secondaryHwnd := 0
    comparisonSecondaryState := 0
}

RestoreCapsLockToggleState() {
    global capsLockToggleStateBeforePeek, capsLockToggleStateKnown

    if (!capsLockToggleStateKnown) {
        return
    }

    try {
        SetCapsLockState(capsLockToggleStateBeforePeek ? "On" : "Off")
    } catch as err {
        ; Ignore failures; this is only to avoid accidental Caps Lock toggles.
    }

    capsLockToggleStateKnown := false
}

IsCloakedWindow(hwnd) {
    cloaked := 0
    try {
        ; DWMWA_CLOAKED = 14. Cloaked windows are hidden shell/UWP surfaces.
        DllCall("dwmapi\DwmGetWindowAttribute", "Ptr", hwnd, "UInt", 14, "Int*", &cloaked, "UInt", 4)
        return cloaked != 0
    } catch as err {
        return false
    }
}

; ------------------------------------------------------------------------------
; Monitor and geometry helpers
; ------------------------------------------------------------------------------

GetWorkAreaForWindow(hwnd) {
    try {
        WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
    } catch as err {
        return false
    }

    windowCenterX := x + (w / 2)
    windowCenterY := y + (h / 2)

    monitorIndex := GetMonitorIndexFromPoint(windowCenterX, windowCenterY)
    if (!monitorIndex) {
        try {
            monitorIndex := MonitorGetPrimary()
        } catch as err {
            monitorIndex := 1
        }
    }

    try {
        MonitorGetWorkArea(monitorIndex, &left, &top, &right, &bottom)
    } catch as err {
        return false
    }

    return Map(
        "left", left,
        "top", top,
        "right", right,
        "bottom", bottom,
        "width", right - left,
        "height", bottom - top
    )
}

GetMonitorIndexFromPoint(pointX, pointY) {
    try {
        monitorCount := MonitorGetCount()
    } catch as err {
        return 0
    }

    Loop monitorCount {
        try {
            MonitorGet(A_Index, &left, &top, &right, &bottom)
        } catch as err {
            continue
        }

        if (pointX >= left && pointX < right && pointY >= top && pointY < bottom) {
            return A_Index
        }
    }

    return 0
}

Clamp(value, minValue, maxValue) {
    if (value < minValue) {
        return minValue
    }
    if (value > maxValue) {
        return maxValue
    }
    return value
}

SafeActivate(hwnd) {
    if (!WindowExists(hwnd)) {
        return false
    }

    try {
        WinActivate("ahk_id " hwnd)
        return true
    } catch as err {
        return false
    }
}

Notify(message) {
    global SHOW_TOOLTIPS, TOOLTIP_MS

    if (!SHOW_TOOLTIPS) {
        return
    }

    ToolTip(message)
    SetTimer(() => ToolTip(), -TOOLTIP_MS)
}
