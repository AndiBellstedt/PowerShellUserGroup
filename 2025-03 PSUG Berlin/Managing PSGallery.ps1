break
#region -- prereqs


net use Z: \\svw-hq1-repo01.templatecorp.company.com\PowerShell
Get-ChildItem Z:\PSRepo -Exclude "Microsoft.PowerShell.PSResourceGet.1.1.1.nupkg" | Remove-Item -Force -Confirm:$false

Get-PSRepository | Unregister-PSRepository
Register-PSRepository -Default

if (Get-Command Get-PSResourceRepository) {
    Get-PSResourceRepository | Unregister-PSResourceRepository
    Register-PSResourceRepository -PSGallery
    if ($PSVersionTable.PSVersion.Major -eq 5) {
        Remove-Module Microsoft.PowerShell.PSResourceGet -Force
        Uninstall-Module -Name Microsoft.PowerShell.PSResourceGet -Force -Confirm:$false
    }
}
Clear-Host
#endregion prereqs



#region -- presentation


#region -- -- Repo flavours
# PowerShell default repository (PowerShellGetV2)
Get-PSRepository


# PowerShell default repository the V3 way... ups (in PS5.1)
Get-PSResourceRepository


# A share based repository is a simple
Invoke-Item \\psrepo.templatecorp.company.com\PowerShell\PSRepo
ServerManager.exe


# Register a share based repository
Register-PSRepository -Name "ShareBasedRepo" `
    -InstallationPolicy Trusted `
    -SourceLocation '\\psrepo.templatecorp.company.com\PowerShell\PSRepo\' `
    -PublishLocation '\\psrepo.templatecorp.company.com\PowerShell\PSRepo\' `
    -ScriptSourceLocation '\\psrepo.templatecorp.company.com\PowerShell\PSRepo\' `
    -ScriptPublishLocation '\\psrepo.templatecorp.company.com\PowerShell\PSRepo\'


# List the repositories again
Get-PSRepository


# Find the module in the new repository
Find-Module -Repository ShareBasedRepo


# A web based repository is a more advanced
https://psrepo.templatecorp.company.com:8625


# Register a web based (NuGet) repository
Register-PSRepository -Name "WebBasedRepo" `
    -InstallationPolicy Trusted `
    -SourceLocation "https://psrepo.templatecorp.company.com:8625/nuget/psrepo/"


# List the repositories again
Get-PSRepository


# Find the module in the new repository
Find-Module -Repository WebBasedRepo


# Install a module from the new repository
Install-Module -Name Microsoft.PowerShell.PSResourceGet -Repository WebBasedRepo -Scope CurrentUser -Force


# Let's take a look into PowerShellGetV3
Get-PSResourceRepository


# Register the repositories
Register-PSResourceRepository -Name "ShareBasedRepo" `
    -Uri '\\psrepo.templatecorp.company.com\PowerShell\PSRepo\' `
    -Trusted `
    -Priority 10


Register-PSResourceRepository -Name "WebBasedRepo" `
    -Uri 'https://psrepo.templatecorp.company.com:8625/nuget/psrepo/' `
    -Trusted `
    -Priority 10 `
    -ApiVersion V2


# List the repositories again
Get-PSResourceRepository


# Compare the repositories queries
Find-PSResource -Name * -Type Module -Repository "ShareBasedRepo"
Find-PSResource -Name * -Type Module -Repository "WebBasedRepo"


#endregion -- Repo flavours



#region -- -- Efficiency & Effectiveness - The share based repository in an air-gapped environment

# Let's take a look on the base of the fileshare
Invoke-Item "\\psrepo.templatecorp.company.com\PowerShell"


# General configuration considerations about the repository
Get-ChildItem "\\psrepo.templatecorp.company.com\PowerShell\PSRepo_Config"


# Check Repository.json



# Check ApprovedModules.json

# The "proxy system" - Get the modules from PSGallery
Get-ChildItem "\\psrepo.templatecorp.company.com\PowerShell\ModuleDownloader"


# Check Invoke-ApprovedModuleDownload.ps1 (full collapsed)


# Security and compliance
Get-AuthenticodeSignature -FilePath "\\psrepo.templatecorp.company.com\PowerShell\ModuleDownloader\Invoke-ApprovedModuleDownload.ps1" | Format-List path, status, StatusMessage, SignatureType, SignerCertificate


# Scheduled Task on the proxy system
. mmc


# Check behave of the scheduled task
$logFile = "\\svw-hq1-repo01.templatecorp.company.com\c$\Administration\Logs\PSRepo\Invoke-ApprovedModuleDownload_$(Get-Date -Format 'yyyy-MM-dd').log"
Get-ChildItem $logFile
Import-Csv $logFile | Select-Object * -ExcludeProperty ModuleName | Format-Table


#endregion -- Efficiency & Effectiveness - The share based repository in an air-gapped environment




#region -- -- Efficiency & Effectiveness - SystemProfile - the customers side

# General considerations about the client side
Get-ChildItem "\\psrepo.templatecorp.company.com\PowerShell\Profile"


# Check Profile.ps1 -> deployment of the gallery - "make it available"


# Check MandatoryModules.json -> the deployment rules for the code


# Check Install-MandetoryModule.ps1 -> stay current


# Check GPOs with deployment & scheduled tasks
. mmc


# Let's do it for the Task-Server


#endregion -- Efficiency & Effectiveness - SystemProfile - the customers side

#endregion presentation
