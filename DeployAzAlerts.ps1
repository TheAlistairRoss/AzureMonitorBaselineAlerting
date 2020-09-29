<#
.SYNOPSIS
    Deploys Baseline alerts for Azure Resources
.DESCRIPTION
    Long description
.EXAMPLE
        $Subscription = Get-AZSubscription | Select -first 1
        $ResourceGroupName = "Contoso_Alerting_RG"
        $ResourceGroupLocation = "uksouth"
        .\DeployAzAlerts.ps1 -Subscription $Subscription -ResourceGroupName $ResourceGroupName -ResourceGroupLocation $ResourceGroupLocation
.INPUTS
    Inputs (if any)
.OUTPUTS
    Output (if any)
.NOTES
    General notes
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [Microsoft.Azure.Commands.Profile.Models.PSAzureSubscription[]]
    $Subscriptions,

    [Parameter(Mandatory = $true)]
    [string]
    $ResourceGroupName,

    [string]
    $ResourceGroupLocation

)

Write-Verbose "`n`n`n## DeployAzAlerts Start ##################################################################`n"

## Test each File Path
$oConfigFile = "DeployAzAlerts.config.json"
$oConfig = Get-Content $oConfigFile | ConvertFrom-Json -AsHashtable

Foreach ($oConfigResourceType in $oConfig.keys)
{
    foreach ($oScript in $oConfig.$oConfigResourceType.scripts)
    {
        $oPath = "$PSScriptRoot\$($oConfig.$oConfigResourceType.resourceScriptdirectory)\$($oConfig.$oConfigResourceType.resourceScriptDirectory)\$($oScript.directory)\$($oScript.scriptName)"
        If ((Test-Path -Path $oPath) -eq $false)
        {
            $oErrorString = "Path '$oPath' not found. Ensure valid template directory." 
            Write-Error -Message $oErrorString
            $oScript.pathTest = $false
        }
        else
        {
            $oVerboseString = "Path '$oPath' found." 
            Write-Verbose $oVerboseString
            $oScript.scriptName = $oPath
            $oScript.pathTest = $true
        }
    }
}
$oVerboseString = "Path Test Results"
Write-Verbose $oVerboseString
$oConfig | ConvertTo-Json -EnumsAsString | Write-Verbose 


# Validate PowerShell
if ($PSVersionTable.PSVersion -lt $Version)
{
    $oErrorString = "PowerShell Version is '$($PSVersionTable.PSVersion)' and requires upgrading to Version 6"
    Write-Error -Message $oErrorString
    Exit
}
else
{
    $oVerboseString = "PowerShell Version = $($PSVersionTable.PSVersion)"
    Write-Verbose $oVerboseString
}

# This needs to be update if automating with a service principal / app registration / managed identity
# Connect-AzAccount 


# Subscription Check
if (!($Subscriptions))
{
    $oAllSubscriptions = Get-AzSubscription
    if ($oAllSubscriptions.count -eq 0 -or !($oAllSubscriptions))
    {
        $oErrorString = "No Subscriptions found. Check Account Permissions"
        Write-Error -Message $oErrorString
        exit
    }
    else
    {
        $oSubscriptions = $oAllSubscriptions
    }
}
else
{
    $oSubscriptions = $Subscriptions
}

$oVerboseString = "Processing '$($oSubscriptions.count)' subscriptions"
Write-Verbose $oVerboseString 
$oSubscriptions | Out-String | Write-Verbose

foreach ($oSubscription in $oSubscriptions)
{
    $oHostString = "Setting Context to Subscription: $($oSubscription.Name) '$($oSubscription.Id)'"
    Write-Host $oHostString -ForegroundColor Magenta
    $Context = Set-AzContext -Subscription $oSubscription 
    $Context | Out-String | Write-Verbose
        

    # Ensure the resource group exists, otherwise deploy it
    Try
    {
        $oResourceGroup = Get-AzResourceGroup $ResourceGroupName -ErrorAction Stop
    }
    catch
    {
        $oHostString = "Resource Group '$ResourceGroupName' not found. Creating Resource Group"
        Write-Host $oHostString -ForegroundColor Blue
    }
    if (!($oResourceGroup))
    {
        $oVerboseString = "Creating Resource Group"
        Write-Verbose $oVerboseString
        Try
        {
            $oResourceGroup = New-AzResourceGroup -ResourceGroupName $ResourceGroupName -Location $ResourceGroupLocation -ErrorAction Stop
        }
        catch
        {
            Write-Error $Error[0]
            $oErrorString = "Failed to deploy Resource Group '$($ResourceGroupName)$($oSubscription.Id)$($oSubscription.Name))"
            Write-Error -Message $oErrorString
            Break
        }
    }
    else
    {
        $oVerboseString = "Resource Group Found"
        Write-Verbose $oVerboseString
        $oResourceGroup | Out-String | Write-Verbose
    }

    # Get All Resources in the subscription
    $oResources = Get-AzResource
    if ($VerbosePreference -notlike "SilentlyContinue")
    {
        $oVerboseString = "'$($oResources.Count)' resources found"
        Write-Verbose $oVerboseString
        $oResources | Group-Object -Property Type | Sort-Object -Property Count -Descending | Select-Object -Property Name, Count | Format-Table -AutoSize | Out-String | Write-Verbose
    }
    
    foreach ($oResourceType in $oConfig.Keys)
    {
        $oHostString = "Initialising Alert Deployment for Resource Type: '$oResourceType'"
        Write-Host $oHostString -ForegroundColor Magenta
        $oFilteredResources = $oResources | Where-Object -Property ResourceType -Like -Value $oResourceType
        if ($oFilteredResources)
        {
            $oVerboseString = "'$($oFilteredResources.Count)' of Resource Type '$oResourceType' found"
            Write-Verbose $oVerboseString

            foreach ($oScript in $oConfig.$oResourceType.scripts)
            {
                if ($oScript.pathTest -like $true)
                {
                    $oCommand = "$($oScript.scriptName)"

                    $oVerboseString = "Script: $oCommand -Subscription `$oSubscription -ResourceGroup `$oResourceGroup -Resources `$oFilteredResources"
                    Write-Verbose $oVerboseString

                    & $oCommand -Subscription $oSubscription -ResourceGroup $oResourceGroup -Resources $oFilteredResources 
                }
            }
        }
        else
        {
            $oHostString = "No Resources of Type '$oResourceType' found." 
            Write-Host $oHostString -ForegroundColor Blue
        }
    }
        
}

Write-Verbose "`n`n`n## DeployAzAlerts End ##################################################################`n"
