<#
    .SYNOPSIS
        This script will download approved modules from the public gallery and publish them into the internal repository.

    .DESCRIPTION
        This script will download approved modules from the public gallery and publish them into the internal repository.
        The script will check the approved modules list and compare the version of the module in the internal repository with the public gallery.
        If the version in the internal repository is lower than the version in the public gallery, the script will download the module from the public gallery and publish it into the internal repository.

        The script will log all actions into a logfile and in addition can log the output to Azure Log Analytics.

    .PARAMETER PublicGalleryName
        Name of the public gallery.

        Default is PSGallery

    .PARAMETER PublicGalleryLocation
        Location of the public gallery.

        Default is https://www.powershellgallery.com/api/v2

    .PARAMETER PathInternalRepository
        Path to the internal repository configuration file.

        Default is \\$((Get-CimInstance -ClassName Win32_ComputerSystem).Domain)\netlogon\PowerShell\PSRepository_ConfigInfo\Internal_Repository.json

    .PARAMETER PathApprovedModules
        Path to the approved modules list file.

        Default is \\$((Get-CimInstance -ClassName Win32_ComputerSystem).Domain)\netlogon\PowerShell\PSRepository_ConfigInfo\ApprovedModules.json

    .PARAMETER ApiKey
        ApiKey to publish into the internal repository.

        This is optional and only need to be specified if the internal repository requires an ApiKey for publishing. (web based repositories)

    .PARAMETER Logfile
        Path to the logfile that will be created by the script. Default is C:\SW-Deport\Logs\Set-PasswordNeverExpires_$(Get-Date -Format "yyyy-MM").log

    .EXAMPLE
        PS C:\> Invoke-ApprovedModuleDownload.ps1

        This will download approved modules from the public gallery and publish them into the internal repository.

    .NOTES
        AUTHOR:     Andreas Bellstedt
        LASTEDIT:   2026-03-22
        VERSION:    1.1.0.0
        KEYWORDS:   Datacenter, Operations, PowerShell, Environment, SystemWide, Profile, ModuleDownloader, Module Management, Module

    .LINK
        https://github.com/AndiBellstedt
#>
#requires -Version 5.0
#requires -Modules PSFramework
param(
    [string]
    $PublicGalleryName = "PSGallery",

    [string]
    $PublicGalleryLocation = "https://www.powershellgallery.com/api/v2",

    [string]
    $PathInternalRepository = "\\psrepo.$((Get-CimInstance -ClassName Win32_ComputerSystem).Domain)\PowerShell\PSRepo_Config\Repository.json",

    [string]
    $PathApprovedModules = "\\psrepo.$((Get-CimInstance -ClassName Win32_ComputerSystem).Domain)\PowerShell\PSRepo_Config\ApprovedModules.json",

    [string]
    $ApiKey = "...",

    [string]
    $Logfile
)



#region Initialization
#region Logging
Set-PSFConfig -FullName PSFramework.Logging.MaxMessageCount -Value 40960
Set-PSFConfig -FullName PSFramework.Logging.Interval -Value 10


# File logging
if ($Logfile) {
    $paramSetPSFLoggingProviderLogFile = @{
        Name             = "Logfile"
        InstanceName     = "$($MyInvocation.MyCommand.Name)_LogFile"
        Enabled          = $true
        FilePath         = $Logfile
        CsvDelimiter     = ";"
        Headers          = ("Timestamp", "Level", "ModuleName", "FunctionName", "Message", "Tags", "ComputerName", "Username", "Data", "Type", "Runspace", "File", "Line", "CallStack", "ErrorRecord")
        TimeFormat       = "yyyy-MM-dd HH:mm:ss"
        IncludeHeader    = $true
        MinLevel         = 1
        MaxLevel         = 6
        ExcludeModules   = ("PSFramework")
        ExcludeFunctions = ""
        Wait             = $true
    }
    Set-PSFLoggingProvider @paramSetPSFLoggingProviderLogFile
}


# Error Logging
Trap {
    # Catch all unhadled errors and log them
    Write-PSFMessage -Level Error -Message $_.Exception -ErrorRecord $_ -PSCmdlet $pscmdlet

    Wait-PSFMessage -Timeout 5m
    if ($Logfile) { Disable-PSFLoggingProvider -Name logfile -InstanceName "$($MyInvocation.MyCommand.Name)_LogFile" -NoFinalizeWait -ErrorAction SilentlyContinue }
    if ($WorkspaceKey -and $WorkspaceId) { Disable-PSFLoggingProvider -Name AzureLogAnalytics -InstanceName "$($MyInvocation.MyCommand.Name)_AzureLogAnalytics"  -ErrorAction SilentlyContinue }
    Set-PSFLoggingProvider -Name logfile -Enabled $false -Wait -ErrorAction SilentlyContinue
    Set-PSFLoggingProvider -Name AzureLogAnalytics -Enabled $false -Wait -ErrorAction SilentlyContinue

    throw $_
}
#endregion Logging


Write-PSFMessage -Level Output -Message "Starting script..."


#endregion Initialization



#region Main script
# Check & ensure PSGallery is registered
$repositoryPublic = Get-PSResourceRepository -Name $PublicGalleryName -ErrorAction SilentlyContinue
if (-not $repositoryPublic) {
    if ($PublicGalleryName -eq "PSGallery") {
        Register-PSResourceRepository -PSGallery -Trusted -Priority 0 -Force
    } else {
        Register-PSResourceRepository -Name $PublicGalleryName -Uri $PublicGalleryLocation
    }
}


# Check & ensure internal repository is registered
$centralPSConfig = Get-Content $PathInternalRepository -ErrorAction SilentlyContinue | ConvertFrom-Json
if ($centralPSConfig) {
    $internalRepoName = $centralPSConfig.Name
    $internalSourceLocation = $centralPSConfig.SourceLocation

    $repositoryInternal = Get-PSResourceRepository -Name $internalRepoName -ErrorAction SilentlyContinue
    if (-not $repositoryInternal) {
        if ($centralPSConfig.Trusted -eq $true) {
            Register-PSResourceRepository -Name $internalRepoName -Trusted -Uri $internalSourceLocation
        } else {
            Register-PSResourceRepository -Name $internalRepoName -Uri $internalSourceLocation
        }

        $repositoryInternal = Get-PSResourceRepository -Name $internalRepoName -ErrorAction SilentlyContinue
    }
} else {
    Write-PSFMessage -Level Error -Message "Internal repository configuration not found. Please check the configuration file at: $($PathInternalRepository)"
    throw 1, "Internal repository configuration not found"
}


# Check approved modules to download and publish
$approvedModuleList = Get-Content $PathApprovedModules -ErrorAction SilentlyContinue | ConvertFrom-Json
$moduleToInstall = @()
foreach ($moduleName in $approvedModuleList) {
    $moduleInternal = Find-PSResource -Name $moduleName -Repository $internalRepoName -ErrorAction SilentlyContinue
    if (-not $moduleInternal) {
        Write-PSFMessage -Level Verbose -Message "Module '$($moduleName)' is not present in internal repository ($($internalRepoName))"
        $moduleToInstall += $moduleName
        continue
    }

    $modulePublic = Find-PSResource -Name $moduleName -Repository $PublicGalleryName -ErrorAction SilentlyContinue
    if (-not $modulePublic) {
        Write-PSFMessage -Level Warning -Message "Unable to find module '$($moduleName)' in public gallery '$($PublicGalleryName)'"
        continue
    }

    if ($moduleInternal.Version -lt $modulePublic.Version) {
        $moduleToInstall += $moduleName
    } else {
        Write-PSFMessage -Level Verbose -Message "Module '$($moduleName)' with version $($moduleInternal.Version) is same in internal repository ($($internalRepoName)) and public gallery ($($PublicGalleryName))"
    }
}


# Download and Publish approved modules
foreach ($moduleName in $moduleToInstall) {
    Write-PSFMessage -Level Important -Message "Installing module '$($moduleName)' from public gallery '$($PublicGalleryName)'"
    switch ($repositoryInternal.Uri.Scheme) {
        "file" {
            Write-PSFMessage -Level Verbose -Message "Publishing module '$($moduleName)' into file based gallery $($repositoryInternal.Name): $($repositoryInternal.Uri.LocalPath)"
            $packageList = Save-PSResource -Name $moduleName -Repository $PublicGalleryName -AsNupkg -TrustRepository -Path $repositoryInternal.Uri.LocalPath -PassThru -ErrorAction Stop
        }


        "https" {
            $tempModulePath = Join-Path -Path $env:TEMP -ChildPath "PSRessource"
            if (-not (Test-Path -Path $tempModulePath)) { $null = New-Item -Path $tempModulePath -ItemType Directory -Force }

            if (Find-PSResource -Name $moduleName -Repository $PublicGalleryName -ErrorAction Stop) {
                # Download the module from public gallery into local temp directory
                $packageList = Save-PSResource -Name $moduleName -Repository $PublicGalleryName -TrustRepository -PassThru -Path $tempModulePath -ErrorAction Stop
            } else {
                Write-PSFMessage -Level Warning -Message "Skipping module '$($moduleName)', Unable to find it in public gallery '$($PublicGalleryName)'"
                continue
            }

            # Publish the module into internal repository
            foreach ($package in $packageList) {
                Write-PSFMessage -Level Verbose -Message "Publishing package '$($package.Name)' from module '$($moduleName)' into $($internalRepoName)"
                $filePath = Join-Path -Path $tempModulePath -ChildPath $package.Name
                $packagedefinitionFile = Get-ChildItem $filePath -Filter *.psd1 -Recurse | Sort-Object FullName | Select-Object -First 1

                if($packagedefinitionFile) {
                    Publish-PSResource -ApiKey $ApiKey -Repository $internalRepoName -Path $packagedefinitionFile.Directory -SkipDependenciesCheck  -ErrorAction Stop
                } else {
                    Write-PSFMessage -Level Warning -Message "Unable to find local module definition file for module '$($moduleName)' in: $($filePath)"
                }
            }
        }


        default {
            # Should not happen, but if function is modified and new parameter sets are added, this will catch it
            Write-PSFMessage -level Error -Message "Unknown repository uri scheme '$($repositoryInternal.Uri.Scheme)'! Developer did a mistake..."
            throw 666, "Unknown repository uri scheme '$($repositoryInternal.Uri.Scheme)'! Developer did a mistake..."
        }
    }
}
#endregion Main script



#region Cleanup
Write-PSFMessage -Level Output -Message "Finishing script"

Wait-PSFMessage -Timeout 5m
if ($Logfile) { Disable-PSFLoggingProvider -Name logfile -InstanceName "$($MyInvocation.MyCommand.Name)_LogFile" -NoFinalizeWait -ErrorAction SilentlyContinue }
Set-PSFLoggingProvider -Name logfile -Enabled $false -ErrorAction SilentlyContinue
Set-PSFLoggingProvider -Name AzureLogAnalytics -Enabled $false -ErrorAction SilentlyContinue
#endregion Cleanup

