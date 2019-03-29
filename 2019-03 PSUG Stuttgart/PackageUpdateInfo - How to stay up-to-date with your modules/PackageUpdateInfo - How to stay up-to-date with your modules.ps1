#region prereqs
# plain white system
$psDir = New-Item -Path $env:PSModulePath.Split(";")[0] -ItemType Directory -Force | Split-Path -Parent
Invoke-Item $psDir
Get-Module -ListAvailable

# allow executing scripts and set PSGallery as trusted
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Force
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted

#endregion prereqs


#region presentation
# find and install a important module
Find-Module -Name PackageUpdateInfo -RequiredVersion 1.1.0.0 | Install-Module -Scope CurrentUser
Invoke-Item $psDir


# import and look into the module
Import-Module -Name PackageUpdateInfo
Get-Command -Module PackageUpdateInfo

# executing GET commands isn't harmful
Get-PackageUpdateInfo


# let's dig into the possiblities of the command
help Get-PackageUpdateInfo


# tryout the parameters
Get-PackageUpdateInfo -ShowOnlyNeededUpdate
Get-PackageUpdateInfo -ShowToastNotification


# let's install some modules to make it feels more like a "real world environment"
Find-Module -Name Az, AzureAD, SpeculationControl, PSUtil, PSModuleDevelopment, PoShPRTG, PSScriptAnalyzer, MSGraph, PoShKeePass | Install-Module -Scope CurrentUser; Find-Module -Name PSFramework -RequiredVersion 0.10.31.179 | Install-Module -Scope AllUsers


# query for module updates is getting slow now
Get-PackageUpdateInfo -ShowOnlyNeededUpdate


# but wait, there was some more commands in the module
Get-Command -Module PackageUpdateInfo


# so lets collect the infos in a background job and import them, when starting the shell
Start-Job -ScriptBlock { Get-PackageUpdateInfo -ShowOnlyNeededUpdate | Export-PackageUpdateInfo } | Out-Null
Import-PackageUpdateInfo -ShowToastNotification


# two lines of code in your profile...
$psDir = $env:PSModulePath.Split(";")[0] | Split-Path -Parent
psEdit "$psDir\profile.ps1"
# manually or with the following line
Add-Content -Path "$psDir\profile.ps1" -Value "Start-Job -ScriptBlock { Get-PackageUpdateInfo -ShowOnlyNeededUpdate | Export-PackageUpdateInfo } | Out-Null`nImport-PackageUpdateInfo -ShowToastNotification"

# Now, the info is present, every time you start the shell
Start-Process powershell.exe

#endregion presentation