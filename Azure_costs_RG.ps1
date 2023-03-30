


$rgs = Get-AzResourceGroup

$costs = @()
# Pour chaque ResourceGroup
foreach ( $rg in $rgs )
{
    $rg.ResourceGroupName
    $cost = "" | select InstanceName, ConsumedService, PretaxCost
    #$rg_price = Get-AzConsumptionUsageDetail -ResourceGroup $rg.ResourceGroupName |  Select-Object * 
    $rg_price = Get-AzConsumptionUsageDetail -ResourceGroup $rg.ResourceGroupName  -StartDate (Get-Date -Day 1).AddDays(-1).ToString("yyyy-MM-dd") -EndDate (Get-Date -Day 1).AddDays(-1).ToString("yyyy-MM-dd") |  Select-Object * 
    $cost = $rg_price | Where { $_.PretaxCost -gt 1 } | select InstanceName, ConsumedService, PretaxCost
    $costs += $cost
}


$costs | sort -Property PretaxCost -Descending
