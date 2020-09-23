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

$oResourceTypeUnqiue = $Resource | Select-Object -Property ResourceType -Unique
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

## Write-Verbose "Resource Group Deployment to '$($ResourceGroup.ResourceGroupName)'"

foreach ($oResource in $oResources)
{

    $oParamsFile = Get-Content -Path $oTemplateParametersFileName | ConvertFrom-Json -AsHashtable
    $oparamsFile.parameters.resourceId.value = $oResource.ResourceId

    $dateTime = Get-Date -Format "yyyyMMddhhmmss"
    $deploymentName = "Metric_alerts-$dateTime"

    # Compile the arguments to a hashtable
    $HashArguments = @{
        Name                    = $deploymentName
        ResourceGroupName       = $ResourceGroup.ResourceGroupName
        TemplateFile            = $oTemplateFileName 
        TemplateParameterObject = $oParamsFile.parameters
    }

    $oParamsFileKeys = $oParamsFile.parameters.keys -split "`n"

    foreach ($oKey in $oParamsFileKeys)
    {
        $HashArguments.Add($oKey, $oParamsFile.parameters.$oKey.value)
    }

    if ($VerbosePreference -notlike "SilentlyContinue")
    {
        $oTemplate = Get-Content -Path $oTemplateFileName -Raw
        $oParametersFinal = $oParamsFile | ConvertTo-Json

        Write-Verbose "`n## Template File ####################################################################`n"
        Write-Verbose $oTemplate
        Write-Verbose "`n## Parameters File ##################################################################`n"
        Write-Verbose $oParametersFinal
    }
    Write-Host "Deploying Metrics Alerts for $($oResource.ResourceId)" -ForegroundColor Magenta
    New-AzResourceGroupDeployment @HashArguments
}

Write-Verbose "`n`n`n## DeployAzMetricsAlert End ##################################################################`n"