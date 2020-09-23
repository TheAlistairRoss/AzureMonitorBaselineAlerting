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



# Validate Template Files
$oTemplateFileName = "$PSScriptRoot/azure-deploy.json"
$oTemplateParametersFileName = "$PSScriptRoot/azure-deploy.parameters.json"

@($oTemplateFileName , $oTemplateParametersFileName) | ForEach-Object {
    If ((Test-Path -Path $_) -eq $false)
    {
        Write-Error "File '$_' not found. Ensure valid template and params file are created and rerun script"
        Break
    }
    else
    {
        Write-Verbose "Path '$_' found"
    }
}
#Validate only one Resource Type

$oResourceTypeUnqiue = $Resources | Select-Object -Property ResourceType -Unique
if ($oResourceTypeUnique.count -gt 1 )
{
    Write-Error -Message "More than 1 Resource Type specified, only pass one resource type to this function"
    $oResourceTypeUnqiue | ForEach-Object { Write-Error -Message "$_" } 
    break
}
else
{
    Write-Verbose "Deploying Multi Resource Metrics for Resource type $oResourceTypeUnique"
}


# Build the subscription scope
$oSubscriptionScope = "/subscriptions/$($subscription.Id)"
Write-Verbose "Scope set to Subscription '$oSubscriptionScope $($Subscription.Name)"

Write-Verbose "Resource Group Deployment to '$($ResourceGroup.ResourceGroupName)'"

# Get Resources Unique Locations
$oResourceLocations = @()
$Resources.Location | Select-Object -Unique | ForEach-Object { $oResourceLocations += $_ }
Write-Verbose "$($oResourceLocations.count) unique locations for resource type found"
If ($VerbosePreference -notlike "SilentlyContinue")
{
    $oResourceLocations
}

$oParamsFile = Get-Content -Path $oTemplateParametersFileName | ConvertFrom-Json -AsHashtable
$oparamsFile.parameters.locations.value = $oResourceLocations 
$oParamsFile.parameters.multiResourceMetricAlertScope.value = $oSubscriptionScope


$dateTime = Get-Date -Format "yyyyMMddhhmmss"
$deploymentName = "multiResourceMetric_alerts-$dateTime"

# Compile the arguments to a hashtable
$HashArguments = @{
    Name                    = $deploymentName
    ResourceGroupName       = $ResourceGroup.ResourceGroupName
    TemplateFile            = $oTemplateFileName 
    TemplateParameterObject = $oParamsFile.parameters
}

$oParamsFileKeys = $oParamsFile.parameters.keys -split "`n"

Foreach ($oKey in $oParamsFileKeys)
{
    $HashArguments.Add($oKey, $oParamsFile.parameters.$oKey.value)
}

If ($VerbosePreference -notlike "SilentlyContinue")
{
    $oTemplate = Get-Content -Path $oTemplateFileName -Raw
    $oParametersFinal = $oParamsFile | ConvertTo-Json

    Write-Verbose "`n## Template File ####################################################################`n"
    Write-Verbose $oTemplate
    Write-Verbose "`n## Parameters File ##################################################################`n"
    Write-Verbose $oParametersFinal
}

Write-Host "Deploying Multi Resource Metrics to Scope '$oSubscriptionScope'" -Foregroundcolor Magenta
New-AzResourceGroupDeployment @HashArguments

Write-Verbose "`n`n`n## DeployAzMultiResourceMetrics End ##################################################################`n"
