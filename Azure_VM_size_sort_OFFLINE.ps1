# MPE - JUIN 2021
# SORT VM SIZE 

# download price list from prices.azure.com/api/retail/prices
function get-list_vmprice()
{
    param($name, $region="westeurope", $currency="EUR" )


    $query = "currencyCode='" + "$currency" + "'&`$filter=serviceName eq 'Virtual Machines' and armRegionName eq '" + "$region" + "' and priceType eq 'Consumption' and serviceFamily eq 'Compute' and endswith(productName, 'Windows')  and startswith(armSkuName, 'Standard_')"
    $query = $query.Replace(' ','%20')
    $query = $query.Replace("'",'%27')

    $uri = "https://prices.azure.com/api/retail/prices?$query"
    $webReq = Invoke-WebRequest -Uri  "$uri" | ConvertFrom-Json
    $items = $webReq.Items
    
    $a=0
    $items_full = $items

    while ( $items_full.Count -lt 10000 -and $a -lt 100 )
    {

    if ( $items.Count -eq 100 )
        {
        $size=$items_full.Count
        $webReq = Invoke-WebRequest -Uri  "$uri&`$skip=$size" | ConvertFrom-Json
        $items = $webReq.Items

        $items_full += $items

        }

        $a++
    }
    $items_full
}

# save price list in Azure_vm_list_price.xml
function save-list_vmprice()
{
    param($path_file_vm_list_price="C:\Temp\Azure_vm_list_price.xml")

    if (! $global:list_vmprice )
    {
        $global:list_vmprice = get-list_vmprice
    }
    $list_vmprice_serialize = [System.Management.Automation.PSSerializer]::Serialize($list_vmprice)
    $list_vmprice_serialize | Out-File $path_file_vm_list_price

}

# load price list in Azure_vm_list_price.xml
function load-list_vmprice()
{
    param($path_file_vm_list_price="C:\Temp\Azure_vm_list_price.xml")

    if (! $global:list_vmprice )
    {
        if (Test-Path $path_file_vm_list_price -PathType leaf)
        {
            $list_vmprice_serialize = Get-Content $path_file_vm_list_price
            $global:list_vmprice = [System.Management.Automation.PSSerializer]::Deserialize($list_vmprice_serialize)
        }
        else
        {
            save-list_vmprice -path_file_vm_list_price $path_file_vm_list_price
        }

    }
}

# download vm size list
function get-list_vmsize()
{
    Param($region="westeurope")

    if (! $global:vmsize )
    {
        $global:vmsize  = Get-AzComputeResourceSku  | where {$_.Locations.Contains("$region") -and $_.ResourceType.Contains("virtualMachines") }
    }
}

# save size list in Azure_vm_list_size.json
function save-list_vmsize()
{
    param($path_file_vm_list_size="C:\Temp\Azure_vm_list_size.json")

    if (! $global:vmsize )
    {
        get-list_vmsize
    }
    
    $list_vmsize_serialize = $vmsize | ConvertTo-Json -Depth 3
    $list_vmsize_serialize | Out-File $path_file_vm_list_size
}

# load size list in Azure_vm_list_size.json
function load-list_vmsize()
{
    param($path_file_vm_list_size="C:\Temp\Azure_vm_list_size.json")

    if (! $global:vmsize )
    {    
        if (Test-Path $path_file_vm_list_size -PathType leaf)
        {
            $list_vmsize_serialize = Get-Content $path_file_vm_list_size
            $global:vmsize = $list_vmsize_serialize | ConvertFrom-Json
        }
        else
        {
            save-list_vmsize -path_file_vm_list_size $path_file_vm_list_siz
        }
    }
}

# get vm size from name
function get-vmsize_name_list()
{
    param($name)

    if ( $global:vmsize )
    {
        foreach ( $size in $global:vmsize)
        {
            if ( $size.Name -eq "$name")
            {
                $size
            }
        }
    }
}


# get vm price
function get-vmprice_in_list()
{
    param($name)
    
    load-list_vmprice

    if ( $global:list_vmprice )
    {
        foreach ( $item in $global:list_vmprice)
        {
            if ( $item.armSkuName -eq "$name")
            {
                if ( ! ($item.skuName -match "Low" -or $item.skuName -match "Spot") )
                {
                    #echo $item.armSkuName
                    [math]::Round([float]$item[0].unitPrice * 730,2)
                }
            }
        }
    }
}


# filter vm size
function get-vmsize()
{
    Param($cpu_min=0, $cpu_max=1024, $ram_min=0, $ram_max=1024, $iops_min=0, $iops_max=100000, $price_max=0, [switch]$crypt_support, [switch]$net_support, [switch]$ssd_support, [switch]$verbose, $region="westeurope")

    if (! $global:vmsize )
    {
        load-list_vmsize
    }

    foreach ( $size in $vmsize)
    {
        $name = $size.Name
        $cpu = [int]$($size.Capabilities | where { $_.Name -eq "vCPUs" }).Value
        $ram = [int]$($size.Capabilities | where { $_.Name -eq "MemoryGB" }).Value
        $iops = [int]$($size.Capabilities | where { $_.Name -eq "UncachedDiskIOPS" }).Value
        $crypt = $($size.Capabilities | where { $_.Name -eq "EncryptionAtHostSupported" }).Value
        $net =  $($size.Capabilities | where { $_.Name -eq "AcceleratedNetworkingEnabled" }).Value
        $ssd =  $($size.Capabilities | where { $_.Name -eq "PremiumIO" }).Value

        if ( ($cpu -ge $cpu_min) -and ($cpu -le $cpu_max) -and ($ram -ge $ram_min) -and ($ram -le $ram_max) -and ($iops -ge $iops_min) -and ($iops -le $iops_max) )
        {
            
            if( ( !$crypt_support -or $crypt -eq "True" ) -and ( !$net_support -or $net -eq "True" ) -and ( !$ssd_support -or $ssd -eq "True" ) )
            {  
                if ( $price_max -gt 0 )
                {
                    $namesize = $size.Name
                    $prix = get-vmprice_in_list -name $namesize 
                    if ($prix -eq $null ) { $prix=999999 }
                }

                if ( $price_max -eq 0 -or $prix -le $price_max )
                {
                    if ( $verbose )
                    {
                        echo "$name $cpu $ram $iops $prix"
                    }
                    else
                    {       
                        $size.Name
                    }
                }
            }
        }
    }
}

# GET VM SIZE CPU>2 RAM>4Gb IOPS>8000 PRICE<600
get-vmsize -cpu_min 2 -ram_min 4 -iops_min 8000 -net_support -crypt_support -ssd_support -price_max 600 -verbose