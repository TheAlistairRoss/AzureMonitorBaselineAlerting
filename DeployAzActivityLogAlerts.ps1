[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [Microsoft.Azure.Commands.Profile.Models.PSAzureSubscription]
    $Subscription,

    [Parameter(Mandatory = $true)]
    [Microsoft.Azure.Commands.ResourceManager.Cmdlets.SdkModels.PSResourceGroup]
    $ResourceGroup,
<#
    [Parameter(Mandatory = $true)]
    [Microsoft.Azure.Commands.ResourceManager.Cmdlets.SdkModels.PSResource[]]
    $Resources,
#>
    [Parameter(Mandatory = $true)]
    [string]
    $ConfigDirectory

)
Write-Host "`n`n`n## DeployAzActivityLogAlert Start ##################################################################`n"

# Validate Directory
$oDirectoryTest = Test-Path -Path $ConfigDirectory
If ($oDirectoryTest -ne $true){
    $oErrorString = "Path: '$ConfigDirectory' not found. Exiting Script"
    Write-Error -Message $oErrorString
    exit
}
else {
    $oHostString = "Path: '$ConfigDirectory'  found."
    Write-Host $oHostString
}

<#
## Validate Resources
$oHostString = "'$($Resources.Count)' of Resources"
Write-Host $oHostString
$oHostString = $Resources | Select-Object Name, ResourceType, ResourceGroupName | Out-String
Write-Host $oHostString

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
    $oHostString = "Deploying Metrics for Resource type '$oResourceTypeUnique'"
    Write-Host $oHostString
}
#>

# Validate Template Files
$oTemplateFileName = "$ConfigDirectory\azure-deploy.json"
$oTemplateParametersFileName = "$ConfigDirectory\azure-deploy.parameters.json"

@($oTemplateFileName , $oTemplateParametersFileName) | ForEach-Object {
    If ((Test-Path -Path $_) -eq $false)
    {
        Write-Error "File '$_' not found. Ensure valid template and params file are created and rerun script"
        Exit
    }
    else
    {
        $oHostString = "Path '$_' found"
        Write-Host $oHostString
    }
}

<#
# Build the subscription scope
$oSubscriptionScope = "/subscriptions/$($subscription.Id)"
$oHostString = "Scope set to Subscription '$oSubscriptionScope $($Subscription.Name)"
Write-Host $oHostString
$oHostString = "Resource Group Deployment to '$($ResourceGroup.ResourceGroupName)'"
Write-Host $oHostString

$oResourceIdsArray = @()
foreach ($oResource in $Resources)
{
    $oResourceIdsArray += $oResource.Id
}
#>

$oParamsFile = Get-Content -Path $oTemplateParametersFileName | ConvertFrom-Json -AsHashtable
#$oParamsFile.parameters.resourceIds.value = $oResourceIdsArray

$oDateTime = Get-Date -Format "yyyyMMddhhmmss"
$oDeploymentName = "Activity_Log_alerts-$oDateTime"

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

if ($VerbosePreference -notlike "SilentlyContinue")
{
    $oTemplate = Get-Content -Path $oTemplateFileName -Raw
    $oParametersFinal = $oParamsFile | ConvertTo-Json

    Write-Verbose "`n## Template File ####################################################################`n"
    Write-Verbose $oTemplate
    Write-Verbose "`n## Parameters File ##################################################################`n"
    Write-Verbose $oParametersFinal
}
$oHostString = "Deploying Activity Log Alerts for Resource Type '$($oResourceTypeUnique)'" 
Write-Host $oHostString -ForegroundColor Magenta
New-AzResourceGroupDeployment @HashArguments


Write-Host "`n`n`n## DeployAzActivityLogAlert End ##################################################################`n"