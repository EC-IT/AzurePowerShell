
$sas = Get-AzStorageAccount

$ip_range = "147.161.224.0/19"

foreach ( $sa in $sas )
{
    $sa.StorageAccountName
    Add-AzStorageAccountNetworkRule -ResourceGroupName $sa.ResourceGroupName -AccountName $sa.StorageAccountName -IPAddressOrRange "147.161.224.0/19"
}