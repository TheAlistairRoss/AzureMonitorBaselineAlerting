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
Write-Verbose "`n`n`n## DeployAzMetricsAlert Start ##################################################################`n"

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
    $oVerboseString = "Deploying Metrics for Resource type '$oResourceTypeUnique'"
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

foreach ($oResource in $Resources)
{
    $oParamsFile = Get-Content -Path $oTemplateParametersFileName | ConvertFrom-Json -AsHashtable
    $oParamsFile.parameters.resourceId.value = $oResource.ResourceId

    $oDateTime = Get-Date -Format "yyyyMMddhhmmss"
    $oDeploymentName = "Metric_alerts-$oDateTime"

    # Compile the arguments to a hashtable
    $HashArguments = @{
        Name                    = $oDeploymentName
        ResourceGroupName       = $ResourceGroup.ResourceGroupName
        TemplateFile            = $oTemplateFileName 
        TemplateParameterObject = $oParamsFile.parameters
    }

    $oParamsFileKeys = $oParamsFile.parameters.keys -split "`n"

    foreach ($oKey in $oParamsFileKeys)
    {
        $HashArguments.Add($oKey, $oParamsFile.parameters.$oKey.value)
    }

    if ($DebugPreference -notlike "SilentlyContinue")
    {
        $oTemplate = Get-Content -Path $oTemplateFileName -Raw
        $oParametersFinal = $oParamsFile | ConvertTo-Json

        Write-Debug "`n## Template File ####################################################################`n"
        Write-Debug $oTemplate
        Write-Debug "`n## Parameters File ##################################################################`n"
        Write-Debug $oParametersFinal
    }
    $oHostString = "Deploying Metrics Alerts for $($oResource.ResourceId)" 
    Write-Host $oHostString -ForegroundColor Magenta
    New-AzResourceGroupDeployment @HashArguments
}

Write-Verbose "`n`n`n## DeployAzMetricsAlert End ##################################################################`n"