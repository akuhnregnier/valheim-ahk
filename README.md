# valheim-ahk

AutoHotkey scripts for Valheim.

## Requirements

- [AutoHotkey v2](https://www.autohotkey.com/) (v2.0 or later). The scripts do not run on v1.
- Nothing else. No admin rights and no compiling are needed for a normal Steam install
  (see [Compatibility notes](#compatibility-notes)).

## hold-toggle.ahk

Does three things: tap `O` to press `;` and keep it held down hands-free, use `9` / `0` as
Ctrl / Shift, and tap `CapsLock` to pause all of that while you type.

### Holding `;`

| Input | Effect |
| --- | --- |
| Tap `O` (or hold it, auto-repeat is ignored) | `;` is pressed and stays held. The game never sees the `O` press. |
| Tap `O` again | `;` is released. |
| Press any other key except `J` / `L` | `;` is released. The key you pressed still reaches the game. This includes `9` and `0`. |
| Right / middle / back / forward mouse button | `;` is released. The click still reaches the game. |
| Release `I`, if `I` was already held when you tapped `O` | `;` is released. |
| Valheim loses focus, or the script exits | `;` is released. |

These never release `;`: pressing or releasing `J` / `L`, the left mouse button, mouse movement,
the scroll wheel, and releasing any key other than `I`.

The left mouse button is exempt on purpose. `;` is bound to Run, so the hold is a sticky sprint,
and it is often used together with auto-run. While auto-running, holding Block turns the run
towards where the camera is looking. Block is on the left mouse button in these bindings
(Valheim's default is the right button), so steering an auto-run with it must not cancel the
sprint.

If `I` was *not* held when you tapped `O`, pressing `I` afterwards releases `;` like any other key.

### Key remaps

| Key | Acts as |
| --- | --- |
| `9` | Left Ctrl |
| `0` | Left Shift |

The remapped key is held for as long as you hold `9` / `0`, and the game never sees the digit
itself. If Valheim loses focus while one is held, the Ctrl / Shift is released so it cannot get
stuck down.

### Pausing to type

Because the script hides `O`, `9` and `0` from the game, they cannot be typed in Valheim's chat,
console, signs or portal names while it is active. `CapsLock` is the escape key for that:

- Tap `CapsLock` to pause the script. `O`, `9` and `0` then behave as ordinary keys.
- Tap `CapsLock` again to resume.

Pausing releases `;`, Ctrl and Shift if the script was holding them. The script stays paused
until you tap `CapsLock` again, including after switching to another window and back. The tray
icon shows an **S** while paused; there is no other indication.

Inside Valheim and KeyViz, `CapsLock` no longer turns capital letters on or off, so typing while
paused is not in capitals. In every other application `CapsLock` works as usual.

### Running it

Double-click `hold-toggle.ahk`, or from a terminal:

```bash
"C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe" hold-toggle.ahk
```

A green **H** icon appears in the system tray while it runs. Right-click it to reload the script
after editing it, suspend its hotkeys, or exit. Starting the script a second time replaces the
running copy.

To start it with Windows, press `Win+R`, enter `shell:startup`, and put a shortcut to
`hold-toggle.ahk` in the folder that opens.

### Where it is active

`O`, `9`, `0` and `CapsLock` are only intercepted while one of the windows listed in `ActiveIn`
has focus. Everywhere else they behave normally, and the script does nothing.

```ahk
ActiveIn := ["ahk_exe valheim.exe", "ahk_exe KeyViz.exe"]
```

`ahk_exe` matches on the executable's file name alone, wherever it is installed. A full path
(`ahk_exe C:\path\to\app.exe`), a window class (`ahk_class UnityWndClass`, which matches every
Unity game) or a window title also work. To find these for any window, right-click the tray icon
and open **Window Spy**. Add or remove entries, then reload the script.

### Configuration

All settings are at the top of `hold-toggle.ahk`:

| Setting | Default | Meaning |
| --- | --- | --- |
| `TriggerKey` | `o` | Key that starts / stops the hold. |
| `HoldKey` | `sc027` | Key that is held: the physical `;` key (right of `L`) on US and UK layouts. |
| `LinkKey` | `i` | If held when the hold starts, releasing it ends the hold. |
| `IgnoreKeys` | `j`, `l` | Keys that never end the hold. |
| `CancelButtons` | right, middle, back, forward | Mouse buttons that end the hold. The left button is left out, see above. |
| `Remaps` | `9` → `LCtrl`, `0` → `LShift` | Keys that act as another key. Pressing one also ends the hold. |
| `PauseKey` | `CapsLock` | Key that pauses / resumes everything above. |
| `ActiveIn` | Valheim, KeyViz | Windows the script's keys work in. |

### Compiling (optional)

Compiling is only useful for running the script on a PC without AutoHotkey installed. The
compiler (Ahk2Exe) is not installed by default: open **AutoHotkey Dash** from the Start menu and
choose **Compile**, which offers to download it. Then either use its window, or:

```bash
"C:\Program Files\AutoHotkey\Compiler\Ahk2Exe.exe" /in hold-toggle.ahk /out hold-toggle.exe /base "C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe"
```

Compiled `.exe` files are git-ignored.

## Compatibility notes

**Administrator rights are not required**, unless the game runs as administrator. Windows stops a
normal program from sending keys to, or seeing keys typed into, an elevated one. `valheim.exe`
requests no elevation itself (its manifest says `asInvoker`), so it runs at the same level as
Steam. If you start Steam or Valheim with "Run as administrator", neither the `O` hotkey nor the
held `;` will work until the script is elevated as well: right-click `hold-toggle.ahk` and choose
**Run as administrator**.

**No special send API is required.** Valheim has no anti-cheat and accepts ordinary simulated key
events. The script sends one plain key-down and one key-up event with `SendEvent` and
`{Blind}`, including the key's scan code, which is the same method AutoHotkey's built-in key
remapping uses. `SendPlay`, `ControlSend`, `DllCall` tricks or artificial delays are not needed.

**Typing in game.** Tap `CapsLock` first; see [Pausing to type](#pausing-to-type).

**Other AutoHotkey scripts.** Keys sent by AutoHotkey scripts, including this one, are ignored
when deciding whether to release `;`. Only real key presses count.

**If `;` does not register in game:**

1. Check the script is running (tray icon) and that Valheim has focus. If the tray icon shows an
   **S**, the script is paused: tap `CapsLock`.
2. Check whether the game is elevated (see above).
3. Check the binding in Valheim's controls menu is the key right of `L`. On other keyboard
   layouts, change `HoldKey` to the key's name or scan code.

## Performance

The script is event-driven and does no polling:

- Idle, it only has a keyboard hook, which Windows calls on key presses. Nothing runs between
  key presses.
- The watcher for "any other key" only runs while `;` is held.
- The mouse hook, which Windows calls for every mouse movement, is only installed while `;` is
  held, and removed again afterwards.
- Losing focus is detected through a Windows foreground-change event rather than a timer.
- Sending the key takes one system call with no added delay.
