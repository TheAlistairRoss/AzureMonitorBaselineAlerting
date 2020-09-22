# AzureMonitorBaselineAlerting

Deploys Baseline alerts for Azure Resources

## EXAMPLE
```
$Subscription = Get-AZSubscription | Select -first 1
$ResourceGroupName = "Contoso_Alerting_RG"
$ResourceGroupLocation = "uksouth"
.\DeployAzAlerts.ps1 -Subscription $Subscription -ResourceGroupName $ResourceGroupName -ResourceGroupLocation $ResourceGroupLocation 
```

