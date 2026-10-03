#Requires AutoHotkey v2.0
#SingleInstance Force

; Tap O to hold ';' down until another key or mouse button is pressed.
; Also remaps 9 to Ctrl and 0 to Shift. CapsLock pauses and resumes all of it, so
; that those keys can be typed. See README.md for the full behaviour.
;
; Needs no admin rights and no special send API for a normal Steam install of
; Valheim. It only has to run as administrator if the game itself does.

; --- Configuration ------------------------------------------------------------
TriggerKey    := "o"        ; tap to start / stop the hold (hidden from the game)
HoldKey       := "sc027"    ; key that is held down: the physical ';' key (US/UK layouts)
LinkKey       := "i"        ; if held when the hold starts, releasing it ends the hold
IgnoreKeys    := ["j", "l"] ; pressing or releasing these never ends the hold
; LButton is deliberately absent: it is bound to Block, which steers an auto-run.
CancelButtons := ["RButton", "MButton", "XButton1", "XButton2"]
Remaps        := Map("9", "LCtrl", "0", "LShift")  ; key => key it acts as; also ends the hold
PauseKey      := "CapsLock" ; tap to pause / resume everything above (hidden from the game)
ActiveIn      := ["ahk_exe valheim.exe", "ahk_exe KeyViz.exe"]

; --- Performance --------------------------------------------------------------
KeyHistory 0
ListLines false
SetKeyDelay -1, -1          ; no sleep after sending the key
ProcessSetPriority "A"      ; stay responsive while the game is using every core
A_MaxHotkeysPerInterval := 500  ; a held remapped key fires its hotkey on every auto-repeat

; --- Setup --------------------------------------------------------------------
holding := false            ; HoldKey is currently held down by this script
linked := false             ; LinkKey was held when the hold started and still is
remapHeld := Map()          ; remap targets currently held down by this script
linkVK := GetKeyVK(LinkKey)
ignoreVK := Map()
for key in IgnoreKeys
    ignoreVK[GetKeyVK(key)] := true

for criterion in ActiveIn
    GroupAdd "HoldTargets", criterion

; Keyboard watcher, only running during a hold. V = keys still reach the game,
; I = ignore keys sent by AutoHotkey (including our own), L0 = collect no text.
watcher := InputHook("V I L0")
watcher.KeyOpt("{All}", "N")
watcher.OnKeyDown := OnKeyDown
watcher.OnKeyUp := OnKeyUp

HotIfWinActive "ahk_group HoldTargets"
Hotkey "*" TriggerKey, OnTrigger
for from, to in Remaps {
    Hotkey "*" from, OnRemapDown.Bind(to)
    Hotkey "*" from " up", OnRemapUp.Bind(to)
}
Hotkey "*" PauseKey, OnPauseKey, "S"    ; S = keeps working while suspended
HotIfWinActive

; Only enabled during a hold, so the mouse hook is not installed the rest of the time.
for button in CancelButtons
    Hotkey "~*" button, OnMouseButton, "Off"

; EVENT_SYSTEM_FOREGROUND: release held keys if the game loses focus.
DllCall("SetWinEventHook", "UInt", 3, "UInt", 3, "Ptr", 0
    , "Ptr", CallbackCreate(OnForegroundChange, , 7), "UInt", 0, "UInt", 0, "UInt", 0)
OnExit OnScriptExit

; --- Logic --------------------------------------------------------------------
OnTrigger(*) {
    if holding
        StopHold()
    else
        StartHold()
    KeyWait TriggerKey      ; swallow auto-repeat until the key is physically released
}

StartHold() {
    global holding := true, linked := GetKeyState(LinkKey, "P")
    ; A single ordinary key-down event, sent the way AutoHotkey's own remapping does.
    SendEvent "{Blind}{" HoldKey " down}"
    watcher.Start()
    SetCancelButtons("On")
}

StopHold() {
    global holding, linked
    if !holding
        return
    holding := linked := false
    SendEvent "{Blind}{" HoldKey " up}"
    watcher.Stop()
    SetCancelButtons("Off")
}

SetCancelButtons(state) {
    HotIf                   ; a hotkey thread defaults to its own hotkey's criterion
    for button in CancelButtons
        Hotkey "~*" button, state
}

OnKeyDown(ih, vk, sc) {
    ; A LinkKey press while linked can only be auto-repeat of the held key.
    if ignoreVK.Has(vk) || (linked && vk = linkVK)
        return
    StopHold()
}

OnKeyUp(ih, vk, sc) {
    if linked && vk = linkVK
        StopHold()
}

OnMouseButton(*) {
    StopHold()
}

; The watcher never sees a remapped key (its hotkey hides it), so end the hold here.
OnRemapDown(to, *) {
    remapHeld[to] := true
    SendEvent "{Blind}{" to " DownR}"
    StopHold()
}

OnRemapUp(to, *) {
    if !remapHeld.Has(to)
        return
    remapHeld.Delete(to)
    SendEvent "{Blind}{" to " up}"
}

; The key-up hotkeys do not fire outside the target windows, so a remapped key
; released after focus has moved away would otherwise leave its target stuck down.
ReleaseRemaps() {
    for to in remapHeld
        SendEvent "{Blind}{" to " up}"
    remapHeld.Clear()
}

OnPauseKey(*) {
    StopHold()
    ReleaseRemaps()
    Suspend -1              ; toggle every hotkey except this one
    KeyWait PauseKey        ; swallow auto-repeat until the key is physically released
}

OnForegroundChange(*) {
    if WinActive("ahk_group HoldTargets")
        return
    StopHold()
    ReleaseRemaps()
}

OnScriptExit(*) {
    StopHold()
    ReleaseRemaps()
}
