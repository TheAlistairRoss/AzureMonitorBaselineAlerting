[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [Microsoft.Azure.Commands.Profile.Models.PSAzureSubscription]
    $Subscription,

    [Parameter(Mandatory = $true)]
    [Microsoft.Azure.Commands.ResourceManager.Cmdlets.SdkModels.PSResourceGroup]
    $ResourceGroup,

    [Parameter(Mandatory = $true)]
    [Microsoft.Azure.Commands.ResourceManager.Cmdlets.SdkModels.PSResource[]]
    $Resources

)
Write-Verbose "`n`n`n## DeployAzMultiResourceMetrics Start ##################################################################`n"

## Validate Resources
$oVerboseString = "'$($Resources.Count)' of Resources"
Write-Verbose $oVerboseString
$oVerboseString = $Resources | Select-Object Name, ResourceType, ResourceGroupName | Out-String
Write-Verbose $oVerboseString

$oResourceTypeUnique = $Resource | Select-Object -Property ResourceType -Unique
if ($oResourceTypeUnique.count -gt 1 )
{
    $oResourceTypeUniqueString = $oResourceTypeUnique | Out-String
    $oErrorString = "More than 1 Resource Type specified, only pass one resource type to this function`n`n $oResourceTypeUniqueString"
    Write-Error -Message $oErrorString
    Exit
}
else
{
    $oVerboseString = "Deploying Multi Resource Metrics for Resource type '$oResourceTypeUnique'"
    Write-Verbose $oVerboseString
}

# Validate Template Files
$oTemplateFileName = "$PSScriptRoot\azure-deploy.json"
$oTemplateParametersFileName = "$PSScriptRoot\azure-deploy.parameters.json"

@($oTemplateFileName , $oTemplateParametersFileName) | ForEach-Object {
    If ((Test-Path -Path $_) -eq $false)
    {
        Write-Error "File '$_' not found. Ensure valid template and params file are created and rerun script"
        Exit
    }
    else
    {
        $oVerboseString = "Path '$_' found"
        Write-Verbose $oVerboseString
    }
}


# Build the subscription scope
$oSubscriptionScope = "/subscriptions/$($subscription.Id)"
$oVerboseString = "Scope set to Subscription '$oSubscriptionScope $($Subscription.Name)"
Write-Verbose $oVerboseString
$oVerboseString = "Resource Group Deployment to '$($ResourceGroup.ResourceGroupName)'"
Write-Verbose $oVerboseString

# Get Resources Unique Locations
$oResourceLocations = @()
$Resources.Location | Select-Object -Unique | ForEach-Object { $oResourceLocations += $_ }
$oVerboseString = "'$($oResourceLocations.count)' unique locations for resource type found"
Write-Verbose $oVerboseString
$oResourceLocations |out-string |Write-Verbose

$oParamsFile = Get-Content -Path $oTemplateParametersFileName | ConvertFrom-Json -AsHashtable
$oparamsFile.parameters.locations.value = $oResourceLocations 
$oParamsFile.parameters.multiResourceMetricAlertScope.value = $oSubscriptionScope

$oDateTime = Get-Date -Format "yyyyMMddhhmmss"
$oDeploymentName = "multiResourceMetric_alerts-$oDateTime"

# Compile the arguments to a hashtable
$HashArguments = @{
    Name                    = $oDeploymentName
    ResourceGroupName       = $ResourceGroup.ResourceGroupName
    TemplateFile            = $oTemplateFileName 
    TemplateParameterObject = $oParamsFile.parameters
}

$oParamsFileKeys = $oParamsFile.parameters.keys -split "`n"

Foreach ($oKey in $oParamsFileKeys)
{
    $HashArguments.Add($oKey, $oParamsFile.parameters.$oKey.value)
}

If ($DebugPreference -notlike "SilentlyContinue")
{
    $oTemplate = Get-Content -Path $oTemplateFileName -Raw
    $oParametersFinal = $oParamsFile | ConvertTo-Json

    Write-Debug "`n## Template File ####################################################################`n"
    Write-Debug $oTemplate
    Write-Debug "`n## Parameters File ##################################################################`n"
    Write-Debug $oParametersFinal
}

$oHostString = "Deploying Multi Resource Metrics to Scope '$oSubscriptionScope'" 
Write-Host $oHostString -Foregroundcolor Magenta
New-AzResourceGroupDeployment @HashArguments

Write-Verbose "`n`n`n## DeployAzMultiResourceMetrics End ##################################################################`n"
