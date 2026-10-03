# valheim-ahk

AutoHotkey scripts for Valheim.

## Requirements

- [AutoHotkey v2](https://www.autohotkey.com/) (v2.0 or later). The scripts do not run on v1.
- Nothing else. No admin rights and no compiling are needed for a normal Steam install
  (see [Compatibility notes](#compatibility-notes)).

## hold-toggle.ahk

Tap `O` to press `;` and keep it held down, hands-free.

| Input | Effect |
| --- | --- |
| Tap `O` (or hold it, auto-repeat is ignored) | `;` is pressed and stays held. The game never sees the `O` press. |
| Tap `O` again | `;` is released. |
| Press any other key except `J` / `L` | `;` is released. The key you pressed still reaches the game. |
| Left / right / middle / back / forward mouse button | `;` is released. The click still reaches the game. |
| Release `I`, if `I` was already held when you tapped `O` | `;` is released. |
| Valheim loses focus, or the script exits | `;` is released. |

These never release `;`: pressing or releasing `J` / `L`, mouse movement, the scroll wheel, and
releasing any key other than `I`.

If `I` was *not* held when you tapped `O`, pressing `I` afterwards releases `;` like any other key.

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

`O` is only intercepted while one of the windows listed in `ActiveIn` has focus. Everywhere else
`O` types normally, and the script does nothing.

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
| `CancelButtons` | left, right, middle, back, forward | Mouse buttons that end the hold. |
| `ActiveIn` | Valheim, KeyViz | Windows the trigger key works in. |

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

**Typing in game.** While the script is active, `O` cannot be typed in Valheim's chat, console,
signs or portal names. Suspend it first from the tray icon (**Suspend Hotkeys**), or add a
suspend key to the script:

```ahk
#SuspendExempt
F8::Suspend
#SuspendExempt false
```

**Other AutoHotkey scripts.** Keys sent by AutoHotkey scripts, including this one, are ignored
when deciding whether to release `;`. Only real key presses count.

**If `;` does not register in game:**

1. Check the script is running (tray icon) and that Valheim has focus.
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
