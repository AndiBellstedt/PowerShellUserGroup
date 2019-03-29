$script:TraceVerboseTimer = New-Object System.Diagnostics.Stopwatch
$script:TraceVerboseTimer.Start()

#region Variables
switch ($env:COMPUTERNAME) {
    "SpecialPC" { New-Variable -Name GitRoot -Option Constant, ReadOnly -Scope script -Value "X:\GitHub" }
    Default { New-Variable -Name GitRoot -Option Constant, ReadOnly -Scope script -Value (Join-Path $home "Development") }
}
New-Variable -Name WorkRoot -Option Constant, ReadOnly -Scope script -Value "C:\Administration"
New-Variable -Name ProfilePath -Option Constant, ReadOnly -Scope Global -Value ( Split-Path $PROFILE -Parent )
New-Variable -Name CodeSignCert -Option Constant, ReadOnly -Scope Global -Value ( Get-childitem -Path Cert:\currentuser\My -codesigningcert | Sort-Object -Property NotAfter -Descending | Select-Object -First 1 )
New-Variable -Name LiveID -Option AllScope, Constant -Scope Global -ErrorAction SilentlyContinue -Value ( [System.Security.Principal.WindowsIdentity]::GetCurrent().Groups | Where-Object Value -match "^S-1-11-96" | ForEach-Object Translate([System.Security.Principal.NTAccount]) | ForEach-Object Value )
if (Get-Command Get-LocalUser -ErrorAction SilentlyContinue) {
    New-Variable -Name User -Option Private -Scope script -Value ( (Get-LocalUser $env:USERNAME -ErrorAction SilentlyContinue).FullName )
} else {
    New-Variable -Name User -Option Private -Scope script -Value ( $env:USERNAME )
}
if ( ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) ) {
    New-Variable -Name TextIsAdmin -Option Constant, ReadOnly -Scope Global -Value "ADMINISTRATOR:"
} else {
    New-Variable -Name TextIsAdmin -Option Constant, ReadOnly -Scope Global -Value ""
}

#endregion Variables


#region UI-Settings
# Windows title
$Host.ui.RawUI.WindowTitle = "[{0}{1}] on [{2}] in [PID {3}] - $($host.Name) $($host.Version)" -f $TextIsAdmin, $User, $env:COMPUTERNAME, $PID

# Shell prompt
. $psscriptroot\Prompt.ps1

# Check for verbose mode (start powershell with SHIFT key hold.
if ("Core" -eq $PSVersionTable.PSEdition) {
    # For now, CORE edition is always verbose, because I can't test for KeyState
    $VerbosePreference = "Continue"
} else {
    # Check SHIFT state ASAP at startup so I can use that to control verbosity :)
    Add-Type -Assembly PresentationCore, WindowsBase
    try {
        if ([System.Windows.Input.Keyboard]::IsKeyDown([System.Windows.Input.Key]::LeftShift) -OR
            [System.Windows.Input.Keyboard]::IsKeyDown([System.Windows.Input.Key]::RightShift)) {
            $VerbosePreference = "Continue"
        } else {
            $VerbosePreference = "SilentlyContinue"
        }
    } catch { $null }
}

#endregion UI-Settings


#region Set individuel environment behavior
# execution policy
Set-ExecutionPolicy RemoteSigned Process -ErrorAction Ignore

# color scheme
$Host.UI.RawUI.BackgroundColor = [consolecolor]::Black

# PSReadline options
Set-PSReadlineOption -HistorySaveStyle SaveNothing
Set-PSReadlineOption -BellStyle None
Set-PSReadlineKeyHandler -Chord Ctrl+Shift+C -Function CaptureScreen

# switch to estimated work root
Set-Location -Path $WorkRoot

# create GIT drive
if ($GitRoot) {
    $null = New-PSDrive -Name "GIT" -PSProvider FileSystem -Root $GitRoot
}

# PackageUpdateInfo
Start-Job -ScriptBlock { Get-PackageUpdateInfo -ShowOnlyNeededUpdate | Export-PackageUpdateInfo } | Out-Null
Import-PackageUpdateInfo

Clear-Host
$TraceVerboseTimer.Stop()
Write-Host "profile execution tooks $($TraceVerboseTimer.ElapsedMilliseconds)ms"

#endregion Set individuel environment
