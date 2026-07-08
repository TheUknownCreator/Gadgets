Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type @"
using System;
using System.Runtime.InteropServices;

public static class Native
{
    [DllImport("user32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool MoveWindow(
        IntPtr hWnd,
        int X,
        int Y,
        int nWidth,
        int nHeight,
        bool bRepaint
    );
    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(
        IntPtr hWnd
    );
}
"@

function OpenExplorer {
    param([Parameter(Mandatory)][string]$Directory, [int]$TimeoutMs = 5000)
    $sh = New-Object -ComObject Shell.Application
    $oldH = @()
    $oldCount = $sh.Windows().Count()
    foreach ($w in $sh.Windows()) {
        if ($w.FullName.ToLower().EndsWith("\explorer.exe")) {
            $oldH += [int]$w.HWND
        }
    }
    Start-Process explorer.exe "`"$Directory`""
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    while ($sw.ElapsedMilliseconds -lt $TimeoutMs) {
        Start-Sleep -Milliseconds 200
        foreach ($w in $sh.Windows()) {
            $hwnd = [int]$w.HWND
            if (-not $w.FullName.ToLower().EndsWith("\explorer.exe") -or $oldH.Contains($hwnd)) {
                continue
            }
            if ([string]::Equals($w.Document.Folder.Self.Path, (Resolve-Path $Directory).Path, [System.StringComparison]::OrdinalIgnoreCase)) {
                if (-not ([int][Native]::GetForegroundWindow() -eq $hwnd)) {
                    [Native]::SetForegroundWindow($hwnd)
                    # while (-not ([int][Native]::GetForegroundWindow() -eq [int]$hwnd)) {
                    #     Start-Sleep -Milliseconds 200
                    # }
                }
                return $w
            }
        }
    }
    throw "Timed out waiting for Explorer window."
}

$shell = New-Object -ComObject Shell.Application
$explorers = @{}
foreach ($window in $shell.Windows()) {
    if ($window.FullName.ToLower().EndsWith("\explorer.exe") -and -not $window.Document.Folder.Self.Path.StartsWith("::")) {
        $hwnd = [int]$window.HWND
        if (-not $explorers.ContainsKey($hwnd)) {
            $explorers[$hwnd] = [PSCustomObject]@{
                Left = $window.Left
                Top = $window.Top
                Width = $window.Width
                Height = $window.Height
                Directories = [System.Collections.Generic.List[string]]::new()
            }
        }
        $explorers[$hwnd].Directories.Add($window.Document.Folder.Self.Path)
    }
}

Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
# Start-Process explorer.exe
# do {
#     Start-Sleep -Milliseconds 200
#     $initWnd = @($(New-Object -ComObject Shell.Application).Windows() | Where-Object {
#         $_.FullName -like "*explorer.exe"
#     })
# } until ($initWnd.Count -gt 0)
# $initWnd[0].Quit()
do {
    Start-Sleep -Milliseconds 200
} until ((New-Object -ComObject Shell.Application).NameSpace(0) -ne $null)

foreach ($explorer in $explorers.Values) {
    $dirs = $explorer.Directories
    $window = OpenExplorer($dirs[0])
    # [Native]::MoveWindow($window.HWND, $explorer.Left, $explorer.Top, $explorer.Width, $explorer.Height, $true)
    if ($dirs.Count -gt 1) {
        $uiRoot = [System.Windows.Automation.AutomationElement]::FromHandle([IntPtr]$window.HWND)
        $btnNewTabI = $uiRoot.findFirst([System.Windows.Automation.TreeScope]::Descendants, (New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::AutomationIdProperty, "AddButton"))).GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)
        $btnAddrBar = $uiRoot.findFirst([System.Windows.Automation.TreeScope]::Descendants, (New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::AutomationIdProperty, "TextBox")))
        $btnAddrBarV = $btnAddrBar.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern)
        for ($i = 1; $i -lt $dirs.Count; $i++) {
            $btnNewTabI.Invoke()
            do {
                Start-Sleep -Milliseconds 200
                $btnAddrBar.SetFocus()
                $btnAddrBarV.SetValue($dirs[$i])
            } while (-not $btnAddrBarV.Current.Value.Equals($dirs[$i]))
            [System.Windows.Forms.SendKeys]::SendWait("{ENTER}")
            Start-Sleep -Milliseconds 200   #TODO wait loading
        }
    }
}
