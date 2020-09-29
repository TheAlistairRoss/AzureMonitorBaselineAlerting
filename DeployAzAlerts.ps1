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
    $ResourceGroupLocation,
    
    # Location of the file "DeployAzAlerts.config.json". This is only required if not in the same directory as this script
    [string]
    $ConfigFilePath
)

Write-Verbose "`n`n`n## DeployAzAlerts Start ##################################################################`n"

## Test each and configure config file
$oConfigFile = "deployAzAlerts.config.json"
$ConfigFilePath = $ConfigFilePath.Trim("\")
$oTemplateFileName = "azure-deploy.json"
$oTemplateParametersFileName = "azure-deploy.parameters.json"

if ($ConfigFilePath)
{
    if ((Test-Path -Path $ConfigFilePath) -ne $true)
    {
        $oErrorString = "Path: '$ConfigFilePath' not found. Exiting Script"
        exit
    }
    else
    {
        $oVerboseString = "Path: '$ConfigFilePath' found. Testing config file" 
    }
}
else
{
    $ConfigFilePath = $PSScriptRoot
    $oVerboseString = "Setting Config File path to '$ConfigFilePath'"
    Write-Verbose $oVerboseString
}
    
if ($ConfigFilePath -notlike "$ConfigFilePath\$oConfigFile")
{
    $oConfigFile = "$ConfigFilePath\$oConfigFile"
    $oVerboseString = "Setting `$oConfigFile to '$oConfigFile'"
    Write-Verbose $oVerboseString
}
if ((Test-Path -Path $oConfigFile) -ne $true)
{
    $oErrorString = "Path: '$oConfigFile' not found. Exiting Script"
    exit
}
else
{
    $oHostString = "File '$oConfigFile' found. Getting Content"
    Write-Verbose $oHostString

    $oConfigFileDirectory = (Get-Item -Path $oConfigFile).Directory.FullName
}

# Get Config File Content
try
{
    $oConfig = Get-Content $oConfigFile -ErrorAction Stop | ConvertFrom-Json -AsHashtable -ErrorAction Stop
}
catch
{
    Write-Error $Error[0]
    exit
}

# Test Config File settings
foreach ($oConfigResourceType in $oConfig.keys)
{
    foreach ($oTemplateDirectory in $oConfig.$oConfigResourceType.templateDirectories)
    {
        $oPath = "$oConfigFileDirectory\$($oConfig.$oConfigResourceType.resourceTemplateDirectory)\$($oTemplateDirectory.directory)"
        If ((Test-Path -Path $oPath) -eq $false)
        {
            $oErrorString = "Path '$oPath' not found. Ensure valid template directory." 
            Write-Error -Message $oErrorString
            $oTemplateDirectory.pathTest = $false
            exit
        }
        else
        {
            $oVerboseString = "Path '$oPath' found." 
            Write-Verbose $oVerboseString
            $oTemplateDirectory.directory = $oPath

            Foreach ($file in @($oTemplateFileName, $oTemplateParametersFileName))
            {
                $oFileFullPath = "$($oTemplateDirectory.directory)\$file"
                if ((Test-Path -Path $oFileFullPath) -eq $false)
                {
                    $oErrorString = "Path '$oFileFullPath' not found. 'Ensure azure-deploy.json' and 'azure-deploy.parameters.json' exists in the directory"
                    Write-Error -Message $oErrorString
                    exit
                }
            }
            $oTemplateDirectory.pathTest = $true
        }
    }
}

$oVerboseString = "Path Test Results"
Write-Verbose $oVerboseString
$oConfig | ConvertTo-Json -EnumsAsString -Depth 5 | Write-Verbose 


# Validate PowerShell
if ($PSVersionTable.PSVersion -lt $Version)
{
    $oErrorString = "PowerShell Version is '$($PSVersionTable.PSVersion)' and requires upgrading to Version 6"
    Write-Error -Message $oErrorString
    exit
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

            foreach ($oTemplateDirectory in $oConfig.$oResourceType.templateDirectories)
            {
                if ($oTemplateDirectory.pathTest -like $true -and $oTemplateDirectory.directory -match "\\multiResourceMetrics")
                {
                    $oCommand = "$PSScriptRoot\DeployAzMultiResourceMetricsAlerts.PS1"
                    $oVerboseString = "Setting Command to $oCommand"
                    Write-Verbose $oVerboseString
                }
                elseif ($oTemplateDirectory.pathTest -like $true -and $oTemplateDirectory.directory -match "\\metrics")
                {
                    $oCommand = "$PSScriptRoot\DeployAzMetricsAlerts.PS1"
                    $oVerboseString = "Setting Command to $oCommand"
                    Write-Verbose $oVerboseString
                }
                else
                {
                    $oErrorString = "Path test or resource directory not correct. Review previous test results"
                    Write-Error $oErrorString
                    Break
                }
                $oVerboseString = "Script: $oCommand -Subscription `$oSubscription -ResourceGroup `$oResourceGroup -Resources `$oFilteredResources -ConfigDirectory `$oTemplateDirectory.directory"
                Write-Verbose $oVerboseString

                & $oCommand -Subscription $oSubscription -ResourceGroup $oResourceGroup -Resources $oFilteredResources -ConfigDirectory $oTemplateDirectory.directory
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
