<#
.SYNOPSIS
    This script ensures that specific PowerShell modules are installed on a computer system if it is part of a domain.

.DESCRIPTION
    The script checks if the computer is part of a domain.
    If it is, it loads a central configuration file named "MandatoryModules.json" from a network location.
    This file contains a list of modules that should be installed. The script reads the content of this file
    and converts it from JSON format into a PowerShell object.

    It then compiles a list of modules to be installed based on the settings in the configuration file,
    ensuring the list is unique. Depending on the version of PowerShellGet available, it installs or updates
    the modules using the appropriate cmdlets.

.PARAMETER ConfigFile
    The path to the central configuration file with the modules that should be installed.

.EXAMPLE
    PS C:\> .\Install-MandatoryModule.ps1

    This command runs the script to ensure the required modules are installed on the computer.

.NOTES
    Version:    1.3.0.0
    Author:     Andreas Bellstedt
    Date:       2025-03-22
    Keywords:   Server Management, PowerShell, PowerShell Ecosystem, Modules

.LINK
    https://github.com/AndiBellstedt

#>
#requires -Version 5.1
#Requires -RunAsAdministrator
[CmdletBinding()]
Param(
    [Parameter(Mandatory = $false)]
    [string]
    $ConfigFile = "\\psrepo.$((Get-CimInstance -ClassName Win32_ComputerSystem).Domain)\PowerShell\ClientSide\MandatoryModules.json"
)

# Get computer system information
$computersystem = Get-CimInstance -ClassName Win32_ComputerSystem

# Only act if the computer is part of a domain
if ($computersystem.PartOfDomain) {
    # Get the central configuration file with the modules that should be installed
    $mandatoryModules = Get-Content -Path $ConfigFile -ErrorAction SilentlyContinue | ConvertFrom-Json

    # Only act if the configuration file actually was loaded
    if ($mandatoryModules) {
        # Create a list of modules that should be installed
        $moduleNameList = @()

        # Go through the settings in the configuration file
        foreach ($setting in $mandatoryModules.PSObject.Properties.Name) {
            # Check if the setting names and match them to the computer system
            switch ($setting) {
                "DEFAULT" {
                    # Search for "DEFAULT" in the config file -> those are modules that should be installed on all systems
                    foreach ($moduleName in $mandatoryModules.$setting) {
                        $moduleNameList += $moduleName
                    }
                }
                { $computersystem.Domain -like $_ } {
                    # Search if domain of the computer matches a pattern in the config file -> those are modules that should be installed on specific domains only
                    foreach ($moduleName in $mandatoryModules.$setting) {
                        $moduleNameList += $moduleName
                    }
                }
                { $env:COMPUTERNAME -like $_ } {
                    # Search if computersname matches a pattern in the config file -> those are modules that should be installed on specific systems
                    foreach ($moduleName in $mandatoryModules.$setting) {
                        $moduleNameList += $moduleName
                    }
                }
                Default {
                    Write-Error "Unknown setting '$($setting)' in MandatoryModules.json"
                }
            }
        }

        # make Module list unique to avoid duplicate installation attempts
        $moduleNameList = $moduleNameList | Select-Object -Unique

        # Depending on the installed PowerShellGet version, install the modules with V1 or preferibly with V2
        if (Get-Command Find-PSResource -ErrorAction SilentlyContinue) {
            # Get the list of repositories to check module origin
            $repositoryList = Get-PSResourceRepository

            # Work through the list of modules that are in scope
            foreach ($moduleName in $moduleNameList) {
                # Check if module is already installed
                $existingModule = Get-PSResource -Name $moduleName -Scope AllUsers -ErrorAction SilentlyContinue

                # If already installed, check if it is from the correct repository. Depending on the result, update or re-install the module
                if ($existingModule) {
                    # Check repository of existing module (case of modules that have been installed from a different repository/ shiped in windows / brought in manually)
                    if ($existingModule.Repository -in $repositoryList.name) {
                        # Updating module
                        Update-PSResource -Name $moduleName -TrustRepository -AcceptLicense -AuthenticodeCheck:$false -Scope AllUsers -Quiet
                    } else {
                        # Installing module
                        Install-PSResource -Name $moduleName -TrustRepository -AcceptLicense -AuthenticodeCheck:$false -Scope AllUsers -Quiet -Reinstall
                    }
                } else {
                    # Installing module
                    Install-PSResource -Name $moduleName -TrustRepository -AcceptLicense -AuthenticodeCheck:$false -Scope AllUsers -Quiet -Reinstall
                }
            }
        } else {
            # Get the list of repositories to check module origin
            $repositoryList = Get-PSRepository

            # Work through the list of modules that are in scope
            foreach ($moduleName in $moduleNameList) {
                # Check if module is already installed
                $existingModule = Get-Module -Name $moduleName -ListAvailable -ErrorAction SilentlyContinue | Sort-Object Version | Select-Object -Last 1

                # If already installed, check if it is from the correct repository. Depending on the result, update or re-install the module
                if ($existingModule -and $existingModule.RepositorySourceLocation) {
                    # Check repository of existing module (case of modules that have been installed from a different repository/ shiped in windows / brought in manually)
                    if ($existingModule.RepositorySourceLocation.tostring() -in $repositoryList.SourceLocation) {
                        # Updating module
                        Update-Module -Name $moduleName -Confirm:$false
                    } else {
                        # Installing module
                        Install-Module -Name $moduleName -Force -SkipPublisherCheck -Scope AllUsers
                    }
                } else {
                    # Installing module
                    Install-Module -Name $moduleName -Force -SkipPublisherCheck -Scope AllUsers
                }
            }
        }
    }
}


