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
$q='AzureDiagnostics | where Category == "AzureFirewallNetworkRule" and TimeGenerated > ago(24h) | distinct  msg_s'
$queryResults = Invoke-AzOperationalInsightsQuery -WorkspaceId "$WorkspaceID" -Query $q

# GET LOGS WITHOUT DNS, NTP, HTTP and HTTPS
$result_no_http_dns = $( ($queryResults.Results) | ?{$_ -notmatch ':443\.'} | ?{$_ -notmatch ':80\.'} | ?{$_ -notmatch ':123\.'}  | ?{$_ -notmatch ':53\.'} | ?{$_ -notmatch 'ICMP'})
$result_no_http_dns_uniq = $( $result_no_http_dns | ForEach-Object{($_ -split "\s+")[5]} | Sort-Object -Unique )

# liste des IP dans les logs
$ip_unique = $result_no_http_dns_uniq | Foreach-Object{ $_.Split(':')[0] }  | Sort-Object -Unique

# liste IP inconnu
$ip_unknown = $ip_unique | ?{$ip_trust -notcontains $_}

echo "IP dans les LOGS, mais pas dans les regles de parfeu : "
$ip_unknown 

# recherche port et adresse source
foreach ( $ip in $ip_unknown)
{
    echo "$ip"
    $s = ($queryResults.Results) | ?{$_ -match "$ip"}    
    echo "- Listes des ports destination :"
    $s.msg_s | Foreach-Object{ $_.Split(':')[2] }  | Sort-Object -Unique # liste PORT
    echo "- Listes des IP sources :"
    $s.msg_s | Foreach-Object{ $_.Split(':')[0] }  | Sort-Object -Unique  # liste IP source
}
