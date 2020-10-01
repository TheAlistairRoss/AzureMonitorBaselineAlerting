# Azure Monitor Baseline Alerts PowerShell Deployment

**Version 1**

This collection of PowerShell scripts are used to deploy ARM Templates dynamically, to provide a consitent set of Metric alerts across multiple Azure subscriptions for multiple resource types. This is achieved by looking up the resources in a given subscription, identifying the resources and deploying the ARM templates to a resource group, building each alert for each resource. 

## EXAMPLE
```PowerShell
$Subscription = Get-AZSubscription | Select -first 1
$ResourceGroupName = "Contoso_Alerting_RG"
$ResourceGroupLocation = "uksouth"

.\DeployAzAlerts.ps1 -Subscription $Subscription -ResourceGroupName $ResourceGroupName -ResourceGroupLocation $ResourceGroupLocation 
```
---
## Configuration Files

The [DeployAZAlerts.config.json](.\DeployAZAlerts.config.json) denotes the files structure for identifying the ARM templates for each resource type. For example:

```json
{
    "Microsoft.Compute/virtualMachines": {
        "resourceDisplayName": "Azure Virtual Machines",
        "resourceTemplateDirectory": "Microsoft.Compute_virtualMachines",
        "templateDirectories": [
            {
                "directory": "multiResourceMetrics"
            },
            {
                "directory": "metrics"
            }
        ]
    }
}
````
This file gives the following properties:

| Property | Description |
| ----------- | ----------- |
| Microsoft.Compute/virtualMachines (JSON Object) | This is the Resource type name. This is used for uniquely identifying which resources to filter by|
| resourceDisplayName | Friendly Name of the resource type. Used for Logging in the script only |
| resourceTemplateDirectory | Name of the directory that the templates reside in for the given resource type. In these examples, I have just replaced the forward slash "/" with an underscore "_" in the resource type name |
| templateDirectories | JSON array with multiple listed directories. The child objects must stay objects as additional properties are added during the script for runtime only|
| directory | The type of alerts to deploy "**metrics** or **multiResourceMetrics** only. If the resource type does not support multi resource metrics, omit this directory|<br>

<br>
<p> To add additional resources, copy the current object, and paste a second at the same level 

```json
{
    "Microsoft.Compute/virtualMachines": {
        "resourceDisplayName": "Azure Virtual Machines",
        "resourceTemplateDirectory": "Microsoft.Compute_virtualMachines",
        "templateDirectories": [
            {
                "directory": "multiResourceMetrics"
            },
            {
                "directory": "metrics"
            }
        ]
    },
    "Microsoft.KeyVault/vaults": {
        "resourceDisplayName": "Azure Key Vault",
        "resourceTemplateDirectory": "Microsoft.KeyVault_vaults",
        "templateDirectories": [
            {
                "directory": "metrics"
            }
        ]
    }
}
```
Ensure the directory structure matches the configuration file and the configuration file is at the root of the template directory structure. For Example:

## <p>Top Level Directory 
[![Root Directory](/README_Assets/RootDirectory_Image.png "Root Directory")](/README_Assets/RootDirectory_Image.png)

## <p>Resource TypeDirectory
[![Resource Type Directory](/README_Assets/ResourceDirectory_Image.png "Resource Type Directory")](/README_Assets/ResourceDirectory_Image.png )


---
## <p>ARM Templates

<p>All the alerts deployed are defined in Azure Resource Manager (ARM) templates. For full details of ARM templates visit [docs.microsoft.com](https://docs.microsoft.com/en-us/azure/azure-resource-manager/templates/overview)

Within each alert type folder, there should be two `.json` files called:
- azure-deploy.json
- azure-deploy.paramters.json

These files must be named exactly as shown

[![Alert Type Directory](/README_Assets/AlertTypeDirectory_Image.png "Alert Type Directory")](/README_Assets/AlertTypeDirectory_Image.png)

These are standard ARM templates, with the following specific requirements:

## Parameter Files
### Multi Resource Metrics

The Parameters **multiResourceMetricAlertScope** and **locations** are populated dynamically and must be named exactly as shown.

- **multiResourceMetricAlertScope** populates with a subscription scope for applying to the multi resource alerts
- **locations** populates with an array of unique locations where resources are deployed in the subscription. 1 alert per location will be created.

All other parameters relate to values applied to the alert types and can either be in the parameter file or in the template. My suggestion it to parameterise values that may change, such as frequency or thresholds.
 
```json
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "parameters": {
    "multiResourceMetricAlertScope": {
      "value": ""
    },
    "locations": {
      "value": []
    },
    "highProcessorUtilization_WindowSize": {
      "value": "PT15M"
    },
    "highProcessorUtilization_EvaluationFrequency": {
      "value": "PT15M"
    },
    "highProcessorUtilization_Threshold": {
      "value": 70
    },
    "highProcessorUtilization_alertSeverity": {
      "value": 3
    }
  },
  "contentVersion": "1.0.0.0"
}
``` 

### Metrics

The parameter **resourceIds** populates dynamically and must be exactly as shown. This populates with an array of resourceIds that metric alerts are applied

All other parameters relate to values applied to the alert types and can either be in the parameter file or in the template. My suggestion it to parameterise values that may change, such as frequency or thresholds.
 
```json
{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "resourceIds": {
            "value": []
        },
        "memoryAvaliableBytes_Threshold": {
            "value": "2147483648"
        },
        "memoryAvaliableBytes_WindowSize": {
            "value": "PT15M"
        },
        "memoryAvaliableBytes_EvaluationFrequency": {
            "value": "PT15M"
        },
        "memoryAvaliableBytes_alertSeverity": {
            "value": 3
        }
    }
}
``` 
## ARM Template File

For the ARM templates to deploy multiple alerts at scale, they utilise the copy function to iterate through the quantity and parameter that are needed to be applied. For more information on the copy function, check out https://docs.microsoft.com/en-us/azure/azure-resource-manager/templates/copy-resources

For the **multiResourceMetrics** this iterates through the number of locations
```json
    "variables": {
        "copy": [
            {
                "name": "locationCopy",
                "count": "[length(parameters('locations'))]",
                "input": "[parameters('locations')[copyIndex('locationCopy')]]"
            }
        ]
    },
```

The resource is also copied and uses the number of locations to determine how many times the resource should be deploy and with what settings.


```json
    "resources": [
//Multi-Resource Metric Alerts
        {
            "type": "microsoft.insights/metricAlerts",
            "apiVersion": "2018-03-01",
//copyIndex specified to iterate through the locations, giving the alert a unique name
            "name": "[concat(variables('highProcessorUtilization_Name'),'_',parameters('locations')[copyIndex(0)])]",
            
// Code omitted for clarity --------------------------------

//targetResourceRegion using the indexed array of copyIndex
                "targetResourceRegion": "[parameters('locations')[copyIndex(0)]]",
                "actions": [],
                "description": "[concat('High Processor Utilization has been detected. The average value has been higher than ', parameters('highProcessorUtilization_Threshold'),', for the specified period of time')]"
            },
// The copy of the resource. Specified by the number of locations
            "copy": {
                "name": "[concat(variables('highProcessorUtilization_Name'),'_Copy')]",
                "count": "[length(parameters('locations'))]"
            }
        }
    ]

```

The **metrics** templates follow the same process for copying, but uses **resourceIds** instead.

```json
    "variables": {
        "copy": [
            {
                "name": "memoryAvaliableBytes_copy",
                "count": "[length(parameters('resourceIds'))]",
                "input": "[parameters('resourceIds')[copyIndex('memoryAvaliableBytes_copy')]]"
            }
        ]
    },
```

The name however of resources uses the `GUID()` function to provide a unique name. This is because the resource name can be significanlty over the length allow for Alert names.

```json
"name": "[concat(variables('memoryAvaliableBytes_Name'),'_',guid(parameters('resourceIds')[copyIndex(0)]))]",

```

## Deploy

Once the templates have been configured, run the script `\DeployAzAlerts.PS1` like the examples below

**This must be in the same location as `DeployAZMetricsAlerts.ps1` and `DeployAzMultiResourceMetricsAlerts.ps1`**



### EXAMPLE 1 
This assumes the scripts are at the root of the template directories
```PowerShell
$Subscription = Get-AZSubscription | Select -first 1
$ResourceGroupName = "Contoso_Alerting_RG"
$ResourceGroupLocation = "uksouth"

.\DeployAzAlerts.ps1 -Subscription $Subscription -ResourceGroupName $ResourceGroupName -ResourceGroupLocation $ResourceGroupLocation 
```

### EXAMPLE 2
The configuration files are located in another location.
```PowerShell
$Subscription = Get-AZSubscription | Select -first 1
$ResourceGroupName = "Contoso_Alerting_RG"
$ResourceGroupLocation = "uksouth"
$ConfigFilePath = "\\ContosoFileShare\BaselineAlerts\DeployAzAlerts.config.json"

.\DeployAzAlerts.ps1 -Subscription $Subscription -ResourceGroupName $ResourceGroupName -ResourceGroupLocation $ResourceGroupLocation -ConfigFilePath $ConfigFilePath
```


# Known Issues / Limitations / Ideas
- All Alerts will deploy to one Resource group. This is by desgin. If you deploy to a different resource group on a second deployment, you will duplicate the alerts.

- The ARM templates deployment mode are defaulted to "Incremental", therefore if the script is re-run, alerts for resource that no longer exist will **not** be removed.

- Version 1 does not allow for scope exclusions or resource group targeting for it's scope. Working on this for Version 2

- Version 1 does not allow for different values for different resources of the same type in one subscription. Working on this for version 2

- Currently deploys templates in series to each subscription. I will look at parallel deployments for multiple subscriptions.

- Script has not been tested for collecting the template config from a remote location such as Github.

- Tags have not been accounted for. Currently tags can be authored in the template, but will apply to all alerts of that type in the template. Version 2 will work on copying tags from the targeted resource.

- PowerShell Scripts need to be changed into a module

- Need to create a cmdlet which creates the directory strucuture and the .JSON files from the config file.

