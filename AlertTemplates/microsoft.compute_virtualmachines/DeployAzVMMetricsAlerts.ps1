[CmdletBinding()]
param (
    [Microsoft.Azure.Commands.ResourceManager.Cmdlets.SdkModels.PSResource[]]
    $virtualMachines,

    [string]
    $multiResourceMetricScope,

    [string]
    $resourceGroupName

)

# Validate the input
if ($virtualMachines){
    $oVirtualMachines = $virtualMachines | Where-Object ResourceType -Like "Microsoft.Compute/virtualMachines"
    if ($oVirtualMachines.count -lt 1){
        Write-Error -Message "No Virtual Machines found" -RecommendedAction Stop
        Exit
    }
}   
Write-Information "$($oVirtualMachines.count) Virtual Machines found"


# Get Virtual Machines
$oVirtualMachinesLocations = @()
$oVirtualMachines.Location | Select-Object -Unique | Foreach-Object {$oVirtualMachinesLocations += $_}
Write-Information "$($oVirtualMachinesLocations.count) unique locations for Virtual Machines found"
$oVirtualMachinesLocations

# Multi Resource Metrics
# These should have 1 standard alert per region. Need to build some validation to identify whether a deployment is needed

$oParamsFile = Get-Content -Path "microsoft.compute_virtualmachines_baseline_alerts_azure-deploy.parameters.json" | ConvertFrom-Json -Depth 10
$oparamsFile.parameters.locations.value = $oVirtualMachinesLocations 
$oParamsFile.parameters.multiResourceMetricAlertScope.value = $multiResourceMetricScope

# Export the converted Parameters file, otherwise the Powershell script needs to declare each parameter
$oParamsFile | ConvertTo-Json -Depth 10 -EnumsAsStrings | Out-File -FilePath "microsoft.compute_virtualmachines_baseline_alerts_azure-deploy.parameters.json"

$dateTime = Get-Date -Format "yyyyMMddhhmmss"
$deploymentName = "microsoft.compute_virtualmachines_baseline_alerts_azure-deploy-$dateTime"

# Compile the arguments to a hashtable
$HashArguments = @{
    Name                  = $deploymentName
    ResourceGroupName     = $resourceGroupName 
    TemplateFile          = "microsoft.compute_virtualmachines_baseline_alerts_azure-deploy.json" 
    TemplateParameterFile = "microsoft.compute_virtualmachines_baseline_alerts_azure-deploy.parameters.json"
}

# Deploy
Write-Information "Deploying Virtual Machine Metrics Template"
New-AzResourceGroupDeployment @HashArguments
