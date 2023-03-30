

$exclude_types = "Microsoft.Compute/restorePointCollections","microsoft.alertsManagement/smartDetectorAlertRules", "Microsoft.AlertsManagement/smartDetectorAlertRules", "Microsoft.Compute/proximityPlacementGroups", "Microsoft.Compute/snapshots", "Microsoft.Compute/virtualMachines/extensions", "microsoft.insights/actiongroups", "Microsoft.Insights/actiongroups", "microsoft.insights/metricalerts", "microsoft.visualstudio/account", "Microsoft.Web/certificates", "Microsoft.Web/connections"

$resources = Get-AzResource

$resources_notags = @()
foreach ( $resource in $resources)
{
    if ( $resource.ResourceType -notin $exclude_types )
    {
        if ( $resource.Tags.Count -eq 0)
        {
            $resources_notags += $resource
        } 
    }
}
$resources_notags.Count
$resources_notags.Name