# MPE - MARS/AVRIL 2021

function Get-AzWorkspaceID()
{
    $workspaces = Get-AzOperationalInsightsWorkspace
    foreach ( $workpace in $workspaces)
    {
        if ( $workpace.Name -notlike "*Default*" -and $workpace.Name -notlike "*Test*"  -and $workpace.Name -notlike "*dev*" )
        {
            return $workpace.CustomerId.Guid;
        }
    }
}
$WorkspaceID = Get-AzWorkspaceID

# List NSG
$nsg_list = Get-AzNetworkSecurityGroup 

# FOR EACH NSG...
foreach ($nsg in $nsg_list)
{
    $nsg_name = $nsg.Name
    echo "`n#### $nsg_name ####"

    # QUERY LOGS
    $q="AzureNetworkAnalytics_CL | where NSGList_s contains `"$nsg_name`" and TimeGenerated > ago(7d) | distinct NSGRule_s  "
    $queryResults = Invoke-AzOperationalInsightsQuery -WorkspaceId "$WorkspaceID" -Query $q
    $rules_in_logs = $( ($queryResults.Results) )

    # ...CHECK IF RULES IN LOGS
    foreach($rule in $nsg.SecurityRules)
    {
        if ( ! $($rules_in_logs | Select-String $rule.Name ) )   
        {
            $rule.Name
        }
    }
}
