# WinEventLogCustomization Presentation - Basics about Windows EventLogs
break

# prereq
Start-Process pwsh.exe -Verb runas -WorkingDirectory $demopath

$demoName = "PSUGHH"
$demopath = "C:\WELCDemo"
Set-Location $demopath

Find-Module WinEventLogCustomization | Install-Module -Scope CurrentUser -Force
Import-Module WinEventLogCustomization
Get-Module


# The module and the commands
Get-Command -Module WinEventLogCustomization
Get-Command -Module WinEventLogCustomization | Select-Object @{n = "Verb"; e = { $_.name.split("-")[0] } }, @{n = "Noun"; e = { $_.name.split("-")[1].replace("WELC", "") } }, Name | Sort-Object noun, verb | Format-Table


# Help is there for you
help New-WELCEventChannelManifest -ShowWindow
help register-WELCEventChannelManifest -Examples


# Writing eventlog information - still, it's the (deprecated/wrong) only WindowsPowerShell way
Write-EventLog -LogName "Windows PowerShell" -Source "PowerShell" -EntryType Information -Message "Yes I can write to the powershell eventlog!" -EventID 666 -Category 1
Get-EventLog -LogName "Windows PowerShell" -Newest 1 | Format-List


#region --- Getting eventlog - the PowerShell[3..7] way
Get-WinEvent -ListLog * | Where-Object IsClassicLog
Get-WinEvent -LogName Application -MaxEvents 10


# Create new custom eventlog
New-WELCEventChannelManifest -ChannelFullName "$($demoName)-PowerShell-Demo/Logging" -Verbose
Get-ChildItem "$($demoName).man" | Register-WELCEventChannelManifest
eventvwr.exe


# Check the eventlog
Get-WELCEventChannel -ChannelFullName "$($demoName)*"

# Set eventlog
Get-WELCEventChannel -ChannelFullName "$($demoName)*" | Set-WELCEventChannel -Enabled $true -MaxEventLogSize 64MB -LogFilePath C:\Administration\WELCDemo

# Clean up - rolling back the configuration
Get-ChildItem "$($demoName).man" | Unregister-WELCEventChannelManifest -Path '$($_.Fullname)'


# Mass edit - Excel usage
Open-WELCExcelTemplate


# Import data from Excel
$excelFile = (Get-ChildItem $demopath\*.xlsx).FullName
$channels = Import-WELCChannelDefinition -Path $excelFile -OutputChannelDefinition
$channels | Format-Table
$channels | New-WELCEventChannelManifest

# import channel config from Excel
$channelConfig = Import-WELCChannelDefinition -Path $excelFile -OutputChannelConfig
$channelConfig | Format-Table
$channelConfig | Set-WELCEventChannel

# move around
Move-WELCEventChannelManifest -Path "$($demoName).man" -DestinationPath "C:\Administration"


#region Logging to eventlogs - PSF example
$paramSetPSFLoggingProvider = @{
    Name           = 'eventlog'
    InstanceName   = $demoName
    LogName        = "$($demoName)-PowerShell-Demo/Logging"
    Source         = "My-$($demoName)-Task"
    MinLevel       = 1
    MaxLevel       = 6
    ExcludeModules = "psframework"
    Enabled        = $true
}
Set-PSFLoggingProvider @paramSetPSFLoggingProvider
Get-PSFLoggingProvider -Name eventlog

Write-PSFMessage -Level Important -Message "Hello $demoName"
Write-PSFMessage -Level Error -Message "Error occured"
Write-PSFMessage -Level Warning -Message "Warning occured"
Get-WELCEventChannel -ChannelFullName PSUG*

Set-PSFLoggingProvider -Name eventlog -InstanceName $demoName -Enabled $false


# manuel function example
function Write-LogEntry {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $LogName,

        [Parameter(Mandatory=$true)]
        [string]
        $Source,

        [int]
        $EventID,

        [int]
        $Category = 1,

        [ValidateSet("Error", "Warning","Information","SuccessAudit","FailureAudit")]
        [string]
        $Type,

        [string]
        $Message
    )

    if(-not $EventID) {
        switch ($Type) {
            "Error" { $EventID = 666 }
            "Warning" { $EventID = 999 }
            "Information" { $EventID = 1000 }
            "SuccessAudit" { $EventID = 500 }
            "FailureAudit" { $EventID = 555 }
            Default {$EventID = 1 }
        }
    }

    if ($Message.Length -gt 31698) { $Message = $Message.SubString(0, 31698) + '...' }

    $id = New-Object System.Diagnostics.EventInstance($EventID, $Category, [System.Diagnostics.EventLogEntryType]::$Type)
    $evtObject = New-Object System.Diagnostics.EventLog
    $evtObject.Log = $LogName
    $evtObject.Source = $Source
    $evtObject.WriteEvent($id, $Message)
}

Write-LogEntry -LogName "$($demoName)-PowerShell-Demo/Logging" -Source "$($demoName)-PowerShell-Demo/Logging" -Type Information -Message "Hello $demoName"
Write-LogEntry -LogName "$($demoName)-PowerShell-Demo/Logging" -Source "$demoName" -Type Information -Message "Hello $demoName"
