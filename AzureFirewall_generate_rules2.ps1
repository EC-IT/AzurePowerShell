# MPE - 26 MARS 2021
# Generate AzureFirewall Rules from AzureFirewall Logs

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

# QUERY LOGS
$q='AzureDiagnostics | where Category == "AzureFirewallNetworkRule" and TimeGenerated > ago(24h) | distinct  msg_s'
$queryResults = Invoke-AzOperationalInsightsQuery -WorkspaceId "$WorkspaceID" -Query $q

# GET LOGS WITHOUT DNS, NTP, HTTP and HTTPS\
$result_no_http_dns = $( ($queryResults.Results) | ?{$_ -notmatch ':443\.'} | ?{$_ -notmatch ':80\.'} | ?{$_ -notmatch ':123\.'}  | ?{$_ -notmatch ':53\.'} | ?{$_ -notmatch 'ICMP'} )
$ip_destination = $( ($result_no_http_dns.msg_s) | Foreach-Object{ $_.Split(' ')[5] } | Foreach-Object{ $_.Split(':')[0] } | Sort-Object -Unique )

$rules_list = @()
$rules_array = @()
foreach ( $ip in $ip_destination )
{
    $s = $result_no_http_dns | ?{$_ -match $ip}
    $ports = $s.msg_s | Foreach-Object{ $_.Split(':')[2] }  | Sort-Object -Unique | Foreach-Object{ $_.Split('.')[0] }
    $ip_cours = $s.msg_s | Foreach-Object{ $_.Split(':')[0] }  | Sort-Object -Unique | Foreach-Object{ $_.Split(' ')[3] }

    $rules_list += echo $("SOURCE: ", $($ip_cours -join '')," DESTINATION : ",$($ip_cours -join ',')," :", $($ports -join ',') -join '')

    $rule = "" | Select ip_source,ip_destination,port_destination
    $rule.ip_destination  = $($ip.Split(':')[0])
    $rule.ip_source = $( $($ip_cours | Sort-Object -Unique) -join ',')
    $rule.port_destination = $($ports -join ',')
    $rules_array += $rule
}

$rules_array | Select  ip_destination, port_destination, ip_source


######

function AzureFireWall_Add_rule()
{
    New-AzFirewallNetworkRuleCollection -Name RC1 -Priority 100  -ActionType "Allow"
    $fwrules_list = @()
    foreach ( $rule in $rules_array)
    {
        $NetRule1 = New-AzFirewallNetworkRule -Name "Allow-1" -Protocol TCP -SourceAddress $rule.ip_source -DestinationAddress $rule.ip_destination -DestinationPort $rule.port_destination
    }

}