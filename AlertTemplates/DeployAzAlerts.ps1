[CmdletBinding()]
param (
    [string]
    $subscriptions,

    [string]
    $resourceGroupName,

    [string]
    $resourceGroupLocation
)

# This needs to be update if automating with a service principal / app registration / managed identity
# Connect-AzAccount 

# Root Path
$oTemplateRootPath = Get-Location

# Subscription Check
$oAllSubscriptions = Get-AzSubscription
if ($oAllSubscriptions.count -eq 0 -or !($oAllSubscriptions))
{
    Write-Error -Message "No Subscriptions found. Check Account Permissions"
    exit
}

if ($subscriptions)
{
    $oSubscriptionsFilter = $subscriptions.Split(",") | ForEach-Object { $_.Trim() }
    $oSubscriptions = $oAllSubscriptions | Where-Object { $_.Id.ToString() -In $oSubscriptionsFilter }
    if ($oSubscriptions.count -lt 1)
    {
        Write-Error -Message "No Subscriptions filtered from the input parameters.`n'$subscriptions'"
    }
    else
    {
        Write-Verbose "$($oSubscriptions.count) subscription(s) found"
    }
}
else
{
    $oSubscriptions = $oAllSubscriptions
}
If ($VerbosePreference -notlike "SilentlyContinue")
{
    $oSubscriptions
}
foreach ($oSubscription in $oSubscriptions)
{
    Set-AzContext -Subscription $oSubscription 
    
    $oSubscriptionScope = "/subscriptions/$($oSubscription.Id)"

    # Ensure the resource group exists, otherwise deploy it
    $oResourceGroup = Get-AzResourceGroup -Name $resourceGroupName
    if (!($oResourceGroup))
    {
        Write-Verbose "Creating Resource Group"
        Try
        {
            New-AzResourceGroup -ResourceGroupName $resourceGroupName -Location $resourceGroupLocation -OutVariable $oResourceGroup -ErrorAction Stop
        }
        catch
        {
            $Error[0]
            Write-Error -Message "Failed to deploy Resource Group '$($resourceGroupName)$($oSubscription.Id)"
            Break
        }
    }
    else
    {
        Write-Verbose "Resource Group Found"
        If ($VerbosePreference -notlike "SilentlyContinue")
        {

            $oResourceGroup
        }
        $resourceGroupLocation = $oResourceGroup.Location
    }

    # Get All Resources in the subscription
    $oResources = Get-AzResource

    
    <# Need to have a think about the logic as a central workspace will hold all the alerts.
    # Workspace Deployments
    $oWorkspaces = $oResources | Where-Object -Property type -Like "Microsoft.OperationalInsights/workspaces"
    if ($oWorkspaces)
    {
        foreach ($oWorkspace in $oWorkspaces)
        {
            $i = 1
            $oParams = @{
                "workspaceId"       = $oWorkspace.Id
                "workspaceLocation" = $oWorkspace.Location
            }

            New-AzResourceGroupDeployment -ResourceGroupName $oResourceGroup.ResourceGroupName `
                -TemplateFile "$($oPath)\Workspaces\azuredeploy.json" `
                -TemplateParameterObject $oParams
            $i++
        }
    }

    # Log Alerts - To be deployed to the same location as a workspace
    #>
    # Virtual Machines
    $oVirtualMachines = $oResources | Where-Object ResourceType -Like "Microsoft.Compute/virtualMachines"
        
    if ($oVirtualMachines)
    {
        $oVMPath = "$oTemplateRootPath\microsoft.compute_virtualmachines"
        Set-Location $oVMPath

        $DeployAzVMMetricsAlertsHashArguments = @{
            virtualMachines          = $oVirtualMachines
            multiResourceMetricScope = $oSubscriptionScope
            resourceGroupName        = $oResourceGroup.ResourceGroupName
        }      
        .\DeployAzVMMetricsAlerts.ps1 @DeployAzVMMetricsAlertsHashArguments
    }
    Set-Location $oTemplateRootPath


}




