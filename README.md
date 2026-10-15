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
- No internet access, no downloads, nothing sent anywhere
- No admin rights needed, no registry changes
- Everything it sets up (two scheduled tasks and one Start Menu shortcut) is visible in Task Scheduler and removed with `-Uninstall`
- `-ExecutionPolicy Bypass` only applies to that single PowerShell run. It doesn't change your system's policy, it's just needed because Windows blocks unsigned scripts by default

## Install

1. Download `Fix-Taskbar.ps1` and save it somewhere permanent, e.g. `Documents\Scripts` (the scheduled tasks point at this location)
2. Right-click the file, choose **Properties**, tick **Unblock** if it's there, and click OK
3. Open PowerShell in that folder and run:

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\Fix-Taskbar.ps1 -Install
   ```

That's it, the watcher starts straight away.

## Other commands

```powershell
# Re-apply auto-hide once, right now
powershell -ExecutionPolicy Bypass -File .\Fix-Taskbar.ps1

# Remove everything -Install set up
powershell -ExecutionPolicy Bypass -File .\Fix-Taskbar.ps1 -Uninstall
```

If you move the script after installing, run `-Install` again from the new location.

## Notes

- Tested on Windows 11 with a dual-monitor setup
- If your monitor's own power-saving feature turns the screen black without Windows noticing, the watcher can't detect it. Use `Ctrl+Alt+B` in that case
- The watcher is a small PowerShell process, a few tens of MB of memory and effectively no CPU

## License

MIT
