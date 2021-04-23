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

# Liste des IP connus dans les regles du parfeu
$AzureFirewall01 = Get-AzFirewall
$ip_trust = $AzureFirewall01.NetworkRuleCollections.Rules.DestinationAddresses | ?{$_ -notmatch '\*'} | ?{$_ -notmatch '/'} 

# QUERY LOGS
$q='AzureDiagnostics | where Category == "AzureFirewallNetworkRule" and msg_s contains "Deny" and TimeGenerated > ago(24h) | distinct  msg_s'
$queryResults = Invoke-AzOperationalInsightsQuery -WorkspaceId "$WorkspaceID" -Query $q

# GET LOGS NOT ALLOW
$result_not_allow = $( ($queryResults.Results) | ?{$_ -notmatch 'Allow'} )
$result_not_allow_uniq = $( $result_not_allow | ForEach-Object{($_ -split "\s+")[5]} | Sort-Object -Unique )

# liste des IP dans les logs
$ip_unique = $result_not_allow_uniq | Foreach-Object{ $_.Split(':')[0] }  | Sort-Object -Unique

# liste IP inconnu
$ip_unknown = $ip_unique 

echo "IP dans les LOGS, mais pas dans les regles de parfeu : "
$ip_unknown 
