<#
    .SYNOPSIS
        A DSC configuration file for clean up resources

    .DESCRIPTION
        This script will be run on the management VM.
#>

param
(    
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $dscPath,  

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $subscriptionId,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $serviceObjectsRgName,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $computeObjectsRgName,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $storageObjectsRgName,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $networkObjectsRgName,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $monitoringObjectsRgName,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $azureCloudEnvironment,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $managementVmName
)


Configuration temResourcesCleanUp
{
    param
    (    
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $dscPath,  
    
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $subscriptionId,
    
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $serviceObjectsRgName,
    
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $computeObjectsRgName,
    
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $storageObjectsRgName,
    
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $networkObjectsRgName,
    
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $monitoringObjectsRgName,
    
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $azureCloudEnvironment,
    
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $managementVmName
    )
    
    # Import the module that contains the File resource.
    Import-DscResource -ModuleName PsDesiredStateConfiguration

    $ErrorActionPreference = 'Stop'
    
    $ScriptPath = [system.io.path]::GetDirectoryName($PSCommandPath)
    . (Join-Path $ScriptPath "logger.ps1")
    
    Node localhost
    {
        LocalConfigurationManager {
            RebootNodeIfNeeded = $true
            ConfigurationMode  = "ApplyOnly"
            DebugMode          = "All" 
        }

        Script DomainJoinStorage {
            # TestScript runs first and if it returns false, then SetScript runs
            GetScript            = {
                return @{'Result' = '' }
            }
            SetScript            = {
                . (Join-Path $using:ScriptPath "logger.ps1")
                try {
                    Write-Log "Cleaning up temporal deployment resources"
                    & "$using:ScriptPath\postDeploymentTempResourcesCleanUp.ps1" -StorageAccountName $Using:StorageAccountName -StorageAccountRG $Using:StorageAccountRG -SubscriptionId $Using:SubscriptionId -ClientId $Using:ClientId -ShareName $Using:ShareName -DomainName $Using:DomainName -IdentityServiceProvider $Using:IdentityServiceProvider -AzureCloudEnvironment $Using:AzureCloudEnvironment -CustomOuPath $Using:CustomOuPath -OUName $Using:OUName -CreateNewOU $Using:CreateNewOU -StoragePurpose $Using:StoragePurpose

                    Write-Log "Successfully domain joined and/or NTFS permission set on Storage account"
                }
                catch {
                    $ErrMsg = $PSItem | Format-List -Force | Out-String
                    Write-Log -Err $ErrMsg
                    throw [System.Exception]::new("Some error occurred in DSC DomainJoinStorage SetScript: $ErrMsg", $PSItem.Exception)
                }
            }
            TestScript           = {
                . (Join-Path $using:ScriptPath "Logger.ps1")

                try {
                    Write-Log "DSC DomainJoinStorage TestScript checking if storage account $Using:StorageAccountName is domain joined."
                    $ADModule = Get-Module -Name ActiveDirectory
                    if (-not $ADModule) {
                        return $False
                    }
                    else {
                        Import-Module activedirectory
                        $IsStorageAccountDomainJoined = Get-ADObject -Filter 'ObjectClass -eq "Computer"' | Where-Object { $_.Name -eq $Using:StorageAccountName }
                        if ($IsStorageAccountDomainJoined) {
                            Write-Log "Storage account $Using:StorageAccountName is already domain joined."
                            return $True
                        }
                        else {
                            Write-Log "Storage account $Using:StorageAccount is not domain joined."
                            return $False
                        }
                    }
                }
                catch {
                    $ErrMsg = $PSItem | Format-List -Force | Out-String
                    Write-Log -Err $ErrMsg
                    throw [System.Exception]::new("Some error occurred in DSC DomainJoinStorage TestScript: $ErrMsg", $PSItem.Exception)
                }
            }
		
            PsDscRunAsCredential = $DomainAdminCred
        }
    }
}

$config = @{
    AllNodes = @(
        @{
            NodeName                    = 'localhost';
            PSDscAllowPlainTextPassword = $true
            PsDscAllowDomainUser        = $true
        }
    )
}

DomainJoinFileShare -ConfigurationData $config -StorageAccountName $StorageAccountName -StorageAccountRG $StorageAccountRG -SubscriptionId $SubscriptionId -ShareName $ShareName -DomainName $DomainName -IdentityServiceProvider $IdentityServiceProvider -AzureCloudEnvironment $AzureCloudEnvironment -CustomOuPath $CustomOuPath -OUName $OUName -CreateNewOU $CreateNewOU -DomainAdminUserName $DomainAdminUserName -DomainAdminUserPassword $DomainAdminUserPassword -ClientId $ClientId -StoragePurpose $StoragePurpose -Verbose;