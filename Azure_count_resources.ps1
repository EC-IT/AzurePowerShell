

$subs = Get-AzSubscription

foreach ( $sub in $subs)
{
    Select-AzSubscription -Subscription $sub.Id
    echo $sub.Name

    $vm = Get-AzVM
    $app = Get-AzWebApp
    $sa = Get-AzStorageAccount
    $sqlserver = Get-AzSqlServer
    $bdd = @()
    foreach ( $server in $sqlserver)
    {
        $bdd += Get-AzSqlDatabase -ServerName $server.ServerName -ResourceGroupName $server.ResourceGroupName
    }

    $vm_nb = $vm.Count
    $app_nb = $app.Count
    $sa_nb = $sa.Count
    $bdd_nb = $bdd.Count

    echo "$($sub.Name). VM : ${vm_nb}, APP : ${app_nb}, SA : ${sa_nb}, SQL : ${bdd_nb}"
}
