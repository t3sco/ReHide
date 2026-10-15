# ReHide

Fixes the Windows 11 bug where, with **Automatically hide the taskbar** turned on, the taskbar on a second monitor stops coming back when you move your mouse to the bottom of the screen.

The usual workaround is to switch auto-hide off and on again in Settings. This script does exactly that for you, automatically, whenever the bug is likely to have been triggered.

## Why it happens

When a monitor sleeps, powers off, or briefly disconnects (OLED screensavers and standby are common culprits), Windows rebuilds that screen's taskbar when it comes back. The rebuilt taskbar sometimes forgets to respond to your cursor. Re-applying the auto-hide setting wakes it back up.

## What it does

- **Watcher (runs from login):** checks every 3 seconds for the screensaver ending, a monitor dropping out or reconnecting, or the PC waking from sleep, then re-applies auto-hide once things settle
- **Unlock task:** re-applies auto-hide a few seconds after you unlock your PC
- **Hotkey:** `Ctrl+Alt+B` re-applies it manually any time

## Is it safe?

Read the script before you run it, it's one short file. In summary:

- It only calls standard Windows APIs (`SHAppBarMessage`, the same mechanism the Settings toggle uses, plus read-only checks for monitor layout and screensaver state)
- The script itself makes no network connections and sends nothing anywhere (the optional one-line installer downloads it from this repo, and that's all it does)
- No admin rights needed, no registry changes
- `Install.cmd` and `Uninstall.cmd` are one line each, open them in Notepad to check
- Everything it sets up is easy to find and removed with `-Uninstall`: a copy of the script in `%LOCALAPPDATA%\ReHide`, two scheduled tasks (visible in Task Scheduler) and one Start Menu shortcut
- It runs through `conhost --headless`, a built-in Windows option that runs PowerShell without a window, so nothing flashes on screen
- `-ExecutionPolicy Bypass` only applies to that single PowerShell run. It doesn't change your system's policy, it's just needed because Windows blocks unsigned scripts by default

## Install

### Option 1: double-click (easiest)

1. Download the zip from the [latest release](https://github.com/t3sco/ReHide/releases/latest) and unzip it
2. Double-click **Install.cmd**. If Windows asks whether to run a downloaded file, click **Run**

### Option 2: one line in PowerShell

```powershell
irm https://raw.githubusercontent.com/t3sco/ReHide/main/install.ps1 | iex
```

This downloads `Fix-Taskbar.ps1` from this repo and installs it. Read [install.ps1](install.ps1) first if you like, it's a few lines.

Either way, the script copies itself to `%LOCALAPPDATA%\ReHide` and the watcher starts straight away. You can delete the zip afterwards.

## Uninstall

Double-click **Uninstall.cmd** from the zip, or run:

```powershell
powershell -ExecutionPolicy Bypass -File "$env:LOCALAPPDATA\ReHide\Fix-Taskbar.ps1" -Uninstall
```

## Other commands

```powershell
# Re-apply auto-hide once, right now (or press Ctrl+Alt+B)
powershell -ExecutionPolicy Bypass -File "$env:LOCALAPPDATA\ReHide\Fix-Taskbar.ps1"
```

To update, install the new version the same way. It replaces the old one.

## Notes

- Tested on Windows 11 with a dual-monitor setup. Windows 10 is untested, and older versions of it don't support `conhost --headless`
- If your monitor's own power-saving feature turns the screen black without Windows noticing, the watcher can't detect it. Use `Ctrl+Alt+B` in that case
- The watcher is a small PowerShell process, a few tens of MB of memory and effectively no CPU

## License

MIT
