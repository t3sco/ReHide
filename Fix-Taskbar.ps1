<#
  Fix-Taskbar.ps1
  Re-applies taskbar auto-hide (same as switching the setting off and on),
  which wakes up the second monitor's taskbar when it stops reappearing.

  Usage:
    .\Fix-Taskbar.ps1             Toggle auto-hide off/on now
    .\Fix-Taskbar.ps1 -Install    Copy to %LOCALAPPDATA%\ReHide and set up
                                  automatic fixing + Ctrl+Alt+B hotkey
    .\Fix-Taskbar.ps1 -Uninstall  Remove everything -Install set up
    .\Fix-Taskbar.ps1 -Watch      (used by the background task) watch for
                                  screensaver ending, monitors reconnecting
                                  and waking from sleep, and fix automatically
#>
param(
    [switch]$Install,
    [switch]$Uninstall,
    [switch]$Watch
)

$TaskName     = 'Fix Taskbar Auto-hide'
$WatcherName  = 'Fix Taskbar Auto-hide Watcher'
$ShortcutPath = Join-Path ([Environment]::GetFolderPath('Programs')) 'Fix Taskbar.lnk'
$Hotkey       = 'CTRL+ALT+B'
$InstallDir   = Join-Path $env:LOCALAPPDATA 'ReHide'
$InstalledPs1 = Join-Path $InstallDir 'Fix-Taskbar.ps1'

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class TaskbarFix {
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT { public int left, top, right, bottom; }

    [StructLayout(LayoutKind.Sequential)]
    public struct APPBARDATA {
        public int cbSize;
        public IntPtr hWnd;
        public uint uCallbackMessage;
        public uint uEdge;
        public RECT rc;
        public IntPtr lParam;
    }

    [DllImport("shell32.dll")]
    static extern UIntPtr SHAppBarMessage(uint dwMessage, ref APPBARDATA pData);

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    static extern IntPtr FindWindow(string lpClassName, string lpWindowName);

    [DllImport("user32.dll")]
    static extern int GetSystemMetrics(int nIndex);

    [DllImport("user32.dll")]
    static extern bool SystemParametersInfo(uint uiAction, uint uiParam, ref bool pvParam, uint fWinIni);

    // ABM_SETSTATE = 0x0A; ABS_AUTOHIDE = 1; ABS_ALWAYSONTOP = 2
    public static void SetState(int state) {
        APPBARDATA d = new APPBARDATA();
        d.cbSize = Marshal.SizeOf(typeof(APPBARDATA));
        d.hWnd = FindWindow("Shell_TrayWnd", null);
        d.lParam = (IntPtr)state;
        SHAppBarMessage(0x0A, ref d);
    }

    // SPI_GETSCREENSAVERRUNNING = 0x72
    public static bool ScreensaverRunning() {
        bool running = false;
        SystemParametersInfo(0x72, 0, ref running, 0);
        return running;
    }

    // Monitor count + virtual desktop bounds; changes when a monitor drops out or comes back
    public static string Layout() {
        return GetSystemMetrics(80) + ":" + GetSystemMetrics(76) + "," + GetSystemMetrics(77)
             + "," + GetSystemMetrics(78) + "," + GetSystemMetrics(79);
    }
}
"@ -ErrorAction SilentlyContinue

function Invoke-TaskbarToggle {
    [TaskbarFix]::SetState(2)       # auto-hide off
    Start-Sleep -Milliseconds 600
    [TaskbarFix]::SetState(1)       # auto-hide back on
}

if ($Uninstall) {
    Stop-ScheduledTask -TaskName $WatcherName -ErrorAction SilentlyContinue
    Unregister-ScheduledTask -TaskName $WatcherName -Confirm:$false -ErrorAction SilentlyContinue
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
    Remove-Item $ShortcutPath -ErrorAction SilentlyContinue
    Remove-Item $InstallDir -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host 'Removed scheduled tasks, hotkey and installed files.'
    return
}

if ($Install) {
    # Stop any running watcher first, so the new one can start
    Stop-ScheduledTask -TaskName $WatcherName -ErrorAction SilentlyContinue

    # Copy this script to a fixed location so the downloaded copy can be moved or deleted
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
    if ($PSCommandPath -ne $InstalledPs1) {
        Copy-Item -LiteralPath $PSCommandPath -Destination $InstalledPs1 -Force
    }
    Unblock-File -LiteralPath $InstalledPs1 -ErrorAction SilentlyContinue

    # conhost --headless runs PowerShell with no window at all (no flash)
    $exe    = 'conhost.exe'
    $psArgs = "--headless powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$InstalledPs1`""
    $user   = "$env:USERDOMAIN\$env:USERNAME"
    $principal = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Limited

    # 1) One-off fix on unlock
    $unlockClass = Get-CimClass -Namespace 'Root/Microsoft/Windows/TaskScheduler' `
                                -ClassName 'MSFT_TaskSessionStateChangeTrigger'
    $unlock = New-CimInstance -CimClass $unlockClass -ClientOnly -Property @{
        StateChange = 8      # 8 = session unlock
        UserId      = $user
        Delay       = 'PT3S'
    }
    $oneShotSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
                                                    -ExecutionTimeLimit (New-TimeSpan -Minutes 1)
    Register-ScheduledTask -TaskName $TaskName `
        -Action (New-ScheduledTaskAction -Execute $exe -Argument $psArgs) `
        -Trigger $unlock -Settings $oneShotSettings -Principal $principal -Force | Out-Null

    # 2) Background watcher from login onwards (screensaver, monitor reconnect, sleep)
    $logon = New-ScheduledTaskTrigger -AtLogOn -User $user
    $logon.Delay = 'PT10S'
    $watchSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
                                                  -ExecutionTimeLimit ([TimeSpan]::Zero) `
                                                  -MultipleInstances IgnoreNew
    Register-ScheduledTask -TaskName $WatcherName `
        -Action (New-ScheduledTaskAction -Execute $exe -Argument "$psArgs -Watch") `
        -Trigger $logon -Settings $watchSettings -Principal $principal -Force | Out-Null
    Start-ScheduledTask -TaskName $WatcherName

    # 3) Start Menu shortcut with a global hotkey
    $shell = New-Object -ComObject WScript.Shell
    $lnk = $shell.CreateShortcut($ShortcutPath)
    $lnk.TargetPath  = $exe
    $lnk.Arguments   = $psArgs
    $lnk.WindowStyle = 7     # minimised
    $lnk.Hotkey      = $Hotkey
    $lnk.Description = 'Re-apply taskbar auto-hide'
    $lnk.Save()

    Write-Host "Installed to $InstallDir. The watcher is running and starts at every login. $Hotkey re-applies auto-hide manually. You can delete the downloaded copy."
    return
}

if ($Watch) {
    Invoke-TaskbarToggle

    $lastLayout = [TaskbarFix]::Layout()
    $ssWas      = $false
    $pending    = $false
    $pendingAt  = Get-Date
    $lastTick   = Get-Date

    while ($true) {
        Start-Sleep -Seconds 3
        $now = Get-Date

        # Big gap between ticks = PC was asleep
        if (($now - $lastTick).TotalSeconds -gt 30) { $pending = $true; $pendingAt = $now }
        $lastTick = $now

        # Screensaver just ended
        $ss = [TaskbarFix]::ScreensaverRunning()
        if ($ssWas -and -not $ss) { $pending = $true; $pendingAt = $now }
        $ssWas = $ss

        # A monitor dropped out or came back
        $layout = [TaskbarFix]::Layout()
        if ($layout -ne $lastLayout) { $pending = $true; $pendingAt = $now; $lastLayout = $layout }

        # Fix once things have been stable for a few seconds
        if ($pending -and -not $ss -and ($now - $pendingAt).TotalSeconds -ge 3) {
            Invoke-TaskbarToggle
            $pending = $false
        }
    }
}

Invoke-TaskbarToggle
