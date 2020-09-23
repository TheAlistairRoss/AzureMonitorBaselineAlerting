<#
.SYNOPSIS
    Deploys multi-resource metrics alerts for Microsoft.Compute/virtualMachines
.DESCRIPTION
    This script receives Virtual Machines as a parameter input (from Get-AZResource | Where-Object ResourceType -Like "Microsoft.Compute/virtualMachines".
    It then identifies the unique location for all virtual machines in the scope and updates the locations parameter in the ARM template parameters file with the locations as an array

    It also takes the subscription Id and applies that as the Mutli-Resource Metric scope

    This requires the file azure-deploy.json and azure-deploy_parameters.json. This script only updates the parameters "multiResourceMetricAlertScope (string)" and "locations (array)"
.EXAMPLE
    PS C:\> 
        $Subscription = Get-AZSubscription | Select -first 1
        $ResourceGroup = Get-AZResourceGroup -Name "Contoso_Alerting_RG"
        $VMs = Get-AzResource | Where-Object ResourceType -Like "Microsoft.Compute/virtualMachines"
        .\DeployAzVMMetricsAlerts.ps1 -Subscription $Subscription -Resource $ResourceGroup -Resources $VMs
.INPUTS
    Inputs (if any)
.OUTPUTS

.NOTES
    Developed by Alistair Ross [MSFT]
    
#>

[CmdletBinding()]
param (
    # Azure Subscription. Example: Get-AzSubscription |Select -First 1
    [Parameter(Mandatory = $true)]
    [Microsoft.Azure.Commands.Profile.Models.PSAzureSubscription]
    $Subscription,
    [Parameter(Mandatory = $true)]

    # Azure Resource Group. Example: Get-AzResourceGroup -Name "ContosoRG"
    [Microsoft.Azure.Commands.ResourceManager.Cmdlets.SdkModels.PSResourceGroup]
    $ResourceGroup,

    # Azure Resource. Example: Get-AzResource | Where ResourceType -like "Microsoft.Compute/virtualMachines"
    [Parameter(Mandatory = $true)]
    [Microsoft.Azure.Commands.ResourceManager.Cmdlets.SdkModels.PSResource[]]
    $Resources
)

$oResourceTypeString = "Microsoft.Compute/virtualMachines"
$oResourceDisplayName = "Azure Virtual Machines"
$oScriptName = "DeployAzVMAlerts"

# Template directory hash.
# Need to collect this from a config file
$oTemplatesHash = @{
    "multiResourceMetrics" = @{
        "scriptName" = "DeployAzMultiResourceMetrics.ps1"
        "pathTest"   = $false
    }
    "metrics"              = @{
        "scriptName" = "DeployAzMetricsAlerts.ps1"
        "pathTest"   = $false
    } 
}


################################# Do not configure below this line ###################################################

Write-Verbose "`n`n`n######### $oScriptName Start ##################################################################`n"

Foreach ($oTemplateDirectory in $oTemplatesHash.keys)
{
    $oPath = "$PSScriptRoot\$oTemplateDirectory\$($oTemplatesHash.$oTemplateDirectory.scriptName)"
    If ((Test-Path -Path $oPath) -eq $false)
    {
        Write-Warning "Path '$oPath' not found. Ensure valid template directory and script name is provided and rerun" 
        $oTemplatesHash.$oTemplateDirectory.scriptName = $oPath
        $oTemplatesHash.$oTemplateDirectory.pathTest = $false
        Break
    }
    else
    {
        Write-Verbose "Path '$oPath' found. "
        $oTemplatesHash.$oTemplateDirectory.scriptName = $oPath
        $oTemplatesHash.$oTemplateDirectory.pathTest = $true
    }
}

# Validate the input
if ($Resources)
{
    $oResources = $Resources | Where-Object ResourceType -Like $oResourceTypeString
    if ($oResources.count -lt 1)
    {
        $oErrorString = "No $oResourceDisplayName found"
        Write-Error -Message $oErrorString -RecommendedAction Stop
        Exit
    }
}   
Write-Verbose "$($oResources.count)$oResourceDisplayName found"

foreach ($oTemplateDirectory in $oTemplatesHash.keys)
{
    if ($VerbosePreference -notlike "SilentlyContinue")
    {
        $oTemplatesHash.$oTemplateDirectory | Out-String | Write-Verbose
    }
    if ($oTemplatesHash.$oTemplateDirectory.pathTest -eq $true)
    {
        $oCommand = "$($oTemplatesHash.$oTemplateDirectory.scriptName)"
        $oVerboseString = "Executing Script: $oCommand" + ' -Subscription $Subscription -ResourceGroup $oResourceGroup -Resources $oFilteredResources'
        Write-Verbose $oVerboseString

        & $oCommand -Subscription $Subscription -ResourceGroup $ResourceGroup -Resources $oResources

    }
    else
    {
        Write-Warning "Path: "
    }
}

Write-Verbose "`n`n`n######### $oScriptName End ##################################################################`n"


