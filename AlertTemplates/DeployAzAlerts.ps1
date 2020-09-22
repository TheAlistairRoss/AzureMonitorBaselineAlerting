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

# Validate PowerShell
if ($PSVersionTable.PSVersion -lt $Version){
        Write-Error "PowerShell Version is '$($PSVersionTable.PSVersion)' and requires upgrading to Version 6"
        break
}else {
    Write-Verbose "PowerShell Version = $($PSVersionTable.PSVersion)"
}

# This needs to be update if automating with a service principal / app registration / managed identity
# Connect-AzAccount 

# Root Path
$oTemplateRootPath = Get-Location

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

if ($VerbosePreference -notlike "SilentlyContinue")
{
    $oSubscriptions
}

foreach ($oSubscription in $oSubscriptions)
{
    Set-AzContext -Subscription $oSubscription 
    

    # Ensure the resource group exists, otherwise deploy it
    Try{
        $oResourceGroup = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction Stop
    }
    catch{
        Write-Verbose "Resource Group $ResourceGroupName does not exist. Creating Resource Group"
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
        if ($VerbosePreference -notlike "SilentlyContinue")
        {
            $oResourceGroup
        }
    }

    # Get All Resources in the subscription
    $oResources = Get-AzResource
    if ($VerbosePreference -notlike "SilentlyContinue")
    {
        Write-Verbose "'$($Resource.Count)' resources found"

        $oResources | Group-Object -Property Type | Sort-Object -Property Count -Descending | Select-Object -Property Name,Count | Format-table -autosize
    }

    
   # Virtual Machine Metric Alerts ######################### 
   
    $oVirtualMachines = $oResources | Where-Object ResourceType -Like "Microsoft.Compute/virtualMachines"
        
    if ($oVirtualMachines)
    {
        $oVMPath = "$oTemplateRootPath\microsoft.compute_virtualmachines"
        Try
        {
            Set-Location $oVMPath -ErrorAction Stop
        }
        catch
        {
            Write-Error $Error[0]
            Write-Error -Message "Failed to set the location for virtual machines, ensure directoy and templates exsit"
            break
        }

        $DeployAzVMMetricsAlertsHashArguments = @{
            VirtualMachines = $oVirtualMachines
            Subscription    = $oSubscription
            ResourceGroup   = $oResourceGroup
        }      
        .\DeployAzVMMetricsAlerts.ps1 @DeployAzVMMetricsAlertsHashArguments
    }

    # Log Alerts
    Set-Location $oTemplateRootPath

}




