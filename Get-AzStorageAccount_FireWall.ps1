# MPE - MAR2021

# liste SA
$list_sa = Get-AzStorageAccount

# Pour chaque SA recupe Firewall HTTPS TLS
$liste_sa_param = @()
foreach ($sa in $list_sa)
{
    $sa_param = "" | select StorageAccountName,FWDefaultAction,FWIpRules,EnableHttpsTrafficOnly,MinimumTlsVersion
    $sa_param.StorageAccountName = $sa.StorageAccountName
    $sa_param.FWDefaultAction = $sa.NetworkRuleSet.DefaultAction
    $sa_param.FWIpRules = $sa.NetworkRuleSet.IpRules.Count
    $sa_param.EnableHttpsTrafficOnly = $sa.EnableHttpsTrafficOnly
    $sa_param.MinimumTlsVersion = $sa.MinimumTlsVersion
    
    $liste_sa_param+=$sa_param
}

# Affiche 
$liste_sa_param | Format-Table