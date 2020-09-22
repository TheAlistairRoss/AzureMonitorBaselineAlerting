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
        .\DeployAzVMMetricsAlerts.ps1 -Subscription $Subscription -Resource $ResourceGroup -VirtualMachines $VMs
.INPUTS
    Inputs (if any)
.OUTPUTS

.NOTES
    Developed by Alistair Ross [MSFT]
    
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [Microsoft.Azure.Commands.Profile.Models.PSAzureSubscription]
    $Subscription,
    [Parameter(Mandatory=$true)]
    [Microsoft.Azure.Commands.ResourceManager.Cmdlets.SdkModels.PSResourceGroup]
    $ResourceGroup,
    [Parameter(Mandatory=$true)]
    [Microsoft.Azure.Commands.ResourceManager.Cmdlets.SdkModels.PSResource[]]
    $VirtualMachines

)

$oTemplateFileName = "azure-deploy.json"
$oTemplateParametersFileName = "azure-deploy.parameters.json"

"$oTemplateFileName", "$oTemplateParametersFileName" | ForEach-Object {
    If ((Test-Path -Path $_) -eq $false)
    {
        Write-Error "Path '$_' not found. Ensure valid template and params file is in the same directory"
        Break
    }
}


# Validate the input
if ($VirtualMachines)
{
    $oVirtualMachines = $VirtualMachines | Where-Object ResourceType -Like "Microsoft.Compute/virtualMachines"
    if ($oVirtualMachines.count -lt 1)
    {
        Write-Error -Message "No Virtual Machines found" -RecommendedAction Stop
        Exit
    }
}   
Write-Verbose "$($oVirtualMachines.count) Virtual Machines found"

$oSubscriptionScope = "/subscriptions/$($subscription.Id)"
Write-Verbose "Scope set to Subscription '$oSubscriptionScope ' ($($Subscription.Name)"

Write-Verbose "Resource Group Deployment to '$($ResourceGroup.ResourceGroupName)'"


# Get Virtual Machines
$oVirtualMachinesLocations = @()
$oVirtualMachines.Location | Select-Object -Unique | ForEach-Object { $oVirtualMachinesLocations += $_ }
Write-Verbose "$($oVirtualMachinesLocations.count) unique locations for Virtual Machines found"
If ($VerbosePreference -notlike "SilentlyContinue")
{
    $oVirtualMachinesLocations
}

# Multi Resource Metrics
# Get the Params file and build

# New Dynamic test
$oParamsFile = Get-Content -Path $oTemplateParametersFileName | ConvertFrom-Json -Depth 10 -AsHashtable
$oparamsFile.parameters.locations.value = $oVirtualMachinesLocations 
$oParamsFile.parameters.multiResourceMetricAlertScope.value = $oSubscriptionScope


$dateTime = Get-Date -Format "yyyyMMddhhmmss"
$deploymentName = "microsoft.compute_virtualmachines_baseline_alerts-$dateTime"


# Compile the arguments to a hashtable
$HashArguments = @{
    Name                  = $deploymentName
    ResourceGroupName     = $ResourceGroup.ResourceGroupName
    TemplateFile          = $oTemplateFileName 
    TemplateParameterObject = $oParamsFile.parameters
}

$oParamsFileKeys = $oParamsFile.parameters.keys -split "`n"

Foreach ($oKey in $oParamsFileKeys){
        $HashArguments.Add($oKey, $oParamsFile.parameters.$oKey.value)
}

$oTemplate = Get-Content -Path $oTemplateFileName -Raw
$oParametersFinal = $oParamsFile |ConvertTo-Json

Write-Verbose "Template File`n"
Write-Verbose $oTemplate
Write-Verbose "`nParameters File`n"
Write-Verbose $oParametersFinal

New-AzResourceGroupDeployment @HashArguments


