
# Get the PowerShell module for importing excel data
Find-Module ImportExcel | Install-Module -Scope CurrentUser -Force
Import-Module ImportExcel
Get-Command -Module ImportExcel


# Import definitions from excel file
$path = "C:\Administration\WELC.xlsx"
$sheet = "CustomEventLogChannels"
$table = "T_Channel"

$excelDocument = Open-ExcelPackage -Path $path
$excelSheet = $excelDocument.Workbook.Worksheets | Where-Object name -like $Sheet
$excelTable = $excelSheet.Tables | Where-Object name -like $Table
$paramImport = @{
    ExcelPackage  = $excelDocument
    WorksheetName = $excelSheet.name
    StartRow      = $excelTable.Address.Start.Row
    StartColumn   = $excelTable.Address.Start.Column
    EndRow        = $excelTable.Address.End.Row
    EndColumn     = $excelTable.Address.End.Column
}

$queryDefinitions = Import-Excel @paramImport | Where-Object SubscriptionEnabled -like "True"


# Create security groups from excel file (RSAT tools needed)
Import-Module ActiveDirectory
foreach ($groupName in ($queryDefinitions | Group-Object TargetGroup).Name) {
    New-ADGroup -Name $groupName -SamAccountName $groupName -Description "Members of this group join specific Windows Event Forwarding subscriptions defined on WEF Server $($server)" -GroupCategory Security -GroupScope DomainLocal
}


# Get the PowerShell module for creating EventLogSubscriptions
Find-Module WindowsEventForwarding | Install-Module -Scope CurrentUser -Force
Import-Module WindowsEventForwarding
Get-Command -Module WindowsEventForwarding


# Create subscription(s) from excel file
$server = "LOG01"

foreach ($queryDefinition in $queryDefinitions) {
    $paramWefSubscription = @{
        ComputerName         = $server
        Name                 = $queryDefinition.ChannelSymbol
        Enabled              = $false
        Query                = $queryDefinition.Query
        LogFile              = $queryDefinition.ChannelName
        SourceDomainComputer = $queryDefinition.TargetGroup
        ReadExistingEvents   = $true
        ContentFormat        = "RenderedText"
        ConfigurationMode    = "MinLatency"
    }

    New-WEFSourceInitiatedSubscription @paramWefSubscription -Verbose
}

Get-WEFSubscription -ComputerName $server

Get-WEFSubscription -ComputerName $server | Set-WEFSubscription -Locale en-US
Get-WEFSubscription -ComputerName $server | Set-WEFSubscription -Enabled $true

$subscriptionRuntimestatus = Get-WEFSubscription -ComputerName $server | Get-WEFSubscriptionRuntimestatus
$subscriptionRuntimestatus | Out-GridView

Get-WEFSubscription -ComputerName $server | Remove-WEFSubscription