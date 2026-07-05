# By TheUknownCreator
Add-Type -AssemblyName System.Windows.Forms
$installer = "RightMenuAddToPATH Installer By TheUknownCreator"
$ScriptName = "AddToPATH.ps1"
$choice = [System.Windows.Forms.MessageBox]::Show(
    "This will generate script at `"$PSScriptRoot\$ScriptName`"`nAre you sure?",
    "$installer",
    [System.Windows.Forms.MessageBoxButtons]::OKCancel,
    [System.Windows.Forms.MessageBoxIcon]::Question
)
if (-not ($choice -eq [System.Windows.Forms.DialogResult]::OK)) {
    exit
}

$script = @'
# By TheUknownCreator
param(
    [Parameter(Mandatory = $true)]
    [string]$Path,
    [Alias("S")]
    [switch]$System                     # If add to System PATH
)
Write-Host "Please wait..."

Add-Type -AssemblyName System.Windows.Forms
$scope = "User"
if ($System.IsPresent) {
    # Rerun script as admin if not
    if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`" -Path `"$Path`" -System"
        exit
    }
    $scope = "Machine"
}
$Path = [System.IO.Path]::GetFullPath($Path.TrimEnd('\'))
$current = [Environment]::GetEnvironmentVariable("Path", $scope)
$list = @()
if ($current) {
    $list = $current.Split(';') | Where-Object { $_ } | ForEach-Object { $_.TrimEnd('\') }
}

# Directory is already added to PATH
if ($list -contains $Path) {
    [System.Windows.Forms.MessageBox]::Show("$scope PATH already contains:`n$Path", "Directory exists")
    exit
}

$newPath = ($list + $Path) -join ';'
[Environment]::SetEnvironmentVariable("Path", $newPath, $scope)

# Broadcast PATH change
# Add-Type @"
# using System;
# using System.Runtime.InteropServices;
# public class Native {
#     [DllImport("user32.dll", SetLastError=true, CharSet=CharSet.Auto)]
#     public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint Msg, UIntPtr wParam, string lParam, uint fuFlags, uint uTimeout, out UIntPtr lpdwResult);
# }
# "@
# $result = [UIntPtr]::Zero
# [Native]::SendMessageTimeout([IntPtr]0xffff, 0x1A, [UIntPtr]::Zero, "Environment", 2, 5000, [ref]$result) | Out-Null

[System.Windows.Forms.MessageBox]::Show("Added `n$Path`nto $scope PATH`nYou may need to restart all consoles to see the change!", "Success")
'@
Set-Content -Path "$PSScriptRoot\$ScriptName" -Value $script -Encoding UTF8

$ScriptPath = "$PSScriptRoot\$ScriptName" -replace '%', '%%'
$command = "powershell -NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`""
Remove-Item "HKLM:\SOFTWARE\Classes\Folder\shell\AddToUserPath" -Recurse -Force -ErrorAction SilentlyContinue
New-Item "HKLM:\SOFTWARE\Classes\Folder\shell\AddToUserPath" -Force | Out-Null
Set-ItemProperty "HKLM:\SOFTWARE\Classes\Folder\shell\AddToUserPath" -Name "(default)" -Value "Add to User PATH"
Set-ItemProperty "HKLM:\SOFTWARE\Classes\Folder\shell\AddToUserPath" -Name "Icon" -Value "imageres.dll,-5302"
New-Item "HKLM:\SOFTWARE\Classes\Folder\shell\AddToUserPath\command" -Force | Out-Null
Set-ItemProperty "HKLM:\SOFTWARE\Classes\Folder\shell\AddToUserPath\command" -Name "(default)" -Value "$command -Path `"%1`""

Remove-Item "HKLM:\SOFTWARE\Classes\Folder\shell\AddToMachinePath" -Recurse -Force -ErrorAction SilentlyContinue
New-Item "HKLM:\SOFTWARE\Classes\Folder\shell\AddToMachinePath" -Force | Out-Null
Set-ItemProperty "HKLM:\SOFTWARE\Classes\Folder\shell\AddToMachinePath" -Name "(default)" -Value "Add to System PATH"
Set-ItemProperty "HKLM:\SOFTWARE\Classes\Folder\shell\AddToMachinePath" -Name "Icon" -Value "imageres.dll,-5302"
New-Item "HKLM:\SOFTWARE\Classes\Folder\shell\AddToMachinePath\command" -Force | Out-Null
Set-ItemProperty "HKLM:\SOFTWARE\Classes\Folder\shell\AddToMachinePath\command" -Name "(default)" -Value "$command -Path `"%1`" -System"

Remove-Item "HKLM:\SOFTWARE\Classes\Directory\background\shell\AddToUserPath" -Recurse -Force -ErrorAction SilentlyContinue
New-Item "HKLM:\SOFTWARE\Classes\Directory\background\shell\AddToUserPath" -Force | Out-Null
Set-ItemProperty "HKLM:\SOFTWARE\Classes\Directory\background\shell\AddToUserPath" -Name "(default)" -Value "Add current folder to User PATH"
Set-ItemProperty "HKLM:\SOFTWARE\Classes\Directory\background\shell\AddToUserPath" -Name "Icon" -Value "imageres.dll,-5302"
New-Item "HKLM:\SOFTWARE\Classes\Directory\background\shell\AddToUserPath\command" -Force | Out-Null
Set-ItemProperty "HKLM:\SOFTWARE\Classes\Directory\background\shell\AddToUserPath\command" -Name "(default)" -Value "$command -Path `"%V`""

Remove-Item "HKLM:\SOFTWARE\Classes\Directory\background\shell\AddToMachinePath" -Recurse -Force -ErrorAction SilentlyContinue
New-Item "HKLM:\SOFTWARE\Classes\Directory\background\shell\AddToMachinePath" -Force | Out-Null
Set-ItemProperty "HKLM:\SOFTWARE\Classes\Directory\background\shell\AddToMachinePath" -Name "(default)" -Value "Add current folder to System PATH"
Set-ItemProperty "HKLM:\SOFTWARE\Classes\Directory\background\shell\AddToMachinePath" -Name "Icon" -Value "imageres.dll,-5302"
New-Item "HKLM:\SOFTWARE\Classes\Directory\background\shell\AddToMachinePath\command" -Force | Out-Null
Set-ItemProperty "HKLM:\SOFTWARE\Classes\Directory\background\shell\AddToMachinePath\command" -Name "(default)" -Value "$command -Path `"%V`" -System"

[System.Windows.Forms.MessageBox]::Show(
    "Successfully installed!`nYou need to restart explorer.exe to see the change.`n`nIf you want to move the script to another directory,`nYou need to move this installer to that directory and re-install again.",
    "$installer"
)