#region -- Custom internal PowerShell Gallery

$copmutersystem = Get-CimInstance -ClassName Win32_ComputerSystem

# Only act if the computer is part of a domain
if ($copmutersystem.PartOfDomain) {
    # Get the central configuration file with the modules that should be installed
    $centralPSConfig = Get-Content "\\psrepo.$($copmutersystem.Domain)\PowerShell\PSRepo_Config\Repository.json" -ErrorAction SilentlyContinue | ConvertFrom-Json

    # Only act if the configuration file actually was loaded
    if ($centralPSConfig) {
        # As a default, we assume there is no need to register the internal repository
        $registerInternalRepo = $false

        # Get the values from the configuration file
        $internalRepoName = $centralPSConfig.Name
        $sourceLocation = $centralPSConfig.SourceLocation
        $scriptSourceLocation = $centralPSConfig.ScriptSourceLocation
        $InstallationPolicy = if ($centralPSConfig.Trusted -eq $true) { "Trusted" } else { "Untrusted" }

        if (-not (Get-Item "$($home)\AppData\Local\Microsoft\Windows\PowerShell\PowerShellGet\PSRepositories.xml" -ErrorAction SilentlyContinue)) {
            # If no there is no PSRepository.xml, we need to register the internal repository
            $registerInternalRepo = $true
        } else {
            # If there is a PSRepository.xml, we need to check if the internal repository is already registered
            $existingRepoConfig = Import-Clixml "$($home)\AppData\Local\Microsoft\Windows\PowerShell\PowerShellGet\PSRepositories.xml" -ErrorAction SilentlyContinue


            if ($existingRepoConfig[$internalRepoName]) {
                # If the internal repository is registered, we need to check if the values are the same

                if (
                    ($existingRepoConfig[$internalRepoName].ScriptSourceLocation -ne $scriptSourceLocation) -and
                    ($existingRepoConfig[$internalRepoName].SourceLocation -ne $sourceLocation) -and
                    ($existingRepoConfig[$internalRepoName].InstallationPolicy -ne $InstallationPolicy)
                ) {
                    # If the values are not the same, we need to register the internal repository
                    $registerInternalRepo = $true
                }

            } else {
                # If the internal repository is not registered, we need to register it
                $registerInternalRepo = $true
            }
        }

        # If the internal repository needs to be registered,
        if ($registerInternalRepo -eq $true) {
            # Unregister existing repositories for PSResourceGetV2
            Get-PSRepository -ErrorAction SilentlyContinue -WarningAction SilentlyContinue | Unregister-PSRepository

            # Register internal repository for PSResourceGetV2
            Register-PSRepository -Name $internalRepoName -SourceLocation $sourceLocation -ScriptSourceLocation $scriptSourceLocation -InstallationPolicy $InstallationPolicy

            # When PSResourceGetV3 do the same un- & reregistering
            if (Get-Command "Get-PSResource" -Module "Microsoft.PowerShell.PSResourceGet" -ErrorAction SilentlyContinue) {
                Get-PSResourceRepository -ErrorAction SilentlyContinue | Unregister-PSResourceRepository -Confirm:$false

                if ($InstallationPolicy -eq "Trusted") {
                    Register-PSResourceRepository -Name $internalRepoName -Trusted -Uri $sourceLocation
                } else {
                    Register-PSResourceRepository -Name $internalRepoName -Uri $sourceLocation
                }
            }
        }
    }
}

#endregion Custom internal PowerShell Gallery
