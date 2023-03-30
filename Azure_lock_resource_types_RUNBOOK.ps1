#MPE - Sept 2021
# Lock ResourceType
Import-Module Az.Resources

#Connection
$connectionName = "AzureRunAsConnection"
$servicePrincipalConnection = Get-AutomationConnection -Name $connectionName  
Add-AzAccount -ServicePrincipal -TenantId $servicePrincipalConnection.TenantId -ApplicationId $servicePrincipalConnection.ApplicationId -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint

$resources = Get-AzResource 
$locks = Get-AzResourceLock
$types_to_lock = "Microsoft.ApiManagement/service","Microsoft.Authorization/locks","Microsoft.Automation/automationAccounts/runbooks","Microsoft.Automation/automationAccounts/variables","Microsoft.Compute/disks","Microsoft.Compute/virtualMachines","Microsoft.KeyVault/vaults","Microsoft.NetApp/netAppAccounts","Microsoft.NetApp/netAppAccounts/capacityPools","Microsoft.NetApp/netAppAccounts/capacityPools/volumes","Microsoft.NetApp/netAppAccounts/snapshotPolicies","Microsoft.Network/applicationGateways","Microsoft.Network/azureFirewalls","Microsoft.Network/loadBalancers","Microsoft.Network/networkInterfaces","Microsoft.Network/networkSecurityGroups","Microsoft.Network/privateDnsZones","Microsoft.Network/privateDnsZones/virtualNetworkLinks","Microsoft.Network/privateEndpoints","Microsoft.Network/publicIPAddresses","Microsoft.Network/routeTables","Microsoft.Network/virtualNetworks","Microsoft.OperationalInsights/workspaces","Microsoft.Portal/dashboards","Microsoft.RecoveryServices/vaults","Microsoft.Sql/servers","Microsoft.Sql/servers/elasticpools","Microsoft.Storage/storageAccounts","Microsoft.Web/hostingEnvironments","Microsoft.Web/sites"

# add lock to ressource
function lock-resource()
{
    param($resource)
    New-AzResourceLock -LockLevel CanNotDelete -LockName "SCRIPT-LOCK-TYPES" -ResourceName $resource.Name -ResourceType $resource.ResourceType -ResourceGroupName $resource.ResourceGroupName -Force
}

function lockResourceType()
{
    if ( !$global:locks ) { $global:locks = Get-AzResourceLock}
    if ( !$global:resources  ) { $global:resources = Get-AzResource }
    $locksResourceName = $locks.ResourceName

    # pour chaque resource
    foreach ( $resource in $resources )
    {
        # si elle faite parti de la liste des Types a verouille
        if ($resource.ResourceType -in $types_to_lock)
        {
            # si elle n'est pas deja verouille
            if ( ! $locksResourceName.Contains($resource.Name) -and ! $resource.Name.ToLower().Contains("test") )
            {
                #echo $resource.Name
                lock-resource $resource
                #Start-Sleep 10
            }
        }
    }
}

if ($servicePrincipalConnection)
{
    lockResourceType
}