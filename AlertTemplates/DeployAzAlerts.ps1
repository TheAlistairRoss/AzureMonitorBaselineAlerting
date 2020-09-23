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
# Template directory hash. Only change this!
$oTemplatesHash = @{
    "Microsoft.Compute/virtualMachines" = @{
        "directory"  = "Microsoft.Compute_VirtualMachines"
        "scriptName" = "DeployAzVMAlerts.ps1"
        "pathTest"   = $false
    }
}

Write-Verbose "`n`n`n## DeployAzAlerts Start ##################################################################`n"

# Validate PowerShell
if ($PSVersionTable.PSVersion -lt $Version)
{
    Write-Error "PowerShell Version is '$($PSVersionTable.PSVersion)' and requires upgrading to Version 6"
    break
}
else
{
    Write-Verbose "PowerShell Version = $($PSVersionTable.PSVersion)"
}

# This needs to be update if automating with a service principal / app registration / managed identity
# Connect-AzAccount 

Foreach ($oTemplateResourceType in $oTemplatesHash.keys)
{
    $oPath = "$PSScriptRoot\$($oTemplatesHash.$oTemplateResourceType.directory)\$($oTemplatesHash.$oTemplateResourceType.scriptName)"
    If ((Test-Path -Path $oPath) -eq $false)
    {
        Write-Error "Path '$oPath' not found. Ensure valid template directory"
        $oTemplatesHash.$oTemplateResourceType.pathTest = $false
        Break
    }
    else
    {
        Write-Verbose "Path '$oTemplateResourceType' found. "
        $oTemplatesHash.$oTemplateResourceType.scriptName = $oPath
        $oTemplatesHash.$oTemplateResourceType.pathTest = $true
    }
}

Write-Verbose "Path test Results"
$oTemplatesHash | ConvertTo-Json -EnumsAsString | Write-Verbose 


# Subscription Check
if (!($Subscriptions))
{
    $oAllSubscriptions = Get-AzSubscription
    if ($oAllSubscriptions.count -eq 0 -or !($oAllSubscriptions))
    {
        Write-Error -Message "No Subscriptions found. Check Account Permissions"
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

Write-Verbose "Processing '$($oSubscriptions.count)' subscriptions"
$oSubscriptions | Out-String | Write-Verbose

foreach ($oSubscription in $oSubscriptions)
{
    $Context = Set-AzContext -Subscription $oSubscription 
    Write-Host "Context set to Subscription: $($oSubscription.Name) '$($oSubscription.Id)'" -ForegroundColor Magenta

    $Context | Out-String | Write-Verbose
        

    # Ensure the resource group exists, otherwise deploy it
    Try
    {
        $oResourceGroup = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction Stop
    }
    catch
    {
        Write-Host "Resource Group $ResourceGroupName does not exist. Creating Resource Group" -ForegroundColor Blue
    }
    if (!($oResourceGroup))
    {
        Write-Verbose "Creating Resource Group"
        Try
        {
            $oResourceGroup = New-AzResourceGroup -ResourceGroupName $ResourceGroupName -Location $ResourceGroupLocation -ErrorAction Stop
        }
        catch
        {
            $Error[0]
            Write-Error -Message "Failed to deploy Resource Group '$($ResourceGroupName)$($oSubscription.Id)$($oSubscription.Name))"
            break
        }
    }
    else
    {
        Write-Verbose "Resource Group Found"
        $oResourceGroup | Out-String | Write-Verbose
    }

    # Get All Resources in the subscription
    $oResources = Get-AzResource
    if ($VerbosePreference -notlike "SilentlyContinue")
    {
        Write-Verbose "'$($oResources.Count)' resources found"

        $oResources | Group-Object -Property Type | Sort-Object -Property Count -Descending | Select-Object -Property Name, Count | Format-Table -AutoSize | Out-String | Write-Verbose
    }
    
    foreach ($oResourceType in $oTemplatesHash.Keys)
    {
        Write-Host "Initialising Alert Deployment for Resource Type: '$oResourceType'" -ForegroundColor Magenta
        $oFilteredResources = $oResources | Where-Object ResourceType -Like $oResourceType
        if ($oFilteredResources)
        {
            Write-Verbose "'$($oFilteredResources.Count)$oResourceType' found"
            if ($oTemplatesHash.$oResourceType.pathTest -eq $true )
            {
                $oCommand = "$($oTemplatesHash.$oResourceType.scriptName)" 
                $oVerboseString = "Executing Script: $oCommand" + ' -Subscription $Subscription -ResourceGroup $oResourceGroup -Resources $oFilteredResources'
                Write-Verbose $oVerboseString

                & $oCommand -Subscription $Subscription -ResourceGroup $oResourceGroup -Resources $oFilteredResources 
            }
        }
        else
        {
            Write-Verbose "No Resources of Type '$oResourceType' found."
        }
    }
}

    Write-Verbose "`n`n`n## DeployAzAlerts End ##################################################################`n"
