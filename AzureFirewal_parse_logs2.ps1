# MPE - oct 2020

# Get All WorkSpace
$all_workspace = Get-AzOperationalInsightsWorkspace

foreach ( $workspace in $all_workspace)
{
    # QUERY LOGS
    $q='AzureDiagnostics | where Category == "AzureFirewallNetworkRule" | distinct  msg_s'
    $queryResults = Invoke-AzOperationalInsightsQuery -WorkspaceId $workspace.CustomerId -Query $q

    # GET LOGS WITHOUT HTTP
    $result_no_http = $( ($queryResults.Results) | ?{$_ -notmatch ':443'} | ?{$_ -notmatch ':80'} )
    $result_no_http_uniq = $( $result_no_http | ForEach-Object{($_ -split "\s+")[5]} | Sort-Object -Unique )
    $result_no_http_uniq.Count


    # GET LOGS WITHOUT DNS AND HTTP
    $result_no_http_dns = $( ($queryResults.Results) | ?{$_ -notmatch ':443'} | ?{$_ -notmatch ':80'} | ?{$_ -notmatch ':53'} )
    $result_no_http_dns_uniq = $( $result_no_http_dns | ForEach-Object{($_ -split "\s+")[5]} | Sort-Object -Unique )
    $result_no_http_dns_uniq.Count

    $result_no_http_dns_uniq
}