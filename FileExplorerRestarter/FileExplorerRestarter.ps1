Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class Native {
    [StructLayout(LayoutKind.Sequential)]
    public struct POINT {
        public int X;
        public int Y;
    }
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }
    [StructLayout(LayoutKind.Sequential)]
    public struct WINDOWPLACEMENT {
        public int length;
        public int flags;
        public int showCmd;
        public POINT ptMinPosition;
        public POINT ptMaxPosition;
        public RECT rcNormalPosition;
    }

    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll", SetLastError=true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool GetWindowPlacement(IntPtr hWnd, ref WINDOWPLACEMENT lpwndpl);
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool MoveWindow(IntPtr hWnd, int X, int Y, int nWidth, int nHeight, bool bRepaint);
}
"@
$TIMEOUT_MS = 300000

function OpenExplorer {
    param([Parameter(Mandatory)][string]$Directory)
    $sh = New-Object -ComObject Shell.Application
    $oldH = @()
    foreach ($w in $sh.Windows()) {
        if ($w.FullName.ToLower().EndsWith("\explorer.exe")) {
            $oldH += [int]$w.HWND
        }
    }
    Start-Process explorer.exe "`"$Directory`""
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    while ($sw.ElapsedMilliseconds -lt $TIMEOUT_MS) {
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
$wp = New-Object Native+WINDOWPLACEMENT
$wp.length = [Runtime.InteropServices.Marshal]::SizeOf([type]"Native+WINDOWPLACEMENT")
foreach ($window in $shell.Windows()) {
    if ($window.FullName.ToLower().EndsWith("\explorer.exe") -and -not $window.Document.Folder.Self.Path.StartsWith("::")) {
        $hwnd = [int]$window.HWND
        if (-not $explorers.ContainsKey($hwnd)) {
            if (-not [Native]::GetWindowPlacement($hwnd, [ref]$wp)) {
                throw "Failed to get window placement."
            }
            $explorers[$hwnd] = [PSCustomObject]@{
                Left        = $wp.rcNormalPosition.Left
                Top         = $wp.rcNormalPosition.Top
                Width       = $wp.rcNormalPosition.Right - $wp.rcNormalPosition.Left
                Height      = $wp.rcNormalPosition.Bottom - $wp.rcNormalPosition.Top
                ShowCmd     = $wp.showCmd
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
} until ($null -ne (New-Object -ComObject Shell.Application).NameSpace(0))

foreach ($explorer in $explorers.Values) {
    $dirs = $explorer.Directories
    $window = OpenExplorer($dirs[0])    #TODO handle timeout
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
            } while (-not $btnAddrBarV.Current.Value.Equals($dirs[$i])) #TODO limit waiting time
            [System.Windows.Forms.SendKeys]::SendWait("{ENTER}")
            Start-Sleep -Milliseconds 200   #TODO wait loading
        }
    }
    [Native]::MoveWindow([IntPtr]$window.HWND, $explorer.Left, $explorer.Top, $explorer.Width, $explorer.Height, $true) | Out-Null
    [Native]::ShowWindow([IntPtr]$window.HWND, $explorer.showCmd) | Out-Null
}