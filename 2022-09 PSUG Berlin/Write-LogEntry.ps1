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
